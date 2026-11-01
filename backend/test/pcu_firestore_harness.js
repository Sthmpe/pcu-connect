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
  if (pattern === 'HH:mm') return `${get('hour')}:${get('minute')}`;
  if (pattern === 'HHmmss') return `${get('hour')}${get('minute')}${get('second')}`;
  if (pattern === 'EEEE') return new Intl.DateTimeFormat('en-GB', { timeZone: tz, weekday: 'long' }).format(d);
  throw new Error('pattern ' + pattern);
}
const mocks = require('./gas_mocks');
const makeSheet = rows => mocks.makeSheet(rows);

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
  const cache = mocks.makeCache();
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
  const encode = v => {
    if (v === null || v === undefined) return { nullValue: null };
    if (v instanceof Date) return { timestampValue: v.toISOString() };
    if (typeof v === 'boolean') return { booleanValue: v };
    if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
    if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
    if (typeof v === 'object') return { mapValue: { fields: Object.fromEntries(Object.entries(v).map(([k, x]) => [k, encode(x)])) } };
    return { stringValue: String(v) };
  };
  const BASE = 'projects/demo-pcu/databases/(default)/documents/';
  const asDoc = key => ({ name: BASE + key, fields: Object.fromEntries(Object.entries(store[key]).map(([k, v]) => [k, encode(v)])) });
  const reads = { queries: 0, batchGets: 0 };
  const pushes = [];
  const mails = [];
  const triggers = [];
  const ctx = {
    console: { log() {}, warn() {}, error: console.error },
    SpreadsheetApp: { getActive: () => ({
      getUrl: () => 'https://docs.google.com/spreadsheets/d/TEST/edit',
      getSheetByName: n => sheets[n] || null,
      insertSheet: n => (sheets[n] = makeSheet([])),
    }), flush() {} },
    ScriptApp: {
      WeekDay: { MONDAY: 'MONDAY' },
      getProjectTriggers: () => triggers.map(t => ({ getHandlerFunction: () => t.fn, t })),
      deleteTrigger: x => { const i = triggers.indexOf(x.t); if (i >= 0) triggers.splice(i, 1); },
      newTrigger: fn => {
        const t = { fn };
        const b = { timeBased: () => b, everyDays: d => ((t.days = d), b), atHour: h => ((t.hour = h), b), nearMinute: m => ((t.minute = m), b),
          onWeekDay: d => ((t.weekDay = d), b), inTimezone: z => ((t.tz = z), b), everyMinutes: m => ((t.minutes = m), b),
          forSpreadsheet: () => b, onFormSubmit: () => ((t.formSubmit = true), b), create: () => (triggers.push(t), t) };
        return b;
      },
    },
    Utilities: {
      formatDate: fmt,
      parseDate: (s) => { const [y, m, d] = s.split('-').map(Number); return new Date(Date.UTC(y, m - 1, d, -1)); },
      computeDigest: (alg, s) => Array.from(crypto.createHash('sha256').update(s).digest()).map(b => (b > 127 ? b - 256 : b)),
      computeRsaSha256Signature: (input, key) => { if (key !== 'PRIVATE') throw new Error('bad key'); return Array.from(crypto.createHash('sha256').update(input).digest()); },
      base64EncodeWebSafe: b => (typeof b === 'string' ? Buffer.from(b) : Buffer.from(b.map(x => x & 255))).toString('base64url') + '=',
      getUuid: () => crypto.randomUUID(),
      DigestAlgorithm: { SHA_256: 'sha256' },
    },
    CacheService: { getScriptCache: () => cache },
    MailApp: { sendEmail: m => { if (ctx.MailApp.fail) throw new Error('quota'); mails.push(m); } },
    PropertiesService: { getScriptProperties: () => ({
      getProperty: k => (k in props ? props[k] : null),
      setProperty: (k, v) => { props[k] = v; },
      deleteProperty: k => { delete props[k]; },
    }) },
    UrlFetchApp: { fetchAll: reqs => reqs.map(r => ctx.UrlFetchApp.fetch(r.url, r)), fetch: (url, o = {}) => {
      if (url.includes('?pageSize')) {
        const path = decodeURIComponent(url.split('/documents/')[1].split('?')[0]);
        const depth = path.split('/').length + 1;
        const keys = Object.keys(store).filter(k => k.startsWith(path + '/') && k.split('/').length === depth);
        return { getResponseCode: () => 200, getContentText: () => JSON.stringify(keys.length ? { documents: keys.map(asDoc) } : {}) };
      }
      if (url.startsWith('https://fcm.googleapis.com/v1/projects/demo-pcu/messages:send')) {
        if (ctx.UrlFetchApp.failPush) return { getResponseCode: () => 403, getContentText: () => '{"error":{"status":"PERMISSION_DENIED"}}' };
        const body = JSON.parse(o.payload);
        pushes.push(body);
        if (body.message.token === 'dead-token') return { getResponseCode: () => 404, getContentText: () => '{"error":{"status":"NOT_FOUND","details":[{"errorCode":"UNREGISTERED"}]}}' };
        return { getResponseCode: () => 200, getContentText: () => '{"name":"projects/demo-pcu/messages/1"}' };
      }
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
          if (w.delete) { delete store[w.delete.split('/documents/')[1]]; return; }
          const p = w.update.name.split('/documents/')[1];
          const fields = Object.fromEntries(Object.entries(w.update.fields).map(([k, v]) => [k, decode(v)]));
          store[p] = Object.assign(store[p] || {}, fields);
        });
        return { getResponseCode: () => 200, getContentText: () => '{}' };
      }
      if (url.endsWith(':runQuery')) {
        if (ctx.UrlFetchApp.failQueries) return { getResponseCode: () => 503, getContentText: () => 'unavailable' };
        reads.queries++;
        const q = JSON.parse(o.payload).structuredQuery;
        const col = q.from[0].collectionId;
        const f = q.where && q.where.fieldFilter;
        const want = f ? decode(f.value) : undefined;
        let keys = Object.keys(store).filter(k => k.startsWith(col + '/') && k.split('/').length === 2 && (!f || store[k][f.field.fieldPath] === want)).sort();
        if (q.startAt) keys = keys.filter(k => BASE + k > q.startAt.values[0].referenceValue);
        keys = keys.slice(0, q.limit);
        const out = keys.map(k => ({ document: asDoc(k), readTime: 'now' }));
        return { getResponseCode: () => 200, getContentText: () => JSON.stringify(out.length ? out : [{ readTime: 'now' }]) };
      }
      if (url.endsWith(':batchGet')) {
        reads.batchGets++;
        const names = JSON.parse(o.payload).documents;
        if (names.length > 100) return { getResponseCode: () => 400, getContentText: () => 'too many' };
        const out = names.map(n => { const k = n.substring(BASE.length); return store[k] ? { found: asDoc(k) } : { missing: n }; });
        return { getResponseCode: () => 200, getContentText: () => JSON.stringify(out) };
      }
      const t = JSON.parse(o.payload).idToken; const email = tokens[t];
      return { getResponseCode: () => (email ? 200 : 400), getContentText: () => JSON.stringify(email ? { users: [{ email, emailVerified: true }] } : { error: {} }) };
    } },
    LockService: { getScriptLock: () => ({ tryLock: () => true, waitLock() {}, releaseLock() {} }) },
    ContentService: { createTextOutput: s => ({ text: s, setMimeType() { return this; } }), MimeType: { JSON: 'json' } },
  };
  vm.createContext(ctx);
  const dir = path.join(__dirname, '..');
  vm.runInContext(['Api.gs', 'Firestore.gs', 'pcu_auto_assign.gs'].map(f => fs.readFileSync(path.join(dir, f), 'utf8')).join('\n'), ctx);
  const call = body => JSON.parse(ctx.doPost({ postData: { contents: JSON.stringify(body) } }).text);
  return { ctx, sheets, props, store, commits, call, reads, triggers, pushes, mails, tokenRequests: () => tokenRequests };
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

// --- Phase 2 and 3: the app saves to Firestore, the sheet sync copies the work back
{
  const { ctx, sheets, store, call, commits, triggers, props } = setup();
  ctx.pcuSetupSyncColumns();
  ctx.pcuMigrate();
  const today = ymd(now);
  const g = sheets['Form Responses 1'].rows;
  const fuRows = sheets['Follow-ups'].rows;
  const before = { g1: g[1].slice(), fuCount: fuRows.length };
  // Saved in the app (as FirestoreGuestRepository writes them).
  store['followUps/app1'] = { guestId: 'G1', worker: 'david@x.com', loggedBy: 'david@x.com', callDate: today, month: today.slice(0, 7),
    outcome: 'Reached', note: 'From the app', attendedSunday: true, sundayDate: ymd(daysAgo(1)), attendedWednesday: false, wednesdayDate: '',
    team: 'Workforce', points: 40, syncedToSheet: false, createdAt: new Date(now.getTime() - 60000) };
  store['followUps/app2'] = { guestId: 'G1', worker: 'david@x.com', loggedBy: 'david@x.com', callDate: today, month: today.slice(0, 7),
    outcome: 'No answer', note: '', attendedSunday: false, sundayDate: '', attendedWednesday: false, wednesdayDate: '',
    team: '', points: 5, syncedToSheet: false, createdAt: new Date(now.getTime()) };
  store['followUps/app3'] = { guestId: 'G3', worker: 'worker.a@x.com', loggedBy: 'boss@x.com', callDate: today, month: today.slice(0, 7),
    outcome: 'Reached', note: 'Admin for Worker A', attendedSunday: false, sundayDate: '', attendedWednesday: false, wednesdayDate: '',
    team: '', points: 10, syncedToSheet: false, createdAt: new Date(now.getTime() - 30000) };
  const fbDate = new Date(now.getTime() - 60000);
  Object.assign(store['guests/G1'], { callStatus: 'No answer', membershipStatus: 'Returning', followUpCount: 2, lastFeedback: 'From the app',
    lastFeedbackDate: fbDate, teamJoined: 'Workforce', lastFollowUpId: 'app2' });
  Object.assign(store['guests/G3'], { callStatus: 'Reached', membershipStatus: 'Contacted', followUpCount: 1, lastFeedback: 'Admin for Worker A',
    lastFeedbackDate: fbDate, lastFollowUpId: 'app3' });

  const denied = call({ action: 'syncNow', idToken: 'tokDavid' });
  check('syncNow is admin only', !denied.ok && denied.code === 'FORBIDDEN', denied);

  const r = call({ action: 'syncNow', idToken: 'tokAdmin' });
  check('syncNow ok', r.ok && r.data.followUps === 3 && r.data.guests === 2 && r.data.missingGuests === 0, r);
  check('the result says 3 follow-ups for 2 guests', r.data.followUpGuests === 2, r.data);
  check('the sheet URL comes from the SHEET_URL property, filled once from the spreadsheet, and is shared in meta/sync',
    r.data.sheetUrl === 'https://docs.google.com/spreadsheets/d/TEST/edit' && props.SHEET_URL === r.data.sheetUrl && store['meta/sync'].sheetUrl === r.data.sheetUrl, [r.data.sheetUrl, props.SHEET_URL]);
  const added = fuRows.slice(before.fuCount);
  check('3 follow-ups appended to the Follow-ups tab', added.length === 3 && added.map(x => x[0]).join() === 'app1,app3,app2', added.map(x => x[0]));
  const a3 = added.find(x => x[0] === 'app3');
  check('appended row: guest, worker, logged by, outcome, note', a3[1] === 'G3' && a3[2] === 'worker.a@x.com' && a3[11] === 'boss@x.com' && a3[4] === 'Reached' && a3[5] === 'Admin for Worker A', a3);
  const a1 = added.find(x => x[0] === 'app1');
  const isDate = v => Object.prototype.toString.call(v) === '[object Date]';
  check('appended row: attendance flag, date as a date, team', a1[6] === true && isDate(a1[7]) && ymd(a1[7]) === ymd(daysAgo(1)) && a1[10] === 'Workforce' && isDate(a1[3]), a1);
  check('guest row: Firebase-owned columns written', g[1][15] === 'No answer' && g[1][16] === 'Returning' && g[1][22] === 2 && g[1][23] === 'From the app' && g[1][21] === 'Workforce', g[1]);
  check('guest row: FEEDBACK 1 filled from the first note', g[1][11] === 'From the app', g[1][11]);
  check('guest row: name, phone, service date and ASSIGNED TO untouched',
    [3, 4, 5, 13, 14].every(c => String(g[1][c]) === String(before.g1[c])), [3, 4, 5, 13, 14].map(c => [before.g1[c], g[1][c]]));
  check('follow-ups marked as synced in Firestore', ['app1', 'app2', 'app3'].every(id => store['followUps/' + id].syncedToSheet === true));
  check('meta/sync records the run', store['meta/sync'].running === false && store['meta/sync'].lastSheetSyncAt instanceof Date
    && store['meta/sync'].lastResult.ok === true && store['meta/sync'].lastResult.followUps === 3, store['meta/sync']);
  check('first syncNow sets up the nightly sync, nightly recalc and weekly triggers', JSON.stringify(r.data.triggersAdded) === '["pcuNightlySync","pcuNightlyRecalc","pcuWeeklySync"]'
    && triggers.find(t => t.fn === 'pcuNightlyRecalc').hour === 0 && triggers.find(t => t.fn === 'pcuNightlyRecalc').minute === 35
    && triggers.find(t => t.fn === 'pcuNightlySync').hour === 0 && triggers.find(t => t.fn === 'pcuNightlySync').minute === 5
    && triggers.find(t => t.fn === 'pcuNightlySync').tz === 'Africa/Lagos' && triggers.find(t => t.fn === 'pcuWeeklySync').weekDay === 'MONDAY', triggers);

  const sheetBefore = JSON.stringify(sheets['Form Responses 1'].rows) + JSON.stringify(fuRows);
  const r2 = call({ action: 'syncNow', idToken: 'tokAdmin' });
  check('second sync changes nothing', r2.ok && r2.data.followUps === 0 && r2.data.guests === 0 && r2.data.triggersAdded.length === 0
    && sheetBefore === JSON.stringify(sheets['Form Responses 1'].rows) + JSON.stringify(fuRows), r2);

  // A run that stopped after writing the sheet but before marking Firestore.
  store['followUps/app1'].syncedToSheet = false;
  const r3 = ctx.pcuNightlySync();
  check('a repeat after an interrupted run adds no duplicate rows', r3.followUps === 0 && r3.alreadyInSheet === 1 && fuRows.filter(x => x[0] === 'app1').length === 1, r3);

  // Work saved in the app is never overwritten by the 5-minute job.
  store['guests/G1'].callStatus = 'Busy';
  g[1][13] = 'worker.a@x.com'; // HOD reassigns in the sheet
  ctx.pcuPushPendingGuests();
  check('5-minute job sends the reassignment only, app work stays', store['guests/G1'].assignedTo === 'worker.a@x.com' && store['guests/G1'].callStatus === 'Busy'
    && store['guests/G1'].followUpCount === 2, store['guests/G1']);
  ctx.pcuPushGuest_('G1');
  check('assignment push keeps app work too', store['guests/G1'].callStatus === 'Busy', store['guests/G1']);
  ctx.pcuMigrateRestart();
  ctx.pcuMigrate();
  check('running the migration again keeps app work and app follow-ups', store['guests/G1'].callStatus === 'Busy'
    && store['followUps/app1'].points === 40 && store['followUps/app1'].createdAt.getTime() === now.getTime() - 60000, [store['guests/G1'].callStatus, store['followUps/app1']]);

  // GENDER is a sheet-owned field: the backfill sends it to every guest, app work stays.
  check('gender read as Male, Female or blank', ctx.pcuGender_('female') === 'Female' && ctx.pcuGender_(' M ') === 'Male'
    && ctx.pcuGender_('MALE') === 'Male' && ctx.pcuGender_('') === '' && ctx.pcuGender_('Prefer not to say') === '');
  check('existing docs have the gender field after the migration', store['guests/G2'].gender === '', store['guests/G2']);
  g[1][6] = 'Female';
  g[2][6] = 'male';
  const gb = ctx.pcuBackfillGender();
  check('the backfill sends gender for the changed guests', gb.pending === 2 && store['guests/G1'].gender === 'Female' && store['guests/G2'].gender === 'Male', [gb, store['guests/G1'].gender, store['guests/G2'].gender]);
  check('the backfill keeps app work', store['guests/G1'].callStatus === 'Busy' && store['guests/G1'].followUpCount === 2, store['guests/G1']);
  check('a second backfill has nothing to send', ctx.pcuBackfillGender().pending === 0);

  // Many follow-ups: query pages of 500, commits of at most 500.
  commits.length = 0;
  for (let i = 0; i < 1200; i++) {
    store[`followUps/bulk${String(i).padStart(4, '0')}`] = { guestId: 'G2', worker: 'david@x.com', loggedBy: 'david@x.com', callDate: today, month: today.slice(0, 7),
      outcome: 'Busy', note: '', attendedSunday: false, sundayDate: '', attendedWednesday: false, wednesdayDate: '', team: '', points: 5,
      syncedToSheet: false, createdAt: new Date(now.getTime() + i) };
  }
  const big = ctx.pcuNightlySync();
  check('1200 follow-ups synced in pages and batches of 500', big.followUps === 1200 && commits.every(n => n <= 500)
    && Object.keys(store).filter(k => k.startsWith('followUps/bulk') && store[k].syncedToSheet === true).length === 1200, [big, commits]);
}

// --- Weekly report and the busy lock
{
  const { ctx, sheets, store, call } = setup();
  ctx.pcuMigrate();
  const w1 = ctx.pcuWeeklySync();
  check('weekly sync writes one report row for last week', !!w1.report && sheets['Weekly Report'].rows.length === 2, sheets['Weekly Report'] && sheets['Weekly Report'].rows);
  const w2 = ctx.pcuWeeklySync();
  check('the same week is never written twice', w2.report === '' && sheets['Weekly Report'].rows.length === 2, w2);
  ctx.LockService.getScriptLock = () => ({ tryLock: () => false, releaseLock() {} });
  const busy = call({ action: 'syncNow', idToken: 'tokAdmin' });
  check('a sync already running gives a plain message', !busy.ok && busy.code === 'BUSY' && /already running/.test(busy.error), busy);
  check('meta/sync left as it was by the busy call', store['meta/sync'].running === false, store['meta/sync']);
}

// --- Without the key, syncNow says so
{
  const { call } = setup({ firestore: false });
  const r = call({ action: 'syncNow', idToken: 'tokAdmin' });
  check('no key: syncNow explains it is not set up', !r.ok && /not set up/.test(r.error), r);
}

// --- Web push through FCM HTTP v1
{
  const { ctx, store, call, pushes } = setup();
  ctx.pcuMigrate();
  store['users/david@x.com/tokens/good-token'] = { token: 'good-token', platform: 'web' };
  store['users/david@x.com/tokens/dead-token'] = { token: 'dead-token', platform: 'web' };
  const r = ctx.pcuSendPush_('David@X.com ', { title: 'New guest for you', body: 'Ada Obi. Please call within 3 days.', tag: 'guest-G1' });
  check('push sent to the live device, dead token removed', r.tokens === 2 && r.sent === 1 && r.removed === 1 && !store['users/david@x.com/tokens/dead-token'] && !!store['users/david@x.com/tokens/good-token'], r);
  const m = pushes.find(p => p.message.token === 'good-token').message;
  check('push has title, body, icon, badge and an https link to the app', m.notification.title === 'New guest for you' && m.webpush.notification.icon === 'https://pcu-workflow.web.app/icons/notification-icon-192-v2.png'
    && m.webpush.notification.badge === 'https://pcu-workflow.web.app/icons/notification-badge-96-v2.png' && m.webpush.fcm_options.link === 'https://pcu-workflow.web.app/' && m.data.tag === 'guest-G1', m);
  check('pcuNotify_ is false when a person has no devices (so email is the fallback)', ctx.pcuNotify_('worker.a@x.com', { title: 'x' }) === false);
  check('pcuNotify_ is true when a device got it', ctx.pcuNotify_('david@x.com', { title: 'x' }) === true);
  const items = Object.keys(store).filter(k => k.startsWith('users/worker.a@x.com/notifications/')).map(k => store[k]);
  check('every notice is kept for the bell, even without a device', items.length === 1 && items[0].read === false && items[0].title === 'x'
    && Object.prototype.toString.call(items[0].createdAt) === '[object Date]' && items[0].link === 'https://pcu-workflow.web.app/', items);

  const denied = call({ action: 'pushCheck', idToken: 'tokDavid' });
  check('pushCheck is admin only', !denied.ok && denied.code === 'FORBIDDEN', denied);
  const ok = call({ action: 'pushCheck', idToken: 'tokAdmin' });
  const last = pushes[pushes.length - 1];
  check('pushCheck validates without sending', ok.ok && ok.data.ok === true && last.validate_only === true && last.message.topic === 'pcu-check', [ok, last]);

  // A scheduled sync that fails tells the HOD.
  store['users/boss@x.com/tokens/boss-phone'] = { token: 'boss-phone', platform: 'web' };
  const before = pushes.length;
  ctx.UrlFetchApp.failQueries = true;
  let threw = false;
  try { ctx.pcuNightlySync(); } catch (e) { threw = true; }
  ctx.UrlFetchApp.failQueries = false;
  const sent = pushes.slice(before);
  check('a failed nightly sync pushes a notice to the HOD', threw && sent.some(p => p.message.token === 'boss-phone' && /did not finish/.test(p.message.notification.title))
    && store['meta/sync'].lastResult.ok === false, sent);
}

// --- Nightly leaderboard rebuild (pcuNightlyRecalc)
{
  const { ctx, store } = setup();
  ctx.pcuMigrate();
  const today = ymd(now);
  const month = today.slice(0, 7);
  // An on-time first call with a Sunday (10 + 10) and a later team join (5 + 20) for David,
  // and a save by the admin for their own guest (never ranked).
  Object.assign(store['guests/G1'], { serviceDate: ymd(daysAgo(1)), membershipStatus: 'Returning' });
  store['followUps/r1'] = { guestId: 'G1', worker: 'david@x.com', loggedBy: 'david@x.com', callDate: today, month, outcome: 'Reached',
    attendedSunday: true, sundayDate: today, attendedWednesday: false, team: '', points: 20, syncedToSheet: false, createdAt: new Date(now.getTime() - 5000) };
  store['followUps/r2'] = { guestId: 'G1', worker: 'david@x.com', loggedBy: 'boss@x.com', callDate: today, month, outcome: 'Reached',
    attendedSunday: false, attendedWednesday: false, team: 'Workforce', points: 25, syncedToSheet: false, createdAt: new Date(now.getTime() - 1000) };
  store['guests/GA'] = { name: 'Admin guest', serviceDate: today, month, assignedTo: 'boss@x.com', membershipStatus: 'New guest' };
  store['followUps/r3'] = { guestId: 'GA', worker: 'boss@x.com', loggedBy: 'boss@x.com', callDate: today, month, outcome: 'Reached', points: 10, createdAt: new Date(now.getTime()) };
  // Drift left by the app: wrong points for David, an entry for the admin.
  store[`rankings/${month}/entries/david@x.com`] = { email: 'david@x.com', name: 'David Olanite', points: 999, lastFollowUpId: 'r2' };
  store[`rankings/${month}/entries/boss@x.com`] = { email: 'boss@x.com', name: 'Boss', points: 10 };

  const r = ctx.pcuNightlyRecalc();
  const david = store[`rankings/${month}/entries/david@x.com`];
  const fromApi = 10 + 10 + 5 + 20; // first call on time, Sunday, then a follow-up with the first team join
  check('recalc corrects drifted points with the API rules', david.points === fromApi && david.lastFollowUpId === 'r2' && r.corrected >= 1, [david, r]);
  check('recalc removes entries for admins and gives every active worker an entry', !store[`rankings/${month}/entries/boss@x.com`]
    && store[`rankings/${month}/entries/worker.a@x.com`].points === 0 && !store[`rankings/${month}/entries/worker.c@x.com`], Object.keys(store).filter(k => k.startsWith('rankings/')));
  check('recalc writes only fields the rules allow', Object.keys(store[`rankings/${month}/entries/worker.a@x.com`]).sort().join() === 'email,name,points,updatedAt');
  const snapshot = JSON.stringify(Object.keys(store).filter(k => k.startsWith('rankings/')).map(k => [k, store[k].points]));
  const r2 = ctx.pcuNightlyRecalc();
  check('a second run changes nothing', r2.corrected === 0 && r2.removed === 0 && r2.written === 0
    && snapshot === JSON.stringify(Object.keys(store).filter(k => k.startsWith('rankings/')).map(k => [k, store[k].points])), r2);
  check('previous month is rebuilt too', r.months.length === 2 && r.months[0] === month, r.months);

  // An offline save on 31 Oct that reached the server at 00:30 on 1 Nov (Lagos).
  const fixedNow = new Date('2026-11-15T10:00:00Z');
  const pts = m => (store['rankings/' + m + '/entries/david@x.com'] || {}).points || 0;
  ctx.pcuRecalcRankings_(fixedNow);
  const octBefore = pts('2026-10'), novBefore = pts('2026-11');
  store['guests/GX'] = { name: 'Late night', serviceDate: '2026-10-20', month: '2026-10', assignedTo: 'david@x.com', membershipStatus: 'Contacted' };
  store['followUps/late'] = { guestId: 'GX', worker: 'david@x.com', loggedBy: 'david@x.com', callDate: '2026-10-31', month: '2026-10', outcome: 'Reached',
    points: 5, createdAt: new Date('2026-10-31T23:30:00Z') };
  ctx.pcuRecalcRankings_(fixedNow);
  check('an offline save counts in the month of the call, not when the server got it', pts('2026-10') === octBefore + 5 && pts('2026-11') === novBefore, [octBefore, pts('2026-10'), novBefore, pts('2026-11')]);
  const moment = ctx.pcuCallMoment_(store['followUps/late']);
  // Dates made inside the script's own context, as Firestore.gs decodes them.
  const sameDay = vm.runInContext("new Date('2026-10-31T09:15:00Z')", ctx);
  check('the sheet gets the call day for a late sync, and the exact time for a same-day one', ymd(moment) === '2026-10-31'
    && ctx.pcuCallMoment_({ callDate: '2026-10-31', createdAt: sameDay }) === sameDay, [ymd(moment)]);
}

// --- Health report (admin only, read only)
{
  const { ctx, store, call } = setup();
  ctx.pcuMigrate();
  delete store['users/worker.a@x.com'];
  delete store['guests/G2'];
  const denied = call({ action: 'health', idToken: 'tokDavid' });
  check('health is admin only', !denied.ok && denied.code === 'FORBIDDEN', denied);
  const r = call({ action: 'health', idToken: 'tokAdmin' });
  check('health counts assigned guests in the sheet and in Firestore', r.ok && r.data.sheet.assigned === 5 && r.data.sheet.assignedByWorker['david@x.com'] === 4 && r.data.firestore.assigned === 3, r.data && r.data.sheet);
  check('health lists the gaps', r.data.gaps.assignedMissingInFirestore.join() === 'G2,G4' && r.data.gaps.workersMissingInUsers.join() === 'worker.a@x.com'
    && r.data.sheet.followUpsWithoutGuestInFirestore.join() === 'G2,G2', r.data.gaps);
}

// --- Nudge (admin only, at most one per worker per 24 hours)
{
  const { ctx, store, call, pushes, mails } = setup();
  ctx.pcuSyncUsers_();
  const nudges = () => Object.keys(store).filter(k => k.startsWith('nudges/')).map(k => store[k]);
  const bell = email => Object.keys(store).filter(k => k.startsWith('users/' + email + '/notifications/')).map(k => store[k]);

  const denied = call({ action: 'nudge', idToken: 'tokDavid', workerEmail: 'worker.a@x.com', outstanding: 4 });
  check('nudge is admin only', !denied.ok && denied.code === 'FORBIDDEN' && nudges().length === 0, denied);
  check('only an active worker can be nudged', call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'worker.c@x.com', outstanding: 2 }).code === 'VALIDATION'
    && call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'boss@x.com', outstanding: 2 }).code === 'VALIDATION'
    && call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'nobody@x.com', outstanding: 2 }).code === 'VALIDATION');
  check('the number of guests waiting is required', call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'worker.a@x.com', outstanding: 0 }).code === 'VALIDATION'
    && call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'worker.a@x.com', outstanding: 2.5 }).code === 'VALIDATION');
  check('the personal line is one short line', call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'worker.a@x.com', outstanding: 2, personalLine: 'x'.repeat(201) }).code === 'VALIDATION');

  // Push blocked (no FCM role yet): the in-app notice and the email still go out.
  store['users/worker.a@x.com/tokens/phone'] = { token: 'phone', platform: 'web' };
  ctx.UrlFetchApp.failPush = true;
  const r = call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: ' Worker.A@x.com ', outstanding: 4, personalLine: '  Proud of\n you!  ' });
  ctx.UrlFetchApp.failPush = false;
  const n = nudges();
  check('a nudge is sent and logged', r.ok && n.length === 1 && n[0].worker === 'worker.a@x.com' && n[0].sentBy === 'boss@x.com' && n[0].outstanding === 4
    && n[0].personalLine === 'Proud of you!' && Object.prototype.toString.call(n[0].sentAt) === '[object Date]', [r, n]);
  check('the default wording', n[0].title === 'A gentle nudge from your HOD'
    && n[0].body === 'You have 4 guests waiting for a call. A quick call today makes a big difference. We are cheering you on.\nProud of you!', n[0]);
  const items = bell('worker.a@x.com');
  check('in-app notice without the push role', items.length === 1 && items[0].title === 'A gentle nudge from your HOD' && items[0].tag === 'nudge' && /cheering you on/.test(items[0].body), items);
  check('email without the push role', mails.length === 1 && mails[0].to === 'worker.a@x.com' && mails[0].subject === 'A gentle nudge from your HOD'
    && /4 guests waiting/.test(mails[0].body) && /Proud of you!/.test(mails[0].body), mails);
  check('the result and the log say what went out', r.data.inApp === true && r.data.emailSent === true && r.data.pushSent === 0
    && n[0].emailSent === true && n[0].pushSent === 0 && /403|PERMISSION/.test(n[0].pushError), [r.data, n[0]]);

  const again = call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'worker.a@x.com', outstanding: 4 });
  check('at most one nudge per worker per 24 hours', !again.ok && again.code === 'TOO_SOON' && /nudge again at/.test(again.error) && nudges().length === 1 && mails.length === 1, again);

  // A day later it is allowed again, and a registered device gets the push.
  store[Object.keys(store).find(k => k.startsWith('nudges/'))].sentAt = new Date(Date.now() - 24 * 60 * 60 * 1000 - 1000);
  const before = pushes.length;
  const later = call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'worker.a@x.com', outstanding: 1 });
  check('after 24 hours a new nudge goes out, with the push when allowed', later.ok && later.data.pushSent === 1 && pushes.length === before + 1
    && nudges().length === 2, later);
  check('one guest reads "1 guest"', nudges().some(x => x.body === 'You have 1 guest waiting for a call. A quick call today makes a big difference. We are cheering you on.'));
  check('another worker has their own 24 hours', call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'david@x.com', outstanding: 2 }).ok);

  // Email trouble never stops the in-app notice.
  ctx.MailApp.fail = true;
  store[Object.keys(store).find(k => k.startsWith('nudges/') && store[k].worker === 'david@x.com')].sentAt = new Date(0);
  const noMail = call({ action: 'nudge', idToken: 'tokAdmin', workerEmail: 'david@x.com', outstanding: 2 });
  ctx.MailApp.fail = false;
  check('a failed email is reported, the notice still saved', noMail.ok && noMail.data.emailSent === false && bell('david@x.com').length === 2, noMail);
}

// --- Auto-assign is always on and repairs itself
{
  const { ctx, triggers } = setup();
  const names = () => triggers.map(t => t.fn).sort().join();
  check('every trigger is installed when none exist', ctx.ensureAssignTriggers_().sort().join() === 'assignBackup,assignOnSubmit,dailyReminder'
    && triggers.find(t => t.fn === 'assignOnSubmit').formSubmit && triggers.find(t => t.fn === 'assignBackup').minutes === 5, triggers);
  check('a second check adds nothing', ctx.ensureAssignTriggers_().length === 0 && names() === 'assignBackup,assignOnSubmit,dailyReminder');
  triggers.splice(triggers.findIndex(t => t.fn === 'assignOnSubmit'), 1);
  ctx.pcuPushPendingGuests();
  check('the 5-minute job puts back a deleted form trigger', names().split(',').includes('assignOnSubmit'), names());
  triggers.splice(triggers.findIndex(t => t.fn === 'assignBackup'), 1);
  ctx.dailyReminder();
  check('the 6pm reminder puts back a deleted backup trigger', names().split(',').includes('assignBackup'), names());
  const src = fs.readFileSync(path.join(__dirname, '..', 'pcu_auto_assign.gs'), 'utf8');
  check('the PCU menu has no Switch on or Switch off items', !/addItem\('Switch (on|off)/.test(src) && !/notificationsO(n|ff)\b/.test(src));
}

// --- The 5-minute backup assigns guests the form trigger missed
{
  const { ctx, sheets, store, mails } = setup();
  ctx.pcuSetupSyncColumns();
  ctx.pcuSyncUsers_();
  const rows = sheets['Form Responses 1'].rows;
  rows.push(guestRow('', 'New Visitor One', daysAgo(1), '', 8000000011));
  rows.push(guestRow('', 'New Visitor Two', daysAgo(2), '', 8000000012));
  rows.push(guestRow('', 'New Visitor Three', daysAgo(0), '', 8000000013));
  rows.push(guestRow('', 'Before Go Live', new Date('2026-10-20T10:00:00Z'), '', 8000000014));
  rows.push(guestRow('', '', daysAgo(1), '', '')); // an empty row
  const before = mails.length;
  const r = ctx.assignBackup();
  const byName = n => rows.find(x => x[4] === n);
  const assignedTo = ['New Visitor One', 'New Visitor Two', 'New Visitor Three'].map(n => byName(n)[13]);
  check('the backup assigns guests since go-live that have no worker', r.assigned === 3 && assignedTo.every(e => e === 'david@x.com' || e === 'worker.a@x.com'), [r, assignedTo]);
  check('it uses the rotation, never an admin and never an inactive worker', !assignedTo.includes('boss@x.com') && !assignedTo.includes('worker.c@x.com')
    && new Set(assignedTo).size === 2, assignedTo);
  check('guests before go-live and empty rows are left alone', byName('Before Go Live')[13] === '' && rows[rows.length - 1][13] === '');
  const ids = ['New Visitor One', 'New Visitor Two', 'New Visitor Three'].map(n => byName(n)[20]);
  check('each gets a GUEST ID and reaches Firestore with its worker', ids.every(id => /^G-[0-9A-F]{8}$/.test(id) && store['guests/' + id] && store['guests/' + id].assignedTo === byName(store['guests/' + id].name)[13]), ids);
  const notices = Object.keys(store).filter(k => k.startsWith('users/boss@x.com/notifications/')).map(k => store[k]);
  check('the admin gets one summary for the run, in the app and by email', notices.length === 1 && notices[0].title === 'Guests assigned'
    && /^3 guests assigned: (David 2, Worker A 1|David 1, Worker A 2|Worker A 2, David 1|Worker A 1, David 2)$/.test(notices[0].body)
    && mails.slice(before).filter(m => m.to === 'boss@x.com').length === 1, [notices, mails.slice(before).map(m => [m.to, m.subject])]);
  const again = ctx.assignBackup();
  check('a second run assigns nothing and sends no summary', again.assigned === 0
    && Object.keys(store).filter(k => k.startsWith('users/boss@x.com/notifications/')).length === 1, again);
  check('summary wording', ctx.assignSummaryText_(['david@x.com', 'david@x.com', 'worker.a@x.com']) === '3 guests assigned: David 2, Worker A 1'
    && ctx.assignSummaryText_(['david@x.com']) === '1 guest assigned: David 1' && ctx.assignSummaryText_([]) === '');
}

// --- Every assignment path sends one summary per run
{
  const { ctx, sheets, store } = setup();
  const notices = () => Object.keys(store).filter(k => k.startsWith('users/boss@x.com/notifications/')).map(k => store[k].body);
  ctx.testAddGuests();
  check('the menu test path sends one summary for its run', notices().length === 1 && /^6 guests assigned: /.test(notices()[0]), notices());
  const rows = sheets['Form Responses 1'].rows;
  sheets['Form Responses 1'].name = 'Form Responses 1';
  rows.push(guestRow('', 'Form Guest', daysAgo(0), '', 8000000021));
  ctx.assignOnSubmit({ range: { getSheet: () => sheets['Form Responses 1'], getRow: () => rows.length } });
  check('a form entry sends a one-guest summary', notices().length === 2 && notices().some(b => /^1 guest assigned: /.test(b)), notices());
  ctx.assignOnSubmit({ range: { getSheet: () => sheets['Form Responses 1'], getRow: () => rows.length } });
  check('a form entry that was already assigned sends nothing', notices().length === 2, notices());
}

// --- HOD "Assign guests" (admin only, safe to tap twice)
{
  const { ctx, sheets, call, store } = setup();
  ctx.pcuSetupSyncColumns();
  const rows = sheets['Form Responses 1'].rows;
  rows.push(guestRow('', 'Range One', daysAgo(1), '', 8000000031));
  rows.push(guestRow('', 'Range Two', daysAgo(1), '', 8000000032));
  rows.push(guestRow('', 'Range Old', daysAgo(40), '', 8000000033));
  const today = ymd(now);
  const from = ymd(daysAgo(3));
  const denied = call({ action: 'assignRange', idToken: 'tokDavid', from, to: today });
  check('Assign guests is admin only', !denied.ok && denied.code === 'FORBIDDEN' && call({ action: 'assignPreview', idToken: 'tokDavid', from, to: today }).code === 'FORBIDDEN');
  check('dates are checked', call({ action: 'assignPreview', idToken: 'tokAdmin', from: today, to: from }).code === 'VALIDATION'
    && call({ action: 'assignPreview', idToken: 'tokAdmin', from: 'soon', to: today }).code === 'VALIDATION');
  const preview = call({ action: 'assignPreview', idToken: 'tokAdmin', from, to: today });
  check('the preview counts guests with no worker in the range', preview.ok && preview.data.unassigned === 2 && preview.data.workers === 2, preview);
  const r = call({ action: 'assignRange', idToken: 'tokAdmin', from, to: today });
  check('preview count equals the result count', r.ok && r.data.assigned === preview.data.unassigned && /^2 guests assigned: /.test(r.data.summary), r);
  check('never to an admin', !['Range One', 'Range Two'].some(n => rows.find(x => x[4] === n)[13] === 'boss@x.com'));
  check('the old guest outside the range stays unassigned', rows.find(x => x[4] === 'Range Old')[13] === '');
  const twice = call({ action: 'assignRange', idToken: 'tokAdmin', from, to: today });
  check('a second tap assigns nothing', twice.ok && twice.data.assigned === 0, twice);
}

// --- Admin-only TEST guest through the real assignment path, and clean-up
{
  const { ctx, sheets, store, call } = setup();
  ctx.pcuSetupSyncColumns();
  check('adding a test guest is admin only', call({ action: 'addTestGuest', idToken: 'tokDavid' }).code === 'FORBIDDEN');
  const r = call({ action: 'addTestGuest', idToken: 'tokAdmin' });
  const rows = sheets['Form Responses 1'].rows;
  const row = rows.find(x => x[4] === r.data.name);
  check('a TEST guest, service date today, assigned in rotation with a GUEST ID', r.ok && /^TEST Guest /.test(r.data.name) && row
    && ymd(row[3]) === ymd(now) && ['david@x.com', 'worker.a@x.com'].includes(r.data.assignedTo) && /^G-[0-9A-F]{8}$/.test(r.data.guestId), r);
  check('it reaches Firestore with its worker', store['guests/' + r.data.guestId] && store['guests/' + r.data.guestId].assignedTo === r.data.assignedTo);
  check('the admins get the one-guest summary', Object.keys(store).some(k => k.startsWith('users/boss@x.com/notifications/') && /^1 guest assigned: /.test(store[k].body)));
  store['followUps/testfu'] = { guestId: r.data.guestId, worker: r.data.assignedTo, month: '2026-11', syncedToSheet: true };
  sheets['Follow-ups'].rows.push(['testfu', r.data.guestId, r.data.assignedTo, now, 'Reached', '', '', '', '', '', '', '']);
  const removed = ctx.removeTestGuestsNow_();
  check('Remove test guests clears the sheet row, the Firestore guest, its follow-up and its Follow-ups row', removed === 1
    && !rows.some(x => x[4] === r.data.name) && !store['guests/' + r.data.guestId] && !store['followUps/testfu']
    && !sheets['Follow-ups'].rows.some(x => x[0] === 'testfu'), [removed]);
  check('real guests stay', !!store['guests/G1'] || rows.some(x => x[20] === 'G1'));
}

// --- Workers added in the sheet reach Firestore users within 5 minutes
{
  const { ctx, sheets, store, call, commits, props } = setup();
  ctx.pcuPushPendingGuests();
  check('the 5-minute job copies the Workers tab to users', store['users/david@x.com'] && store['users/david@x.com'].role === 'worker');
  sheets.Workers.rows.push(['W006', 'Roi Deals', ' RoiDealsInc@gmail.com ', '', 'Worker', 'Yes']);
  ctx.pcuTable_('Workers', true);
  ctx.pcuPushPendingGuests();
  const u = store['users/roidealsinc@gmail.com'];
  check('a worker typed into the Workers tab arrives with a clean email, the right role and active flag', u && u.role === 'worker' && u.active === true && u.id === 'W006' && u.email === 'roidealsinc@gmail.com', u);
  check('nothing is written again while the Workers tab is unchanged', props.USERS_KEY && ctx.pcuSyncUsersIfChanged_() === 0);
  sheets.Workers.rows[sheets.Workers.rows.length - 1][5] = 'No';
  ctx.pcuTable_('Workers', true);
  ctx.pcuPushPendingGuests();
  check('switching a worker off in the sheet reaches the app', store['users/roidealsinc@gmail.com'].active === false);
  const added = call({ action: 'saveWorker', idToken: 'tokAdmin', name: 'App Added', email: 'app.added@x.com', phone: '0800', role: 'Worker' });
  const again = call({ action: 'saveWorker', idToken: 'tokAdmin', name: 'App Added', email: 'App.Added@x.com ', phone: '0800', role: 'Worker' });
  check('a worker added in the app is one row, and adding the same email again is refused', added.ok && !again.ok && again.code === 'VALIDATION'
    && sheets.Workers.rows.filter(r => String(r[2]).trim().toLowerCase() === 'app.added@x.com').length === 1 && store['users/app.added@x.com'], [added, again]);
}

// --- Redistribute (admin only, preview equals result, safe twice)
{
  const { ctx, sheets, store, call } = setup();
  sheets.Workers.rows.push(['W007', 'Ada Two', 'ada2@x.com', '0803 111 2222', 'Worker', 'Yes']);
  const rows = sheets['Form Responses 1'].rows;
  rows.push(guestRow('R1', 'Waiting Four', daysAgo(4), 'david@x.com', 8000000041));
  rows.push(guestRow('R2', 'Waiting Five', daysAgo(5), 'david@x.com', 8000000042));
  rows.push(guestRow('R3', 'Waiting Four Too', daysAgo(4), 'david@x.com', 8000000043));
  ctx.pcuSetupSyncColumns();
  ctx.pcuMigrate();
  ctx.pcuTable_('Workers', true);
  const base = { action: 'redistribute', fromEmail: 'david@x.com' };
  check('redistribute is admin only', call({ ...base, idToken: 'tokDavid', preview: true }).code === 'FORBIDDEN');
  const pv = call({ ...base, idToken: 'tokAdmin', mode: 'outstanding', preview: true });
  check('outstanding: never called, since go-live, more than 3 days; oldest first, spread evenly', pv.ok && pv.data.guests === 3
    && pv.data.candidates.map(c => c.id).join() === 'R2,R1,R3' && pv.data.text === '3 guests: Ada 2, Worker A 1', pv.data);
  check('never to an admin, an inactive worker or the source', pv.data.plan.every(x => !['boss@x.com', 'worker.c@x.com', 'david@x.com'].includes(x.email)), pv.data.plan);
  const unc = call({ ...base, idToken: 'tokAdmin', mode: 'uncalled', preview: true });
  check('all uncalled includes newer and older guests, never a called one', unc.data.guests > 3 && !unc.data.candidates.some(c => c.id === 'G2'), unc.data.candidates);
  const fuBefore = JSON.stringify(Object.keys(store).filter(k => k.startsWith('followUps/')).map(k => [k, store[k].worker]));
  const done = call({ ...base, idToken: 'tokAdmin', mode: 'outstanding' });
  check('preview counts equal the result counts', done.ok && done.data.moved === pv.data.guests && done.data.text === pv.data.text, done.data);
  const to = id => rows.find(x => x[20] === id)[13];
  check('the sheet owns assignment: ASSIGNED TO changed', to('R2') === 'ada2@x.com' && to('R1') === 'worker.a@x.com' && to('R3') === 'ada2@x.com', [to('R2'), to('R1'), to('R3')]);
  check('Firestore follows the sheet', store['guests/R2'].assignedTo === 'ada2@x.com' && store['guests/R1'].assignedTo === 'worker.a@x.com');
  const tab = sheets.Reassignments.rows;
  check('a Reassignments tab row per guest, with who and when', tab.length === 4 && tab[1][1] === 'R2' && tab[1][3] === 'david@x.com' && tab[1][4] === 'ada2@x.com' && tab[1][5] === 'boss@x.com' && tab[1][6] === 'Outstanding', tab);
  const logs = Object.keys(store).filter(k => k.startsWith('reassignments/')).map(k => store[k]);
  check('and a reassignments document per guest', logs.length === 3 && logs.every(l => l.from === 'david@x.com' && l.by === 'boss@x.com' && l.mode === 'outstanding'));
  check('follow-up history and points stay with whoever made the calls', JSON.stringify(Object.keys(store).filter(k => k.startsWith('followUps/')).map(k => [k, store[k].worker])) === fuBefore);
  const bell = e => Object.keys(store).filter(k => k.startsWith('users/' + e + '/notifications/')).map(k => store[k]);
  check('the new workers and the previous worker are told', bell('ada2@x.com').some(n => /^2 guests were passed to you from David/.test(n.body))
    && bell('worker.a@x.com').some(n => /^1 guest was passed to you/.test(n.body)) && bell('david@x.com').some(n => /^3 of your guests were passed/.test(n.body)));
  const twice = call({ ...base, idToken: 'tokAdmin', mode: 'outstanding' });
  check('a second tap moves nothing', twice.ok && twice.data.moved === 0 && sheets.Reassignments.rows.length === 4, twice.data);
  const sel = call({ ...base, idToken: 'tokAdmin', mode: 'selected', guestIds: ['G1', 'R3'], toEmails: ['worker.a@x.com'] });
  check('selected: only the chosen guests still with the source, to the chosen worker', sel.ok && sel.data.moved === 1 && to('G1') === 'worker.a@x.com' && to('R3') === 'ada2@x.com', sel.data);
  check('an admin cannot be the only recipient', call({ ...base, idToken: 'tokAdmin', mode: 'uncalled', toEmails: ['boss@x.com'], preview: true }).code === 'VALIDATION');
}

console.log(fails ? `\n${fails} FAILED` : '\nALL PASSED');
process.exitCode = fails ? 1 : 0;
