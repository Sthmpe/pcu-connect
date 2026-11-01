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
    // The Workers tab ID (W001), used by the app's Team screen to turn a worker on or off.
    id: w.id || '',
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
    gender: guest.gender || '',
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

/**
 * Copies the Workers tab to users only when it changed since the last copy
 * (fingerprint in the USERS_KEY Script Property). Never fails the caller.
 * Returns the documents written.
 */
function pcuSyncUsersIfChanged_() {
  try {
    var workers = pcuWorkers_();
    var key = pcuHex_(
      Utilities.computeDigest(
        Utilities.DigestAlgorithm.SHA_256,
        JSON.stringify(
          workers.list.map(function (w) {
            return pcuUserDoc_(w);
          })
        )
      )
    ).substring(0, 16);
    var props = PropertiesService.getScriptProperties();
    if (props.getProperty('USERS_KEY') === key) return 0;
    var written = pcuSyncUsers_();
    props.setProperty('USERS_KEY', key);
    return written;
  } catch (err) {
    console.warn('Could not send workers to Firestore: ' + (err && err.message));
    return 0;
  }
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

/**
 * Sends several guests in one pass (one read of the sheet), for bulk
 * assignment. Like pcuPushGuest_: everything the first time, then only the
 * sheet-owned fields. Returns the documents written.
 */
function pcuPushGuests_(ids) {
  if (!pcuFsEnabled_() || !ids.length) return 0;
  var guests = pcuGuestRows_(true);
  var followUps = pcuFollowUps_(true);
  var workers = pcuWorkers_();
  var want = {};
  ids.forEach(function (id) {
    want[id] = true;
  });
  var list = guests.list.filter(function (g) {
    return want[g.id] && g.assignedTo;
  });
  var exists = pcuExistingGuests_(list);
  var writes = [];
  list.forEach(function (g) {
    writes = writes.concat(pcuGuestSheetWrites_(g, followUps.byGuest[g.id] || [], workers, !!exists[g.id]));
  });
  var written = pcuFsCommit_(writes);
  var now = new Date();
  list.forEach(function (g) {
    pcuSetCell_(guests.table, g.rowIndex, PCU_FS.SYNC_KEY, pcuGuestSyncKey_(g, followUps.byGuest[g.id] || [], workers));
    pcuSetCell_(guests.table, g.rowIndex, PCU_FS.SYNCED_AT, now);
  });
  return written;
}

/** Same as pcuPushGuests_, but never fails the caller. */
function pcuPushGuestsQuietly_(ids) {
  try {
    return pcuPushGuests_(ids);
  } catch (err) {
    console.warn('Could not send ' + ids.length + ' guests to Firestore: ' + (err && err.message));
    return 0;
  }
}

/**
 * Removes guests from Firestore with their follow-ups and Follow-ups tab rows
 * (used by Remove test guests). Never fails the caller. Returns docs deleted.
 */
function pcuDeleteGuestsQuietly_(ids) {
  try {
    if (!pcuFsEnabled_() || !ids.length) return 0;
    var want = {};
    ids.forEach(function (id) {
      want[id] = true;
    });
    var paths = ids.map(function (id) {
      return 'guests/' + id;
    });
    ids.forEach(function (id) {
      pcuFsQueryEqual_('followUps', 'guestId', id).forEach(function (f) {
        paths.push('followUps/' + f.id);
      });
    });
    var deleted = pcuFsDeleteDocs_(paths);
    var fu = pcuTable_(PCU.SHEETS.FOLLOW_UPS, true);
    var guestCol = pcuCol_(fu, PCU.F.GUEST);
    for (var i = fu.rows.length - 1; i >= 0; i--) {
      if (want[pcuStr_(fu.rows[i][guestCol])]) fu.sheet.deleteRow(i + 2);
    }
    return deleted;
  } catch (err) {
    console.warn('Could not remove test guests from Firestore: ' + (err && err.message));
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
  // Every scheduled run checks that auto-assign is still on (pcu_auto_assign.gs).
  if (typeof ensureAssignTriggersQuietly_ === 'function') ensureAssignTriggersQuietly_();
  if (!pcuFsEnabled_()) return { skipped: 'not set up' };
  // Workers added in the Workers tab or from the PCU menu reach the app within 5 minutes.
  pcuSyncUsersIfChanged_();
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

/**
 * Sends GENDER (and any other changed sheet-owned field) for every recent
 * assigned guest now, instead of waiting for the 5-minute run. Adding gender
 * changed every guest's SYNC KEY, so this reaches them all; work saved in the
 * app is never touched. Run by hand until "pending" reaches 0.
 */
function pcuBackfillGender() {
  var result = pcuPushPendingGuests();
  console.log('Gender backfill: ' + JSON.stringify(result));
  return result;
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

/**
 * When the call happened. callDate is the Lagos day on the phone when it was
 * saved; createdAt is when the server got it, which can be the next day for
 * a save made offline. The day always comes from callDate; createdAt only
 * adds the time when it falls on that same day.
 */
function pcuCallMoment_(d) {
  var day = pcuDate_(d.callDate);
  if (!day) return d.createdAt instanceof Date ? d.createdAt : '';
  return d.createdAt instanceof Date && pcuDay_(d.createdAt) === pcuStr_(d.callDate) ? d.createdAt : day;
}

/** One Follow-ups tab row for a follow-up saved in the app. */
function pcuSyncFollowUpRow_(table, f) {
  var d = f.data;
  var values = {};
  values[PCU.F.ID] = f.id;
  values[PCU.F.GUEST] = d.guestId || '';
  values[PCU.F.WORKER] = pcuEmail_(d.worker);
  values[PCU.F.LOGGED_BY] = pcuEmail_(d.loggedBy || d.worker);
  values[PCU.F.DATE] = pcuCallMoment_(d);
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
    result.sheetUrl = pcuSheetUrl_();
    pcuFsCommit_([
      pcuFsSet_(PCU_SYNC.META, {
        running: false,
        lastSheetSyncAt: finishedAt,
        sheetUrl: result.sheetUrl,
        lastResult: {
          ok: true,
          by: by,
          followUps: result.followUps,
          followUpGuests: result.followUpGuests,
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
  var newFor = {};
  pending.forEach(function (f) {
    if (inSheet[f.id]) return;
    inSheet[f.id] = true;
    newRows.push(pcuSyncFollowUpRow_(fu, f));
    newFor[pcuStr_(f.data.guestId)] = true;
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
    // Distinct guests of the follow-ups just added: "Synced 6 follow-ups for 4 guests".
    followUpGuests: Object.keys(newFor).filter(function (id) {
      return !!id;
    }).length,
    alreadyInSheet: pending.length - newRows.length,
    guests: updated,
    guestsChecked: ids.length - missing,
    missingGuests: missing
  };
}

/**
 * The sheet's address for the HOD's "Open the sheet" link: the SHEET_URL
 * Script Property, filled once from this script's spreadsheet when missing.
 */
function pcuSheetUrl_() {
  var props = PropertiesService.getScriptProperties();
  var url = props.getProperty('SHEET_URL');
  if (url) return url;
  try {
    url = SpreadsheetApp.getActive().getUrl();
    if (url) props.setProperty('SHEET_URL', url);
  } catch (err) {
    console.warn('No sheet URL: ' + (err && err.message));
  }
  return url || '';
}

/** Nightly at 00:05 Africa/Lagos (see pcuEnsureSyncTriggers_). */
function pcuNightlySync() {
  if (typeof ensureAssignTriggersQuietly_ === 'function') ensureAssignTriggersQuietly_();
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
 * Makes sure the nightly sync (00:05), nightly leaderboard rebuild (00:35)
 * and weekly (Monday 01:00) Africa/Lagos triggers exist, adding only the
 * missing ones. Called by syncNow, so the
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
  if (!have.pcuNightlyRecalc) {
    // Half an hour after the sync, so the leaderboard is rebuilt from the day's saves.
    ScriptApp.newTrigger('pcuNightlyRecalc').timeBased().everyDays(1).atHour(0).nearMinute(35).inTimezone(PCU.TZ).create();
    added.push('pcuNightlyRecalc');
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
  // Cheap, and keeps users (names, roles, IDs) current for the app.
  pcuSyncUsersQuietly_();
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
  // Paths on the app's site; sent as full https URLs (see pcuPushMessage_).
  ICON: 'icons/notification-icon-192-v2.png',
  BADGE: 'icons/notification-badge-96-v2.png',
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
      notification: { icon: pcuAppLink_() + '/' + PCU_PUSH.ICON, badge: pcuAppLink_() + '/' + PCU_PUSH.BADGE },
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

// ---------------------------------------------------------------------------
// Health (admin only, read only): the sheet against Firestore
// ---------------------------------------------------------------------------

/**
 * Counts that show whether the sheet and Firestore agree: assigned guests per
 * worker in each, assigned guests missing or assigned differently in
 * Firestore, follow-ups (sheet tab and Firestore) whose guest is missing,
 * Workers tab rows missing from users, and the installed triggers.
 */
function pcuHealth_(user) {
  pcuRequireAdmin_(user);
  if (!pcuFsEnabled_()) throw pcuError_('NOT_READY', 'Firestore is not set up yet.');
  var guests = pcuGuestRows_(true);
  var workers = pcuWorkers_();
  var sheetFollowUps = pcuFollowUps_(true);
  var sheetIds = {};
  var assigned = guests.list.filter(function (g) {
    sheetIds[g.id] = true;
    return !!g.assignedTo;
  });
  var count = function (list, key) {
    var out = {};
    list.forEach(function (x) {
      var k = key(x);
      out[k] = (out[k] || 0) + 1;
    });
    return out;
  };

  var fsGuests = {};
  pcuFsQueryAll_('guests').forEach(function (d) {
    fsGuests[d.id] = d.data;
  });
  var fsAssigned = Object.keys(fsGuests).filter(function (id) {
    return !!fsGuests[id].assignedTo;
  });
  var missingInFs = assigned.filter(function (g) {
    return !fsGuests[g.id];
  });
  var assignedDifferently = assigned.filter(function (g) {
    return fsGuests[g.id] && pcuEmail_(fsGuests[g.id].assignedTo || '') !== pcuEmail_(g.assignedTo);
  });

  var sheetFuList = [];
  Object.keys(sheetFollowUps.byGuest).forEach(function (id) {
    sheetFuList = sheetFuList.concat(sheetFollowUps.byGuest[id]);
  });
  var fsFollowUps = pcuFsQueryAll_('followUps');
  var users = {};
  pcuFsQueryAll_('users').forEach(function (d) {
    users[d.id] = d.data;
  });
  var admins = {};
  workers.list.forEach(function (w) {
    if (w.isAdmin) admins[w.email] = true;
  });

  return {
    sheet: {
      guests: guests.list.length,
      assigned: assigned.length,
      assignedByWorker: count(assigned, function (g) {
        return pcuEmail_(g.assignedTo);
      }),
      assignedToAdmins: assigned.filter(function (g) {
        return admins[pcuEmail_(g.assignedTo)];
      }).map(function (g) {
        return g.id;
      }),
      unassignedSinceGoLive: guests.list.filter(function (g) {
        return !g.assignedTo && g.serviceDay && g.serviceDay >= PCU_FS_GO_LIVE_();
      }).length,
      followUps: sheetFuList.length,
      followUpsWithoutGuestInSheet: sheetFuList.filter(function (f) {
        return !sheetIds[f.guestId];
      }).length,
      followUpsWithoutGuestInFirestore: sheetFuList.filter(function (f) {
        return !fsGuests[f.guestId];
      }).map(function (f) {
        return f.guestId;
      })
    },
    firestore: {
      guests: Object.keys(fsGuests).length,
      assigned: fsAssigned.length,
      assignedByWorker: count(fsAssigned, function (id) {
        return pcuEmail_(fsGuests[id].assignedTo);
      }),
      followUps: fsFollowUps.length,
      followUpsWithoutGuest: fsFollowUps.filter(function (f) {
        return !fsGuests[f.data.guestId];
      }).map(function (f) {
        return f.id;
      }),
      followUpsNotYetInSheet: fsFollowUps.filter(function (f) {
        return f.data.syncedToSheet === false;
      }).length
    },
    gaps: {
      assignedMissingInFirestore: missingInFs.map(function (g) {
        return g.id;
      }),
      assignedDifferently: assignedDifferently.map(function (g) {
        return g.id;
      }),
      workersMissingInUsers: workers.list.filter(function (w) {
        return !users[pcuEmail_(w.email)];
      }).map(function (w) {
        return w.email;
      }),
      usersDifferentFromWorkersTab: workers.list.filter(function (w) {
        var u = users[pcuEmail_(w.email)];
        return u && (u.active !== !!w.active || u.role !== (w.isAdmin ? 'admin' : 'worker'));
      }).map(function (w) {
        return w.email;
      })
    },
    triggers: ScriptApp.getProjectTriggers().map(function (t) {
      return t.getHandlerFunction();
    }),
    notify: PropertiesService.getScriptProperties().getProperty('NOTIFY') || '(not set)'
  };
}

/** Go-live day ('yyyy-MM-dd'): GO_LIVE from pcu_auto_assign.gs when present. */
function PCU_FS_GO_LIVE_() {
  return typeof GO_LIVE === 'string' ? GO_LIVE : '2026-10-28';
}

// ---------------------------------------------------------------------------
// Redistribute (admin only): move a worker's waiting guests to others
// ---------------------------------------------------------------------------

var PCU_REDIS = {
  TAB: 'Reassignments',
  HEADERS: ['TIMESTAMP', 'GUEST ID', 'GUEST NAME', 'FROM', 'TO', 'BY', 'REASON'],
  OUTSTANDING_AFTER_DAYS: 3,
  MODES: { outstanding: 'Outstanding', uncalled: 'All uncalled', selected: 'Selected' }
};

/**
 * The plan for one redistribution, from the sheet (owner of ASSIGNED TO) and
 * Firestore (owner of the calls). Candidates are the source worker's guests
 * never called: "outstanding" (since go-live, more than 3 days since the
 * visit), "uncalled" (any), or "selected" (those of guestIds still with the
 * source). They are dealt oldest visit first, evenly, to the recipients:
 * active workers only, never admins and never the source. The same function
 * makes the preview and the move, so their counts agree.
 */
function pcuRedistributePlan_(req, guests) {
  var from = pcuEmail_(req.fromEmail);
  var mode = PCU_REDIS.MODES[req.mode] ? req.mode : 'outstanding';
  var workers = pcuWorkers_();
  var source = workers.byEmail[from];
  if (!source) throw pcuError_('VALIDATION', 'Choose a worker whose guests to move.');
  var wanted = null;
  if (req.toEmails && req.toEmails.length) {
    wanted = {};
    req.toEmails.forEach(function (e) {
      wanted[pcuEmail_(e)] = true;
    });
  }
  var recipients = workers.list
    .filter(function (w) {
      return w.active && !w.isAdmin && w.email !== from && (!wanted || wanted[w.email]);
    })
    .sort(function (a, b) {
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0;
    });
  if (!recipients.length) throw pcuError_('VALIDATION', 'Choose at least one active worker to receive the guests.');

  var mine = guests.list.filter(function (g) {
    return pcuEmail_(g.assignedTo) === from;
  });
  var docs = pcuFsGetDocs_(
    mine.map(function (g) {
      return 'guests/' + g.id;
    })
  );
  var followUps = pcuFollowUps_(true);
  var today = pcuToday_();
  var goLive = PCU_FS_GO_LIVE_();
  var selected = {};
  (req.guestIds || []).forEach(function (id) {
    selected[pcuStr_(id)] = true;
  });
  var candidates = mine.filter(function (g) {
    var doc = docs['guests/' + g.id];
    var calls = doc ? Number(doc.followUpCount) || 0 : pcuCallCount_(g, followUps.byGuest[g.id] || []);
    if (calls > 0) return false;
    if (mode === 'selected') return !!selected[g.id];
    if (mode === 'uncalled') return true;
    return !!g.serviceDay && g.serviceDay >= goLive && pcuDaysBetween_(g.serviceDay, today) > PCU_REDIS.OUTSTANDING_AFTER_DAYS;
  });
  candidates.sort(function (a, b) {
    return a.serviceDay < b.serviceDay ? -1 : a.serviceDay > b.serviceDay ? 1 : a.rowIndex - b.rowIndex;
  });
  var moves = candidates.map(function (g, i) {
    return { guest: g, to: recipients[i % recipients.length] };
  });
  var counts = {};
  moves.forEach(function (m) {
    counts[m.to.email] = (counts[m.to.email] || 0) + 1;
  });
  var n = moves.length;
  var text = n === 0
    ? 'No guests to move.'
    : n + (n === 1 ? ' guest: ' : ' guests: ') + (typeof workerCountsText_ === 'function' ? workerCountsText_(counts) : JSON.stringify(counts));
  return { from: from, source: source, mode: mode, recipients: recipients, moves: moves, counts: counts, text: text, candidates: candidates };
}

/** Admin only. req.preview true: the plan; otherwise the move, under the shared lock. */
function pcuRedistribute_(user, req) {
  pcuRequireAdmin_(user);
  if (!pcuFsEnabled_()) throw pcuError_('NOT_READY', 'Not set up yet.');
  if (req.preview) {
    var plan = pcuRedistributePlan_(req, pcuGuestRows_(true));
    return pcuRedistributeJson_(plan, false);
  }
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(30000)) throw pcuError_('BUSY', 'Another change is running. Try again in a moment.');
  var done;
  try {
    // Fresh data inside the lock: a second tap finds nothing left to move.
    var guests = pcuGuestRows_(true);
    done = pcuRedistributePlan_(req, guests);
    if (done.moves.length) pcuRedistributeApply_(user, done, guests);
  } finally {
    lock.releaseLock();
  }
  if (done.moves.length) pcuRedistributeNotify_(done);
  return pcuRedistributeJson_(done, true);
}

function pcuRedistributeJson_(plan, moved) {
  return {
    mode: plan.mode,
    guests: plan.moves.length,
    moved: moved ? plan.moves.length : 0,
    text: plan.text,
    plan: plan.recipients.map(function (w) {
      return { email: w.email, name: w.name, count: plan.counts[w.email] || 0 };
    }),
    candidates: plan.candidates.map(function (g) {
      return { id: g.id, name: g.name, serviceDate: g.serviceDay };
    })
  };
}

/** ASSIGNED TO in the sheet first (it owns assignment), then Firestore, then both logs. */
function pcuRedistributeApply_(user, plan, guests) {
  var now = new Date();
  plan.moves.forEach(function (m) {
    pcuSetCell_(guests.table, m.guest.rowIndex, PCU.G.ASSIGNED_TO, m.to.email);
    pcuSetCell_(guests.table, m.guest.rowIndex, PCU.G.ASSIGNED_DATE, now);
    m.guest.assignedTo = m.to.email;
  });
  SpreadsheetApp.flush();
  pcuTable_(PCU.SHEETS.GUESTS, true);
  pcuPushGuests_(
    plan.moves.map(function (m) {
      return m.guest.id;
    })
  );

  var ss = SpreadsheetApp.getActive();
  var tab = ss.getSheetByName(PCU_REDIS.TAB);
  if (!tab) {
    tab = ss.insertSheet(PCU_REDIS.TAB);
    tab.getRange(1, 1, 1, PCU_REDIS.HEADERS.length).setValues([PCU_REDIS.HEADERS]);
  }
  var by = pcuEmail_(user.email);
  var reason = PCU_REDIS.MODES[plan.mode];
  var rows = plan.moves.map(function (m) {
    return [now, m.guest.id, m.guest.name, plan.from, m.to.email, by, reason];
  });
  tab.getRange(tab.getLastRow() + 1, 1, rows.length, PCU_REDIS.HEADERS.length).setValues(rows);

  pcuFsCommit_(
    plan.moves.map(function (m) {
      return pcuFsSet_('reassignments/' + Utilities.getUuid(), {
        guestId: m.guest.id,
        guestName: m.guest.name,
        from: plan.from,
        to: m.to.email,
        by: by,
        mode: plan.mode,
        at: now
      });
    })
  );
}

/** Tells each new worker and the previous worker: in-app, push if registered, email. */
function pcuRedistributeNotify_(plan) {
  var fromFirst = String(plan.source.name || plan.from).replace(/^TEST\s+/i, '').split(/\s+/)[0];
  var tell = function (worker, title, body) {
    pcuSaveNotification_(worker.email, { title: title, body: body, tag: 'reassigned' });
    pcuSendPush_(worker.email, { title: title, body: body, tag: 'reassigned' });
    if (!/@/.test(worker.email) || /@example\.(com|org)$/i.test(worker.email)) return;
    try {
      MailApp.sendEmail({
        to: worker.email,
        subject: title,
        body: body + '\n\n' + pcuAppLink_() + '/',
        htmlBody: typeof emailShell_ === 'function' ? emailShell_(title, '<p>' + body + '</p>') : body
      });
    } catch (err) {
      console.warn('Reassignment email to ' + worker.email + ' failed: ' + (err && err.message));
    }
  };
  plan.recipients.forEach(function (w) {
    var n = plan.counts[w.email] || 0;
    if (!n) return;
    tell(w, 'New guests for you', n + (n === 1 ? ' guest was' : ' guests were') + ' passed to you from ' + fromFirst +
      '. They have been waiting since their visit, so a call soon means a lot.');
  });
  var total = plan.moves.length;
  tell(plan.source, 'Some guests were shared', total + (total === 1 ? ' of your guests was' : ' of your guests were') +
    ' passed to other workers so they get a call soon. Your calls and points stay with you.');
}

// ---------------------------------------------------------------------------
// Nudge (admin only): a friendly reminder to a worker with guests waiting
// ---------------------------------------------------------------------------

var PCU_NUDGE = {
  TITLE: 'A gentle nudge from your HOD',
  BODY: 'You have {n} guests waiting for a call. A quick call today makes a big difference. We are cheering you on.',
  EVERY_MS: 24 * 60 * 60 * 1000,
  MAX_LINE: 200,
  MAX_GUESTS: 1000
};

/** The nudge text for [n] waiting guests ("1 guest" when there is one). */
function pcuNudgeBody_(n) {
  var body = PCU_NUDGE.BODY.replace('{n}', String(n));
  return n === 1 ? body.replace('1 guests', '1 guest') : body;
}

/** When [email] was last nudged (Date), or null. */
function pcuLastNudge_(email) {
  var last = null;
  pcuFsQueryEqual_('nudges', 'worker', email).forEach(function (d) {
    // WhatsApp nudges (logged by the app) do not count toward the 24 hours.
    if (d.data.channel === 'whatsapp') return;
    var sentAt = d.data.sentAt;
    var at = sentAt instanceof Date ? sentAt : sentAt ? new Date(sentAt) : null;
    if (at && (!last || at.getTime() > last.getTime())) last = at;
  });
  return last;
}

/**
 * Sends one nudge: logged in nudges/{id} first (at most one per worker per
 * 24 hours), then an in-app notice, a push to registered devices and an
 * email. The in-app notice and the email do not need the push (FCM) role.
 * req: { workerEmail, outstanding, personalLine? }.
 */
function pcuNudge_(user, req) {
  pcuRequireAdmin_(user);
  if (!pcuFsEnabled_()) throw pcuError_('NOT_READY', 'Nudges are not set up yet.');
  var email = pcuEmail_(req.workerEmail);
  var worker = pcuWorkers_().byEmail[email];
  if (!worker || !worker.active || worker.isAdmin) throw pcuError_('VALIDATION', 'Choose an active worker to nudge.');
  var n = Number(req.outstanding);
  if (!(n >= 1 && n <= PCU_NUDGE.MAX_GUESTS && Math.floor(n) === n)) {
    throw pcuError_('VALIDATION', 'A nudge needs the number of guests waiting.');
  }
  var line = pcuStr_(req.personalLine).replace(/\s+/g, ' ').trim();
  if (line.length > PCU_NUDGE.MAX_LINE) {
    throw pcuError_('VALIDATION', 'Keep the personal line to ' + PCU_NUDGE.MAX_LINE + ' characters.');
  }
  var body = pcuNudgeBody_(n);
  var full = line ? body + '\n' + line : body;
  var now = new Date();
  var id = Utilities.getUuid();

  // Check and log under the lock, so two quick taps cannot both send.
  var logged = pcuWithLock_(function () {
    var last = pcuLastNudge_(email);
    if (last && now.getTime() - last.getTime() < PCU_NUDGE.EVERY_MS) {
      var next = new Date(last.getTime() + PCU_NUDGE.EVERY_MS);
      var err = pcuError_('TOO_SOON', (worker.name || 'This worker') + ' was nudged in the last 24 hours. You can nudge again at ' +
        Utilities.formatDate(next, PCU.TZ, 'HH:mm') + ' on ' + Utilities.formatDate(next, PCU.TZ, 'EEEE') + '.');
      err.nextAt = next;
      throw err;
    }
    pcuFsCommit_([
      pcuFsSet_('nudges/' + id, {
        worker: email,
        workerName: worker.name || '',
        sentBy: pcuEmail_(user.email),
        sentByName: user.name || '',
        sentAt: now,
        channel: 'app',
        outstanding: n,
        personalLine: line,
        title: PCU_NUDGE.TITLE,
        body: full
      })
    ]);
    return true;
  });
  if (logged !== true) throw pcuError_('BUSY', 'Another nudge is being sent. Try again in a moment.');

  var notice = { title: PCU_NUDGE.TITLE, body: full, tag: 'nudge' };
  pcuSaveNotification_(email, notice);
  var push = pcuSendPush_(email, notice);
  var emailSent = pcuNudgeEmail_(worker, body, line);
  try {
    pcuFsCommit_([
      pcuFsSet_('nudges/' + id, { inApp: true, pushSent: push.sent || 0, pushError: push.error || '', emailSent: emailSent })
    ]);
  } catch (err) {
    console.warn('Nudge ' + id + ' delivery not recorded: ' + (err && err.message));
  }
  return {
    id: id,
    sentAt: now,
    nextAt: new Date(now.getTime() + PCU_NUDGE.EVERY_MS),
    inApp: true,
    pushSent: push.sent || 0,
    emailSent: emailSent
  };
}

/** The nudge by email. Never throws; false when it could not be sent. */
function pcuNudgeEmail_(worker, body, line) {
  if (!/@/.test(worker.email) || /@example\.(com|org)$/i.test(worker.email)) return false;
  try {
    var esc = function (t) {
      return String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    };
    var html = '<p>Hi ' + esc(worker.name || 'there') + ',</p><p>' + esc(body) + '</p>' + (line ? '<p>' + esc(line) + '</p>' : '');
    MailApp.sendEmail({
      to: worker.email,
      subject: PCU_NUDGE.TITLE,
      body: 'Hi ' + (worker.name || 'there') + ',\n\n' + body + (line ? '\n\n' + line : '') + '\n\n' + pcuAppLink_() + '/',
      htmlBody: typeof emailShell_ === 'function' ? emailShell_(PCU_NUDGE.TITLE, html) : html
    });
    return true;
  } catch (err) {
    console.warn('Nudge email to ' + worker.email + ' failed: ' + (err && err.message));
    return false;
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

// ---------------------------------------------------------------------------
// Nightly recalculation of points and the leaderboard (phase 3)
// ---------------------------------------------------------------------------

var PCU_RECALC = { MONTHS: 2 };

/**
 * Nightly at 00:35 Africa/Lagos, after the sheet sync: rebuilds the
 * leaderboard (rankings/{month}/entries) for this month and last month from
 * followUps and guests with the same rules as the API (pcuPoints_), which
 * corrects any drift from saves made offline or at the same time. Every
 * active worker gets an entry (0 included); admins and paused workers never
 * do. Safe to run any number of times.
 */
function pcuNightlyRecalc() {
  if (!pcuFsEnabled_()) return { skipped: 'not set up' };
  return pcuWithLock_(function () {
    return pcuRecalcRankings_(new Date());
  });
}

function pcuRecalcRankings_(now) {
  var months = [pcuMonth_(now)];
  while (months.length < PCU_RECALC.MONTHS) {
    var p = months[months.length - 1].split('-');
    var y = +p[0];
    var m = +p[1] - 1;
    if (m < 1) {
      m = 12;
      y--;
    }
    months.push(y + '-' + pcuPad2_(m));
  }

  // Every follow-up, grouped by guest, oldest first, in the API's shape.
  var byGuest = {};
  pcuFsQueryAll_('followUps').forEach(function (doc) {
    var f = doc.data;
    var guestId = pcuStr_(f.guestId);
    if (!guestId) return;
    (byGuest[guestId] = byGuest[guestId] || []).push({
      id: doc.id,
      guestId: guestId,
      workerEmail: pcuEmail_(f.worker),
      // The call's day decides the month (as in the app); createdAt only orders.
      date: pcuCallMoment_(f) || null,
      order: f.createdAt instanceof Date ? f.createdAt.getTime() : Number.MAX_SAFE_INTEGER,
      sunday: f.attendedSunday === true,
      wednesday: f.attendedWednesday === true,
      team: pcuStr_(f.team)
    });
  });
  Object.keys(byGuest).forEach(function (id) {
    byGuest[id].sort(function (a, b) {
      return a.order - b.order;
    });
  });

  // Guests with a follow-up in these months, and every member.
  var want = {};
  Object.keys(byGuest).forEach(function (id) {
    if (byGuest[id].some(function (f) {
      return f.date && months.indexOf(pcuMonth_(f.date)) >= 0;
    })) want['guests/' + id] = true;
  });
  var docs = pcuFsGetDocs_(Object.keys(want));
  pcuFsQueryEqual_('guests', 'membershipStatus', PCU.STATUS.MEMBER).forEach(function (doc) {
    docs['guests/' + doc.id] = doc.data;
  });
  var guests = {
    list: Object.keys(docs).map(function (path) {
      var g = docs[path];
      return {
        id: path.substring('guests/'.length),
        serviceDay: pcuStr_(g.serviceDate),
        status: pcuStr_(g.membershipStatus),
        membershipDate: g.memberSince instanceof Date ? g.memberSince : null,
        assignedTo: pcuEmail_(g.assignedTo)
      };
    })
  };

  var workers = pcuWorkers_().list.filter(function (w) {
    return w.active && !w.isAdmin;
  });
  var result = { months: months, workers: workers.length, corrected: 0, removed: 0 };
  var writes = [];
  months.forEach(function (month) {
    var points = pcuPoints_(month, guests, { byGuest: byGuest });
    var existing = {};
    pcuFsList_('rankings/' + month + '/entries').forEach(function (doc) {
      existing[doc.id] = doc.data;
    });
    var keep = {};
    workers.forEach(function (w) {
      var email = pcuEmail_(w.email);
      var value = (points[email] && points[email].points) || 0;
      keep[email] = true;
      var old = existing[email];
      if (old && old.points === value && old.name === w.name) return;
      if (old) result.corrected++;
      // Only fields the security rules allow, so later saves from the app still pass.
      writes.push(pcuFsSet_('rankings/' + month + '/entries/' + email, {
        email: email,
        name: w.name,
        points: value,
        updatedAt: now
      }));
    });
    Object.keys(existing).forEach(function (email) {
      if (keep[email]) return;
      writes.push({ delete: pcuFsDocsBase_() + '/rankings/' + month + '/entries/' + email });
      result.removed++;
    });
  });
  result.written = pcuFsCommit_(writes);
  console.log('Leaderboard recalculated: ' + JSON.stringify(result));
  return result;
}

/** Every document of a collection, read in pages of 500. */
function pcuFsQueryAll_(collection) {
  var docs = [];
  var last = null;
  for (;;) {
    var query = {
      from: [{ collectionId: collection }],
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

/** The documents of one (sub)collection path, for example 'rankings/2026-11/entries'. */
function pcuFsList_(path) {
  var docs = [];
  var pageToken = '';
  do {
    var url = PCU_FS.API + '/' + pcuFsDocsBase_() + '/' + path + '?pageSize=300' + (pageToken ? '&pageToken=' + encodeURIComponent(pageToken) : '');
    var res = UrlFetchApp.fetch(url, { headers: { Authorization: 'Bearer ' + pcuFsToken_() }, muteHttpExceptions: true });
    if (res.getResponseCode() !== 200) {
      throw pcuError_('SERVER', 'Firestore read failed (' + res.getResponseCode() + '): ' + res.getContentText().substring(0, 200));
    }
    var body = JSON.parse(res.getContentText());
    (body.documents || []).forEach(function (doc) {
      docs.push(pcuFsDocument_(doc));
    });
    pageToken = body.nextPageToken || '';
  } while (pageToken);
  return docs;
}
