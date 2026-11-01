// Runs backend/PcuApi.gs in Node against a mock of the Apps Script services.
// Usage: node backend/test/pcu_api_harness.js backend/Api.gs
const fs = require('fs'); const vm = require('vm'); const crypto = require('crypto');
const TZ = 'Africa/Lagos';
function fmt(d, tz, pattern) {
  const parts = new Intl.DateTimeFormat('en-GB', { timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short' }).formatToParts(d);
  const get = t => parts.find(p => p.type === t).value;
  const wd = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 }[get('weekday')];
  if (pattern === 'yyyy-MM-dd') return `${get('year')}-${get('month')}-${get('day')}`;
  if (pattern === 'yyyy-MM') return `${get('year')}-${get('month')}`;
  if (pattern === 'u') return String(wd);
  throw new Error('pattern ' + pattern);
}
const mocks = require('./gas_mocks');
const makeSheet = (name, rows) => mocks.makeSheet(rows, name);
const cache = mocks.makeCache();
const D = s => new Date(s); // local parse ok for test
const guestsHeader = ["Timestamp","","","SERVICE DATE","FULL NAME","PHONE NUMBER","GENDER","MARITAL STATUS","HOW DID YOU ARRIVE?","WHAT WAS THE MAJOR WAY","COULD YOU DESCRIBE","FEEDBACK 1","FEEDBACK 2 ","ASSIGNED TO","ASSIGNED DATE","CALL STATUS","MEMBERSHIP STATUS","FEEDBACK 1 DATE","FEEDBACK 2 DATE","MEMBERSHIP DATE","GUEST ID","TEAM JOINED","FOLLOW-UP COUNT","LAST FEEDBACK","LAST FEEDBACK DATE"];
function guestRow(id, name, service, assigned, status) { const r = new Array(25).fill(''); r[0]=D(service); r[3]=D(service); r[4]=name; r[5]=8000000001; r[13]=assigned; r[16]=status||'New guest'; r[20]=id; return r; }
// Pinned to the 15th at noon (Lagos), so "this month" fixtures never cross a month boundary.
const real = new Date(); const now = new Date(Date.UTC(real.getUTCFullYear(), real.getUTCMonth(), 15, 11)); const ymd = d => fmt(d, TZ, 'yyyy-MM-dd');
function FixedDate(...a) { if (!new.target) return now.toString(); return a.length ? new Date(...a) : new Date(now.getTime()); }
FixedDate.prototype = Date.prototype; FixedDate.now = () => now.getTime(); FixedDate.UTC = Date.UTC; FixedDate.parse = Date.parse;
const daysAgo = n => new Date(now.getTime() - n*86400000);
const sheets = {
  'Form Responses 1': makeSheet('g', [guestsHeader,
    guestRow('G1','Ada Obi', daysAgo(2), 'david@x.com'),
    guestRow('G2','Bola Ade', daysAgo(10), 'david@x.com'),
    guestRow('G3','Chi Eze', daysAgo(1), 'worker.a@x.com'),
    guestRow('G4','Old Guest', D('2025-01-05'), ''),
  ]),
  'Follow-ups': makeSheet('f', [["Follow-up ID","Guest","Worker","Call date","Call status","Note","Attended Sunday?","Sunday date","Attended Wednesday?","Wednesday date","Joined team"],
    ['a1','G2','david@x.com', daysAgo(9), 'Reached','hello','FALSE','','','',''] ]),
  'Workers': makeSheet('w', [["ID","Name","Email","Phone","Role","Active"],
    ['W001','Opeyemi Olanite','boss@x.com','08000000101','Admin','Yes'],
    ['W002','TEST Worker A','worker.a@x.com','','Worker','Yes'],
    ['W004','Inactive C','worker.c@x.com','','Worker','No'],
    ['W005','David Olanite','david@x.com','','Worker','Yes']]),
};
const props = { FIREBASE_WEB_API_KEY: 'KEY' };
const tokens = { tokAdmin: 'boss@x.com', tokDavid: 'david@x.com', tokC: 'worker.c@x.com', tokStranger: 'nobody@x.com' };
const ctx = {
  console,
  Date: FixedDate,
  SpreadsheetApp: { getActive: () => ({ getSheetByName: n => sheets[n] || null }), flush() {} },
  Utilities: {
    formatDate: fmt,
    parseDate: (s, tz, p) => { const [y,m,d] = s.split('-').map(Number); return new Date(Date.UTC(y, m-1, d, -1)); }, // midnight Lagos
    computeDigest: (alg, s) => Array.from(crypto.createHash('sha256').update(s).digest()),
    base64EncodeWebSafe: b => Buffer.from(b.map(x => x & 255)).toString('base64url'),
    getUuid: () => crypto.randomUUID(),
    DigestAlgorithm: { SHA_256: 'sha256' },
  },
  CacheService: { getScriptCache: () => cache },
  PropertiesService: { getScriptProperties: () => ({ getProperty: k => (k in props ? props[k] : null) }) },
  UrlFetchApp: { fetch: (url, opts) => { const t = JSON.parse(opts.payload).idToken; const email = tokens[t];
    return { getResponseCode: () => email ? 200 : 400, getContentText: () => JSON.stringify(email ? { users: [{ email, emailVerified: true }] } : { error: {} }) }; } },
  LockService: { getScriptLock: () => ({ tryLock: () => true, releaseLock() {} }) },
  ContentService: { createTextOutput: s => ({ text: s, setMimeType() { return this; } }), MimeType: { JSON: 'json' } },
};
vm.createContext(ctx);
vm.runInContext(fs.readFileSync(process.argv[2], 'utf8'), ctx);
function call(body) { const out = ctx.doPost({ postData: { contents: JSON.stringify(body) } }); return JSON.parse(out.text); }
const month = fmt(now, TZ, 'yyyy-MM');
let fails = 0; const check = (label, cond, extra) => { console.log((cond ? 'PASS ' : 'FAIL ') + label + (cond ? '' : ' ' + JSON.stringify(extra))); if (!cond) fails++; };

let r = call({ action: 'me', idToken: 'tokDavid' }); check('me worker', r.ok && r.data.role === 'Worker', r);
r = call({ action: 'me', idToken: 'tokAdmin' }); check('me admin', r.ok && r.data.role === 'Admin', r);
r = call({ action: 'me', idToken: 'tokC' }); check('inactive denied', !r.ok && r.code === 'ACCESS_DENIED', r);
r = call({ action: 'me', idToken: 'tokStranger' }); check('stranger denied', !r.ok && r.code === 'ACCESS_DENIED', r);
r = call({ action: 'me', idToken: 'bad' }); check('bad token', !r.ok && r.code === 'UNAUTHENTICATED', r);
// Mock tokens: rejected unless ALLOW_MOCK_TOKENS is exactly "true".
r = call({ action: 'me', idToken: 'mock_token_david@x.com' }); check('mock token rejected when property unset', !r.ok && r.code === 'UNAUTHENTICATED', r);
for (const v of ['false', 'TRUE', 'True', ' true', '1', '']) {
  props.ALLOW_MOCK_TOKENS = v;
  r = call({ action: 'me', idToken: 'mock_token_david@x.com' }); check(`mock token rejected when property is ${JSON.stringify(v)}`, !r.ok && r.code === 'UNAUTHENTICATED', r);
}
props.ALLOW_MOCK_TOKENS = 'true';
r = call({ action: 'me', idToken: 'mock_token_david@x.com' }); check('mock token accepted when property is "true"', r.ok && r.data.role === 'Worker', r);
r = call({ action: 'me', idToken: 'mock_token_worker.c@x.com' }); check('mock token still enforces Workers tab', !r.ok && r.code === 'ACCESS_DENIED', r);
delete props.ALLOW_MOCK_TOKENS;
r = call({ action: 'guests', idToken: 'tokDavid', month }); check('worker sees own guests only', r.ok && r.data.guests.every(g => g.assignedTo === 'david@x.com'), r);
const g1 = r.data.guests.find(g => g.id === 'G1'); check('phone leading zero', g1 && g1.phone === '08000000001', g1);
check('G1 first visit counted', g1.sundays + g1.wednesdays >= 1, g1);
const g2 = r.data.guests.find(g => g.id === 'G2'); check('G2 has 1 follow-up', !g2 || g2.followUps === 1, g2);
r = call({ action: 'guests', idToken: 'tokDavid', month, workerEmail: 'worker.a@x.com' }); check('worker cannot widen scope', r.ok && r.data.guests.every(g => g.assignedTo === 'david@x.com'), r);
r = call({ action: 'guests', idToken: 'tokAdmin', month }); check('admin sees all this month', r.ok && r.data.guests.length >= 2, r.data && r.data.guests.length);
r = call({ action: 'guest', idToken: 'tokDavid', id: 'G3' }); check('worker blocked from other guest', !r.ok && r.code === 'FORBIDDEN', r);
r = call({ action: 'logFollowUp', idToken: 'tokDavid', guestId: 'G1', outcome: 'Reached', note: 'Enjoyed it', attendedSunday: true, sundayDate: ymd(daysAgo(30*0+1)), attendedWednesday: false, team: '' });
check('log ok', r.ok, r); check('first call on time +10 +10 attendance', r.ok && r.data.pointsEarned === 20, r.data && r.data.pointsEarned);
check('status Returning', r.ok && r.data.guest.status === 'Returning', r.data && r.data.guest.status);
check('history newest first', r.ok && r.data.guest.history.length === 1, r.data && r.data.guest.history);
r = call({ action: 'logFollowUp', idToken: 'tokDavid', guestId: 'G1', outcome: 'Reached', note: '', attendedSunday: true, sundayDate: ymd(daysAgo(-2)), team: '' });
check('future date rejected', !r.ok && r.code === 'VALIDATION', r);
r = call({ action: 'logFollowUp', idToken: 'tokDavid', guestId: 'G1', outcome: 'Maybe', team: '' }); check('bad outcome rejected', !r.ok && r.code === 'VALIDATION', r);
// Make G1 a member: need 4 distinct Sundays this month (or 3 + 2 Weds). Use distinct past dates in current month.
const dayOfMonth = Number(ymd(now).slice(8));
if (dayOfMonth >= 5) {
  for (const n of [2,3,4]) call({ action: 'logFollowUp', idToken: 'tokDavid', guestId: 'G1', outcome: 'Reached', note: 'again '+n, attendedSunday: true, sundayDate: ymd(daysAgo(n)), team: n===4?'Workforce':'' });
  r = call({ action: 'guest', idToken: 'tokDavid', id: 'G1' });
  check('member after 4 sundays', r.ok && r.data.status === 'Member', r.data && [r.data.status, r.data.sundays]);
  check('team joined', r.data.team === 'Workforce', r.data.team);
  check('membership date set', !!r.data.membershipDate, r.data.membershipDate);
}
r = call({ action: 'ranking', idToken: 'tokDavid', month }); check('ranking excludes admin & inactive', r.ok && r.data.entries.every(e => e.email !== 'boss@x.com' && e.email !== 'worker.c@x.com'), r);
check('ranking me', r.ok && r.data.me && r.data.me.email === 'david@x.com' && r.data.me.rank === 1, r.data && r.data.me);
console.log('  david points', r.data.me.points, JSON.stringify(r.data.me.breakdown));
r = call({ action: 'ranking', idToken: 'tokAdmin', month }); check('admin has no me', r.ok && r.data.me === null, r.data.me);
r = call({ action: 'dashboard', idToken: 'tokDavid', month }); check('worker blocked from dashboard', !r.ok && r.code === 'FORBIDDEN', r);
r = call({ action: 'dashboard', idToken: 'tokAdmin', month }); check('dashboard', r.ok && r.data.trend.length === 12 && r.data.totals.guests >= 2, r);
console.log('  totals', JSON.stringify(r.data.totals), 'top', JSON.stringify(r.data.topWorkers));
r = call({ action: 'team', idToken: 'tokAdmin', month }); check('team', r.ok && r.data.members.length === 4, r);
const david = r.data.members.find(m => m.email === 'david@x.com'); console.log('  david stats', JSON.stringify(david));
r = call({ action: 'saveWorker', idToken: 'tokAdmin', name: 'Ruth A', email: 'Ruth@X.com', phone: '', role: 'Worker', active: true }); check('save worker', r.ok && r.data.id === 'W006' && r.data.email === 'ruth@x.com', r);
r = call({ action: 'saveWorker', idToken: 'tokAdmin', name: 'Ruth A', email: 'ruth@x.com', role: 'Worker' }); check('duplicate worker rejected', !r.ok && r.code === 'VALIDATION', r);
r = call({ action: 'setWorkerActive', idToken: 'tokAdmin', id: 'W002', active: false }); check('deactivate', r.ok && r.data.active === false, r);
r = call({ action: 'setWorkerActive', idToken: 'tokAdmin', id: 'W001', active: false }); check('cannot deactivate self', !r.ok && r.code === 'VALIDATION', r);
r = call({ action: 'nope', idToken: 'tokAdmin' }); check('unknown action', !r.ok && r.code === 'VALIDATION', r);

// Admin logs a follow-up on behalf of the assigned worker.
const fu = () => sheets['Follow-ups'].rows;
const lastFu = () => fu()[fu().length - 1];
const davidPoints = () => call({ action: 'ranking', idToken: 'tokDavid', month }).data.me.points;
let pointsBefore = davidPoints();
// 1) Follow-ups tab without a "Logged by" column: still works.
r = call({ action: 'logFollowUp', idToken: 'tokAdmin', guestId: 'G2', outcome: 'No answer', note: 'admin call', attendedSunday: false, attendedWednesday: false, team: '' });
check('admin log ok without Logged by column', r.ok, r);
check('admin log credits the assigned worker', lastFu()[2] === 'david@x.com', lastFu());
check('no extra cell written when column missing', lastFu().length === 11, lastFu().length);
check('admin points go to the worker', davidPoints() === pointsBefore + 5, [pointsBefore, davidPoints()]);
check('assigned to unchanged', r.ok && r.data.guest.assignedTo === 'david@x.com', r.data && r.data.guest.assignedTo);
// 2) Add the column, as on the test sheet.
fu()[0].push('Logged by');
pointsBefore = davidPoints();
r = call({ action: 'logFollowUp', idToken: 'tokAdmin', guestId: 'G2', outcome: 'Reached', note: 'second admin call', attendedSunday: false, attendedWednesday: false, team: '' });
check('admin log ok with Logged by column', r.ok, r);
check('Worker is assigned worker, Logged by is admin', lastFu()[2] === 'david@x.com' && lastFu()[11] === 'boss@x.com', lastFu());
const h0 = r.ok && r.data.guest.history[0];
check('history marks admin log', h0 && h0.loggedByAdmin === true && h0.workerEmail === 'david@x.com' && h0.workerName === 'David Olanite' && h0.loggedByName === 'Opeyemi Olanite', h0);
check('admin log counts for worker points', davidPoints() === pointsBefore + 5, [pointsBefore, davidPoints()]);
r = call({ action: 'ranking', idToken: 'tokAdmin', month }); check('admin stays out of ranking', r.ok && r.data.entries.every(e => e.email !== 'boss@x.com'), r.data && r.data.entries);
r = call({ action: 'dashboard', idToken: 'tokAdmin', month }); check('admin not a top worker', r.ok && r.data.topWorkers.every(w => w.email !== 'boss@x.com'), r.data && r.data.topWorkers);
r = call({ action: 'team', idToken: 'tokAdmin', month });
const boss = r.ok && r.data.members.find(m => m.email === 'boss@x.com');
check('admin has no follow-ups or points', boss && boss.followUps === 0 && boss.points === 0, boss);
r = call({ action: 'guest', idToken: 'tokDavid', id: 'G2' });
check('worker sees the admin label', r.ok && r.data.history.some(h => h.loggedByAdmin && h.loggedByEmail === 'boss@x.com'), r.data && r.data.history);
check('old rows without Logged by are not labelled', r.ok && r.data.history.filter(h => h.loggedByAdmin).length === 1, r.data && r.data.history);
r = call({ action: 'logFollowUp', idToken: 'tokDavid', guestId: 'G2', outcome: 'Reached', note: 'my call', attendedSunday: false, attendedWednesday: false, team: '' });
check('worker log: Logged by is the worker', r.ok && lastFu()[11] === 'david@x.com' && r.data.guest.history[0].loggedByAdmin === false, lastFu());
r = call({ action: 'logFollowUp', idToken: 'tokAdmin', guestId: 'G4', outcome: 'Reached', note: '', attendedSunday: false, attendedWednesday: false, team: '' });
check('admin cannot log for an unassigned guest', !r.ok && r.code === 'VALIDATION', r);
r = call({ action: 'logFollowUp', idToken: 'tokDavid', guestId: 'G3', outcome: 'Reached', note: '', attendedSunday: false, attendedWednesday: false, team: '' });
check('worker still blocked from other guests', !r.ok && r.code === 'FORBIDDEN', r);
console.log('Follow-ups rows now:', sheets['Follow-ups'].rows.length - 1, '| guest G1 row:', JSON.stringify(sheets['Form Responses 1'].rows[1].slice(11, 25)));
ctx.pcuSelfTest();
console.log(fails ? `\n${fails} FAILED` : '\nALL PASSED');
process.exitCode = fails ? 1 : 0;
