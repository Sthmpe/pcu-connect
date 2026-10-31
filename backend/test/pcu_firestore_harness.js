// Runs backend/Api.gs + backend/Firestore.gs in Node against mocks of the Apps
// Script services and the Firestore REST API (no network, no real data).
// Usage: node backend/test/pcu_firestore_harness.js
const fs = require('fs'); const vm = require('vm'); const crypto = require('crypto'); const path = require('path');
const TZ = 'Africa/Lagos';

function fmt(d, tz, pattern) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: tz, year: 'numeric', month: '2-digit', day: '2-digit', weekday: 'short',
    hour: '2-digit', minute: '2-digit', second: '2-digit', hourCycle: 'h23',
  }).formatToParts(d);
  const get = t => parts.find(p => p.type === t).value;
  const wd = { Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7 }[get('weekday')];
  if (pattern === 'yyyy-MM-dd') return `${get('year')}-${get('month')}-${get('day')}`;
  if (pattern === 'yyyy-MM') return `${get('year')}-${get('month')}`;
  if (pattern === "yyyy-MM-dd'T'HH:mm:ss") return `${get('year')}-${get('month')}-${get('day')}T${get('hour')}:${get('minute')}:${get('second')}`;
  if (pattern === 'u') return String(wd);
  throw new Error('pattern ' + pattern);
}
function makeSheet(rows) {
  const sheet = { rows,
    getDataRange() { return { getValues: () => sheet.rows.map(r => r.slice()) }; },
    appendRow(r) { sheet.rows.push(r.slice()); },
    getRange(r, c) { return { setValue(v) { while (sheet.rows.length < r) sheet.rows.push([]); sheet.rows[r - 1][c - 1] = v; } }; } };
  return sheet;
}

const now = new Date(); const ymd = d => fmt(d, TZ, 'yyyy-MM-dd');
const daysAgo = n => new Date(now.getTime() - n * 86400000);
const guestsHeader = ['Timestamp', '', '', 'SERVICE DATE', 'FULL NAME', 'PHONE NUMBER', 'GENDER', 'MARITAL STATUS', 'HOW DID YOU ARRIVE?', 'WHAT WAS THE MAJOR WAY', 'COULD YOU DESCRIBE', 'FEEDBACK 1', 'FEEDBACK 2 ', 'ASSIGNED TO', 'ASSIGNED DATE', 'CALL STATUS', 'MEMBERSHIP STATUS', 'FEEDBACK 1 DATE', 'FEEDBACK 2 DATE', 'MEMBERSHIP DATE', 'GUEST ID', 'TEAM JOINED', 'FOLLOW-UP COUNT', 'LAST FEEDBACK', 'LAST FEEDBACK DATE'];
function guestRow(id, name, service, assigned, phone) {
  const r = new Array(25).fill('');
  r[0] = service; r[3] = service; r[4] = name; r[5] = phone || 8000000001; r[13] = assigned; r[14] = service; r[16] = 'New guest'; r[20] = id;
  return r;
}

function setup(opts = {}) {
  const sheets = {
    'Form Responses 1': makeSheet([guestsHeader.slice(),
      guestRow('G1', 'Ada Obi', daysAgo(2), 'david@x.com', 8000000001),
      guestRow('G2', 'Bola Ade', daysAgo(10), 'david@x.com', 8000000002),
      guestRow('G3', 'Chi Eze', daysAgo(1), 'worker.a@x.com', 8000000003),
      guestRow('G4', 'Old Guest', new Date('2024-01-05'), 'david@x.com', 8000000004),
      guestRow('', 'No Id Yet', daysAgo(3), 'david@x.com', 8000000005),
      ...(opts.extraGuests || []),
    ]),
    'Follow-ups': makeSheet([['Follow-up ID', 'Guest', 'Worker', 'Call date', 'Call status', 'Note', 'Attended Sunday?', 'Sunday date', 'Attended Wednesday?', 'Wednesday date', 'Joined team', 'Logged by'],
      ['a1', 'G2', 'david@x.com', daysAgo(9), 'Reached', 'hello', 'TRUE', daysAgo(9), '', '', '', ''],
      ['a2', 'G2', 'david@x.com', daysAgo(5), 'No answer', '', '', '', '', '', 'Workforce', 'boss@x.com'],
    ]),
    'Workers': makeSheet([['ID', 'Name', 'Email', 'Phone', 'Role', 'Active'],
      ['W001', 'Opeyemi Olanite', 'boss@x.com', '08000000101', 'Admin', 'Yes'],
      ['W002', 'TEST Worker A', '  Worker.A@X.com ', '', 'Worker', 'Yes'],
      ['W004', 'Inactive C', 'worker.c@x.com', '', 'Worker', 'No'],
      ['W005', 'David Olanite', 'david@x.com', '', 'Worker', 'Yes']]),
  };
  const props = { FIREBASE_WEB_API_KEY: 'KEY' };
  if (opts.firestore !== false) {
    props.FIRESTORE_SA_KEY = JSON.stringify({ project_id: 'demo-pcu', client_email: 'sa@demo-pcu.iam.gserviceaccount.com', private_key: 'PRIVATE', token_uri: 'https://oauth2.googleapis.com/token' });
  }
  const store = {}; const commits = []; let tokenRequests = 0;
  const cache = {};
  const tokens = { tokAdmin: 'boss@x.com', tokDavid: 'david@x.com' };
  const decode = v => {
    if ('stringValue' in v) return v.stringValue;
    if ('integerValue' in v) return Number(v.integerValue);
    if ('doubleValue' in v) return v.doubleValue;
    if ('booleanValue' in v) return v.booleanValue;
    if ('timestampValue' in v) return new Date(v.timestampValue);
    if ('nullValue' in v) return null;
    if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
    if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields).map(([k, x]) => [k, decode(x)]));
    throw new Error('bad value ' + JSON.stringify(v));
  };
  const ctx = {
    console: { log() {}, warn() {}, error: console.error },
    SpreadsheetApp: { getActive: () => ({ getSheetByName: n => sheets[n] || null }), flush() {} },
    Utilities: {
      formatDate: fmt,
      parseDate: (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(Date.UTC(y, m - 1, d, -1)); },
      computeDigest: (alg, s) => Array.from(crypto.createHash('sha256').update(s).digest()).map(b => (b > 127 ? b - 256 : b)),
      computeRsaSha256Signature: (input, key) => { if (key !== 'PRIVATE') throw new Error('bad key'); return Array.from(crypto.createHash('sha256').update(input).digest()); },
      base64EncodeWebSafe: b => (typeof b === 'string' ? Buffer.from(b) : Buffer.from(b.map(x => x & 255))).toString('base64url') + '=',
      getUuid: () => crypto.randomUUID(),
      DigestAlgorithm: { SHA_256: 'sha256' },
    },
    CacheService: { getScriptCache: () => ({ get: k => cache[k] || null, put: (k, v) => { cache[k] = v; } }) },
    PropertiesService: { getScriptProperties: () => ({
      getProperty: k => (k in props ? props[k] : null),
      setProperty: (k, v) => { props[k] = v; },
      deleteProperty: k => { delete props[k]; },
    }) },
    UrlFetchApp: { fetch: (url, o) => {
      if (url === 'https://oauth2.googleapis.com/token') {
        tokenRequests++;
        const ok = o.payload.grant_type === 'urn:ietf:params:oauth:grant-type:jwt-bearer' && o.payload.assertion.split('.').length === 3;
        return { getResponseCode: () => (ok ? 200 : 400), getContentText: () => JSON.stringify({ access_token: 'ACCESS' }) };
      }
      if (url.endsWith(':commit')) {
        const writes = JSON.parse(o.payload).writes;
        const authed = o.headers && o.headers.Authorization === 'Bearer ACCESS';
        if (!authed || writes.length > 500) return { getResponseCode: () => 400, getContentText: () => 'rejected' };
        commits.push(writes.length);
        writes.forEach(w => {
          const p = w.update.name.split('/documents/')[1];
          const fields = Object.fromEntries(Object.entries(w.update.fields).map(([k, v]) => [k, decode(v)]));
          store[p] = Object.assign(store[p] || {}, fields);
        });
        return { getResponseCode: () => 200, getContentText: () => '{}' };
      }
      const t = JSON.parse(o.payload).idToken; const email = tokens[t];
      return { getResponseCode: () => (email ? 200 : 400), getContentText: () => JSON.stringify(email ? { users: [{ email, emailVerified: true }] } : { error: {} }) };
    } },
    LockService: { getScriptLock: () => ({ tryLock: () => true, releaseLock() {} }) },
    ContentService: { createTextOutput: s => ({ text: s, setMimeType() { return this; } }), MimeType: { JSON: 'json' } },
  };
  vm.createContext(ctx);
  const dir = path.join(__dirname, '..');
  vm.runInContext(fs.readFileSync(path.join(dir, 'Api.gs'), 'utf8') + '\n' + fs.readFileSync(path.join(dir, 'Firestore.gs'), 'utf8'), ctx);
  const call = body => JSON.parse(ctx.doPost({ postData: { contents: JSON.stringify(body) } }).text);
  return { ctx, sheets, props, store, commits, call, tokenRequests: () => tokenRequests };
}

let fails = 0;
const check = (label, cond, extra) => { console.log((cond ? 'PASS ' : 'FAIL ') + label + (cond ? '' : ' ' + JSON.stringify(extra))); if (!cond) fails++; };
const docs = (store, col) => Object.keys(store).filter(k => k.startsWith(col + '/'));

// --- Stable GUEST IDs
{
  const { ctx } = setup();
  const t = new Date('2026-10-25T09:15:30Z');
  const a = ctx.pcuStableGuestId_(t, '0803 555 0101');
  check('stable id format G-XXXXXXXX', /^G-[0-9A-F]{8}$/.test(a), a);
  check('same row gives the same id', a === ctx.pcuStableGuestId_(new Date(t.getTime()), '08035550101'), a);
  check('different phone gives a different id', a !== ctx.pcuStableGuestId_(t, '0803 555 0102'));
  check('id uses Africa/Lagos time', ctx.pcuStableGuestId_(t, '1') === ctx.pcuStableGuestId_('2026-10-25T10:15:30', '1'));
}

// --- IDs written to the sheet, never duplicated
{
  const { ctx, sheets } = setup();
  const rows = sheets['Form Responses 1'].rows;
  check('one missing id filled', ctx.pcuEnsureGuestIds_() === 1);
  const id = rows[5][20];
  check('filled id is stable', /^G-[0-9A-F]{8}$/.test(id), id);
  check('second run writes nothing', ctx.pcuEnsureGuestIds_() === 0);
  rows.push(rows[5].slice()); rows[6][20] = '';
  check('a duplicate row is skipped, not given the same id', ctx.pcuEnsureGuestIds_() === 0 && rows[6][20] === '', rows[6][20]);
}

// --- Disabled until the key exists
{
  const { ctx, commits } = setup({ firestore: false });
  const r = ctx.pcuPushPendingGuests();
  check('no key: the 5-minute job does nothing', r.skipped === 'not set up' && commits.length === 0, r);
  check('no key: pushing a guest does nothing', ctx.pcuPushGuest_('G1') === 0);
}

// --- Migration
{
  const { ctx, sheets, store, commits, props } = setup();
  const r = ctx.pcuMigrate();
  check('migration finishes in one run', r.done === true, r);
  check('marker cleared when done', !props.PCU_JOB_migrate);
  check('users written with clean emails', !!store['users/worker.a@x.com'] && store['users/worker.a@x.com'].email === 'worker.a@x.com', Object.keys(store));
  check('Workers tab emails normalised', sheets.Workers.rows[2][2] === 'worker.a@x.com', sheets.Workers.rows[2][2]);
  check('roles mapped', store['users/boss@x.com'].role === 'admin' && store['users/david@x.com'].role === 'worker');
  check('inactive worker kept inactive', store['users/worker.c@x.com'].active === false);
  check('guests from the last 12 months only', !!store['guests/G1'] && !store['guests/G4'], docs(store, 'guests'));
  const g2 = store['guests/G2'];
  check('guest sheet fields', g2.name === 'Bola Ade' && g2.assignedTo === 'david@x.com' && g2.assignedName === 'David Olanite' && /^\d{4}-\d{2}$/.test(g2.month), g2);
  check('guest work fields', g2.followUpCount === 2 && g2.teamJoined === '' && g2.sundayDates.length >= 1, g2);
  const a1 = store['followUps/a1']; const a2 = store['followUps/a2'];
  check('follow-ups copied with worker and loggedBy', a1.worker === 'david@x.com' && a1.loggedBy === 'david@x.com' && a2.loggedBy === 'boss@x.com', [a1, a2]);
  check('follow-up points: first call within 3 days +10, Sunday +10', a1.points === 20, a1.points);
  check('follow-up points: +5 and first team join +20', a2.points === 25, a2.points);
  check('points always allowed by the rules', docs(store, 'followUps').every(k => store[k].points >= 5 && store[k].points <= 80 && store[k].points % 5 === 0));
  const count = Object.keys(store).length; const before = commits.length;
  ctx.pcuMigrate();
  check('running again changes nothing', Object.keys(store).length === count && commits.length > before);
}

// --- Batches of 500 and resume from the marker
{
  const extra = []; for (let i = 0; i < 1200; i++) extra.push(guestRow('B' + i, 'Bulk ' + i, daysAgo(5), 'david@x.com', 9000000000 + i));
  const { ctx, store, commits, props } = setup({ extraGuests: extra });
  ctx.PCU_FS.TIME_BUDGET_MS = -1; // stop after the first full batch
  const first = ctx.pcuMigrate();
  check('long run stops early with a marker', first.done === false && !!props.PCU_JOB_migrate, first);
  check('every commit has at most 500 writes', commits.every(n => n <= 500), commits);
  ctx.PCU_FS.TIME_BUDGET_MS = 10 * 60 * 1000;
  const second = ctx.pcuMigrate();
  check('next run continues from the marker and finishes', second.done === true && !props.PCU_JOB_migrate, second);
  check('all 1200 bulk guests arrived once', docs(store, 'guests').filter(k => k.startsWith('guests/B')).length === 1200);
  check('first run did not process everything again', first.processed + second.processed === 1200 + 4, [first.processed, second.processed]);
}

// --- 5-minute job: new guests, nothing twice, reassignments
{
  const { ctx, sheets, store } = setup();
  ctx.pcuSetupSyncColumns();
  const r1 = ctx.pcuPushPendingGuests();
  check('first run sends every recent assigned guest', r1.pending === 4 && r1.done, r1);
  const r2 = ctx.pcuPushPendingGuests();
  check('second run sends nothing', r2.pending === 0, r2);
  const rows = sheets['Form Responses 1'].rows;
  rows[1][13] = 'worker.a@x.com'; // HOD reassigns Ada in the sheet
  const r3 = ctx.pcuPushPendingGuests();
  check('a reassignment is sent', r3.pending === 1 && store['guests/G1'].assignedTo === 'worker.a@x.com' && store['guests/G1'].assignedName === 'TEST Worker A', [r3, store['guests/G1']]);
  check('the sheet keeps ASSIGNED TO as the HOD set it', rows[1][13] === 'worker.a@x.com');
}

// --- Saving through the API keeps Firestore in step
{
  const { store, call } = setup();
  const r = call({ action: 'logFollowUp', idToken: 'tokAdmin', guestId: 'G1', outcome: 'Reached', note: 'admin call', attendedSunday: false, attendedWednesday: false, team: '' });
  check('admin save ok', r.ok, r);
  const id = Object.keys(store).find(k => k.startsWith('followUps/') && store[k].note === 'admin call');
  check('the new follow-up is in Firestore', !!id, Object.keys(store));
  check('credited to the assigned worker, logged by the admin', id && store[id].worker === 'david@x.com' && store[id].loggedBy === 'boss@x.com', id && store[id]);
  check('the guest totals moved with it', store['guests/G1'].followUpCount === 1 && store['guests/G1'].callStatus === 'Reached', store['guests/G1']);
  const s = call({ action: 'saveWorker', idToken: 'tokAdmin', name: 'Ruth A', email: '  Ruth@X.com ', phone: '', role: 'Worker', active: true });
  check('new worker saved', s.ok && s.data.email === 'ruth@x.com', s);
  check('new worker reaches users with a clean email', !!store['users/ruth@x.com'] && store['users/ruth@x.com'].active === true, Object.keys(store).filter(k => k.startsWith('users/')));
  call({ action: 'setWorkerActive', idToken: 'tokAdmin', id: 'W004', active: true });
  check('reactivation reaches users', store['users/worker.c@x.com'].active === true);
}

// --- The access token is cached
{
  const h = setup();
  h.ctx.pcuSyncUsers_(); h.ctx.pcuSyncUsers_();
  check('token requested once and reused', h.tokenRequests() === 1, h.tokenRequests());
}

console.log(fails ? `\n${fails} FAILED` : '\nALL PASSED');
process.exitCode = fails ? 1 : 0;
