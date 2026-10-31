/**
 * PCU Connect: Firestore side of the backend (docs/BACKEND_PLAN.md, phase 1).
 *
 * Apps Script talks to Firestore through the REST API with a service account
 * whose JSON key lives only in the Script Property FIRESTORE_SA_KEY. Without
 * that property every function here is a no-op, so the existing API keeps
 * working exactly as before.
 *
 * Phase 1 field ownership: the sheet is still where work is saved (through
 * the Apps Script API), so guests are sent with all their fields. From phase
 * 2 the app writes work fields itself and only sheet-owned fields are sent.
 *
 * Long jobs use batch writes (up to 500 per commit), stop before the Apps
 * Script time limit, and keep a progress marker in Script Properties so the
 * next trigger continues where the last one stopped. Every write is keyed by
 * a stable id, so running a job twice changes nothing.
 */

var PCU_FS = {
  KEY_PROPERTY: 'FIRESTORE_SA_KEY',
  SCOPE: 'https://www.googleapis.com/auth/datastore',
  TOKEN_URL: 'https://oauth2.googleapis.com/token',
  API: 'https://firestore.googleapis.com/v1',
  BATCH_SIZE: 500,
  TIME_BUDGET_MS: 4.5 * 60 * 1000,
  STALE_MARKER_MS: 30 * 60 * 1000,
  // Extra guest columns used for sending. Both are optional.
  SYNCED_AT: 'SYNCED AT',
  SYNC_KEY: 'SYNC KEY',
  // Months of history copied by the migration.
  MIGRATION_MONTHS: 12
};

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------

/** Trimmed, lowercased email. Used for every email the backend stores or compares. */
function pcuEmail_(value) {
  return pcuStr_(value).toLowerCase();
}

function pcuHex_(bytes) {
  return bytes
    .map(function (b) {
      var v = (b < 0 ? b + 256 : b).toString(16);
      return v.length === 1 ? '0' + v : v;
    })
    .join('');
}

/**
 * Stable GUEST ID for a row that has none: "G-" plus the first 8 hex
 * characters of SHA-256 over the Africa/Lagos timestamp and the phone digits.
 * The same row always gives the same ID, so re-runs never duplicate.
 */
function pcuStableGuestId_(timestamp, phone) {
  var isDate = Object.prototype.toString.call(timestamp) === '[object Date]';
  var stamp = isDate ? Utilities.formatDate(timestamp, PCU.TZ, "yyyy-MM-dd'T'HH:mm:ss") : pcuStr_(timestamp);
  var digits = pcuStr_(phone).replace(/\D/g, '');
  var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, stamp + '|' + digits);
  return 'G-' + pcuHex_(digest).substring(0, 8).toUpperCase();
}

function pcuFsEnabled_() {
  return !!PropertiesService.getScriptProperties().getProperty(PCU_FS.KEY_PROPERTY);
}

function pcuFsKey_() {
  var raw = PropertiesService.getScriptProperties().getProperty(PCU_FS.KEY_PROPERTY);
  if (!raw) throw pcuError_('SERVER', 'Firestore is not set up yet.');
  return JSON.parse(raw);
}

// ---------------------------------------------------------------------------
// Access token (service account JWT, cached for 55 minutes)
// ---------------------------------------------------------------------------

function pcuB64_(value) {
  return Utilities.base64EncodeWebSafe(value).replace(/=+$/, '');
}

function pcuFsToken_() {
  var cache = CacheService.getScriptCache();
  var cached = cache.get('pcu.fs.token');
  if (cached) return cached;

  var key = pcuFsKey_();
  var now = Math.floor(Date.now() / 1000);
  var header = pcuB64_(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  var claims = pcuB64_(
    JSON.stringify({
      iss: key.client_email,
      scope: PCU_FS.SCOPE,
      aud: key.token_uri || PCU_FS.TOKEN_URL,
      iat: now,
      exp: now + 3600
    })
  );
  var signature = pcuB64_(Utilities.computeRsaSha256Signature(header + '.' + claims, key.private_key));
  var res = UrlFetchApp.fetch(key.token_uri || PCU_FS.TOKEN_URL, {
    method: 'post',
    payload: {
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: header + '.' + claims + '.' + signature
    },
    muteHttpExceptions: true
  });
  if (res.getResponseCode() !== 200) {
    throw pcuError_('SERVER', 'Firestore sign-in failed (' + res.getResponseCode() + ').');
  }
  var token = JSON.parse(res.getContentText()).access_token;
  cache.put('pcu.fs.token', token, 3300);
  return token;
}

function pcuFsDocsBase_() {
  var key = pcuFsKey_();
  return 'projects/' + key.project_id + '/databases/(default)/documents';
}

// ---------------------------------------------------------------------------
// Value encoding
// ---------------------------------------------------------------------------

function pcuFsValue_(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (v instanceof Date) return isNaN(v.getTime()) ? { nullValue: null } : { timestampValue: v.toISOString() };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(pcuFsValue_) } };
  if (typeof v === 'object') return { mapValue: { fields: pcuFsFields_(v) } };
  return { stringValue: String(v) };
}

function pcuFsFields_(obj) {
  var fields = {};
  Object.keys(obj).forEach(function (k) {
    fields[k] = pcuFsValue_(obj[k]);
  });
  return fields;
}

/**
 * A write that sets exactly the given fields and leaves every other field of
 * the document alone (update mask), creating the document if needed.
 */
function pcuFsSet_(path, data) {
  return {
    update: { name: pcuFsDocsBase_() + '/' + path, fields: pcuFsFields_(data) },
    updateMask: { fieldPaths: Object.keys(data) }
  };
}

/** Commits writes in batches of up to 500. Returns the number written. */
function pcuFsCommit_(writes) {
  if (!writes.length) return 0;
  var url = PCU_FS.API + '/' + pcuFsDocsBase_() + ':commit';
  for (var i = 0; i < writes.length; i += PCU_FS.BATCH_SIZE) {
    var chunk = writes.slice(i, i + PCU_FS.BATCH_SIZE);
    var res = UrlFetchApp.fetch(url, {
      method: 'post',
      contentType: 'application/json',
      headers: { Authorization: 'Bearer ' + pcuFsToken_() },
      payload: JSON.stringify({ writes: chunk }),
      muteHttpExceptions: true
    });
    if (res.getResponseCode() !== 200) {
      throw pcuError_('SERVER', 'Firestore write failed (' + res.getResponseCode() + '): ' + res.getContentText().substring(0, 300));
    }
  }
  return writes.length;
}

// ---------------------------------------------------------------------------
// Document builders
// ---------------------------------------------------------------------------

function pcuUserDoc_(w) {
  return {
    name: w.name,
    email: pcuEmail_(w.email),
    phone: w.phone || '',
    role: w.isAdmin ? 'admin' : 'worker',
    active: !!w.active
  };
}

/** Attendance dates (yyyy-MM-dd) from the first visit and follow-ups. */
function pcuAttendanceDates_(guest, followUps) {
  var sundays = {};
  var wednesdays = {};
  if (guest.serviceDate) (pcuIsWednesday_(guest.serviceDate) ? wednesdays : sundays)[pcuDay_(guest.serviceDate)] = true;
  followUps.forEach(function (f) {
    if (f.sunday) sundays[pcuDay_(f.sundayDate || f.date)] = true;
    if (f.wednesday) wednesdays[pcuDay_(f.wednesdayDate || f.date)] = true;
  });
  return { sundays: Object.keys(sundays).sort(), wednesdays: Object.keys(wednesdays).sort() };
}

/** Sheet-owned guest fields. */
function pcuGuestSheetFields_(guest, workers) {
  var assigned = workers.byEmail[guest.assignedTo];
  return {
    name: guest.name,
    phone: guest.phone,
    serviceDate: guest.serviceDay,
    month: guest.month,
    assignedTo: pcuEmail_(guest.assignedTo),
    assignedName: assigned ? assigned.name : '',
    assignedDate: guest.assignedDate || null,
    sheetRow: guest.rowIndex + 2
  };
}

/** Work fields, as the sheet holds them during phase 1. */
function pcuGuestWorkFields_(guest, followUps) {
  var attendance = pcuAttendanceDates_(guest, followUps);
  var first = followUps[0];
  return {
    callStatus: guest.callStatus || '',
    membershipStatus: guest.status || PCU.STATUS.NEW,
    followUpCount: pcuCallCount_(guest, followUps),
    firstCallAt: first && first.date ? first.date : null,
    lastFeedback: guest.lastFeedback || guest.feedback2 || guest.feedback1 || '',
    lastFeedbackDate: guest.lastFeedbackDate || guest.feedback2Date || guest.feedback1Date || null,
    teamJoined: guest.team || '',
    memberSince: guest.membershipDate || null,
    sundayDates: attendance.sundays,
    wednesdayDates: attendance.wednesdays
  };
}

function pcuGuestDoc_(guest, followUps, workers) {
  var doc = pcuGuestSheetFields_(guest, workers);
  var work = pcuGuestWorkFields_(guest, followUps);
  Object.keys(work).forEach(function (k) {
    doc[k] = work[k];
  });
  return doc;
}

/**
 * Points earned by each follow-up of one guest, using the same rules as the
 * leaderboard: first call on time +10 (else +5), +10 per attendance, +20 for
 * the first team join, +30 on the follow-up that made the guest a member.
 */
function pcuFollowUpPoints_(guest, followUps) {
  var P = PCU.POINTS;
  var teamSeen = !!(guest.team && !followUps.some(function (f) { return !!f.team; }));
  var points = [];
  var replay = { serviceDate: guest.serviceDate, serviceDay: guest.serviceDay, status: PCU.STATUS.NEW, followUpCount: 0 };
  followUps.forEach(function (f, i) {
    var p = i === 0 && pcuFirstCallOnTime_(guest, followUps) ? P.FIRST_CALL : P.FOLLOW_UP;
    p += ((f.sunday ? 1 : 0) + (f.wednesday ? 1 : 0)) * P.ATTENDANCE;
    if (f.team && !teamSeen) {
      p += P.TEAM_JOIN;
      teamSeen = true;
    }
    var before = replay.status;
    replay.status = pcuNextStatus_(replay, followUps.slice(0, i + 1));
    if (before !== PCU.STATUS.MEMBER && replay.status === PCU.STATUS.MEMBER) p += P.MEMBER;
    points.push(p);
  });
  return points;
}

function pcuFollowUpDoc_(f, points) {
  var callDay = pcuDay_(f.date);
  return {
    guestId: f.guestId,
    worker: pcuEmail_(f.workerEmail),
    loggedBy: pcuEmail_(f.loggedBy || f.workerEmail),
    callDate: callDay,
    month: pcuMonth_(f.date),
    outcome: f.outcome,
    note: f.note || '',
    attendedSunday: !!f.sunday,
    sundayDate: f.sunday ? pcuDay_(f.sundayDate || f.date) : '',
    attendedWednesday: !!f.wednesday,
    wednesdayDate: f.wednesday ? pcuDay_(f.wednesdayDate || f.date) : '',
    team: f.team || '',
    points: points,
    syncedToSheet: true,
    createdAt: f.date || null
  };
}

/** Writes for one guest and all its follow-ups. */
function pcuGuestWrites_(guest, followUps, workers) {
  var writes = [pcuFsSet_('guests/' + guest.id, pcuGuestDoc_(guest, followUps, workers))];
  var points = pcuFollowUpPoints_(guest, followUps);
  followUps.forEach(function (f, i) {
    if (f.id) writes.push(pcuFsSet_('followUps/' + f.id, pcuFollowUpDoc_(f, points[i])));
  });
  return writes;
}

/** Fingerprint of what was last sent for a guest, stored in SYNC KEY. */
function pcuGuestSyncKey_(guest, followUps, workers) {
  var digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    JSON.stringify(pcuGuestDoc_(guest, followUps, workers)) + '|' + followUps.length
  );
  return pcuHex_(digest).substring(0, 16);
}

// ---------------------------------------------------------------------------
// GUEST IDs
// ---------------------------------------------------------------------------

/**
 * Gives every row with a name or phone a stable GUEST ID. Rows whose ID would
 * collide with an existing one are logged and skipped for a person to check.
 * Returns the number of IDs written.
 */
function pcuEnsureGuestIds_() {
  var t = pcuTable_(PCU.SHEETS.GUESTS, true);
  if (pcuCol_(t, PCU.G.ID) < 0) return 0;
  var seen = {};
  t.rows.forEach(function (row) {
    var id = pcuStr_(pcuCell_(t, row, PCU.G.ID));
    if (id) seen[id] = true;
  });
  var written = 0;
  t.rows.forEach(function (row, i) {
    if (pcuStr_(pcuCell_(t, row, PCU.G.ID))) return;
    var name = pcuStr_(pcuCell_(t, row, PCU.G.NAME));
    var phone = pcuStr_(pcuCell_(t, row, PCU.G.PHONE));
    if (!name && !phone) return;
    var id = pcuStableGuestId_(pcuCell_(t, row, PCU.G.TIMESTAMP), phone);
    if (seen[id]) {
      console.warn('GUEST ID ' + id + ' already used; row ' + (i + 2) + ' needs a person to check it.');
      return;
    }
    pcuSetCell_(t, i, PCU.G.ID, id);
    seen[id] = true;
    written++;
  });
  return written;
}

// ---------------------------------------------------------------------------
// Progress markers for long jobs
// ---------------------------------------------------------------------------

function pcuMarkerKey_(job) {
  return 'PCU_JOB_' + job;
}

function pcuReadMarker_(job) {
  var raw = PropertiesService.getScriptProperties().getProperty(pcuMarkerKey_(job));
  return raw ? JSON.parse(raw) : null;
}

function pcuWriteMarker_(job, marker) {
  var props = PropertiesService.getScriptProperties();
  if (marker) props.setProperty(pcuMarkerKey_(job), JSON.stringify(marker));
  else props.deleteProperty(pcuMarkerKey_(job));
}

/**
 * Runs [step] over items until the time budget is used. With [resumable] it
 * starts at the saved marker and saves a new one when it stops early, so the
 * next trigger continues (for lists that stay the same between runs). Without
 * it the job always starts at the top (for lists that shrink as work is done).
 * step(item) returns an array of writes. Returns { done, processed, written }.
 */
function pcuRunJob_(job, items, step, resumable) {
  var started = Date.now();
  var saved = resumable ? pcuReadMarker_(job) : null;
  var marker = saved || { next: 0, startedAt: new Date().toISOString() };
  var writes = [];
  var processed = 0;
  var written = 0;
  var i = marker.next;
  for (; i < items.length; i++) {
    writes = writes.concat(step(items[i]));
    processed++;
    if (writes.length >= PCU_FS.BATCH_SIZE) {
      written += pcuFsCommit_(writes);
      writes = [];
      if (Date.now() - started > PCU_FS.TIME_BUDGET_MS) {
        i++;
        break;
      }
    }
  }
  written += pcuFsCommit_(writes);
  var done = i >= items.length;
  if (resumable) {
    pcuWriteMarker_(job, done ? null : { next: i, startedAt: marker.startedAt, updatedAt: new Date().toISOString() });
  }
  return { done: done, processed: processed, written: written };
}

/** Script lock so jobs never run twice at the same time. */
function pcuWithLock_(fn) {
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) return { skipped: 'busy' };
  try {
    return fn();
  } finally {
    lock.releaseLock();
  }
}

// ---------------------------------------------------------------------------
// Users
// ---------------------------------------------------------------------------

/** Writes every row of the Workers tab to users/{email}. */
function pcuSyncUsers_() {
  if (!pcuFsEnabled_()) return 0;
  var workers = pcuWorkers_();
  return pcuFsCommit_(
    workers.list.map(function (w) {
      return pcuFsSet_('users/' + pcuEmail_(w.email), pcuUserDoc_(w));
    })
  );
}

/** Trims and lowercases every email in the Workers tab. Returns rows changed. */
function pcuNormaliseWorkerEmails_() {
  var t = pcuTable_(PCU.SHEETS.WORKERS, true);
  var changed = 0;
  t.rows.forEach(function (row, i) {
    var raw = pcuCell_(t, row, PCU.W.EMAIL);
    var clean = pcuEmail_(raw);
    if (clean && clean !== raw) {
      pcuSetCell_(t, i, PCU.W.EMAIL, clean);
      changed++;
    }
  });
  return changed;
}

// ---------------------------------------------------------------------------
// Sending guests
// ---------------------------------------------------------------------------

/** Sends one guest (and its follow-ups) now. Used after assignment and after a save. */
function pcuPushGuest_(guestId) {
  if (!pcuFsEnabled_()) return 0;
  var guests = pcuGuestRows_(true);
  var guest = pcuFindGuest_(guests, guestId);
  if (!guest || !guest.assignedTo) return 0;
  var followUps = pcuFollowUps_(true).byGuest[guest.id] || [];
  var workers = pcuWorkers_();
  var written = pcuFsCommit_(pcuGuestWrites_(guest, followUps, workers));
  pcuSetCell_(guests.table, guest.rowIndex, PCU_FS.SYNC_KEY, pcuGuestSyncKey_(guest, followUps, workers));
  pcuSetCell_(guests.table, guest.rowIndex, PCU_FS.SYNCED_AT, new Date());
  return written;
}

/** Same as pcuPushGuest_, but never fails the caller. */
function pcuPushGuestQuietly_(guestId) {
  try {
    return pcuPushGuest_(guestId);
  } catch (err) {
    console.warn('Could not send guest ' + guestId + ' to Firestore: ' + (err && err.message));
    return 0;
  }
}

/**
 * Every 5 minutes: stable IDs for new rows, then send each assigned guest
 * whose fields changed since it was last sent (new guests, reassignments,
 * new follow-ups). Only the last MIGRATION_MONTHS months are considered.
 */
function pcuPushPendingGuests() {
  if (!pcuFsEnabled_()) return { skipped: 'not set up' };
  return pcuWithLock_(function () {
    pcuEnsureGuestIds_();
    var guests = pcuGuestRows_(true);
    var followUps = pcuFollowUps_(true);
    var workers = pcuWorkers_();
    var oldest = pcuRecentMonths_(PCU_FS.MIGRATION_MONTHS)[0];
    var syncKeyCol = pcuCol_(guests.table, PCU_FS.SYNC_KEY);

    var pending = guests.list.filter(function (g) {
      if (!g.assignedTo || g.month < oldest) return false;
      var sent = syncKeyCol < 0 ? '' : pcuStr_(guests.table.rows[g.rowIndex][syncKeyCol]);
      return sent !== pcuGuestSyncKey_(g, followUps.byGuest[g.id] || [], workers);
    });

    var result = pcuRunJob_('push', pending, function (g) {
      return pcuGuestWrites_(g, followUps.byGuest[g.id] || [], workers);
    }, false);
    // Mark what has been sent so the next run skips it.
    var now = new Date();
    pending.slice(0, result.processed).forEach(function (g) {
      pcuSetCell_(guests.table, g.rowIndex, PCU_FS.SYNC_KEY, pcuGuestSyncKey_(g, followUps.byGuest[g.id] || [], workers));
      pcuSetCell_(guests.table, g.rowIndex, PCU_FS.SYNCED_AT, now);
    });
    result.pending = pending.length;
    return result;
  });
}

// ---------------------------------------------------------------------------
// Migration (run by hand, repeat until it says done)
// ---------------------------------------------------------------------------

/**
 * Copies users, then the last 12 months of guests with their follow-ups.
 * Safe to run again at any time. Run it from the editor until the log says
 * "done"; each run continues from the saved marker.
 */
function pcuMigrate() {
  if (!pcuFsEnabled_()) throw new Error('Set FIRESTORE_SA_KEY first.');
  return pcuWithLock_(function () {
    pcuNormaliseWorkerEmails_();
    var users = pcuSyncUsers_();
    pcuEnsureGuestIds_();
    var guests = pcuGuestRows_(true);
    var followUps = pcuFollowUps_(true);
    var workers = pcuWorkers_();
    var oldest = pcuRecentMonths_(PCU_FS.MIGRATION_MONTHS)[0];
    var list = guests.list.filter(function (g) {
      return g.month >= oldest;
    });
    var result = pcuRunJob_('migrate', list, function (g) {
      return pcuGuestWrites_(g, followUps.byGuest[g.id] || [], workers);
    }, true);
    result.users = users;
    result.guests = list.length;
    console.log('Migration ' + (result.done ? 'done' : 'paused, run again') + ': ' + JSON.stringify(result));
    return result;
  });
}

/** Clears the migration marker so the next run starts from the top. */
function pcuMigrateRestart() {
  pcuWriteMarker_('migrate', null);
}

/** Manual check after setting or rotating the key: sends users only. */
function pcuFirestoreCheck() {
  var n = pcuSyncUsers_();
  console.log('Firestore OK. ' + n + ' users written.');
  return n;
}

/**
 * Adds the optional SYNCED AT and SYNC KEY columns to the guests tab if they
 * are missing. Run once by hand on the test sheet. Without them every 5-minute
 * run sends all recent guests again (harmless, just slower).
 */
function pcuSetupSyncColumns() {
  var t = pcuTable_(PCU.SHEETS.GUESTS, true);
  [PCU_FS.SYNCED_AT, PCU_FS.SYNC_KEY].forEach(function (header) {
    if (pcuCol_(t, header) >= 0) return;
    var col = t.headers.length + 1;
    t.sheet.getRange(1, col).setValue(header);
    t.headers.push(header);
  });
  pcuTable_(PCU.SHEETS.GUESTS, true);
}

/** Creates the 5-minute trigger for pcuPushPendingGuests (run once by hand). */
function pcuInstallFirestoreTriggers() {
  ScriptApp.getProjectTriggers().forEach(function (t) {
    if (t.getHandlerFunction() === 'pcuPushPendingGuests') ScriptApp.deleteTrigger(t);
  });
  ScriptApp.newTrigger('pcuPushPendingGuests').timeBased().everyMinutes(5).create();
}
