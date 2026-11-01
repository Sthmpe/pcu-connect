/**
 * PCU Connect: Firestore side of the backend (docs/BACKEND_PLAN.md, phase 1).
 *
 * Apps Script talks to Firestore through the REST API with a service account
 * whose JSON key lives only in the Script Property FIRESTORE_SA_KEY. Without
 * that property every function here is a no-op, so the existing API keeps
 * working exactly as before.
 *
 * Field ownership (phase 2): the app writes follow-ups and the guest work
 * fields straight to Firestore. The 5-minute job and the assignment push send
 * only sheet-owned fields (name, phone, service date, ASSIGNED TO), plus the
 * work fields the first time a guest is sent. The sheet sync below copies the
 * work back to the sheet.
 *
 * Long jobs use batch writes (up to 500 per commit), stop before the Apps
 * Script time limit, and keep a progress marker in Script Properties so the
 * next trigger continues where the last one stopped. Every write is keyed by
 * a stable id, so running a job twice changes nothing.
 */

var PCU_FS = {
  KEY_PROPERTY: 'FIRESTORE_SA_KEY',
  // Firestore, plus Cloud Messaging for web push (Firebase Cloud Messaging API).
  SCOPE: 'https://www.googleapis.com/auth/datastore https://www.googleapis.com/auth/firebase.messaging',
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
  var cached = cache.get('pcu.fs.token.v2');
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
  cache.put('pcu.fs.token.v2', token, 3300);
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
/**
 * Fingerprint of the sheet-owned fields last sent for a guest, stored in SYNC
 * KEY. Work fields belong to Firestore, so the sheet sync writing them to the
 * sheet never makes a guest look changed.
 */
function pcuGuestSyncKey_(guest, followUps, workers) {
  var digest = Utilities.computeDigest(
    Utilities.DigestAlgorithm.SHA_256,
    JSON.stringify(pcuGuestSheetFields_(guest, workers))
  );
  return pcuHex_(digest).substring(0, 16);
}

/**
 * Writes for a guest from the sheet: everything the first time it is sent,
 * afterwards only the sheet-owned fields, so work saved in the app is never
 * overwritten.
 */
function pcuGuestSheetWrites_(guest, followUps, workers, alreadySent) {
  if (!alreadySent) return pcuGuestWrites_(guest, followUps, workers);
  return [pcuFsSet_('guests/' + guest.id, pcuGuestSheetFields_(guest, workers))];
}

/**
 * Ids of [guests] that already have a Firestore document. Their work fields
 * belong to Firestore, so the sheet only ever sends sheet-owned fields for them.
 */
function pcuExistingGuests_(guests) {
  var found = pcuFsGetDocs_(
    guests.map(function (g) {
      return 'guests/' + g.id;
    })
  );
  var ids = {};
  Object.keys(found).forEach(function (path) {
    ids[path.substring('guests/'.length)] = true;
  });
  return ids;
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

/** Sends one guest now (sheet-owned fields once it exists). Used after assignment. */
function pcuPushGuest_(guestId) {
  if (!pcuFsEnabled_()) return 0;
  var guests = pcuGuestRows_(true);
  var guest = pcuFindGuest_(guests, guestId);
  if (!guest || !guest.assignedTo) return 0;
  var followUps = pcuFollowUps_(true).byGuest[guest.id] || [];
  var workers = pcuWorkers_();
  var exists = pcuExistingGuests_([guest]);
  var written = pcuFsCommit_(pcuGuestSheetWrites_(guest, followUps, workers, !!exists[guest.id]));
  pcuSetCell_(guests.table, guest.rowIndex, PCU_FS.SYNC_KEY, pcuGuestSyncKey_(guest, followUps, workers));
  pcuSetCell_(guests.table, guest.rowIndex, PCU_FS.SYNCED_AT, new Date());
  return written;
}

/**
 * Sends a guest the caller has already loaded, without reading the sheet
 * again. Used right after a save, where re-reading every row is the slow part.
 */
function pcuPushGuestData_(guestsTable, guest, followUps, workers) {
  if (!pcuFsEnabled_() || !guest.assignedTo) return 0;
  // The guest and the follow-up just saved. Earlier follow-ups are already in
  // Firestore (some were written by the app) and are left alone.
  var writes = [pcuFsSet_('guests/' + guest.id, pcuGuestDoc_(guest, followUps, workers))];
  var last = followUps[followUps.length - 1];
  if (last && last.id) {
    var points = pcuFollowUpPoints_(guest, followUps);
    writes.push(pcuFsSet_('followUps/' + last.id, pcuFollowUpDoc_(last, points[points.length - 1])));
  }
  var written = pcuFsCommit_(writes);
  pcuSetCell_(guestsTable, guest.rowIndex, PCU_FS.SYNC_KEY, pcuGuestSyncKey_(guest, followUps, workers));
  pcuSetCell_(guestsTable, guest.rowIndex, PCU_FS.SYNCED_AT, new Date());
  return written;
}

/** Same as pcuPushGuestData_, but never fails the caller. */
function pcuPushGuestDataQuietly_(guestsTable, guest, followUps, workers) {
  try {
    return pcuPushGuestData_(guestsTable, guest, followUps, workers);
  } catch (err) {
    console.warn('Could not send guest ' + guest.id + ' to Firestore: ' + (err && err.message));
    return 0;
  }
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

    var exists = pcuExistingGuests_(pending);
    var result = pcuRunJob_('push', pending, function (g) {
      return pcuGuestSheetWrites_(g, followUps.byGuest[g.id] || [], workers, !!exists[g.id]);
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
    var exists = pcuExistingGuests_(list);
    var result = pcuRunJob_('migrate', list, function (g) {
      return pcuGuestSheetWrites_(g, followUps.byGuest[g.id] || [], workers, !!exists[g.id]);
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

// ---------------------------------------------------------------------------
// Sheet sync (phase 3): Firestore -> sheet
// ---------------------------------------------------------------------------

var PCU_SYNC = {
  META: 'meta/sync',
  PAGE: 500,
  REPORT_TAB: 'Weekly Report',
  REPORT_HEADERS: ['WEEK', 'FROM', 'TO', 'FOLLOW-UPS', 'GUESTS CALLED', 'ATTENDANCES', 'TEAM JOINS', 'NEW MEMBERS', 'WRITTEN AT']
};

/** Decodes a Firestore REST value. Timestamps become Dates. */
function pcuFsDecode_(v) {
  if (!v || 'nullValue' in v) return null;
  if ('stringValue' in v) return v.stringValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('timestampValue' in v) return new Date(v.timestampValue);
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(pcuFsDecode_);
  if ('mapValue' in v) {
    var out = {};
    var fields = v.mapValue.fields || {};
    Object.keys(fields).forEach(function (k) {
      out[k] = pcuFsDecode_(fields[k]);
    });
    return out;
  }
  if ('referenceValue' in v) return v.referenceValue;
  return null;
}

function pcuFsDocument_(doc) {
  var data = {};
  var fields = doc.fields || {};
  Object.keys(fields).forEach(function (k) {
    data[k] = pcuFsDecode_(fields[k]);
  });
  return { id: doc.name.split('/').pop(), name: doc.name, data: data };
}

function pcuFsPost_(suffix, body) {
  var res = UrlFetchApp.fetch(PCU_FS.API + '/' + pcuFsDocsBase_() + suffix, {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + pcuFsToken_() },
    payload: JSON.stringify(body),
    muteHttpExceptions: true
  });
  if (res.getResponseCode() !== 200) {
    throw pcuError_('SERVER', 'Firestore read failed (' + res.getResponseCode() + '): ' + res.getContentText().substring(0, 300));
  }
  return JSON.parse(res.getContentText());
}

/** Every document of [collection] where [field] == [value], read in pages. */
function pcuFsQueryEqual_(collection, field, value) {
  var docs = [];
  var last = null;
  for (;;) {
    var query = {
      from: [{ collectionId: collection }],
      where: { fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: pcuFsValue_(value) } },
      orderBy: [{ field: { fieldPath: '__name__' }, direction: 'ASCENDING' }],
      limit: PCU_SYNC.PAGE
    };
    if (last) query.startAt = { values: [{ referenceValue: last }], before: false };
    var page = pcuFsPost_(':runQuery', { structuredQuery: query }).filter(function (r) {
      return !!r.document;
    });
    page.forEach(function (r) {
      docs.push(pcuFsDocument_(r.document));
    });
    if (page.length < PCU_SYNC.PAGE) return docs;
    last = page[page.length - 1].document.name;
  }
}

/** Documents by path ('guests/G1'), as { path: data }. Missing ones are left out. */
function pcuFsGetDocs_(paths) {
  var out = {};
  var base = pcuFsDocsBase_();
  for (var i = 0; i < paths.length; i += 100) {
    var names = paths.slice(i, i + 100).map(function (p) {
      return base + '/' + p;
    });
    pcuFsPost_(':batchGet', { documents: names }).forEach(function (r) {
      if (!r.found) return;
      var doc = pcuFsDocument_(r.found);
      out[doc.name.substring(base.length + 1)] = doc.data;
    });
  }
  return out;
}

/** A Lagos day ('yyyy-MM-dd') or Date as a Date, or ''. */
function pcuSyncDate_(value) {
  if (value instanceof Date) return value;
  return pcuDate_(value) || '';
}

/** One Follow-ups tab row for a follow-up saved in the app. */
function pcuSyncFollowUpRow_(table, f) {
  var d = f.data;
  var values = {};
  values[PCU.F.ID] = f.id;
  values[PCU.F.GUEST] = d.guestId || '';
  values[PCU.F.WORKER] = pcuEmail_(d.worker);
  values[PCU.F.LOGGED_BY] = pcuEmail_(d.loggedBy || d.worker);
  values[PCU.F.DATE] = d.createdAt instanceof Date ? d.createdAt : pcuSyncDate_(d.callDate);
  values[PCU.F.OUTCOME] = d.outcome || '';
  values[PCU.F.NOTE] = d.note || '';
  values[PCU.F.SUNDAY] = d.attendedSunday === true;
  values[PCU.F.SUNDAY_DATE] = d.attendedSunday ? pcuSyncDate_(d.sundayDate) : '';
  values[PCU.F.WEDNESDAY] = d.attendedWednesday === true;
  values[PCU.F.WEDNESDAY_DATE] = d.attendedWednesday ? pcuSyncDate_(d.wednesdayDate) : '';
  values[PCU.F.TEAM] = d.team || '';
  var row = [];
  for (var c = 0; c < table.headers.length; c++) row.push('');
  Object.keys(values).forEach(function (header) {
    var col = pcuCol_(table, header);
    if (col >= 0) row[col] = values[header];
  });
  return row;
}

function pcuSameCell_(a, b) {
  if (a instanceof Date || b instanceof Date) {
    return a instanceof Date && b instanceof Date && a.getTime() === b.getTime();
  }
  return pcuStr_(a) === pcuStr_(b);
}

/**
 * Writes the Firebase-owned columns of one guest row from its Firestore
 * document. Never touches ASSIGNED TO, name, phone or service date. FEEDBACK 1
 * and 2 keep the first two notes and are never replaced. Returns cells changed.
 */
function pcuSyncGuestRow_(t, rowIndex, d, followUps) {
  var G = PCU.G;
  var row = t.rows[rowIndex];
  var changed = 0;
  function set(header, value) {
    if (value === null || value === undefined) return;
    var col = pcuCol_(t, header);
    if (col < 0 || pcuSameCell_(row[col], value)) return;
    pcuSetCell_(t, rowIndex, header, value);
    changed++;
  }
  set(G.CALL_STATUS, d.callStatus);
  set(G.STATUS, d.membershipStatus);
  set(G.FOLLOW_UP_COUNT, typeof d.followUpCount === 'number' ? d.followUpCount : null);
  set(G.TEAM, d.teamJoined);
  if (d.lastFeedback) {
    set(G.LAST_FEEDBACK, d.lastFeedback);
    set(G.LAST_FEEDBACK_DATE, d.lastFeedbackDate);
  }
  if (d.memberSince) set(G.MEMBERSHIP_DATE, d.memberSince);

  var notes = followUps.filter(function (f) {
    return !!f.note;
  });
  if (notes[0] && !pcuStr_(pcuCell_(t, row, G.FEEDBACK_1))) {
    set(G.FEEDBACK_1, notes[0].note);
    set(G.FEEDBACK_1_DATE, notes[0].date);
  }
  if (notes[1] && !pcuStr_(pcuCell_(t, row, G.FEEDBACK_2))) {
    set(G.FEEDBACK_2, notes[1].note);
    set(G.FEEDBACK_2_DATE, notes[1].date);
  }
  return changed;
}

/**
 * Copies work saved in the app to the sheet: appends new follow-ups to the
 * Follow-ups tab (keyed by Follow-up ID, so a repeat adds nothing), writes the
 * Firebase-owned columns of each touched guest, then marks the follow-ups as
 * synced and records the run in meta/sync. Runs under the shared script lock.
 */
function pcuSheetSync_(by) {
  if (!pcuFsEnabled_()) throw pcuError_('NOT_READY', 'Sync to sheet is not set up yet.');
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw pcuError_('BUSY', 'A sync is already running. Try again in a minute.');
  var startedAt = new Date();
  try {
    pcuFsCommit_([pcuFsSet_(PCU_SYNC.META, { running: true, startedAt: startedAt, startedBy: by })]);
    var result = pcuSheetSyncLocked_();
    result.by = by;
    result.ok = true;
    var finishedAt = new Date();
    pcuFsCommit_([
      pcuFsSet_(PCU_SYNC.META, {
        running: false,
        lastSheetSyncAt: finishedAt,
        lastResult: {
          ok: true,
          by: by,
          followUps: result.followUps,
          guests: result.guests,
          alreadyInSheet: result.alreadyInSheet,
          missingGuests: result.missingGuests,
          seconds: Math.round((finishedAt - startedAt) / 1000)
        }
      })
    ]);
    result.lastSheetSyncAt = finishedAt.toISOString();
    return result;
  } catch (err) {
    try {
      pcuFsCommit_([
        pcuFsSet_(PCU_SYNC.META, {
          running: false,
          lastResult: { ok: false, by: by, error: String((err && err.message) || err).substring(0, 300), at: new Date() }
        })
      ]);
    } catch (ignored) {
      // The error below is the one that matters.
    }
    // The HOD hears about a scheduled sync that failed (a button press shows it on screen).
    if (by === 'nightly' || by === 'weekly') {
      pcuNotifyAdmins_({
        title: 'Sheet sync did not finish',
        body: 'Open the dashboard and tap Sync to sheet.',
        tag: 'sync-failed'
      });
    }
    throw err;
  } finally {
    lock.releaseLock();
  }
}

function pcuSheetSyncLocked_() {
  var pending = pcuFsQueryEqual_('followUps', 'syncedToSheet', false);
  pending.sort(function (a, b) {
    var ta = a.data.createdAt instanceof Date ? a.data.createdAt.getTime() : 0;
    var tb = b.data.createdAt instanceof Date ? b.data.createdAt.getTime() : 0;
    return ta - tb || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  });

  // 1. Follow-ups tab: append the ones it does not have yet, in one write.
  var fu = pcuTable_(PCU.SHEETS.FOLLOW_UPS, true);
  pcuRequireCol_(fu, PCU.F.ID);
  pcuRequireCol_(fu, PCU.F.GUEST);
  var inSheet = {};
  var idCol = pcuCol_(fu, PCU.F.ID);
  fu.rows.forEach(function (row) {
    var id = pcuStr_(row[idCol]);
    if (id) inSheet[id] = true;
  });
  var newRows = [];
  pending.forEach(function (f) {
    if (inSheet[f.id]) return;
    inSheet[f.id] = true;
    newRows.push(pcuSyncFollowUpRow_(fu, f));
  });
  if (newRows.length) {
    fu.sheet.getRange(fu.dataRows + 2, 1, newRows.length, fu.headers.length).setValues(newRows);
    SpreadsheetApp.flush();
  }

  // 2. Guest rows: the Firebase-owned columns of every touched guest.
  var ids = [];
  var seen = {};
  pending.forEach(function (f) {
    var id = pcuStr_(f.data.guestId);
    if (id && !seen[id]) {
      seen[id] = true;
      ids.push(id);
    }
  });
  var docs = pcuFsGetDocs_(
    ids.map(function (id) {
      return 'guests/' + id;
    })
  );
  var t = pcuTableHead_(PCU.SHEETS.GUESTS);
  var rowOf = {};
  pcuRowsWithIds_(t, ids).forEach(function (rowIndex) {
    rowOf[rowIndex] = true;
  });
  var rows = Object.keys(rowOf).map(Number);
  pcuLoadRowSet_(t, rows);
  var firstRowById = {};
  rows
    .sort(function (a, b) {
      return a - b;
    })
    .forEach(function (rowIndex) {
      var id = pcuStr_(pcuCell_(t, t.rows[rowIndex], PCU.G.ID));
      if (id && firstRowById[id] === undefined) firstRowById[id] = rowIndex;
    });
  var followUps = pcuFollowUps_(true).byGuest;
  var updated = 0;
  var missing = 0;
  ids.forEach(function (id) {
    var doc = docs['guests/' + id];
    var rowIndex = firstRowById[id];
    if (!doc || rowIndex === undefined) {
      missing++;
      return;
    }
    if (pcuSyncGuestRow_(t, rowIndex, doc, followUps[id] || []) > 0) updated++;
  });
  SpreadsheetApp.flush();

  // 3. Firestore: mark what reached the sheet (batches of 500).
  var now = new Date();
  var writes = pending.map(function (f) {
    return pcuFsSet_('followUps/' + f.id, { syncedToSheet: true });
  });
  ids.forEach(function (id) {
    if (docs['guests/' + id]) writes.push(pcuFsSet_('guests/' + id, { syncedToSheetAt: now }));
  });
  pcuFsCommit_(writes);

  pcuClearStatsCache_();
  return {
    followUps: newRows.length,
    alreadyInSheet: pending.length - newRows.length,
    guests: updated,
    guestsChecked: ids.length - missing,
    missingGuests: missing
  };
}

/** Nightly at 00:05 Africa/Lagos (see pcuEnsureSyncTriggers_). */
function pcuNightlySync() {
  return pcuSheetSync_('nightly');
}

/**
 * Mondays at 01:00 Africa/Lagos: a catch-up sync, then last week's results
 * (Monday to Sunday) as one row of the Weekly Report tab, written once per week.
 */
function pcuWeeklySync() {
  var result = pcuSheetSync_('weekly');
  result.report = pcuWriteWeeklyReport_(new Date());
  return result;
}

/** Writes the Weekly Report row for the week before [now]. Returns the week key, or '' if it was already there. */
function pcuWriteWeeklyReport_(now) {
  var today = pcuDay_(now);
  var dow = Number(Utilities.formatDate(now, PCU.TZ, 'u')); // 1 = Monday
  var monday = pcuAddDays_(today, -(dow - 1) - 7);
  var sunday = pcuAddDays_(monday, 6);
  var week = monday;

  var ss = SpreadsheetApp.getActive();
  var sheet = ss.getSheetByName(PCU_SYNC.REPORT_TAB);
  if (!sheet) {
    sheet = ss.insertSheet(PCU_SYNC.REPORT_TAB);
    sheet.getRange(1, 1, 1, PCU_SYNC.REPORT_HEADERS.length).setValues([PCU_SYNC.REPORT_HEADERS]);
  }
  var lastRow = sheet.getLastRow();
  if (lastRow > 1) {
    var weeks = sheet.getRange(2, 1, lastRow - 1, 1).getValues();
    for (var i = 0; i < weeks.length; i++) {
      var w = weeks[i][0] instanceof Date ? pcuDay_(weeks[i][0]) : pcuStr_(weeks[i][0]);
      if (w === week) return '';
    }
  }

  var inWeek = function (date) {
    var d = date ? pcuDay_(date) : '';
    return d >= monday && d <= sunday;
  };
  var followUps = pcuFollowUps_(true).byGuest;
  var count = 0;
  var called = 0;
  var attendances = 0;
  var teamJoins = 0;
  Object.keys(followUps).forEach(function (guestId) {
    var any = false;
    var teamSeen = false;
    followUps[guestId].forEach(function (f) {
      var joined = !!f.team && !teamSeen;
      if (f.team) teamSeen = true;
      if (!inWeek(f.date)) return;
      any = true;
      count++;
      attendances += (f.sunday ? 1 : 0) + (f.wednesday ? 1 : 0);
      if (joined) teamJoins++;
    });
    if (any) called++;
  });
  var members = pcuGuestsWhere_({ members: true }).list.filter(function (g) {
    return g.status === PCU.STATUS.MEMBER && inWeek(g.membershipDate);
  }).length;

  sheet.appendRow([week, monday, sunday, count, called, attendances, teamJoins, members, now]);
  return week;
}

function pcuAddDays_(day, n) {
  var p = day.split('-');
  var d = new Date(Date.UTC(+p[0], +p[1] - 1, +p[2] + n));
  return d.getUTCFullYear() + '-' + pcuPad2_(d.getUTCMonth() + 1) + '-' + pcuPad2_(d.getUTCDate());
}

/**
 * Makes sure the nightly (00:05) and weekly (Monday 01:00) Africa/Lagos
 * triggers exist, adding only the missing ones. Called by syncNow, so the
 * first "Sync to sheet" sets them up. Returns the handlers it added.
 */
function pcuEnsureSyncTriggers_() {
  var have = {};
  ScriptApp.getProjectTriggers().forEach(function (t) {
    have[t.getHandlerFunction()] = true;
  });
  var added = [];
  if (!have.pcuNightlySync) {
    ScriptApp.newTrigger('pcuNightlySync').timeBased().everyDays(1).atHour(0).nearMinute(5).inTimezone(PCU.TZ).create();
    added.push('pcuNightlySync');
  }
  if (!have.pcuWeeklySync) {
    ScriptApp.newTrigger('pcuWeeklySync').timeBased().onWeekDay(ScriptApp.WeekDay.MONDAY).atHour(1).inTimezone(PCU.TZ).create();
    added.push('pcuWeeklySync');
  }
  return added;
}

/** The sheet sync for the HOD's "Sync to sheet" button (admin only). */
function pcuSyncNow_(user) {
  pcuRequireAdmin_(user);
  var result = pcuSheetSync_('syncNow ' + user.email);
  try {
    result.triggersAdded = pcuEnsureSyncTriggers_();
  } catch (err) {
    console.warn('Could not set up the sync triggers: ' + (err && err.message));
    result.triggersAdded = [];
  }
  return result;
}

// ---------------------------------------------------------------------------
// Web push (Firebase Cloud Messaging HTTP v1)
// ---------------------------------------------------------------------------

var PCU_PUSH = {
  API: 'https://fcm.googleapis.com/v1/projects/',
  ICON: 'icons/notification-icon-192.png',
  BADGE: 'icons/notification-badge-96.png',
  DEFAULT_LINK: 'https://pcu-workflow.web.app'
};

/** The app's address for links in pushes (APP_LINK from pcu_auto_assign.gs when present). */
function pcuAppLink_() {
  var link = typeof APP_LINK === 'string' && /^https:\/\//.test(APP_LINK) ? APP_LINK : PCU_PUSH.DEFAULT_LINK;
  return link.replace(/\/+$/, '');
}

/** Push tokens saved by the app at users/{email}/tokens. */
function pcuUserTokens_(email) {
  var url = PCU_FS.API + '/' + pcuFsDocsBase_() + '/users/' + encodeURIComponent(pcuEmail_(email)) + '/tokens?pageSize=100';
  var res = UrlFetchApp.fetch(url, {
    headers: { Authorization: 'Bearer ' + pcuFsToken_() },
    muteHttpExceptions: true
  });
  if (res.getResponseCode() !== 200) return [];
  return (JSON.parse(res.getContentText()).documents || []).map(function (doc) {
    return pcuFsDocument_(doc).id;
  });
}

/** The FCM HTTP v1 message for one device. */
function pcuPushMessage_(token, n) {
  var link = n.link || pcuAppLink_() + '/';
  var message = {
    notification: { title: n.title, body: n.body || '' },
    data: { title: n.title, body: n.body || '', link: link, tag: n.tag || '' },
    webpush: {
      notification: { icon: PCU_PUSH.ICON, badge: PCU_PUSH.BADGE },
      fcm_options: { link: link }
    }
  };
  if (n.tag) message.webpush.notification.tag = n.tag;
  if (token) message.token = token;
  return message;
}

/**
 * Sends a push to every device of [email]. Tokens FCM says are gone are
 * deleted. Returns { tokens, sent, removed, error } and never throws.
 */
function pcuSendPush_(email, n) {
  var result = { tokens: 0, sent: 0, removed: 0, error: '' };
  if (!pcuFsEnabled_() || !email) return result;
  try {
    var tokens = pcuUserTokens_(email);
    result.tokens = tokens.length;
    if (!tokens.length) return result;
    var url = PCU_PUSH.API + pcuFsKey_().project_id + '/messages:send';
    var auth = 'Bearer ' + pcuFsToken_();
    var responses = UrlFetchApp.fetchAll(
      tokens.map(function (token) {
        return {
          url: url,
          method: 'post',
          contentType: 'application/json',
          headers: { Authorization: auth },
          payload: JSON.stringify({ message: pcuPushMessage_(token, n) }),
          muteHttpExceptions: true
        };
      })
    );
    var gone = [];
    responses.forEach(function (res, i) {
      var code = res.getResponseCode();
      if (code === 200) {
        result.sent++;
        return;
      }
      var text = res.getContentText();
      if (code === 404 || /UNREGISTERED|registration token is not a valid/i.test(text)) gone.push(tokens[i]);
      else result.error = code + ': ' + text.substring(0, 200);
    });
    if (gone.length) {
      pcuFsDeleteDocs_(
        gone.map(function (t) {
          return 'users/' + pcuEmail_(email) + '/tokens/' + t;
        })
      );
      result.removed = gone.length;
    }
  } catch (err) {
    result.error = String((err && err.message) || err).substring(0, 200);
  }
  if (result.error) console.warn('Push to ' + email + ' failed: ' + result.error);
  return result;
}

/** Deletes documents by path (batches of 500). */
function pcuFsDeleteDocs_(paths) {
  var base = pcuFsDocsBase_();
  return pcuFsCommit_(
    paths.map(function (p) {
      return { delete: base + '/' + p };
    })
  );
}

/**
 * Tells a person about something: an item in their in-app list (the bell)
 * and a push to their devices. Returns true when at least one device got the
 * push, so the caller can fall back to email.
 */
function pcuNotify_(email, n) {
  pcuSaveNotification_(email, n);
  return pcuSendPush_(email, n).sent > 0;
}

/** users/{email}/notifications/{id}, read by the app's bell. Never throws. */
function pcuSaveNotification_(email, n) {
  if (!pcuFsEnabled_() || !email) return;
  try {
    pcuFsCommit_([
      pcuFsSet_('users/' + pcuEmail_(email) + '/notifications/' + Utilities.getUuid(), {
        title: n.title,
        body: n.body || '',
        tag: n.tag || '',
        link: n.link || pcuAppLink_() + '/',
        read: false,
        createdAt: new Date()
      })
    ]);
  } catch (err) {
    console.warn('Notification for ' + email + ' not saved: ' + (err && err.message));
  }
}

/** Every active admin, for HOD notices. */
function pcuNotifyAdmins_(n) {
  pcuWorkers_().list.forEach(function (w) {
    if (w.isAdmin && w.active) pcuNotify_(w.email, n);
  });
}

/**
 * Admin only: checks that the service account may send pushes, without
 * sending anything (FCM validate_only). Returns { ok, status, error }.
 */
function pcuPushCheck_(user) {
  pcuRequireAdmin_(user);
  if (!pcuFsEnabled_()) throw pcuError_('NOT_READY', 'Notifications are not set up yet.');
  var message = pcuPushMessage_(null, { title: 'PCU Connect check', body: 'Not sent', tag: 'check' });
  message.topic = 'pcu-check';
  var res = UrlFetchApp.fetch(PCU_PUSH.API + pcuFsKey_().project_id + '/messages:send', {
    method: 'post',
    contentType: 'application/json',
    headers: { Authorization: 'Bearer ' + pcuFsToken_() },
    payload: JSON.stringify({ validate_only: true, message: message }),
    muteHttpExceptions: true
  });
  var code = res.getResponseCode();
  return { ok: code === 200, status: code, error: code === 200 ? '' : res.getContentText().substring(0, 400) };
}
