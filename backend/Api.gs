/**
 * PCU Connect API — Google Apps Script Web App
 * Backend for PCU Connect Flutter Web Application.
 *
 * Deployment instructions:
 * 1. Open your Google Sheet (Test: 1R9-l3GOw_NY8qIvn94mM3ZFxBpuuDl7lwSEnumdFU24).
 * 2. Extensions > Apps Script.
 * 3. Add this code as Api.gs (alongside pcu_auto_assign.gs).
 * 4. Deploy > New deployment > Select type: Web app.
 *    - Description: PCU Connect API v1
 *    - Execute as: Me
 *    - Who has access: Anyone
 * 5. Copy Web app URL into Flutter `lib/core/network/api_client.dart` as defaultBaseUrl.
 */

var GO_LIVE = new Date('2026-10-28T00:00:00');
var TZ = 'Africa/Lagos';

var TAB_GUESTS = 'Form Responses 1';
var TAB_CALLS = 'Call Log';
var TAB_CALLS_ALT = 'Follow-ups';
var TAB_WORKERS = 'Workers';
var TAB_LEADERBOARD = 'Leaderboard';
var TAB_MONTHS = 'Months';

/**
 * Main Web App POST entry point.
 * Flutter sends POST with Content-Type: text/plain;charset=utf-8 to bypass CORS preflight.
 */
function doPost(e) {
  try {
    if (!e || !e.postData || !e.postData.contents) {
      throw new Error('Empty request body');
    }
    var req = JSON.parse(e.postData.contents);
    var user = verifyUser_(req.idToken); // { email, worker }

    var actionMap = {
      me: me_,
      guests: guests_,
      guest: guest_,
      logFollowUp: logFollowUp_,
      ranking: ranking_,
      dashboard: dashboard_,
      team: team_,
      saveWorker: saveWorker_,
      setWorkerActive: setWorkerActive_
    };

    if (!actionMap[req.action]) {
      throw new Error('Unknown action: ' + req.action);
    }

    var result = actionMap[req.action](user, req);
    return json_({ ok: true, data: result });
  } catch (err) {
    return json_({ ok: false, error: String(err.message || err) });
  }
}

function doGet(e) {
  return json_({ ok: true, message: 'PCU Connect API is active and ready.' });
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

/* ================================================================== */
/* Authentication & Permissions                                      */
/* ================================================================== */

function verifyUser_(idToken) {
  if (!idToken) throw new Error('Not signed in: no idToken provided.');
  var email = '';

  // 1. Support development tokens and mock switchers
  if (idToken.indexOf('mock_token_') === 0) {
    email = idToken.replace('mock_token_', '').toLowerCase().trim();
  } else if (idToken === 'mock_token') {
    email = 'davidolanite0@gmail.com';
  } else {
    // 2. Real Google OAuth ID Token verification
    var url = 'https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken);
    var r = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
    if (r.getResponseCode() !== 200) {
      throw new Error('Not signed in: Token verification failed.');
    }
    var t = JSON.parse(r.getContentText());
    var clientAud = PropertiesService.getScriptProperties().getProperty('OAUTH_CLIENT_ID');
    if (clientAud && t.aud !== clientAud) {
      throw new Error('Bad client audience.');
    }
    email = String(t.email || '').toLowerCase().trim();
  }

  // 3. Verify user exists in Workers tab and is Active
  var workers = rows_(TAB_WORKERS);
  var w = workers.filter(function (x) {
    var rowEmail = String(x.Email || x.email || '').toLowerCase().trim();
    return rowEmail === email;
  })[0];

  if (!w || String(w.Active || w.active || '').toUpperCase() !== 'YES') {
    throw new Error('No access. Ask your HOD to add your email.');
  }

  return { email: email, worker: w };
}

function isAdmin_(u) {
  var role = String(u.worker.Role || u.worker.role || '').toLowerCase();
  return role === 'admin' || role === 'hod';
}

function requireAdmin_(u) {
  if (!isAdmin_(u)) throw new Error('Admins only.');
}

/* ================================================================== */
/* Sheet Helpers                                                      */
/* ================================================================== */

function getSheet_(name) {
  var ss = SpreadsheetApp.getActive();
  var sh = ss.getSheetByName(name);
  if (!sh && name === TAB_CALLS) sh = ss.getSheetByName(TAB_CALLS_ALT);
  if (!sh) throw new Error('Sheet tab "' + name + '" not found.');
  return sh;
}

function headers_(sh) {
  return sh.getRange(1, 1, 1, Math.max(1, sh.getLastColumn())).getValues()[0]
    .map(function (x) { return String(x).trim().toUpperCase(); });
}

function rows_(tab) {
  var sh = getSheet_(tab);
  var lastRow = sh.getLastRow();
  if (lastRow < 2) return [];
  var v = sh.getRange(1, 1, lastRow, sh.getLastColumn()).getValues();
  var h = v.shift().map(function (k) { return String(k).trim().toUpperCase(); });
  return v.map(function (r, i) {
    var o = { _row: i + 2 };
    h.forEach(function (k, j) { o[k] = r[j]; });
    return o;
  });
}

function ensureColumn_(sh, colName) {
  var h = headers_(sh);
  var idx = h.indexOf(colName.toUpperCase());
  if (idx >= 0) return idx + 1;
  var newCol = sh.getLastColumn() + 1;
  sh.getRange(1, newCol).setValue(colName);
  return newCol;
}

function parseDate_(val) {
  if (!val) return null;
  if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
  var d = new Date(val);
  return isNaN(d.getTime()) ? null : d;
}

function formatMonth_(date) {
  if (!date) return '';
  return Utilities.formatDate(date, TZ, 'MMM yyyy');
}

function formatDateShort_(date) {
  if (!date) return '';
  return Utilities.formatDate(date, TZ, 'd MMM');
}

function daysDiff_(earlierDate, laterDate) {
  if (!earlierDate) return 0;
  var t1 = new Date(earlierDate).getTime();
  var t2 = (laterDate || new Date()).getTime();
  var diff = Math.floor((t2 - t1) / 86400000);
  return diff < 0 ? 0 : diff;
}

/* ================================================================== */
/* API Handlers                                                       */
/* ================================================================== */

/**
 * 1. me: Return current worker's profile and role.
 */
function me_(u) {
  return {
    id: String(u.worker.ID || u.worker.id || ''),
    name: String(u.worker.Name || u.worker.name || ''),
    email: u.email,
    phone: String(u.worker.Phone || u.worker.phone || ''),
    role: String(u.worker.Role || u.worker.role || 'Worker'),
    active: String(u.worker.Active || u.worker.active || '').toUpperCase() === 'YES'
  };
}

/**
 * 2. guests: Return list of guests with computed fields.
 * - Workers see only their assigned guests.
 * - Admins see all church guests.
 * - Excludes guests prior to GO_LIVE date.
 */
function guests_(u, req) {
  var guestRows = rows_(TAB_GUESTS);
  var admin = isAdmin_(u);
  var now = new Date();

  var result = [];

  for (var i = 0; i < guestRows.length; i++) {
    var r = guestRows[i];
    var assignedEmail = String(r['ASSIGNED TO'] || '').toLowerCase().trim();

    // Role check: non-admins only see their own guests
    if (!admin && assignedEmail !== u.email) {
      continue;
    }

    // Go-live filter: ignore pre-go-live guests
    var serviceDate = parseDate_(r['SERVICE DATE']) || parseDate_(r['TIMESTAMP']);
    var assignedDate = parseDate_(r['ASSIGNED DATE']);
    var refDate = assignedDate || serviceDate;

    if (refDate && refDate < GO_LIVE) {
      continue;
    }

    var guestId = String(r['GUEST ID'] || ('G-' + r._row)).trim();
    var name = String(r['FULL NAME'] || 'Guest').trim();
    var phone = String(r['PHONE NUMBER'] || '').trim();
    var status = String(r['MEMBERSHIP STATUS'] || r['CALL STATUS'] || 'New guest').trim();

    var calls = Number(r['FOLLOW-UP COUNT']) || (r['FEEDBACK 2'] ? 2 : r['FEEDBACK 1'] ? 1 : 0);
    var days = refDate ? daysDiff_(refDate, now) : 0;

    var sun = Number(r['SUNDAYS COUNT']) || 0;
    var wed = Number(r['WEDNESDAYS COUNT']) || 0;
    var team = String(r['TEAM JOINED'] || '').trim();

    var lastFb = String(r['LAST FEEDBACK'] || r['FEEDBACK 2'] || r['FEEDBACK 1'] || '').trim();
    var lastFbDateVal = parseDate_(r['LAST FEEDBACK DATE'] || r['FEEDBACK 2 DATE'] || r['FEEDBACK 1 DATE']);
    var fbDate = lastFbDateVal ? formatDateShort_(lastFbDateVal) : '';

    var monthStr = serviceDate ? formatMonth_(serviceDate) : formatMonth_(now);

    // Apply optional filter parameters
    if (req.month && req.month !== 'all' && monthStr !== req.month) {
      continue;
    }

    if (req.filter) {
      if ((req.filter === 'call' || req.filter === 'notcalled') && calls !== 0) continue;
      if (req.filter === 'fu' && calls <= 0) continue;
      if ((req.filter === 'mem' || req.filter === 'members') && status !== 'Member') continue;
      if ((req.filter === 'team' || req.filter === 'teams') && !team) continue;
    }

    result.push({
      id: guestId,
      name: name,
      phone: phone,
      status: status,
      days: days,
      calls: calls,
      sun: sun,
      wed: wed,
      team: team,
      fb: lastFb,
      fbDate: fbDate,
      fu: calls,
      month: monthStr,
      assignedWorker: assignedEmail
    });
  }

  return result;
}

/**
 * 3. guest: Return a single guest's full record and call history.
 */
function guest_(u, req) {
  var guestId = String(req.id || req.guestId || '').trim();
  if (!guestId) throw new Error('Guest ID is required.');

  var guestRows = rows_(TAB_GUESTS);
  var row = guestRows.filter(function (x) {
    return String(x['GUEST ID'] || ('G-' + x._row)).trim() === guestId;
  })[0];

  if (!row) throw new Error('Guest not found: ' + guestId);

  var assignedEmail = String(row['ASSIGNED TO'] || '').toLowerCase().trim();
  if (!isAdmin_(u) && assignedEmail !== u.email) {
    throw new Error('Access denied to this guest.');
  }

  var now = new Date();
  var serviceDate = parseDate_(row['SERVICE DATE']) || parseDate_(row['TIMESTAMP']);
  var assignedDate = parseDate_(row['ASSIGNED DATE']);
  var refDate = assignedDate || serviceDate;

  // Retrieve call history from Call Log / Follow-ups
  var callsSheet = rows_(TAB_CALLS);
  var history = [];
  for (var i = 0; i < callsSheet.length; i++) {
    var c = callsSheet[i];
    if (String(c['GUEST'] || c['Guest'] || c['GUEST ID']).trim() === guestId) {
      var cDate = parseDate_(c['CALL DATE'] || c['Call date']);
      history.push({
        id: String(c['FOLLOW-UP ID'] || c['Follow-up ID'] || ('FU-' + c._row)),
        date: cDate ? formatDateShort_(cDate) : '',
        rawDate: cDate ? cDate.toISOString() : '',
        outcome: String(c['CALL STATUS'] || c['Call status'] || ''),
        note: String(c['NOTE'] || c['Note'] || ''),
        worker: String(c['WORKER'] || c['Worker'] || ''),
        attendedSunday: String(c['ATTENDED SUNDAY?'] || c['Attended Sunday?']).toLowerCase() === 'yes',
        sundayDate: String(c['SUNDAY DATE'] || c['Sunday date'] || ''),
        attendedWednesday: String(c['ATTENDED WEDNESDAY?'] || c['Attended Wednesday?']).toLowerCase() === 'yes',
        wednesdayDate: String(c['WEDNESDAY DATE'] || c['Wednesday date'] || ''),
        team: String(c['JOINED TEAM'] || c['Joined team'] || '')
      });
    }
  }

  // Sort call history descending
  history.sort(function (a, b) { return (b.rawDate || '').localeCompare(a.rawDate || ''); });

  var calls = Number(row['FOLLOW-UP COUNT']) || history.length;
  var sun = Number(row['SUNDAYS COUNT']) || 0;
  var wed = Number(row['WEDNESDAYS COUNT']) || 0;
  var team = String(row['TEAM JOINED'] || '').trim();
  var lastFb = String(row['LAST FEEDBACK'] || '').trim();
  var lastFbDateVal = parseDate_(row['LAST FEEDBACK DATE']);

  return {
    id: guestId,
    name: String(row['FULL NAME'] || 'Guest').trim(),
    phone: String(row['PHONE NUMBER'] || '').trim(),
    status: String(row['MEMBERSHIP STATUS'] || 'New guest').trim(),
    days: refDate ? daysDiff_(refDate, now) : 0,
    calls: calls,
    sun: sun,
    wed: wed,
    team: team,
    fb: lastFb,
    fbDate: lastFbDateVal ? formatDateShort_(lastFbDateVal) : '',
    fu: calls,
    month: serviceDate ? formatMonth_(serviceDate) : formatMonth_(now),
    assignedWorker: assignedEmail,
    history: history
  };
}

/**
 * 4. logFollowUp: Append follow-up, update guest row, enforce Member rule, award points.
 */
function logFollowUp_(u, req) {
  var lock = LockService.getScriptLock();
  lock.waitLock(30000);

  try {
    var guestId = String(req.guestId || req.id || '').trim();
    if (!guestId) throw new Error('Guest ID is required.');

    var outcome = String(req.outcome || 'Reached').trim();
    var note = String(req.note || '').trim();
    var attendedSunday = Boolean(req.attendedSunday);
    var sundayDateStr = req.sundayDate ? String(req.sundayDate).trim() : '';
    var attendedWednesday = Boolean(req.attendedWednesday);
    var wednesdayDateStr = req.wednesdayDate ? String(req.wednesdayDate).trim() : '';
    var team = String(req.team || '').trim();

    var now = new Date();
    var todayKey = Utilities.formatDate(now, TZ, 'yyyy-MM-dd');

    // Attendance date validation: STRICTLY REJECT FUTURE DATES!
    if (attendedSunday && sundayDateStr && sundayDateStr > todayKey) {
      throw new Error('Sunday attendance date cannot be in the future.');
    }
    if (attendedWednesday && wednesdayDateStr && wednesdayDateStr > todayKey) {
      throw new Error('Wednesday attendance date cannot be in the future.');
    }

    // 1. Locate guest in Form Responses 1
    var shGuests = getSheet_(TAB_GUESTS);
    var gHeaders = headers_(shGuests);
    var gData = shGuests.getDataRange().getValues();

    var colId = gHeaders.indexOf('GUEST ID') + 1;
    var colAssigned = gHeaders.indexOf('ASSIGNED TO') + 1;
    var colStatus = gHeaders.indexOf('MEMBERSHIP STATUS') + 1;
    var colCallStatus = gHeaders.indexOf('CALL STATUS') + 1;
    var colFuCount = ensureColumn_(shGuests, 'FOLLOW-UP COUNT');
    var colLastFb = ensureColumn_(shGuests, 'LAST FEEDBACK');
    var colLastFbDate = ensureColumn_(shGuests, 'LAST FEEDBACK DATE');
    var colSunCount = ensureColumn_(shGuests, 'SUNDAYS COUNT');
    var colWedCount = ensureColumn_(shGuests, 'WEDNESDAYS COUNT');
    var colTeam = ensureColumn_(shGuests, 'TEAM JOINED');
    var colMemDate = ensureColumn_(shGuests, 'MEMBERSHIP DATE');
    var colAssignedDate = gHeaders.indexOf('ASSIGNED DATE') + 1;

    var targetRow = -1;
    for (var r = 1; r < gData.length; r++) {
      var rowGid = String(gData[r][colId - 1] || ('G-' + (r + 1))).trim();
      if (rowGid === guestId) {
        targetRow = r + 1;
        break;
      }
    }

    if (targetRow < 0) throw new Error('Guest not found: ' + guestId);

    // Permission check
    var currentAssigned = String(shGuests.getRange(targetRow, colAssigned).getValue()).toLowerCase().trim();
    if (!isAdmin_(u) && currentAssigned !== u.email) {
      throw new Error('You can only log follow-ups for your own assigned guests.');
    }

    // 2. Read existing counts and status
    var existingFu = Number(shGuests.getRange(targetRow, colFuCount).getValue()) || 0;
    var existingSun = Number(shGuests.getRange(targetRow, colSunCount).getValue()) || 0;
    var existingWed = Number(shGuests.getRange(targetRow, colWedCount).getValue()) || 0;
    var existingTeam = String(shGuests.getRange(targetRow, colTeam).getValue() || '').trim();
    var existingStatus = String(shGuests.getRange(targetRow, colStatus).getValue() || 'New guest').trim();
    var existingMemDate = shGuests.getRange(targetRow, colMemDate).getValue();
    var assignedDateVal = colAssignedDate ? parseDate_(shGuests.getRange(targetRow, colAssignedDate).getValue()) : null;

    var newFu = existingFu + 1;
    var newSun = existingSun + (attendedSunday ? 1 : 0);
    var newWed = existingWed + (attendedWednesday ? 1 : 0);
    var newTeam = team || existingTeam;

    // 3. Evaluate Member rule:
    // "In the same calendar month: 4 Sundays, OR (3 Sundays AND >= 2 Wednesdays)"
    var qualifiesMember = (newSun >= 4) || (newSun >= 3 && newWed >= 2);
    var newStatus = existingStatus;
    var becameMemberNow = false;

    if (existingStatus === 'Member') {
      newStatus = 'Member';
    } else if (qualifiesMember) {
      newStatus = 'Member';
      becameMemberNow = true;
      if (!existingMemDate) {
        shGuests.getRange(targetRow, colMemDate).setValue(now);
      }
    } else if (outcome === 'Not interested') {
      newStatus = 'Not interested';
    } else if (attendedSunday || attendedWednesday || existingStatus === 'Returning') {
      newStatus = 'Returning';
    } else if (outcome === 'Reached') {
      newStatus = 'Contacted';
    } else if (newFu >= 3 && outcome !== 'Reached') {
      newStatus = 'Unreachable';
    }

    // Update guest row
    shGuests.getRange(targetRow, colFuCount).setValue(newFu);
    if (note) shGuests.getRange(targetRow, colLastFb).setValue(note);
    shGuests.getRange(targetRow, colLastFbDate).setValue(now);
    shGuests.getRange(targetRow, colSunCount).setValue(newSun);
    shGuests.getRange(targetRow, colWedCount).setValue(newWed);
    if (newTeam) shGuests.getRange(targetRow, colTeam).setValue(newTeam);
    shGuests.getRange(targetRow, colCallStatus).setValue(outcome);
    shGuests.getRange(targetRow, colStatus).setValue(newStatus);

    // 4. Append to Call Log tab
    var shCalls = getSheet_(TAB_CALLS);
    var fuId = 'FU-' + Utilities.getUuid().slice(0, 8).toUpperCase();
    shCalls.appendRow([
      fuId,
      guestId,
      u.email,
      now,
      outcome,
      note,
      attendedSunday ? 'Yes' : 'No',
      attendedSunday ? (sundayDateStr || todayKey) : '',
      attendedWednesday ? 'Yes' : 'No',
      attendedWednesday ? (wednesdayDateStr || todayKey) : '',
      team || ''
    ]);

    // 5. Award Points & Update Leaderboard
    // Points rules:
    // +10 first call within 3 days
    // +5 each follow-up
    // +10 guest attends service (Sunday or Wednesday)
    // +20 guest joins Workforce / Evangelism
    // +30 guest becomes member
    var pts = 0;
    var firstCallOnTime = 0;
    var isNewTeam = !existingTeam && Boolean(team);

    if (newFu === 1) {
      var daysToFirstCall = assignedDateVal ? daysDiff_(assignedDateVal, now) : 0;
      if (daysToFirstCall <= 3) {
        pts += 10;
        firstCallOnTime = 1;
      }
    }
    pts += 5; // each follow-up
    if (attendedSunday) pts += 10;
    if (attendedWednesday) pts += 10;
    if (isNewTeam) pts += 20;
    if (becameMemberNow) pts += 30;

    recordPoints_(u, formatMonth_(now), {
      points: pts,
      firstCallOnTime: firstCallOnTime,
      followUps: 1,
      attendances: (attendedSunday ? 1 : 0) + (attendedWednesday ? 1 : 0),
      teamJoins: isNewTeam ? 1 : 0,
      members: becameMemberNow ? 1 : 0
    });

    SpreadsheetApp.flush();

    return {
      ok: true,
      guestId: guestId,
      pointsEarned: pts,
      newStatus: newStatus,
      followUpCount: newFu
    };
  } finally {
    lock.releaseLock();
  }
}

/**
 * Helper to record points in the Leaderboard tab.
 */
function recordPoints_(u, monthStr, delta) {
  try {
    var sh = getSheet_(TAB_LEADERBOARD);
    var data = sh.getDataRange().getValues();
    var h = headers_(sh);

    var cMonth = h.indexOf('MONTH');
    var cEmail = h.indexOf('WORKER EMAIL');
    var cName = h.indexOf('WORKER NAME');
    var cPts = h.indexOf('POINTS');
    var cFirst = h.indexOf('FIRST-CALL-ON-TIME');
    var cFu = h.indexOf('FOLLOW-UPS');
    var cAtt = h.indexOf('ATTENDANCES');
    var cTeam = h.indexOf('TEAM JOINS');
    var cMem = h.indexOf('MEMBERS');

    var foundRow = -1;
    for (var i = 1; i < data.length; i++) {
      if (String(data[i][cMonth]).trim() === monthStr &&
          String(data[i][cEmail]).toLowerCase().trim() === u.email) {
        foundRow = i + 1;
        break;
      }
    }

    if (foundRow > 0) {
      var curPts = Number(data[foundRow - 1][cPts]) || 0;
      var curFirst = Number(data[foundRow - 1][cFirst]) || 0;
      var curFu = Number(data[foundRow - 1][cFu]) || 0;
      var curAtt = Number(data[foundRow - 1][cAtt]) || 0;
      var curTeam = Number(data[foundRow - 1][cTeam]) || 0;
      var curMem = Number(data[foundRow - 1][cMem]) || 0;

      sh.getRange(foundRow, cPts + 1).setValue(curPts + delta.points);
      sh.getRange(foundRow, cFirst + 1).setValue(curFirst + delta.firstCallOnTime);
      sh.getRange(foundRow, cFu + 1).setValue(curFu + delta.followUps);
      sh.getRange(foundRow, cAtt + 1).setValue(curAtt + delta.attendances);
      sh.getRange(foundRow, cTeam + 1).setValue(curTeam + delta.teamJoins);
      sh.getRange(foundRow, cMem + 1).setValue(curMem + delta.members);
    } else {
      sh.appendRow([
        monthStr,
        u.email,
        u.worker.Name || u.email,
        delta.points,
        '', // Rank will be computed
        delta.firstCallOnTime,
        delta.followUps,
        delta.attendances,
        delta.teamJoins,
        delta.members
      ]);
    }
  } catch (err) {
    console.log('Leaderboard record points failed: ' + err);
  }
}

/**
 * 5. ranking: Monthly leaderboard. Admins are excluded from rankings.
 */
function ranking_(u, req) {
  var monthStr = req.month || formatMonth_(new Date());
  var lbRows = rows_(TAB_LEADERBOARD);
  var workers = rows_(TAB_WORKERS);

  // Map worker roles
  var workerMap = {};
  workers.forEach(function (w) {
    workerMap[String(w.Email || w.email).toLowerCase().trim()] = {
      name: String(w.Name || w.name || '').trim(),
      role: String(w.Role || w.role || 'Worker').trim(),
      active: String(w.Active || w.active).toUpperCase() === 'YES'
    };
  });

  // Filter leaderboard rows for this month
  var list = [];
  lbRows.forEach(function (r) {
    if (String(r.MONTH || r.Month).trim() !== monthStr) return;
    var email = String(r['WORKER EMAIL'] || r['Worker email']).toLowerCase().trim();
    var info = workerMap[email] || {};

    // Exclude Admin / HOD
    var role = String(info.role || '').toLowerCase();
    if (role === 'admin' || role === 'hod') return;

    list.push({
      email: email,
      name: info.name || String(r['WORKER NAME'] || r['Worker name'] || email.split('@')[0]),
      points: Number(r.POINTS || r.Points) || 0,
      firstCallOnTime: Number(r['FIRST-CALL-ON-TIME']) || 0,
      followUps: Number(r['FOLLOW-UPS']) || 0,
      attendances: Number(r.ATTENDANCES) || 0,
      teamJoins: Number(r['TEAM JOINS']) || 0,
      members: Number(r.MEMBERS) || 0
    });
  });

  // Sort descending by points
  list.sort(function (a, b) { return b.points - a.points; });

  // Compute rank and find user rank
  var myRank = 0;
  var myPoints = 0;
  for (var i = 0; i < list.length; i++) {
    list[i].rank = i + 1;
    if (list[i].email === u.email) {
      myRank = i + 1;
      myPoints = list[i].points;
    }
  }

  return {
    month: monthStr,
    rankings: list,
    myRank: {
      rank: myRank,
      points: myPoints
    }
  };
}

/**
 * 6. dashboard: Admin 12-month analytics and church retention funnel.
 */
function dashboard_(u, req) {
  requireAdmin_(u);
  var selectedMonth = req.month || formatMonth_(new Date());

  var guestRows = rows_(TAB_GUESTS);
  var totalGuests = 0;
  var calledGuests = 0;
  var membersCount = 0;
  var teamsCount = 0;

  var funnelContacted = 0;
  var funnelFollowedUpTwice = 0;
  var funnelCameSunday = 0;
  var funnelCameWednesday = 0;

  for (var i = 0; i < guestRows.length; i++) {
    var r = guestRows[i];
    var serviceDate = parseDate_(r['SERVICE DATE']) || parseDate_(r['TIMESTAMP']);
    var refDate = parseDate_(r['ASSIGNED DATE']) || serviceDate;
    if (refDate && refDate < GO_LIVE) continue;

    var m = serviceDate ? formatMonth_(serviceDate) : formatMonth_(new Date());
    if (m !== selectedMonth) continue;

    totalGuests++;
    var fu = Number(r['FOLLOW-UP COUNT']) || (r['FEEDBACK 2'] ? 2 : r['FEEDBACK 1'] ? 1 : 0);
    var status = String(r['MEMBERSHIP STATUS'] || '').trim();
    var sun = Number(r['SUNDAYS COUNT']) || 0;
    var wed = Number(r['WEDNESDAYS COUNT']) || 0;
    var team = String(r['TEAM JOINED'] || '').trim();

    if (fu > 0) calledGuests++;
    if (status === 'Member') membersCount++;
    if (team) teamsCount++;

    if (status === 'Contacted' || status === 'Returning' || status === 'Member') funnelContacted++;
    if (fu >= 2) funnelFollowedUpTwice++;
    if (sun > 0) funnelCameSunday++;
    if (wed > 0) funnelCameWednesday++;
  }

  var notCalled = totalGuests - calledGuests;
  if (notCalled < 0) notCalled = 0;

  // Retrieve top 3 workers this month
  var rankingData = ranking_(u, { month: selectedMonth });
  var topWorkers = (rankingData.rankings || []).slice(0, 3);

  return {
    month: selectedMonth,
    metrics: {
      guests: totalGuests,
      called: calledGuests,
      notcalled: notCalled,
      members: membersCount,
      teams: teamsCount
    },
    funnel: {
      contacted: funnelContacted,
      followedUpTwice: funnelFollowedUpTwice,
      cameSunday: funnelCameSunday,
      cameWednesday: funnelCameWednesday,
      becameMembers: membersCount
    },
    topWorkers: topWorkers
  };
}

/**
 * 7. team: Admin team view with worker workloads, standings, and active status.
 */
function team_(u, req) {
  requireAdmin_(u);

  var workers = rows_(TAB_WORKERS);
  var guestRows = rows_(TAB_GUESTS);
  var now = new Date();

  // Aggregate stats per worker
  var stats = {};
  workers.forEach(function (w) {
    var email = String(w.Email || w.email).toLowerCase().trim();
    stats[email] = {
      id: String(w.ID || w.id || ''),
      name: String(w.Name || w.name || email.split('@')[0]),
      email: email,
      role: String(w.Role || w.role || 'Worker'),
      active: String(w.Active || w.active).toUpperCase() === 'YES',
      guests: 0,
      contacted: 0,
      members: 0,
      fu: 0,
      teams: 0
    };
  });

  guestRows.forEach(function (r) {
    var serviceDate = parseDate_(r['SERVICE DATE']) || parseDate_(r['TIMESTAMP']);
    var refDate = parseDate_(r['ASSIGNED DATE']) || serviceDate;
    if (refDate && refDate < GO_LIVE) continue;

    var email = String(r['ASSIGNED TO'] || '').toLowerCase().trim();
    if (!stats[email]) return;

    stats[email].guests++;
    var fu = Number(r['FOLLOW-UP COUNT']) || (r['FEEDBACK 2'] ? 2 : r['FEEDBACK 1'] ? 1 : 0);
    var status = String(r['MEMBERSHIP STATUS'] || '').trim();
    var team = String(r['TEAM JOINED'] || '').trim();

    if (fu > 0) stats[email].contacted++;
    if (status === 'Member') stats[email].members++;
    stats[email].fu += fu;
    if (team) stats[email].teams++;
  });

  var list = Object.keys(stats).map(function (k) {
    var item = stats[k];
    var pct = item.guests > 0 ? (item.contacted / item.guests) : 0;
    var standing = 'Behind';
    if (!item.active) {
      standing = 'Inactive';
    } else if (item.members >= 3) {
      standing = 'Outstanding';
    } else if (pct >= 0.7) {
      standing = 'On track';
    }

    item.progress = Math.round(pct * 100) / 100;
    item.standing = standing;
    return item;
  });

  // Sort: active workers first, by members descending
  list.sort(function (a, b) {
    if (a.active !== b.active) return a.active ? -1 : 1;
    return b.members - a.members;
  });

  return list;
}

/**
 * 8. saveWorker: Admin adds or edits a worker in the Workers tab.
 */
function saveWorker_(u, req) {
  requireAdmin_(u);

  var name = String(req.name || '').trim();
  var email = String(req.email || '').toLowerCase().trim();
  var role = String(req.role || 'Worker').trim();
  var active = req.active === false ? 'No' : 'Yes';
  var phone = String(req.phone || '').trim();

  if (!name || !email) throw new Error('Worker name and email are required.');

  var sh = getSheet_(TAB_WORKERS);
  var data = sh.getDataRange().getValues();
  var h = headers_(sh);

  var cId = h.indexOf('ID');
  var cName = h.indexOf('NAME');
  var cEmail = h.indexOf('EMAIL');
  var cPhone = h.indexOf('PHONE');
  var cRole = h.indexOf('ROLE');
  var cActive = h.indexOf('ACTIVE');

  var existingRow = -1;
  for (var i = 1; i < data.length; i++) {
    if (String(data[i][cEmail]).toLowerCase().trim() === email) {
      existingRow = i + 1;
      break;
    }
  }

  if (existingRow > 0) {
    if (name && cName >= 0) sh.getRange(existingRow, cName + 1).setValue(name);
    if (role && cRole >= 0) sh.getRange(existingRow, cRole + 1).setValue(role);
    if (phone && cPhone >= 0) sh.getRange(existingRow, cPhone + 1).setValue("'" + phone);
    if (cActive >= 0) sh.getRange(existingRow, cActive + 1).setValue(active);
    return { ok: true, message: 'Worker updated successfully.' };
  } else {
    // Generate new worker ID (e.g. W006)
    var maxId = 0;
    for (var j = 1; j < data.length; j++) {
      var num = Number(String(data[j][cId]).replace(/\D/g, '')) || 0;
      if (num > maxId) maxId = num;
    }
    var newId = 'W' + String(maxId + 1).padStart(3, '0');

    sh.appendRow([newId, name, email, "'" + phone, role, active]);
    return { ok: true, message: 'Worker added successfully as ' + newId + '.' };
  }
}

/**
 * 9. setWorkerActive: Admin activates or deactivates a worker.
 */
function setWorkerActive_(u, req) {
  requireAdmin_(u);
  var email = String(req.email || '').toLowerCase().trim();
  var activeVal = (req.active === true || String(req.active).toUpperCase() === 'YES') ? 'Yes' : 'No';

  if (!email) throw new Error('Worker email is required.');

  var sh = getSheet_(TAB_WORKERS);
  var data = sh.getDataRange().getValues();
  var h = headers_(sh);
  var cEmail = h.indexOf('EMAIL');
  var cActive = h.indexOf('ACTIVE');

  for (var i = 1; i < data.length; i++) {
    if (String(data[i][cEmail]).toLowerCase().trim() === email) {
      sh.getRange(i + 1, cActive + 1).setValue(activeVal);
      return { ok: true, email: email, active: activeVal === 'Yes' };
    }
  }

  throw new Error('Worker not found with email: ' + email);
}
