/**
 * PCU Connect API
 * ----------------
 * Google Apps Script web app that lets the Flutter app read and write the
 * PCU Google Sheet directly. Add this file to the Apps Script project that is
 * bound to the sheet (Extensions > Apps Script), next to the existing
 * round-robin and reminder scripts.
 *
 * Deploy: Deploy > New deployment > Web app
 *   Execute as: Me
 *   Who has access: Anyone
 * Copy the /exec URL into the Flutter build: --dart-define=APPS_SCRIPT_URL=<url>
 *
 * Script Properties (Project Settings > Script properties):
 *   FIREBASE_WEB_API_KEY  The Firebase web API key (same as in firebase_options.dart).
 *   ALLOW_MOCK_TOKENS     Optional. Only the exact value "true" lets mock_token
 *                         logins through. Set it on the TEST sheet only, never
 *                         on the live church sheet.
 *
 * Request:  POST body (text/plain) {"action": "...", "idToken": "<Firebase ID token>", ...}
 * Response: {"ok": true, "data": ...} or {"ok": false, "code": "...", "error": "..."}
 *
 * Every request is checked twice: the Firebase ID token must be valid, and the
 * Google email must be an Active row in the Workers tab. Workers only ever see
 * and change their own guests. All names in this file start with "pcu" so they
 * never clash with the other scripts in the project.
 */

var PCU = {
  TZ: 'Africa/Lagos',
  SHEETS: {
    GUESTS: 'Form Responses 1',
    FOLLOW_UPS: 'Follow-ups',
    WORKERS: 'Workers'
  },
  // Column headers, matched case-insensitively and ignoring extra spaces.
  G: {
    TIMESTAMP: 'TIMESTAMP',
    SERVICE_DATE: 'SERVICE DATE',
    NAME: 'FULL NAME',
    PHONE: 'PHONE NUMBER',
    ASSIGNED_TO: 'ASSIGNED TO',
    ASSIGNED_DATE: 'ASSIGNED DATE',
    CALL_STATUS: 'CALL STATUS',
    STATUS: 'MEMBERSHIP STATUS',
    FEEDBACK_1: 'FEEDBACK 1',
    FEEDBACK_2: 'FEEDBACK 2',
    FEEDBACK_1_DATE: 'FEEDBACK 1 DATE',
    FEEDBACK_2_DATE: 'FEEDBACK 2 DATE',
    MEMBERSHIP_DATE: 'MEMBERSHIP DATE',
    ID: 'GUEST ID',
    TEAM: 'TEAM JOINED',
    FOLLOW_UP_COUNT: 'FOLLOW-UP COUNT',
    LAST_FEEDBACK: 'LAST FEEDBACK',
    LAST_FEEDBACK_DATE: 'LAST FEEDBACK DATE'
  },
  F: {
    ID: 'FOLLOW-UP ID',
    GUEST: 'GUEST',
    WORKER: 'WORKER',
    DATE: 'CALL DATE',
    OUTCOME: 'CALL STATUS',
    NOTE: 'NOTE',
    SUNDAY: 'ATTENDED SUNDAY?',
    SUNDAY_DATE: 'SUNDAY DATE',
    WEDNESDAY: 'ATTENDED WEDNESDAY?',
    WEDNESDAY_DATE: 'WEDNESDAY DATE',
    TEAM: 'JOINED TEAM',
    // Optional. Who actually saved the row when an admin logs for a worker.
    LOGGED_BY: 'LOGGED BY'
  },
  W: {
    ID: 'ID',
    NAME: 'NAME',
    EMAIL: 'EMAIL',
    PHONE: 'PHONE',
    ROLE: 'ROLE',
    ACTIVE: 'ACTIVE'
  },
  OUTCOMES: ['Reached', 'No answer', 'Busy', 'Switched off', 'Wrong number', 'Not interested'],
  TEAMS: ['Workforce', 'Evangelism'],
  STATUS: {
    NEW: 'New guest',
    CONTACTED: 'Contacted',
    RETURNING: 'Returning',
    MEMBER: 'Member',
    NOT_INTERESTED: 'Not interested',
    UNREACHABLE: 'Unreachable'
  },
  FIRST_CALL_WINDOW_DAYS: 3,
  UNREACHABLE_AFTER: 3,
  MEMBER_RULE: { SUNDAYS: 4, SUNDAYS_WITH_WEDNESDAYS: 3, WEDNESDAYS: 2 },
  POINTS: { FIRST_CALL: 10, FOLLOW_UP: 5, ATTENDANCE: 10, TEAM_JOIN: 20, MEMBER: 30 },
  TOKEN_CACHE_SECONDS: 1800,
  MAX_NOTE_LENGTH: 2000
};

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

function doPost(e) {
  try {
    var body = (e && e.postData && e.postData.contents) || '{}';
    var req = JSON.parse(body);
    var user = pcuVerifyUser_(req.idToken);
    var handlers = pcuHandlers_();
    var handler = handlers[req.action];
    if (!handler) throw pcuError_('VALIDATION', 'Unknown action: ' + req.action);
    return pcuJson_({ ok: true, data: handler(user, req) });
  } catch (err) {
    var code = err && err.code ? err.code : 'SERVER';
    if (code === 'SERVER') console.error(err && err.stack ? err.stack : err);
    var message = err && err.message ? err.message : String(err);
    return pcuJson_({ ok: false, code: code, error: message });
  }
}

function pcuHandlers_() {
  return {
    me: pcuMe_,
    guests: pcuGuests_,
    guest: pcuGuest_,
    logFollowUp: pcuLogFollowUp_,
    ranking: pcuRanking_,
    dashboard: pcuDashboard_,
    team: pcuTeam_,
    saveWorker: pcuSaveWorker_,
    setWorkerActive: pcuSetWorkerActive_
  };
}

function pcuJson_(payload) {
  return ContentService.createTextOutput(JSON.stringify(payload)).setMimeType(ContentService.MimeType.JSON);
}

function pcuError_(code, message) {
  var error = new Error(message);
  error.code = code;
  return error;
}

// ---------------------------------------------------------------------------
// Authentication
// ---------------------------------------------------------------------------

/**
 * Verifies the Firebase ID token with Google's Identity Toolkit, then checks
 * the email against the Workers tab. Verified emails are cached briefly so
 * repeat requests stay fast.
 */
function pcuVerifyUser_(idToken) {
  if (!idToken) throw pcuError_('UNAUTHENTICATED', 'Please sign in.');

  // Dev mock tokens are only honoured when the Script Property
  // ALLOW_MOCK_TOKENS is exactly "true". Set it on the TEST sheet only.
  if (idToken.indexOf('mock_token_') === 0 || idToken === 'mock_token') {
    var allowMock = PropertiesService.getScriptProperties().getProperty('ALLOW_MOCK_TOKENS');
    if (allowMock !== 'true') {
      throw pcuError_('UNAUTHENTICATED', 'Please sign in.');
    }
    var mockEmail = idToken === 'mock_token' ? 'davidolanite0@gmail.com' : idToken.replace('mock_token_', '').trim().toLowerCase();
    var mockWorker = pcuWorkers_().byEmail[mockEmail];
    if (!mockWorker || !mockWorker.active) {
      throw pcuError_(
        'ACCESS_DENIED',
        'This Google account is not an active member of the PCU team. Ask your HOD to add it.'
      );
    }
    return { email: mockEmail, worker: mockWorker, isAdmin: mockWorker.isAdmin };
  }

  var cache = CacheService.getScriptCache();
  var digest = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_256, idToken);
  var cacheKey = 'pcu_tok_' + Utilities.base64EncodeWebSafe(digest).substring(0, 43);
  var email = cache.get(cacheKey);

  if (!email) {
    var apiKey = PropertiesService.getScriptProperties().getProperty('FIREBASE_WEB_API_KEY');
    if (!apiKey) throw pcuError_('SERVER', 'FIREBASE_WEB_API_KEY is missing from Script Properties.');

    var response = UrlFetchApp.fetch(
      'https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=' + encodeURIComponent(apiKey),
      {
        method: 'post',
        contentType: 'application/json',
        payload: JSON.stringify({ idToken: idToken }),
        muteHttpExceptions: true
      }
    );
    if (response.getResponseCode() !== 200) {
      throw pcuError_('UNAUTHENTICATED', 'Your session has expired. Please sign in again.');
    }
    var users = JSON.parse(response.getContentText()).users || [];
    var account = users[0];
    if (!account || !account.email || account.emailVerified === false) {
      throw pcuError_('UNAUTHENTICATED', 'Your Google account could not be verified.');
    }
    email = String(account.email).trim().toLowerCase();
    cache.put(cacheKey, email, PCU.TOKEN_CACHE_SECONDS);
  }

  var worker = pcuWorkers_().byEmail[email];
  if (!worker || !worker.active) {
    throw pcuError_(
      'ACCESS_DENIED',
      'This Google account is not an active member of the PCU team. Ask your HOD to add it.'
    );
  }
  return { email: email, worker: worker, isAdmin: worker.isAdmin };
}

function pcuRequireAdmin_(user) {
  if (!user.isAdmin) throw pcuError_('FORBIDDEN', 'Only the HOD can do this.');
}

// ---------------------------------------------------------------------------
// Sheet access
// ---------------------------------------------------------------------------

var pcuTableCache_ = {};

/** Reads a tab once per request and indexes its headers. */
function pcuTable_(name, fresh) {
  if (!fresh && pcuTableCache_[name]) return pcuTableCache_[name];
  var sheet = SpreadsheetApp.getActive().getSheetByName(name);
  if (!sheet) throw pcuError_('SERVER', 'Missing tab: ' + name);
  var values = sheet.getDataRange().getValues();
  var headers = values.length ? values[0] : [];
  var index = {};
  for (var c = 0; c < headers.length; c++) {
    var key = pcuHeaderKey_(headers[c]);
    if (key && index[key] === undefined) index[key] = c;
  }
  var table = { name: name, sheet: sheet, headers: headers, index: index, rows: values.slice(1) };
  pcuTableCache_[name] = table;
  return table;
}

function pcuHeaderKey_(value) {
  return String(value || '').replace(/\s+/g, ' ').trim().toUpperCase();
}

/** Column index for a header, or -1 when the column does not exist. */
function pcuCol_(table, header) {
  var i = table.index[pcuHeaderKey_(header)];
  return i === undefined ? -1 : i;
}

function pcuRequireCol_(table, header) {
  var i = pcuCol_(table, header);
  if (i < 0) throw pcuError_('SERVER', 'Column "' + header + '" not found in ' + table.name + '.');
  return i;
}

function pcuCell_(table, row, header) {
  var i = pcuCol_(table, header);
  return i < 0 ? '' : row[i];
}

/** Writes one cell. rowIndex is 0-based within table.rows. */
function pcuSetCell_(table, rowIndex, header, value) {
  var col = pcuCol_(table, header);
  if (col < 0) return;
  table.sheet.getRange(rowIndex + 2, col + 1).setValue(value);
  table.rows[rowIndex][col] = value;
}

/** Appends a row, placing values by header name. */
function pcuAppend_(table, valuesByHeader) {
  var row = [];
  for (var c = 0; c < table.headers.length; c++) row.push('');
  Object.keys(valuesByHeader).forEach(function (header) {
    var col = pcuCol_(table, header);
    if (col >= 0) row[col] = valuesByHeader[header];
  });
  table.sheet.appendRow(row);
  table.rows.push(row);
  return table.rows.length - 1;
}

/** Copies the Workers tab to Firestore users when Firestore is set up. Never throws. */
function pcuSyncUsersQuietly_() {
  if (typeof pcuSyncUsers_ !== 'function') return;
  try {
    pcuSyncUsers_();
  } catch (err) {
    console.warn('Could not send workers to Firestore: ' + (err && err.message));
  }
}

// ---------------------------------------------------------------------------
// Value helpers
// ---------------------------------------------------------------------------

function pcuStr_(value) {
  return value === null || value === undefined ? '' : String(value).trim();
}

function pcuBool_(value) {
  if (value === true) return true;
  var v = pcuStr_(value).toLowerCase();
  return v === 'true' || v === 'yes' || v === 'y' || v === '1';
}

/** Parses a sheet value or a "yyyy-MM-dd" string into a Date, or null. */
function pcuDate_(value) {
  if (value instanceof Date) return isNaN(value.getTime()) ? null : value;
  var s = pcuStr_(value);
  if (!s) return null;
  if (/^\d{4}-\d{2}-\d{2}$/.test(s)) return Utilities.parseDate(s, PCU.TZ, 'yyyy-MM-dd');
  var d = new Date(s);
  return isNaN(d.getTime()) ? null : d;
}

function pcuDay_(date) {
  return date ? Utilities.formatDate(date, PCU.TZ, 'yyyy-MM-dd') : '';
}

function pcuMonth_(date) {
  return date ? Utilities.formatDate(date, PCU.TZ, 'yyyy-MM') : '';
}

function pcuToday_() {
  return pcuDay_(new Date());
}

/** Whole days from day string a to day string b (b minus a). */
function pcuDaysBetween_(a, b) {
  if (!a || !b) return 0;
  var pa = a.split('-');
  var pb = b.split('-');
  var ta = Date.UTC(+pa[0], +pa[1] - 1, +pa[2]);
  var tb = Date.UTC(+pb[0], +pb[1] - 1, +pb[2]);
  return Math.round((tb - ta) / 86400000);
}

function pcuIsWednesday_(date) {
  return Utilities.formatDate(date, PCU.TZ, 'u') === '3';
}

/** Keeps a leading zero on Nigerian numbers stored as plain numbers. */
function pcuPhone_(value) {
  var s = pcuStr_(value);
  if (/^\d{10}$/.test(s) && s.charAt(0) !== '0') return '0' + s;
  return s;
}

function pcuMonthParam_(value) {
  var s = pcuStr_(value);
  if (/^\d{4}-\d{2}$/.test(s)) return s;
  return pcuMonth_(new Date());
}

/** The last [count] month keys ending with the current month, oldest first. */
function pcuRecentMonths_(count) {
  var now = new Date();
  var parts = pcuMonth_(now).split('-');
  var year = +parts[0];
  var month = +parts[1];
  var keys = [];
  for (var i = count - 1; i >= 0; i--) {
    var m = month - i;
    var y = year;
    while (m < 1) {
      m += 12;
      y -= 1;
    }
    keys.push(y + '-' + (m < 10 ? '0' + m : m));
  }
  return keys;
}

// ---------------------------------------------------------------------------
// Domain loading
// ---------------------------------------------------------------------------

function pcuWorkers_() {
  var t = pcuTable_(PCU.SHEETS.WORKERS);
  var byEmail = {};
  var byId = {};
  var list = [];
  t.rows.forEach(function (row, i) {
    var email = pcuStr_(pcuCell_(t, row, PCU.W.EMAIL)).toLowerCase();
    if (!email) return;
    var role = pcuStr_(pcuCell_(t, row, PCU.W.ROLE)) || 'Worker';
    var isAdmin = /^(admin|hod)$/i.test(role);
    var worker = {
      rowIndex: i,
      id: pcuStr_(pcuCell_(t, row, PCU.W.ID)),
      name: pcuStr_(pcuCell_(t, row, PCU.W.NAME)) || email,
      email: email,
      phone: pcuPhone_(pcuCell_(t, row, PCU.W.PHONE)),
      role: isAdmin ? 'Admin' : 'Worker',
      isAdmin: isAdmin,
      active: pcuBool_(pcuCell_(t, row, PCU.W.ACTIVE))
    };
    byEmail[email] = worker;
    if (worker.id) byId[worker.id] = worker;
    list.push(worker);
  });
  return { table: t, byEmail: byEmail, byId: byId, list: list };
}

/** Follow-ups grouped by guest id, oldest first. */
function pcuFollowUps_(fresh) {
  var t = pcuTable_(PCU.SHEETS.FOLLOW_UPS, fresh);
  var byGuest = {};
  t.rows.forEach(function (row, i) {
    var guestId = pcuStr_(pcuCell_(t, row, PCU.F.GUEST));
    if (!guestId) return;
    var item = {
      rowIndex: i,
      id: pcuStr_(pcuCell_(t, row, PCU.F.ID)),
      guestId: guestId,
      workerEmail: pcuStr_(pcuCell_(t, row, PCU.F.WORKER)).toLowerCase(),
      // Blank when the column is missing or the row predates it.
      loggedBy: pcuStr_(pcuCell_(t, row, PCU.F.LOGGED_BY)).toLowerCase(),
      date: pcuDate_(pcuCell_(t, row, PCU.F.DATE)),
      outcome: pcuStr_(pcuCell_(t, row, PCU.F.OUTCOME)),
      note: pcuStr_(pcuCell_(t, row, PCU.F.NOTE)),
      sunday: pcuBool_(pcuCell_(t, row, PCU.F.SUNDAY)),
      sundayDate: pcuDate_(pcuCell_(t, row, PCU.F.SUNDAY_DATE)),
      wednesday: pcuBool_(pcuCell_(t, row, PCU.F.WEDNESDAY)),
      wednesdayDate: pcuDate_(pcuCell_(t, row, PCU.F.WEDNESDAY_DATE)),
      team: pcuStr_(pcuCell_(t, row, PCU.F.TEAM))
    };
    (byGuest[guestId] = byGuest[guestId] || []).push(item);
  });
  Object.keys(byGuest).forEach(function (id) {
    byGuest[id].sort(function (a, b) {
      return (a.date ? a.date.getTime() : 0) - (b.date ? b.date.getTime() : 0);
    });
  });
  return { table: t, byGuest: byGuest };
}

/** Every guest row with an id, as plain objects. */
function pcuGuestRows_(fresh) {
  var t = pcuTable_(PCU.SHEETS.GUESTS, fresh);
  var list = [];
  t.rows.forEach(function (row, i) {
    var id = pcuStr_(pcuCell_(t, row, PCU.G.ID));
    if (!id) return;
    var serviceDate = pcuDate_(pcuCell_(t, row, PCU.G.SERVICE_DATE)) || pcuDate_(pcuCell_(t, row, PCU.G.TIMESTAMP));
    list.push({
      rowIndex: i,
      id: id,
      name: pcuStr_(pcuCell_(t, row, PCU.G.NAME)),
      phone: pcuPhone_(pcuCell_(t, row, PCU.G.PHONE)),
      serviceDate: serviceDate,
      serviceDay: pcuDay_(serviceDate),
      month: pcuMonth_(serviceDate),
      assignedTo: pcuStr_(pcuCell_(t, row, PCU.G.ASSIGNED_TO)).toLowerCase(),
      assignedDate: pcuDate_(pcuCell_(t, row, PCU.G.ASSIGNED_DATE)),
      callStatus: pcuStr_(pcuCell_(t, row, PCU.G.CALL_STATUS)),
      status: pcuStr_(pcuCell_(t, row, PCU.G.STATUS)),
      feedback1: pcuStr_(pcuCell_(t, row, PCU.G.FEEDBACK_1)),
      feedback2: pcuStr_(pcuCell_(t, row, PCU.G.FEEDBACK_2)),
      feedback1Date: pcuDate_(pcuCell_(t, row, PCU.G.FEEDBACK_1_DATE)),
      feedback2Date: pcuDate_(pcuCell_(t, row, PCU.G.FEEDBACK_2_DATE)),
      membershipDate: pcuDate_(pcuCell_(t, row, PCU.G.MEMBERSHIP_DATE)),
      team: pcuStr_(pcuCell_(t, row, PCU.G.TEAM)),
      followUpCount: Number(pcuCell_(t, row, PCU.G.FOLLOW_UP_COUNT)) || 0,
      lastFeedback: pcuStr_(pcuCell_(t, row, PCU.G.LAST_FEEDBACK)),
      lastFeedbackDate: pcuDate_(pcuCell_(t, row, PCU.G.LAST_FEEDBACK_DATE))
    });
  });
  return { table: t, list: list };
}

function pcuFindGuest_(guests, id) {
  for (var i = 0; i < guests.list.length; i++) {
    if (guests.list[i].id === id) return guests.list[i];
  }
  return null;
}

// ---------------------------------------------------------------------------
// Business rules
// ---------------------------------------------------------------------------

/**
 * Distinct Sunday and Wednesday attendances per month. The first visit counts
 * (a Wednesday visit as a Wednesday, any other day as a Sunday service).
 * Logged attendance can be on any past date; the toggle decides the type.
 */
function pcuAttendanceByMonth_(guest, followUps) {
  var months = {};
  function add(kind, date) {
    if (!date) return;
    var m = pcuMonth_(date);
    months[m] = months[m] || { sundays: {}, wednesdays: {} };
    months[m][kind][pcuDay_(date)] = true;
  }
  if (guest.serviceDate) add(pcuIsWednesday_(guest.serviceDate) ? 'wednesdays' : 'sundays', guest.serviceDate);
  followUps.forEach(function (f) {
    if (f.sunday) add('sundays', f.sundayDate || f.date);
    if (f.wednesday) add('wednesdays', f.wednesdayDate || f.date);
  });
  var result = {};
  Object.keys(months).forEach(function (m) {
    result[m] = {
      sundays: Object.keys(months[m].sundays).length,
      wednesdays: Object.keys(months[m].wednesdays).length
    };
  });
  return result;
}

function pcuQualifies_(counts) {
  var r = PCU.MEMBER_RULE;
  return (
    counts.sundays >= r.SUNDAYS || (counts.sundays >= r.SUNDAYS_WITH_WEDNESDAYS && counts.wednesdays >= r.WEDNESDAYS)
  );
}

function pcuQualifiesAnyMonth_(attendance) {
  return Object.keys(attendance).some(function (m) {
    return pcuQualifies_(attendance[m]);
  });
}

/** Number of calls, counting feedback written before the app existed. */
function pcuCallCount_(guest, followUps) {
  var legacy = Math.max(guest.followUpCount, (guest.feedback1 ? 1 : 0) + (guest.feedback2 ? 1 : 0));
  return Math.max(followUps.length, legacy);
}

/**
 * Status after a follow-up, in priority order:
 * Member (sticky) > Not interested (sticky) > Returning > Contacted > Unreachable > unchanged.
 */
function pcuNextStatus_(guest, followUps) {
  var S = PCU.STATUS;
  var current = guest.status || S.NEW;
  if (current === S.MEMBER || pcuQualifiesAnyMonth_(pcuAttendanceByMonth_(guest, followUps))) return S.MEMBER;
  var latest = followUps[followUps.length - 1];
  if (current === S.NOT_INTERESTED || (latest && latest.outcome === 'Not interested')) return S.NOT_INTERESTED;
  var attended = followUps.some(function (f) {
    return f.sunday || f.wednesday;
  });
  if (attended) return S.RETURNING;
  var reached = followUps.some(function (f) {
    return f.outcome === 'Reached';
  });
  if (reached) return S.CONTACTED;
  if (followUps.length >= PCU.UNREACHABLE_AFTER) return S.UNREACHABLE;
  return current;
}

/** True when the first follow-up happened within the first-call window. */
function pcuFirstCallOnTime_(guest, followUps) {
  var first = followUps[0];
  if (!first || !first.date || !guest.serviceDay) return false;
  return pcuDaysBetween_(guest.serviceDay, pcuDay_(first.date)) <= PCU.FIRST_CALL_WINDOW_DAYS;
}

// ---------------------------------------------------------------------------
// Serialisers
// ---------------------------------------------------------------------------

function pcuGuestJson_(guest, followUps, workers, withHistory) {
  var latest = followUps[followUps.length - 1];
  var latestNote = null;
  for (var i = followUps.length - 1; i >= 0; i--) {
    if (followUps[i].note) {
      latestNote = followUps[i];
      break;
    }
  }
  var latestTeam = '';
  followUps.forEach(function (f) {
    if (f.team) latestTeam = f.team;
  });
  var thisMonth = pcuAttendanceByMonth_(guest, followUps)[pcuMonth_(new Date())] || { sundays: 0, wednesdays: 0 };
  var assigned = workers.byEmail[guest.assignedTo];

  var json = {
    id: guest.id,
    name: guest.name,
    phone: guest.phone,
    serviceDate: guest.serviceDay,
    month: guest.month,
    daysSinceVisit: guest.serviceDay ? Math.max(0, pcuDaysBetween_(guest.serviceDay, pcuToday_())) : 0,
    followUps: pcuCallCount_(guest, followUps),
    status: guest.status || PCU.STATUS.NEW,
    lastOutcome: latest ? latest.outcome : guest.callStatus,
    lastFeedback: guest.lastFeedback || (latestNote ? latestNote.note : '') || guest.feedback2 || guest.feedback1,
    lastFeedbackDate: pcuDay_(
      guest.lastFeedbackDate || (latestNote ? latestNote.date : null) || guest.feedback2Date || guest.feedback1Date
    ),
    team: guest.team || latestTeam,
    assignedTo: guest.assignedTo,
    assignedName: assigned ? assigned.name : '',
    sundays: thisMonth.sundays,
    wednesdays: thisMonth.wednesdays,
    membershipDate: pcuDay_(guest.membershipDate)
  };

  if (withHistory) {
    json.history = followUps
      .slice()
      .reverse()
      .map(function (f) {
        var worker = workers.byEmail[f.workerEmail];
        var loggedBy = f.loggedBy || f.workerEmail;
        var logger = workers.byEmail[loggedBy];
        return {
          id: f.id,
          date: pcuDay_(f.date),
          outcome: f.outcome,
          note: f.note,
          attendedSunday: f.sunday,
          sundayDate: pcuDay_(f.sundayDate),
          attendedWednesday: f.wednesday,
          wednesdayDate: pcuDay_(f.wednesdayDate),
          team: f.team,
          workerEmail: f.workerEmail,
          workerName: worker ? worker.name : '',
          loggedByEmail: loggedBy,
          loggedByName: logger ? logger.name : '',
          loggedByAdmin: loggedBy !== f.workerEmail
        };
      });
  }
  return json;
}

function pcuWorkerJson_(worker, stats) {
  var s = stats || {};
  return {
    id: worker.id,
    name: worker.name,
    email: worker.email,
    phone: worker.phone,
    role: worker.role,
    active: worker.active,
    guests: s.guests || 0,
    contacted: s.contacted || 0,
    followUps: s.followUps || 0,
    members: s.members || 0,
    inTeam: s.inTeam || 0,
    calledWithin3Days: s.calledWithin3Days || 0,
    points: s.points || 0
  };
}

// ---------------------------------------------------------------------------
// Handlers
// ---------------------------------------------------------------------------

function pcuMe_(user) {
  var w = user.worker;
  return { id: w.id, name: w.name, email: w.email, phone: w.phone, role: w.role, active: w.active };
}

/** Guests whose first visit was in req.month. Workers get their own only. */
function pcuGuests_(user, req) {
  var month = pcuMonthParam_(req.month);
  var scope = user.isAdmin ? pcuStr_(req.workerEmail).toLowerCase() : user.email;
  var guests = pcuGuestRows_();
  var followUps = pcuFollowUps_();
  var workers = pcuWorkers_();

  var list = guests.list
    .filter(function (g) {
      return g.month === month && (!scope || g.assignedTo === scope);
    })
    .map(function (g) {
      return pcuGuestJson_(g, followUps.byGuest[g.id] || [], workers, false);
    });
  return { month: month, guests: list };
}

function pcuGuest_(user, req) {
  var id = pcuStr_(req.id);
  var guest = pcuFindGuest_(pcuGuestRows_(), id);
  if (!guest) throw pcuError_('NOT_FOUND', 'Guest not found.');
  if (!user.isAdmin && guest.assignedTo !== user.email) {
    throw pcuError_('FORBIDDEN', 'This guest is assigned to someone else.');
  }
  return pcuGuestJson_(guest, pcuFollowUps_().byGuest[id] || [], pcuWorkers_(), true);
}

/**
 * Saves a follow-up, then updates the guest row: call status, feedback,
 * team, follow-up count and membership status. Runs under a script lock so
 * two people saving at once cannot overwrite each other.
 */
function pcuLogFollowUp_(user, req) {
  var guestId = pcuStr_(req.guestId);
  var outcome = pcuStr_(req.outcome);
  var note = pcuStr_(req.note).substring(0, PCU.MAX_NOTE_LENGTH);
  var team = pcuStr_(req.team);
  var attendedSunday = req.attendedSunday === true;
  var attendedWednesday = req.attendedWednesday === true;
  var today = pcuToday_();

  if (!guestId) throw pcuError_('VALIDATION', 'Missing guest.');
  if (PCU.OUTCOMES.indexOf(outcome) < 0) throw pcuError_('VALIDATION', 'Choose how the call went.');
  if (team && PCU.TEAMS.indexOf(team) < 0) throw pcuError_('VALIDATION', 'Unknown team.');

  // Attendance can be any past date (not only Sundays or Wednesdays), never a future one.
  var sundayDate = attendedSunday ? pcuDate_(req.sundayDate) : null;
  var wednesdayDate = attendedWednesday ? pcuDate_(req.wednesdayDate) : null;
  if (attendedSunday && !sundayDate) throw pcuError_('VALIDATION', 'Pick the date they attended.');
  if (attendedWednesday && !wednesdayDate) throw pcuError_('VALIDATION', 'Pick the date they attended.');
  if ((sundayDate && pcuDay_(sundayDate) > today) || (wednesdayDate && pcuDay_(wednesdayDate) > today)) {
    throw pcuError_('VALIDATION', 'Attendance date cannot be in the future.');
  }

  var lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw pcuError_('BUSY', 'Someone else is saving right now. Please try again.');
  try {
    var guests = pcuGuestRows_(true);
    var followUps = pcuFollowUps_(true);
    var workers = pcuWorkers_();
    var guest = pcuFindGuest_(guests, guestId);
    if (!guest) throw pcuError_('NOT_FOUND', 'Guest not found.');
    if (!user.isAdmin && guest.assignedTo !== user.email) {
      throw pcuError_('FORBIDDEN', 'This guest is assigned to someone else.');
    }
    // The follow-up always counts for the assigned worker, so an admin logging
    // on their behalf never earns points or calls. ASSIGNED TO is not changed.
    var creditEmail = user.isAdmin ? guest.assignedTo : user.email;
    if (!creditEmail) {
      throw pcuError_('VALIDATION', 'Assign this guest to a worker before logging a follow-up.');
    }

    var before = (followUps.byGuest[guestId] || []).slice();
    var statusBefore = guest.status || PCU.STATUS.NEW;
    var teamBefore = guest.team;
    var now = new Date();

    var entry = {
      id: Utilities.getUuid().substring(0, 8),
      guestId: guestId,
      workerEmail: creditEmail,
      loggedBy: user.email,
      date: now,
      outcome: outcome,
      note: note,
      sunday: attendedSunday,
      sundayDate: sundayDate,
      wednesday: attendedWednesday,
      wednesdayDate: wednesdayDate,
      team: team
    };

    var values = {};
    values[PCU.F.ID] = entry.id;
    values[PCU.F.GUEST] = guestId;
    values[PCU.F.WORKER] = creditEmail;
    values[PCU.F.LOGGED_BY] = user.email;
    values[PCU.F.DATE] = now;
    values[PCU.F.OUTCOME] = outcome;
    values[PCU.F.NOTE] = note;
    values[PCU.F.SUNDAY] = attendedSunday;
    values[PCU.F.SUNDAY_DATE] = sundayDate || '';
    values[PCU.F.WEDNESDAY] = attendedWednesday;
    values[PCU.F.WEDNESDAY_DATE] = wednesdayDate || '';
    values[PCU.F.TEAM] = team;
    pcuAppend_(followUps.table, values);

    var all = before.concat([entry]);
    pcuApplyToGuest_(guests.table, guest, all, now);
    SpreadsheetApp.flush();

    // Points earned by this save, using the same rules as the leaderboard.
    var points = 0;
    if (before.length === 0 && pcuFirstCallOnTime_(guest, all)) points += PCU.POINTS.FIRST_CALL;
    else points += PCU.POINTS.FOLLOW_UP;
    if (attendedSunday) points += PCU.POINTS.ATTENDANCE;
    if (attendedWednesday) points += PCU.POINTS.ATTENDANCE;
    var teamAlreadySet = teamBefore || before.some(function (f) {
      return !!f.team;
    });
    if (team && !teamAlreadySet) points += PCU.POINTS.TEAM_JOIN;
    if (statusBefore !== PCU.STATUS.MEMBER && guest.status === PCU.STATUS.MEMBER) points += PCU.POINTS.MEMBER;

    var result = { guest: pcuGuestJson_(guest, all, workers, true), pointsEarned: points };
  } finally {
    lock.releaseLock();
  }
  // Phase 1: keep Firestore in step, reusing what this save already loaded.
  // Never fails the save; the 5-minute job catches up if this does not get through.
  if (typeof pcuPushGuestDataQuietly_ === 'function') {
    pcuPushGuestDataQuietly_(guests.table, guest, all, workers);
  }
  return result;
}

/** Writes the derived columns of a guest row and updates the in-memory guest. */
function pcuApplyToGuest_(table, guest, followUps, now) {
  var latest = followUps[followUps.length - 1];
  var G = PCU.G;

  pcuSetCell_(table, guest.rowIndex, G.CALL_STATUS, latest.outcome);
  pcuSetCell_(table, guest.rowIndex, G.FOLLOW_UP_COUNT, followUps.length);
  guest.callStatus = latest.outcome;
  guest.followUpCount = followUps.length;

  // FEEDBACK 1 and 2 keep the first two notes; existing values are never replaced.
  var notes = followUps.filter(function (f) {
    return !!f.note;
  });
  if (!guest.feedback1 && notes[0]) {
    pcuSetCell_(table, guest.rowIndex, G.FEEDBACK_1, notes[0].note);
    pcuSetCell_(table, guest.rowIndex, G.FEEDBACK_1_DATE, notes[0].date);
    guest.feedback1 = notes[0].note;
    guest.feedback1Date = notes[0].date;
  }
  if (!guest.feedback2 && notes[1]) {
    pcuSetCell_(table, guest.rowIndex, G.FEEDBACK_2, notes[1].note);
    pcuSetCell_(table, guest.rowIndex, G.FEEDBACK_2_DATE, notes[1].date);
    guest.feedback2 = notes[1].note;
    guest.feedback2Date = notes[1].date;
  }

  // LAST FEEDBACK is always the newest note.
  if (latest.note) {
    pcuSetCell_(table, guest.rowIndex, G.LAST_FEEDBACK, latest.note);
    pcuSetCell_(table, guest.rowIndex, G.LAST_FEEDBACK_DATE, now);
    guest.lastFeedback = latest.note;
    guest.lastFeedbackDate = now;
  }

  if (latest.team) {
    pcuSetCell_(table, guest.rowIndex, G.TEAM, latest.team);
    guest.team = latest.team;
  }

  var nextStatus = pcuNextStatus_(guest, followUps);
  if (nextStatus !== guest.status) {
    pcuSetCell_(table, guest.rowIndex, G.STATUS, nextStatus);
    guest.status = nextStatus;
  }
  if (nextStatus === PCU.STATUS.MEMBER && !guest.membershipDate) {
    pcuSetCell_(table, guest.rowIndex, G.MEMBERSHIP_DATE, now);
    guest.membershipDate = now;
  }
}

/**
 * Points per worker for one month, computed from the Follow-ups tab so the
 * leaderboard can never drift from what was actually logged.
 */
function pcuPoints_(month, guests, followUps) {
  var P = PCU.POINTS;
  var byWorker = {};
  function bucket(email) {
    return (byWorker[email] = byWorker[email] || {
      points: 0,
      firstCalls: 0,
      followUps: 0,
      attendances: 0,
      teamJoins: 0,
      members: 0
    });
  }

  var guestById = {};
  guests.list.forEach(function (g) {
    guestById[g.id] = g;
  });

  Object.keys(followUps.byGuest).forEach(function (guestId) {
    var list = followUps.byGuest[guestId];
    var guest = guestById[guestId];
    var teamSeen = false;
    list.forEach(function (f, i) {
      var isTeamJoin = !!f.team && !teamSeen;
      if (f.team) teamSeen = true;
      if (!f.date || pcuMonth_(f.date) !== month || !f.workerEmail) return;
      var b = bucket(f.workerEmail);
      if (i === 0 && guest && pcuFirstCallOnTime_(guest, list)) {
        b.firstCalls++;
        b.points += P.FIRST_CALL;
      } else {
        b.followUps++;
        b.points += P.FOLLOW_UP;
      }
      var attended = (f.sunday ? 1 : 0) + (f.wednesday ? 1 : 0);
      b.attendances += attended;
      b.points += attended * P.ATTENDANCE;
      if (isTeamJoin) {
        b.teamJoins++;
        b.points += P.TEAM_JOIN;
      }
    });
  });

  guests.list.forEach(function (g) {
    if (g.status === PCU.STATUS.MEMBER && g.membershipDate && pcuMonth_(g.membershipDate) === month && g.assignedTo) {
      var b = bucket(g.assignedTo);
      b.members++;
      b.points += P.MEMBER;
    }
  });
  return byWorker;
}

function pcuRanking_(user, req) {
  var month = pcuMonthParam_(req.month);
  var workers = pcuWorkers_();
  var points = pcuPoints_(month, pcuGuestRows_(), pcuFollowUps_());

  var entries = workers.list
    .filter(function (w) {
      return w.active && !w.isAdmin;
    })
    .map(function (w) {
      var p = points[w.email] || {};
      return {
        email: w.email,
        name: w.name,
        points: p.points || 0,
        breakdown: {
          firstCalls: p.firstCalls || 0,
          followUps: p.followUps || 0,
          attendances: p.attendances || 0,
          teamJoins: p.teamJoins || 0,
          members: p.members || 0
        }
      };
    });

  entries.sort(function (a, b) {
    return b.points - a.points || a.name.localeCompare(b.name);
  });
  entries.forEach(function (e) {
    e.rank =
      1 +
      entries.filter(function (other) {
        return other.points > e.points;
      }).length;
  });

  var me = null;
  entries.forEach(function (e) {
    if (e.email === user.email) me = e;
  });
  return { month: month, entries: entries, me: me };
}

/** Per worker numbers for one month (guests by first visit date). */
function pcuWorkerStats_(month, guests, followUps) {
  var stats = {};
  function bucket(email) {
    return (stats[email] = stats[email] || {
      guests: 0,
      contacted: 0,
      followUps: 0,
      members: 0,
      inTeam: 0,
      calledWithin3Days: 0,
      points: 0
    });
  }

  guests.list.forEach(function (g) {
    if (g.month !== month || !g.assignedTo) return;
    var list = followUps.byGuest[g.id] || [];
    var b = bucket(g.assignedTo);
    b.guests++;
    if (pcuCallCount_(g, list) > 0) b.contacted++;
    if (g.status === PCU.STATUS.MEMBER) b.members++;
    if (g.team || list.some(function (f) { return !!f.team; })) b.inTeam++;
    if (pcuFirstCallOnTime_(g, list)) b.calledWithin3Days++;
  });

  Object.keys(followUps.byGuest).forEach(function (guestId) {
    followUps.byGuest[guestId].forEach(function (f) {
      if (f.date && pcuMonth_(f.date) === month && f.workerEmail) bucket(f.workerEmail).followUps++;
    });
  });

  var points = pcuPoints_(month, guests, followUps);
  Object.keys(points).forEach(function (email) {
    bucket(email).points = points[email].points;
  });
  return stats;
}

function pcuDashboard_(user, req) {
  pcuRequireAdmin_(user);
  var month = pcuMonthParam_(req.month);
  var guests = pcuGuestRows_();
  var followUps = pcuFollowUps_();
  var workers = pcuWorkers_();

  var months = pcuRecentMonths_(12);
  var trend = {};
  months.forEach(function (m) {
    trend[m] = { month: m, guests: 0, members: 0, called: 0 };
  });

  var totals = { guests: 0, called: 0, members: 0, inTeam: 0, followUps: 0 };
  guests.list.forEach(function (g) {
    var list = followUps.byGuest[g.id] || [];
    var called = pcuCallCount_(g, list) > 0;
    var member = g.status === PCU.STATUS.MEMBER;
    if (trend[g.month]) {
      trend[g.month].guests++;
      if (called) trend[g.month].called++;
      if (member) trend[g.month].members++;
    }
    if (g.month !== month) return;
    totals.guests++;
    if (called) totals.called++;
    if (member) totals.members++;
    if (g.team || list.some(function (f) { return !!f.team; })) totals.inTeam++;
    totals.followUps += list.length;
  });

  var points = pcuPoints_(month, guests, followUps);
  var top = workers.list
    .filter(function (w) {
      return !w.isAdmin && points[w.email];
    })
    .map(function (w) {
      return { email: w.email, name: w.name, members: points[w.email].members, points: points[w.email].points };
    })
    .sort(function (a, b) {
      return b.members - a.members || b.points - a.points;
    })
    .slice(0, 3);

  return {
    month: month,
    totals: totals,
    topWorkers: top,
    trend: months.map(function (m) {
      return trend[m];
    })
  };
}

function pcuTeam_(user, req) {
  pcuRequireAdmin_(user);
  var month = pcuMonthParam_(req.month);
  var stats = pcuWorkerStats_(month, pcuGuestRows_(), pcuFollowUps_());
  var members = pcuWorkers_().list.map(function (w) {
    return pcuWorkerJson_(w, stats[w.email]);
  });
  return { month: month, members: members };
}

function pcuSaveWorker_(user, req) {
  pcuRequireAdmin_(user);
  var name = pcuStr_(req.name);
  var email = pcuStr_(req.email).toLowerCase();
  var phone = pcuStr_(req.phone);
  var isAdmin = /^(admin|hod)$/i.test(pcuStr_(req.role));
  var active = isAdmin ? true : req.active !== false;

  if (!name) throw pcuError_('VALIDATION', 'Enter a name.');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) throw pcuError_('VALIDATION', 'Enter a valid Google email.');

  var lock = LockService.getScriptLock();
  if (!lock.tryLock(20000)) throw pcuError_('BUSY', 'Someone else is saving right now. Please try again.');
  try {
    pcuTable_(PCU.SHEETS.WORKERS, true);
    var workers = pcuWorkers_();
    if (workers.byEmail[email]) throw pcuError_('VALIDATION', 'This email is already on the team.');

    var next = 1;
    workers.list.forEach(function (w) {
      var match = /^W(\d+)$/i.exec(w.id);
      if (match) next = Math.max(next, Number(match[1]) + 1);
    });
    var id = 'W' + ('00' + next).slice(-3);

    var values = {};
    values[PCU.W.ID] = id;
    values[PCU.W.NAME] = name;
    values[PCU.W.EMAIL] = email;
    values[PCU.W.PHONE] = phone;
    values[PCU.W.ROLE] = isAdmin ? 'Admin' : 'Worker';
    values[PCU.W.ACTIVE] = active ? 'Yes' : 'No';
    pcuAppend_(workers.table, values);
    SpreadsheetApp.flush();

    pcuSyncUsersQuietly_();
    return pcuWorkerJson_({
      id: id,
      name: name,
      email: email,
      phone: phone,
      role: isAdmin ? 'Admin' : 'Worker',
      active: active
    });
  } finally {
    lock.releaseLock();
  }
}

function pcuSetWorkerActive_(user, req) {
  pcuRequireAdmin_(user);
  var id = pcuStr_(req.id);
  var active = req.active === true;
  var workers = pcuWorkers_();
  var worker = workers.byId[id];
  if (!worker) throw pcuError_('NOT_FOUND', 'Worker not found.');
  if (!active && worker.email === user.email) {
    throw pcuError_('VALIDATION', 'You cannot make yourself inactive.');
  }

  pcuSetCell_(workers.table, worker.rowIndex, PCU.W.ACTIVE, active ? 'Yes' : 'No');
  SpreadsheetApp.flush();
  worker.active = active;
  pcuSyncUsersQuietly_();

  var month = pcuMonth_(new Date());
  var stats = pcuWorkerStats_(month, pcuGuestRows_(), pcuFollowUps_());
  return pcuWorkerJson_(worker, stats[worker.email]);
}

// ---------------------------------------------------------------------------
// Manual checks (run from the Apps Script editor)
// ---------------------------------------------------------------------------

/**
 * Runs every read action as the first active Admin in the Workers tab,
 * skipping token verification, and logs the results. Use it after deploying
 * to confirm the sheet columns are found.
 */
function pcuSelfTest() {
  var admin = pcuWorkers_().list.filter(function (w) {
    return w.isAdmin && w.active;
  })[0];
  if (!admin) throw new Error('No active Admin in the Workers tab.');
  var user = { email: admin.email, worker: admin, isAdmin: true };
  var month = pcuMonth_(new Date());

  [PCU.SHEETS.GUESTS, PCU.SHEETS.FOLLOW_UPS, PCU.SHEETS.WORKERS].forEach(function (name) {
    var t = pcuTable_(name);
    console.log(name + ': ' + t.rows.length + ' rows');
  });
  [PCU.G.SERVICE_DATE, PCU.G.NAME, PCU.G.PHONE, PCU.G.ASSIGNED_TO, PCU.G.ID, PCU.G.STATUS].forEach(function (h) {
    pcuRequireCol_(pcuTable_(PCU.SHEETS.GUESTS), h);
  });
  [PCU.F.ID, PCU.F.GUEST, PCU.F.WORKER, PCU.F.DATE, PCU.F.OUTCOME].forEach(function (h) {
    pcuRequireCol_(pcuTable_(PCU.SHEETS.FOLLOW_UPS), h);
  });

  console.log('me: ' + JSON.stringify(pcuMe_(user)));
  console.log('guests this month: ' + pcuGuests_(user, { month: month }).guests.length);
  console.log('ranking: ' + JSON.stringify(pcuRanking_(user, { month: month }).entries.slice(0, 3)));
  console.log('dashboard totals: ' + JSON.stringify(pcuDashboard_(user, { month: month }).totals));
  console.log('team size: ' + pcuTeam_(user, { month: month }).members.length);
  console.log('All checks passed.');
}
