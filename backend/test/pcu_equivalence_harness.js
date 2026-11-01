// Runs an older Api.gs and the current one side by side on the same large,
// messy Guests tab and checks they answer every request the same way and
// leave the sheets the same. Guards the speed work (partial reads, month
// index, caches) against behaviour changes.
// Usage: node backend/test/pcu_equivalence_harness.js [old Api.gs] [new Api.gs]
//   old defaults to commit 472bccc (before the speed work), new to backend/Api.gs.
const fs = require('fs'); const vm = require('vm'); const path = require('path'); const { execSync } = require('child_process');
const { makeSheet, makeCache } = require('./gas_mocks');
const TZ = 'Africa/Lagos';

const repo = path.join(__dirname, '..', '..');
const oldSource = process.argv[2] ? fs.readFileSync(process.argv[2], 'utf8') : execSync('git show 472bccc:backend/Api.gs', { cwd: repo }).toString();
const newSource = fs.readFileSync(process.argv[3] || path.join(__dirname, '..', 'Api.gs'), 'utf8');

const lagosFormat = new Intl.DateTimeFormat('en-GB', { timeZone: TZ, year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short' });
function fmt(d, tz, pattern) {
  if (tz !== TZ) throw new Error('tz ' + tz);
  const parts = lagosFormat.formatToParts(d);
  const get = t => parts.find(p => p.type === t).value;
  const wd = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 }[get('weekday')];
  const y = String(d.getUTCFullYear() < 1000 ? get('year').padStart(4, '0') : get('year'));
  if (pattern === 'yyyy-MM-dd') return `${y}-${get('month')}-${get('day')}`;
  if (pattern === 'yyyy-MM') return `${y}-${get('month')}`;
  if (pattern === 'u') return String(wd);
  throw new Error('pattern ' + pattern);
}

// Pinned clock: 15 Nov 2026, 12:00 Lagos.
const NOW = Date.UTC(2026, 10, 15, 11);
function FixedDate(...a) { if (!new.target) return new Date(NOW).toString(); return a.length ? new Date(...a) : new Date(NOW); }
FixedDate.prototype = Date.prototype; FixedDate.now = () => NOW; FixedDate.UTC = Date.UTC; FixedDate.parse = Date.parse;

// Deterministic data.
let seed = 42; const rand = () => (seed = (seed * 1103515245 + 12345) % 2147483648) / 2147483648;
const pick = a => a[Math.floor(rand() * a.length)];
const lagos = (y, m, d, h = 10) => new Date(Date.UTC(y, m - 1, d, h - 1));

const header = ['Timestamp', '', '', 'SERVICE DATE', 'FULL NAME', 'PHONE NUMBER', 'GENDER', 'MARITAL STATUS', 'HOW DID YOU ARRIVE?', 'WHAT WAS THE MAJOR WAY', 'COULD YOU DESCRIBE', 'FEEDBACK 1', 'FEEDBACK 2 ', 'ASSIGNED TO', 'ASSIGNED DATE', 'CALL STATUS', 'MEMBERSHIP STATUS', 'FEEDBACK 1 DATE', 'FEEDBACK 2 DATE', 'MEMBERSHIP DATE', 'GUEST ID', 'TEAM JOINED', 'FOLLOW-UP COUNT', 'LAST FEEDBACK', 'LAST FEEDBACK DATE'];
const C = Object.fromEntries(header.map((h, i) => [h.trim(), i]));
const workers = ['david@x.com', 'worker.a@x.com', 'worker.b@x.com', 'boss@x.com', 'worker.c@x.com', ''];
const statuses = ['New guest', 'New guest', 'New guest', 'Contacted', 'Returning', 'Unreachable', 'Not interested'];
function guestRow(n, service, opts = {}) {
  const r = new Array(header.length).fill('');
  r[C.Timestamp] = opts.timestamp !== undefined ? opts.timestamp : service;
  r[C['SERVICE DATE']] = service;
  r[C['FULL NAME']] = 'Guest ' + n;
  r[C['PHONE NUMBER']] = 8000000000 + n;
  r[C['ASSIGNED TO']] = opts.assigned !== undefined ? opts.assigned : pick(workers);
  r[C['MEMBERSHIP STATUS']] = opts.status || pick(statuses);
  r[C['GUEST ID']] = opts.id !== undefined ? opts.id : 'G' + String(n).padStart(5, '0');
  if (rand() < 0.2) { r[C['FEEDBACK 1']] = 'legacy note ' + n; r[C['FEEDBACK 1 DATE']] = service; }
  if (rand() < 0.1) r[C['FOLLOW-UP COUNT']] = 1 + Math.floor(rand() * 3);
  if (rand() < 0.05) r[C['TEAM JOINED']] = 'Workforce';
  if (opts.memberDate) { r[C['MEMBERSHIP STATUS']] = 'Member'; r[C['MEMBERSHIP DATE']] = opts.memberDate; }
  return r;
}

function buildGuests() {
  const rows = [header.slice()];
  let n = 1;
  // In-order history: Jan 2023 to Nov 2026, Sundays and Wednesdays.
  for (let y = 2023; y <= 2026; y++) for (let m = 1; m <= 12; m++) {
    if (y === 2026 && m > 11) break;
    for (let k = 0; k < 40; k++) rows.push(guestRow(n++, lagos(y, m, 1 + Math.floor(rand() * 28), 9 + Math.floor(rand() * 10))));
  }
  const strays = [
    guestRow(n++, lagos(2026, 4, 12)), guestRow(n++, lagos(2025, 11, 2)), guestRow(n++, lagos(2026, 10, 7)),
    guestRow(n++, lagos(2027, 3, 1)), guestRow(n++, new Date(Date.UTC(23, 8, 3, 9))),
    guestRow(n++, '', { timestamp: lagos(2026, 10, 18) }),              // no service date: month from Timestamp
    guestRow(n++, '2026-10-11'),                                        // string date
    guestRow(n++, lagos(2026, 11, 1), { id: '' }),                      // no id yet
    guestRow(n++, lagos(2026, 10, 4), { id: ' G-SPACED ' }),            // id with spaces
    guestRow(n++, lagos(2024, 2, 4), { id: 'G-DUP' }), guestRow(n++, lagos(2026, 9, 6), { id: 'G-DUP' }),
    guestRow(n++, lagos(2021, 5, 2), { memberDate: lagos(2026, 11, 3), assigned: 'david@x.com' }),  // old guest, member this month
    guestRow(n++, lagos(2022, 1, 9), { memberDate: lagos(2026, 3, 8), assigned: 'worker.a@x.com' }),
    guestRow(n++, lagos(1915, 6, 6)),                                    // before 1920: slow date path
  ];
  strays.forEach(r => rows.splice(1 + Math.floor(rand() * (rows.length - 1)), 0, r));
  // A few members in recent months, and a run of current-month guests at the bottom.
  for (let k = 0; k < 6; k++) rows.push(guestRow(n++, lagos(2026, 10, 1 + k * 4), { memberDate: lagos(2026, 10 + (k % 2), 10 + k), assigned: pick(workers.slice(0, 3)) }));
  for (let k = 0; k < 30; k++) rows.push(guestRow(n++, lagos(2026, 11, 1 + (k % 14)), { assigned: pick(['david@x.com', 'worker.a@x.com']), status: 'New guest' }));
  rows.push(guestRow(n++, lagos(2026, 11, 12), { id: 'G-FRESH', assigned: 'david@x.com', status: 'New guest' }));
  rows.push(guestRow(n++, lagos(2026, 11, 13), { id: 'G-FRESH2', assigned: 'david@x.com', status: 'New guest' }));
  return rows;
}

function buildFollowUps(guestRows) {
  const rows = [['Follow-up ID', 'Guest', 'Worker', 'Call date', 'Call status', 'Note', 'Attended Sunday?', 'Sunday date', 'Attended Wednesday?', 'Wednesday date', 'Joined team', 'Logged by']];
  const ids = guestRows.slice(1).map(r => String(r[C['GUEST ID']]).trim()).filter(Boolean);
  for (let k = 0; k < 400; k++) {
    const id = pick(ids);
    const date = lagos(2026, 1 + Math.floor(rand() * 11), 1 + Math.floor(rand() * 28), 15);
    if (date.getTime() > NOW) continue;
    const sunday = rand() < 0.3;
    rows.push(['f' + k, id, pick(workers.slice(0, 3)), date, pick(['Reached', 'No answer', 'Busy']), rand() < 0.5 ? 'note ' + k : '',
      sunday ? 'TRUE' : '', sunday ? date : '', '', '', rand() < 0.05 ? 'Evangelism' : '', rand() < 0.2 ? 'boss@x.com' : '']);
  }
  return rows;
}

const workerRows = [['ID', 'Name', 'Email', 'Phone', 'Role', 'Active'],
  ['W001', 'Opeyemi Olanite', 'boss@x.com', '08000000101', 'Admin', 'Yes'],
  ['W002', 'TEST Worker A', 'worker.a@x.com', '', 'Worker', 'Yes'],
  ['W003', 'TEST Worker B', 'worker.b@x.com', '', 'Worker', 'Yes'],
  ['W004', 'Inactive C', 'worker.c@x.com', '', 'Worker', 'No'],
  ['W005', 'David Olanite', 'david@x.com', '', 'Worker', 'Yes']];

const guests0 = buildGuests();
const followUps0 = buildFollowUps(guests0);
const clone = rows => rows.map(r => r.map(v => (v instanceof Date ? new Date(v.getTime()) : v)));

function makeRuntime(source) {
  const sheets = {
    'Form Responses 1': makeSheet(clone(guests0), 'guests'),
    'Follow-ups': makeSheet(clone(followUps0), 'followUps'),
    'Workers': makeSheet(clone(workerRows), 'workers'),
  };
  const cache = makeCache();
  let uuid = 0;
  const ctx = {
    console: { log() {}, warn() {}, error: console.error },
    Date: FixedDate,
    SpreadsheetApp: { getActive: () => ({ getSheetByName: n => sheets[n] || null }), flush() {} },
    Utilities: {
      formatDate: fmt,
      parseDate: s => { const [y, m, d] = s.split('-').map(Number); return new Date(Date.UTC(y, m - 1, d, -1)); },
      getUuid: () => 'uuid' + String(++uuid).padStart(8, '0'),
    },
    CacheService: { getScriptCache: () => cache },
    PropertiesService: { getScriptProperties: () => ({ getProperty: k => (k === 'ALLOW_MOCK_TOKENS' ? 'true' : null) }) },
    LockService: { getScriptLock: () => ({ tryLock: () => true, releaseLock() {} }) },
    ContentService: { createTextOutput: s => ({ text: s, setMimeType() { return this; } }), MimeType: { JSON: 'json' } },
  };
  vm.createContext(ctx);
  vm.runInContext(source, ctx);
  // Each Apps Script request starts with fresh globals; the old code kept tables in one.
  const call = body => { vm.runInContext('pcuTableCache_ = {};', ctx); return JSON.parse(ctx.doPost({ postData: { contents: JSON.stringify(body) } }).text); };
  const clearStats = () => Object.keys(cache.store).filter(k => k.startsWith('pcu_stats_')).forEach(k => cache.remove(k));
  return { sheets, cache, call, clearStats };
}

const before = makeRuntime(oldSource);
const after = makeRuntime(newSource);

// Follow-up ids come from getUuid, which the new code also uses for its cache;
// compare everything except those ids.
// Guest fields added on purpose after the old version: compared by their own tests, not here.
const ADDED_GUEST_FIELDS = ['gender', 'lastCallDate', 'sundayDates', 'wednesdayDates'];
function normalise(value) {
  return JSON.parse(JSON.stringify(value), function (k, v) {
    if (k === 'id' && typeof v === 'string' && v.startsWith('uuid')) return 'ID';
    if (v && typeof v === 'object' && !Array.isArray(v) && 'serviceDate' in v && 'phone' in v) {
      const copy = Object.assign({}, v);
      ADDED_GUEST_FIELDS.forEach(f => delete copy[f]);
      return copy;
    }
    return v;
  });
}
const sheetRows = rt => Object.fromEntries(Object.entries(rt.sheets).map(([name, s]) =>
  [name, normalise(s.rows.slice(0, s.getLastRow()).map(r => (name === 'Follow-ups' ? r.slice(1) : r)))]));

let checks = 0; let fails = 0;
function same(label, body) {
  const a = normalise(before.call(body)); const b = normalise(after.call(body));
  checks++;
  if (JSON.stringify(a) !== JSON.stringify(b)) {
    fails++;
    const ja = JSON.stringify(a); const jb = JSON.stringify(b);
    let i = 0; while (ja[i] === jb[i]) i++;
    const from = Math.max(0, i - 150);
    console.log('FAIL ' + label + ' (first difference at ' + i + ')\n  old: ...' + ja.slice(from, i + 150) + '\n  new: ...' + jb.slice(from, i + 150));
  }
  return b;
}
function sameSheets(label) {
  checks++;
  const a = JSON.stringify(sheetRows(before)); const b = JSON.stringify(sheetRows(after));
  if (a !== b) { fails++; console.log('FAIL sheets ' + label); }
}

const D = 'mock_token_david@x.com'; const A = 'mock_token_boss@x.com'; const W = 'mock_token_worker.a@x.com';
const months = []; for (let y = 2022; y <= 2027; y++) for (let m = 1; m <= 12; m++) months.push(`${y}-${String(m).padStart(2, '0')}`);
const recent = months.filter(m => m >= '2025-10' && m <= '2027-03');
const guestIds = guests0.slice(1).map(r => r[C['GUEST ID']]).filter(Boolean);

function readAll(tag) {
  same(tag + ' me worker', { action: 'me', idToken: D });
  same(tag + ' me admin', { action: 'me', idToken: A });
  months.forEach(m => same(`${tag} guests admin ${m}`, { action: 'guests', idToken: A, month: m }));
  recent.forEach(m => {
    same(`${tag} guests worker ${m}`, { action: 'guests', idToken: D, month: m });
    same(`${tag} guests admin filter ${m}`, { action: 'guests', idToken: A, month: m, workerEmail: 'worker.a@x.com' });
    same(`${tag} ranking worker ${m}`, { action: 'ranking', idToken: W, month: m });
    same(`${tag} ranking admin ${m}`, { action: 'ranking', idToken: A, month: m });
    same(`${tag} dashboard ${m}`, { action: 'dashboard', idToken: A, month: m });
    same(`${tag} team ${m}`, { action: 'team', idToken: A, month: m });
  });
  ['2024-05', '2023-01', '0023-09'].forEach(m => {
    same(`${tag} ranking ${m}`, { action: 'ranking', idToken: A, month: m });
    same(`${tag} dashboard ${m}`, { action: 'dashboard', idToken: A, month: m });
    same(`${tag} team ${m}`, { action: 'team', idToken: A, month: m });
  });
  same(tag + ' dashboard default month', { action: 'dashboard', idToken: A });
  same(tag + ' team default month', { action: 'team', idToken: A });
  const ids = ['G-SPACED', ' G-SPACED ', 'G-DUP', 'g00010', 'G-MISSING', '', 'G-FRESH', ...guestIds.filter((_, i) => i % 97 === 0)];
  ids.forEach(id => {
    same(`${tag} guest admin ${JSON.stringify(id)}`, { action: 'guest', idToken: A, id });
    same(`${tag} guest worker ${JSON.stringify(id)}`, { action: 'guest', idToken: D, id });
  });
}

console.log('start reads');
readAll('start');
// Reads again with warm caches (index and stats) must still match.
console.log('warm reads');
readAll('warm');

// Saves: worker, admin on behalf, attendance up to Member, errors.
const saves = [
  [D, 'G-FRESH', { outcome: 'Reached', note: 'first', attendedSunday: true, sundayDate: '2026-11-01' }],
  [D, 'G-FRESH', { outcome: 'Busy', note: '' }],
  [A, 'G-FRESH', { outcome: 'Reached', note: 'admin', attendedSunday: true, sundayDate: '2026-11-08', team: 'Workforce' }],
  [D, 'G-FRESH', { outcome: 'Reached', attendedSunday: true, sundayDate: '2026-11-15', attendedWednesday: true, wednesdayDate: '2026-11-04' }],
  [D, 'G-FRESH2', { outcome: 'No answer' }],
  [W, 'G-FRESH2', { outcome: 'Reached' }],
  [A, 'G-SPACED', { outcome: 'Reached', note: 'spaced id' }],
  [A, 'G-DUP', { outcome: 'Reached', note: 'dup id' }],
  [D, 'G-MISSING', { outcome: 'Reached' }],
  [D, 'G-FRESH', { outcome: 'Maybe' }],
  [D, 'G-FRESH', { outcome: 'Reached', attendedSunday: true, sundayDate: '2026-12-01' }],
  [A, guestIds[5], { outcome: 'Reached', note: 'old guest' }],
];
saves.forEach(([token, guestId, extra], i) => {
  same(`save ${i} ${guestId}`, Object.assign({ action: 'logFollowUp', idToken: token, guestId, team: '' }, extra));
  sameSheets(`after save ${i}`);
  same(`ranking after save ${i}`, { action: 'ranking', idToken: A, month: '2026-11' });
  same(`dashboard after save ${i}`, { action: 'dashboard', idToken: A, month: '2026-11' });
  same(`team after save ${i}`, { action: 'team', idToken: A, month: '2026-11' });
});
same('saveWorker', { action: 'saveWorker', idToken: A, name: 'New Person', email: 'new@x.com', role: 'Worker' });
same('team after saveWorker', { action: 'team', idToken: A, month: '2026-11' });
same('setWorkerActive', { action: 'setWorkerActive', idToken: A, id: 'W003', active: false });
same('ranking after setWorkerActive', { action: 'ranking', idToken: A, month: '2026-11' });
sameSheets('after worker changes');

// Rows added by the form (appended): the index must pick them up.
// Rows are built once (guestRow is random) and copied into both runtimes.
const new1 = guestRow(90001, lagos(2026, 11, 14), { id: 'G-NEW1', assigned: 'david@x.com', status: 'New guest' });
const new2 = guestRow(90002, lagos(2026, 10, 30), { id: 'G-NEW2', assigned: 'worker.a@x.com', status: 'New guest' });
const new3 = guestRow(90003, lagos(2026, 11, 14), { id: 'G-NEW3', assigned: 'david@x.com', status: 'New guest' });
[before, after].forEach(rt => {
  const s = rt.sheets['Form Responses 1'];
  s.appendRow(clone([new1])[0]);
  s.appendRow(clone([new2])[0]);
  rt.clearStats(); // stats are cached for 90 s; this is "after 90 s"
});
readAll('appended');

// A row deleted in the middle: the tab got shorter, so the index is rebuilt.
[before, after].forEach(rt => { rt.sheets['Form Responses 1'].rows.splice(1700, 1); rt.clearStats(); });
readAll('deleted');

// Deleted and appended (same length): rows shifted under the index; the check must catch it.
[before, after].forEach(rt => {
  const s = rt.sheets['Form Responses 1'];
  s.rows.splice(1600, 1);
  s.appendRow(clone([new3])[0]);
  rt.clearStats();
});
readAll('shifted');

const reads = after.sheets['Form Responses 1'].reads.length;
console.log(`${checks} comparisons, ${guests0.length - 1} guest rows; new code made ${reads} Guests reads`);
console.log(fails ? `${fails} FAILED` : 'ALL PASSED');
process.exit(fails ? 1 : 0);
