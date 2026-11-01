/** PCU Connect: test-copy-only leaderboard. Points confirmed 28 October 2026. */
const PCU_TEST_SPREADSHEET = '1R9-l3GOw_NY8qIvn94mM3ZFxBpuuDl7lwSEnumdFU24';
const PCU_POINTS = { first: 10, followup: 5, attendance: 10, team: 20, member: 30 };

function pcuSetupLeaderboard() {
  pcuRefreshLeaderboard();
  const names = ScriptApp.getProjectTriggers().map(t => t.getHandlerFunction());
  if (!names.includes('pcuRefreshLeaderboard')) {
    ScriptApp.newTrigger('pcuRefreshLeaderboard').timeBased().everyHours(1).create();
  }
  if (!names.includes('pcuSnapshotPreviousMonth')) {
    ScriptApp.newTrigger('pcuSnapshotPreviousMonth').timeBased()
      .onMonthDay(1).atHour(1).inTimezone(TZ).create();
  }
  console.log('Leaderboard ready: hourly current totals; previous month saved on the 1st, 1-2am Lagos. No emails sent.');
}

function pcuRefreshLeaderboard() {
  withLock_(() => pcuWriteLeaderboardMonth_(Utilities.formatDate(new Date(), TZ, 'yyyy-MM'), false));
}

function pcuSnapshotPreviousMonth() {
  withLock_(() => {
    const current = Utilities.formatDate(new Date(), TZ, 'yyyy-MM');
    const parts = current.split('-').map(Number);
    const previous = Utilities.formatDate(new Date(Date.UTC(parts[0], parts[1] - 2, 15)), TZ, 'yyyy-MM');
    if (previous >= GO_LIVE.slice(0, 7)) pcuWriteLeaderboardMonth_(previous, true);
    pcuWriteLeaderboardMonth_(current, false);
  });
}

function pcuWriteLeaderboardMonth_(month, freeze) {
  const props = PropertiesService.getScriptProperties();
  const marker = 'PCU_SNAPSHOT_' + month;
  if (props.getProperty(marker)) return; // completed months are immutable
  const ss = SpreadsheetApp.openById(PCU_TEST_SPREADSHEET);
  const read = name => {
    const sheet = ss.getSheetByName(name);
    if (!sheet) throw new Error('Missing sheet: ' + name);
    const values = sheet.getDataRange().getValues();
    const keys = values.shift().map(v => String(v).trim().toUpperCase());
    return values.filter(r => r.some(v => v !== '')).map(r => {
      const out = {}; keys.forEach((k, i) => { out[k] = r[i]; }); return out;
    });
  };
  const scores = pcuScoreMonth_(month, read(WORKERS_SHEET), read(RESPONSES_SHEET), read(CALLS_SHEET));
  const sheet = ss.getSheetByName('Leaderboard');
  if (!sheet) throw new Error('Leaderboard tab is missing.');
  const header = sheet.getRange(1, 1, 1, 11).getValues()[0].map(String);
  const expected = ['Month', 'Worker email', 'Worker name', 'Points', 'Rank', 'First-call-on-time', 'Follow-ups', 'Sunday/Wed attendances', 'Team joins', 'Members', 'Leaderboard ID'];
  if (header.join('|') !== expected.join('|')) throw new Error('Leaderboard headers differ. Nothing overwritten.');
  const existing = sheet.getLastRow() > 1 ? sheet.getRange(2, 1, sheet.getLastRow() - 1, 11).getValues() : [];
  const byKey = {}; existing.forEach((r, i) => { if (r[10]) byKey[String(r[10])] = i + 2; });
  let nextRow = sheet.getLastRow() + 1;
  scores.forEach(s => {
    const key = month + '|' + s.email;
    const row = [new Date(month + '-01T12:00:00+01:00'), s.email, s.name, s.points, s.rank,
      s.first, s.followups, s.attendances, s.teams, s.members, key];
    const target = byKey[key] || nextRow++;
    if (target > sheet.getMaxRows()) sheet.insertRowsAfter(sheet.getMaxRows(), target - sheet.getMaxRows());
    sheet.getRange(target, 1, 1, 11).setValues([row]);
    sheet.getRange(target, 1).setNumberFormat('mmm yyyy');
  });
  SpreadsheetApp.flush();
  if (freeze) props.setProperty(marker, new Date().toISOString());
  console.log(month + ': ' + scores.length + ' workers, ' + scores.reduce((n, s) => n + s.points, 0) + ' points' + (freeze ? ' (saved)' : ' (current)'));
}

/** Pure calculation; dates are calendar dates in Lagos, attendances are unique guest/service/date. */
function pcuScoreMonth_(month, workers, guests, calls, now) {
  now = now || new Date();
  const day = value => value instanceof Date && !isNaN(value.getTime()) ? Utilities.formatDate(value, TZ, 'yyyy-MM-dd') : '';
  const email = value => String(value || '').trim().toLowerCase();
  const yes = value => value === true || /^(true|yes|y)$/i.test(String(value).trim());
  const today = day(now), score = {}, guestById = {};
  workers.forEach(w => {
    const address = email(w.EMAIL);
    if (address && String(w.ROLE).trim().toLowerCase() === 'worker') {
      score[address] = { email: address, name: String(w.NAME || ''), first: 0, followups: 0, attendances: 0, teams: 0, members: 0 };
    }
  });
  guests.forEach(g => {
    const arrived = day(g['SERVICE DATE']);
    if (g['GUEST ID'] && arrived && arrived >= GO_LIVE && arrived <= today) guestById[String(g['GUEST ID'])] = g;
  });
  const valid = calls.filter(c => c['FOLLOW-UP ID'] && guestById[String(c.GUEST)] && day(c['CALL DATE']) >= GO_LIVE && day(c['CALL DATE']) <= today)
    .sort((a, b) => a['CALL DATE'] - b['CALL DATE'] || String(a['FOLLOW-UP ID']).localeCompare(String(b['FOLLOW-UP ID'])));
  const first = new Set(), seenAttendance = new Set(), seenTeams = new Set(), seenLog = new Set();
  valid.forEach(c => {
    const logId = String(c['FOLLOW-UP ID']);
    if (seenLog.has(logId)) return;
    seenLog.add(logId);
    const id = String(c.GUEST), g = guestById[id], called = day(c['CALL DATE']);
    const arrived = day(g['SERVICE DATE']), assigned = day(g['ASSIGNED DATE']);
    if (called < arrived || (assigned && called < assigned)) return;
    const s = score[email(c.WORKER)], inMonth = called.slice(0, 7) === month;
    if (s && inMonth) s.followups++;
    if (!first.has(id)) {
      first.add(id);
      const days = assigned ? (Date.parse(called) - Date.parse(assigned)) / 86400000 : -1;
      if (s && inMonth && days >= 0 && days <= 3) s.first++;
    }
    [['ATTENDED SUNDAY?', 'SUNDAY DATE', 0], ['ATTENDED WEDNESDAY?', 'WEDNESDAY DATE', 3]].forEach(([flag, field, weekday]) => {
      const attended = day(c[field]);
      if (!yes(c[flag]) || !attended || attended < GO_LIVE || attended < arrived || attended > today) return;
      if (new Date(attended + 'T12:00:00Z').getUTCDay() !== weekday) return;
      const key = id + '|' + attended;
      if (seenAttendance.has(key)) return;
      seenAttendance.add(key);
      if (s && attended.slice(0, 7) === month) s.attendances++;
    });
    if (/^(workforce|evangelism)$/i.test(String(c['JOINED TEAM']).trim()) && !seenTeams.has(id)) {
      seenTeams.add(id);
      if (s && inMonth) s.teams++;
    }
  });
  Object.keys(guestById).forEach(id => {
    const g = guestById[id], s = score[email(g['ASSIGNED TO'])], became = day(g['MEMBERSHIP DATE']);
    if (s && became && became >= GO_LIVE && became <= today && became.slice(0, 7) === month) s.members++;
  });
  const rows = Object.values(score).map(s => ({ ...s, points: s.first * PCU_POINTS.first + s.followups * PCU_POINTS.followup + s.attendances * PCU_POINTS.attendance + s.teams * PCU_POINTS.team + s.members * PCU_POINTS.member }))
    .sort((a, b) => b.points - a.points || a.email.localeCompare(b.email));
  rows.forEach((s, i) => { s.rank = i && s.points === rows[i - 1].points ? rows[i - 1].rank : i + 1; });
  return rows;
}

/** Read-only verification: no guest assignment, guest edits, triggers or email. */
function pcuVerifyPhase1() {
  const workers = activeWorkers_();
  if (workers.some(w => String(w.role).trim().toLowerCase() !== 'worker' || !w.active)) throw new Error('Admin/inactive worker remains eligible.');
  if (!workers.length) throw new Error('No active Workers found.');
  const d = value => new Date(value + 'T12:00:00+01:00');
  const w = [{ EMAIL: 'a@example.com', NAME: 'A', ROLE: 'Worker' }, { EMAIL: 'admin@example.com', ROLE: 'Admin' }];
  const g = [{ 'GUEST ID': 'g1', 'SERVICE DATE': d('2026-11-01'), 'ASSIGNED DATE': d('2026-11-01'), 'ASSIGNED TO': 'a@example.com', 'MEMBERSHIP DATE': d('2026-11-29') }, { 'GUEST ID': 'old', 'SERVICE DATE': d('2026-10-01'), 'ASSIGNED TO': 'a@example.com' }];
  const base = { GUEST: 'g1', WORKER: 'a@example.com', 'CALL DATE': d('2026-11-02'), 'ATTENDED SUNDAY?': true, 'SUNDAY DATE': d('2026-11-01'), 'JOINED TEAM': 'Workforce' };
  const logs = [{ ...base, 'FOLLOW-UP ID': '1' }, { ...base, 'FOLLOW-UP ID': '2' }, { ...base, GUEST: 'old', 'FOLLOW-UP ID': '3' }];
  const result = pcuScoreMonth_('2026-11', w, g, logs, d('2026-11-30'));
  if (result.length !== 1 || result[0].points !== 80 || result[0].attendances !== 1 || result[0].teams !== 1) throw new Error('Scoring verification failed: ' + JSON.stringify(result));
  console.log('PASS: ' + workers.length + ' eligible active Workers; Admins excluded. Scoring: duplicate attendance/team and pre-launch guests excluded. Expected 80 points verified.');
}
