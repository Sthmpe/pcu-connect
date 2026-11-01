/**
 * PCU guest assignment
 * - Every new form entry goes to the next ACTIVE worker on the Workers tab (round robin).
 * - Everything is run from the "PCU" menu at the top of the sheet.
 * Paste into Extensions > Apps Script once, save, then reload the sheet.
 */

const RESPONSES_SHEET = 'Form Responses 1';
const WORKERS_SHEET = 'Workers';
const HEADER_ROW = 1;          // headers must be in row 1 of both tabs
const TZ = 'Africa/Lagos';
const TEST_PREFIX = 'TEST Guest';
const CALLS_SHEET = 'Call Log';            // the app's Call Log tab (fallback: Follow-ups)
const GO_LIVE = '2026-10-28';              // only guests assigned from this day are chased
const REMINDER_HOUR = 18;                  // 6pm daily reminder
const APP_LINK = 'https://pcu-workflow.web.app';  // the PCU Connect web app (also the link in pushes)

/* ------------------------------------------------------------------ */
/* Menu                                                                */
/* ------------------------------------------------------------------ */

function onOpen() {
  const ui = SpreadsheetApp.getUi();
  ui.createMenu('PCU')
    .addItem('Assign selected rows', 'assignSelectedRows')
    .addItem("Assign today's unassigned guests", 'assignTodaysUnassigned')
    .addItem('Who is next?', 'showNextWorker')
    .addItem('Assignment summary', 'showSummary')
    .addSeparator()
    .addSubMenu(ui.createMenu('Workers')
      .addItem('Add worker', 'addWorker')
      .addItem('Remove worker (stop new names)', 'deactivateWorker')
      .addItem('Bring worker back', 'reactivateWorker')
      .addItem('List workers', 'listWorkers'))
    // Auto-assign and notifications are always on and repair themselves
    // (ensureAssignTriggers_), so there is nothing to switch.
    .addSubMenu(ui.createMenu('Auto-assign')
      .addItem('Check status', 'triggerStatus')
      .addItem('Restart rotation from first worker', 'resetRotation'))
    .addSubMenu(ui.createMenu('Notifications')
      .addItem('Check status', 'notificationsStatus')
      .addItem("Send today's reminder now", 'dailyReminder'))
    .addSubMenu(ui.createMenu('Testing (test copy only)')
      .addItem('Add test guests', 'testAddGuests')
      .addItem('Remove test guests', 'removeTestGuests'))
    .addToUi();
}

/* ------------------------------------------------------------------ */
/* Automatic assignment                                                */
/* ------------------------------------------------------------------ */

/** Runs on every form submission (auto-assign is always on). */
function assignOnSubmit(e) {
  const run = [];
  withLock_(() => {
    const sheet = e.range.getSheet();
    if (sheet.getName() !== RESPONSES_SHEET) return;
    const worker = assignRow_(sheet, e.range.getRow());
    if (worker) run.push(worker);
  });
  notifyAssignSummary_(run);
}

/**
 * Every 5 minutes (backup for the form trigger): assigns each guest on
 * Form Responses 1 whose service date is on or after GO_LIVE and who has no
 * ASSIGNED TO, through the same rotation, lock and assignRow_ path.
 */
function assignBackup() {
  ensureAssignTriggersQuietly_();
  return assignUnassigned_({ from: GO_LIVE });
}

/** 'yyyy-MM-dd' of a row's SERVICE DATE, else its TIMESTAMP (as the app reads it); '' when neither. */
function rowServiceDay_(row, h) {
  for (const name of ['SERVICE DATE', 'TIMESTAMP']) {
    const v = row[h.indexOf(name)];
    if (v instanceof Date && !isNaN(v.getTime())) return dayKey_(v);
    if (typeof pcuDate_ === 'function') {
      const d = pcuDate_(v);
      if (d) return dayKey_(d);
    }
  }
  return '';
}

/**
 * Assigns every guest with a name, no worker and a service day in
 * [opts.from, opts.to] (inclusive; to defaults to no limit), under the
 * shared lock, re-reading the sheet inside it so a second run assigns
 * nothing twice. Sends the new guests to Firestore in one pass and one
 * summary to the admins. Returns { assigned, byWorker, summary }.
 */
function assignUnassigned_(opts) {
  const run = [];
  withLock_(() => {
    const sheet = responses_();
    const h = headers_(sheet);
    const nameCol = h.indexOf('FULL NAME');
    const assignedCol = h.indexOf('ASSIGNED TO');
    const data = sheet.getDataRange().getValues();
    for (let i = HEADER_ROW; i < data.length; i++) {
      if (!String(data[i][nameCol]).trim() || String(data[i][assignedCol]).trim()) continue;
      const day = rowServiceDay_(data[i], h);
      if (!day || day < opts.from || (opts.to && day > opts.to)) continue;
      const worker = assignRow_(sheet, i + 1, { push: false });
      if (worker) run.push({ worker: worker, row: i + 1 });
    }
    if (run.length && typeof pcuPushGuestsQuietly_ === 'function') {
      SpreadsheetApp.flush();
      const idCol = h.indexOf('GUEST ID') + 1;
      pcuPushGuestsQuietly_(run.map(x => String(sheet.getRange(x.row, idCol).getValue()).trim()));
    }
  });
  const emails = run.map(x => x.worker);
  notifyAssignSummary_(emails);
  return { assigned: emails.length, byWorker: countByWorker_(emails), summary: assignSummaryText_(emails) };
}

/** Gives one row to the next active worker. Returns the email, or '' if nothing was done.
 *  opts.push false: the caller sends the guest to Firestore (bulk runs). */
function assignRow_(sheet, row, opts) {
  const h = headers_(sheet);
  const assignedCol = h.indexOf('ASSIGNED TO') + 1;
  const dateCol = h.indexOf('ASSIGNED DATE') + 1;
  const idCol = h.indexOf('GUEST ID') + 1;
  const statusCol = h.indexOf('MEMBERSHIP STATUS') + 1;
  if (!assignedCol) throw new Error('No "ASSIGNED TO" header found in row ' + HEADER_ROW);
  if (row <= HEADER_ROW) return '';

  // Every guest gets a permanent ID, even if no worker is available yet.
  // With Firestore.gs present the ID is stable (timestamp plus phone), so a
  // re-run can never create a second document for the same guest.
  if (idCol && !sheet.getRange(row, idCol).getValue()) {
    const tsCol = h.indexOf('TIMESTAMP') + 1;
    const phoneCol = h.indexOf('PHONE NUMBER') + 1;
    const id = typeof pcuStableGuestId_ === 'function' && tsCol && phoneCol
      ? pcuStableGuestId_(sheet.getRange(row, tsCol).getValue(), sheet.getRange(row, phoneCol).getValue())
      : 'G-' + Utilities.getUuid().slice(0, 8).toUpperCase();
    sheet.getRange(row, idCol).setValue(id);
  }

  if (sheet.getRange(row, assignedCol).getValue()) return ''; // already has a worker

  const workers = activeWorkers_();
  if (workers.length === 0) return '';

  const props = PropertiesService.getScriptProperties();
  const next = Number(props.getProperty('NEXT_INDEX') || 0) % workers.length;
  const worker = workers[next].email;

  sheet.getRange(row, assignedCol).setValue(worker);
  if (dateCol) sheet.getRange(row, dateCol).setValue(new Date());
  if (statusCol && !sheet.getRange(row, statusCol).getValue()) sheet.getRange(row, statusCol).setValue('New guest');
  props.setProperty('NEXT_INDEX', String((next + 1) % workers.length));
  notifyNewGuest_(workers[next], sheet, row, h);
  // Send the new guest to Firestore straight away (no-op until it is set up).
  if (idCol && typeof pcuPushGuestQuietly_ === 'function' && !(opts && opts.push === false)) {
    SpreadsheetApp.flush();
    pcuPushGuestQuietly_(String(sheet.getRange(row, idCol).getValue()).trim());
  }
  return worker;
}

/* ------------------------------------------------------------------ */
/* Admin summary: one per run that assigned guests                     */
/* ------------------------------------------------------------------ */

/** { email: count } in first-assigned order. */
function countByWorker_(emails) {
  const out = {};
  emails.forEach(e => { out[e] = (out[e] || 0) + 1; });
  return out;
}

/**
 * "5 guests assigned: David 2, Worker A 1, Worker B 1". A worker is named by
 * first name; test accounts ("TEST Worker A") by their name without "TEST";
 * full names when two in the run share a first name.
 */
function assignSummaryText_(emails) {
  if (!emails.length) return '';
  const counts = countByWorker_(emails);
  const full = {};
  const short = {};
  allWorkers_().forEach(w => {
    const name = String(w.name || w.email).trim();
    const test = /^TEST\s+/i.test(name);
    full[w.email] = name.replace(/^TEST\s+/i, '');
    short[w.email] = test ? full[w.email] : full[w.email].split(/\s+/)[0];
  });
  const first = Object.keys(counts).map(e => short[e] || e);
  const clash = first.some((f, i) => first.indexOf(f) !== i);
  const parts = Object.keys(counts).map((e, i) => (clash ? full[e] || e : first[i]) + ' ' + counts[e]);
  const n = emails.length;
  return n + (n === 1 ? ' guest' : ' guests') + ' assigned: ' + parts.join(', ');
}

/**
 * Tells every active admin once per run: an in-app notice, a push if their
 * device is registered, and an email. Nothing when nothing was assigned.
 */
function notifyAssignSummary_(emails) {
  if (!emails.length) return;
  const text = assignSummaryText_(emails);
  allWorkers_()
    .filter(w => w.active && /^(admin|hod)$/i.test(String(w.role).trim()))
    .forEach(admin => {
      try {
        if (typeof pcuNotify_ === 'function') pcuNotify_(admin.email, { title: 'Guests assigned', body: text, tag: 'assigned' });
      } catch (err) { console.warn('Summary notice failed: ' + err); }
      if (!realEmail_(admin.email)) return;
      try {
        MailApp.sendEmail({ to: admin.email, subject: text, htmlBody: emailShell_('Guests assigned', '<p>' + text + '.</p>') });
      } catch (err) { console.warn('Summary email failed: ' + err); }
    });
}

/* ------------------------------------------------------------------ */
/* Notifications (email)                                               */
/* ------------------------------------------------------------------ */

function notificationsStatus() {
  ensureAssignTriggersQuietly_();
  alert_('Notifications are always ON: a push (or an email when the phone has no push) for each new guest, ' +
         'and the 6pm reminder.\nEmails left today (Google limit): ' + MailApp.getRemainingDailyQuota());
}

/** Notifications are always on; NOTIFY=OFF is only honoured as an emergency stop set by hand. */
function notifyOn_() { return PropertiesService.getScriptProperties().getProperty('NOTIFY') !== 'OFF'; }

/** Skips fake/test addresses so test guests don't bounce. */
function realEmail_(email) { return /@/.test(email) && !/@example\.(com|org)$/i.test(email); }

/**
 * Tells the worker about a new guest: a push to their phone first (when they
 * turned notifications on in the app), the email only as the fallback.
 */
function notifyNewGuest_(worker, sheet, row, h) {
  let v;
  try { v = sheet.getRange(row, 1, 1, h.length).getValues()[0]; } catch (err) { return; }
  const get = n => (h.indexOf(n) >= 0 ? String(v[h.indexOf(n)]).trim() : '');
  const name = get('FULL NAME') || 'A new guest';
  if (typeof pcuNotify_ === 'function' &&
      pcuNotify_(worker.email, { title: 'New guest for you', body: name + '. Please call within 3 days.', tag: 'guest-' + get('GUEST ID') })) {
    return;
  }
  if (!notifyOn_() || !realEmail_(worker.email)) return;
  try {
    const phone = get('PHONE NUMBER');
    const digits = phone.replace(/\D/g, '').slice(-10);
    const wa = digits ? 'https://wa.me/234' + digits : '';
    MailApp.sendEmail({
      to: worker.email,
      subject: 'New guest for you: ' + name,
      htmlBody: emailShell_('You have a new guest',
        '<p>Hi ' + (worker.name || 'there') + ',</p>' +
        '<p><b>' + name + '</b> has just been given to you. Please call within 3 days.</p>' +
        (phone ? '<p>Phone: <a href="tel:' + phone + '">' + phone + '</a>' +
                 (wa ? ' &nbsp;|&nbsp; <a href="' + wa + '">WhatsApp</a>' : '') + '</p>' : '') +
        '<p>After the call, log it in the app so it counts for you.</p>')
    });
  } catch (err) { console.log('New-guest email failed: ' + err); }
}

/** Runs every day at 6pm: emails each active worker their guests not called yet. */
function dailyReminder() {
  ensureAssignTriggersQuietly_();
  if (!notifyOn_()) return;
  const sheet = responses_();
  const h = headers_(sheet);
  const c = n => h.indexOf(n);
  const data = sheet.getDataRange().getValues().slice(HEADER_ROW);

  // count calls per guest from the Call Log tab
  const calls = {};
  var cs = SpreadsheetApp.getActive().getSheetByName(CALLS_SHEET);
  if (!cs) cs = SpreadsheetApp.getActive().getSheetByName('Follow-ups');
  if (cs) {
    const cv = cs.getDataRange().getValues();
    const gCol = cv[0].map(x => String(x).trim().toUpperCase()).indexOf('GUEST');
    cv.slice(1).forEach(r => { const g = String(r[gCol]).trim(); if (g) calls[g] = (calls[g] || 0) + 1; });
  }

  const goLive = new Date(GO_LIVE + 'T00:00:00');
  const now = new Date();
  let sent = 0;
  activeWorkers_().forEach(w => {
    const overdue = [], due = [];
    data.forEach(r => {
      if (String(r[c('ASSIGNED TO')]).trim().toLowerCase() !== w.email) return;
      const d = r[c('ASSIGNED DATE')];
      if (!(d instanceof Date) || d < goLive) return;
      if (calls[String(r[c('GUEST ID')]).trim()]) return; // already called at least once
      const days = Math.floor((now - d) / 86400000);
      const line = '<li><b>' + String(r[c('FULL NAME')]).trim() + '</b> - ' + String(r[c('PHONE NUMBER')]).trim() +
                   ' <span style="color:#666">(' + (days === 0 ? 'today' : days + ' day' + (days > 1 ? 's' : '') + ' ago') + ')</span></li>';
      (days > 3 ? overdue : due).push(line);
    });
    if (!overdue.length && !due.length) return;
    const waiting = overdue.length + due.length;
    // Push first; the email is the fallback for people without notifications on.
    if (typeof pcuNotify_ === 'function' && pcuNotify_(w.email, {
      title: waiting + (waiting === 1 ? ' guest is' : ' guests are') + ' waiting for your call',
      body: overdue.length ? overdue.length + ' of them over 3 days. Open the app to call.' : 'Open the app to call them.',
      tag: 'daily-reminder'
    })) { sent++; return; }
    if (!realEmail_(w.email)) return;
    MailApp.sendEmail({
      to: w.email,
      subject: 'PCU reminder: ' + (overdue.length + due.length) + ' guest(s) not called yet',
      htmlBody: emailShell_('Guests waiting for your call',
        '<p>Hi ' + (w.name || 'there') + ', these guests have not been called yet:</p>' +
        (overdue.length ? '<p style="color:#C62828;margin-bottom:4px"><b>Over 3 days - please call today</b></p><ul>' + overdue.join('') + '</ul>' : '') +
        (due.length ? '<p style="margin-bottom:4px"><b>New (within 3 days)</b></p><ul>' + due.join('') + '</ul>' : ''))
    });
    sent++;
  });
  console.log('Reminders sent: ' + sent);
}

function emailShell_(title, body) {
  return '<div style="font-family:Arial,sans-serif;max-width:520px;margin:auto;border:1px solid #e5e5e5;border-radius:10px;overflow:hidden">' +
    '<div style="background:#0B1F3A;color:#fff;padding:16px 20px;font-size:18px"><b>PCU Connect</b>' +
    '<div style="color:#C9A227;font-size:13px;margin-top:4px">' + title + '</div></div>' +
    '<div style="padding:16px 20px;color:#222;font-size:14px;line-height:1.5">' + body +
    '<p style="margin-top:20px"><a href="' + APP_LINK + '" style="background:#C9A227;color:#0B1F3A;padding:10px 16px;' +
    'border-radius:6px;text-decoration:none;font-weight:bold">Open PCU Connect</a></p></div></div>';
}

/* ------------------------------------------------------------------ */
/* Manual assignment                                                   */
/* ------------------------------------------------------------------ */

/** HOD highlights rows in Form Responses 1, then uses this. Rows that already have a worker are skipped. */
function assignSelectedRows() {
  const ui = SpreadsheetApp.getUi();
  const sheet = SpreadsheetApp.getActiveSheet();
  if (sheet.getName() !== RESPONSES_SHEET) {
    ui.alert('Open the "' + RESPONSES_SHEET + '" tab and highlight the guest rows first.');
    return;
  }
  const range = sheet.getActiveRange();
  const run = [];
  withLock_(() => {
    for (let r = range.getRow(); r <= range.getLastRow(); r++) {
      const worker = assignRow_(sheet, r);
      if (worker) run.push(worker);
    }
  });
  notifyAssignSummary_(run);
  ui.alert(run.length + ' guest(s) assigned. Rows that already had a worker were left alone.');
}

/** Assigns every guest whose Timestamp is today and who has no worker yet. */
function assignTodaysUnassigned() {
  const ui = SpreadsheetApp.getUi();
  const sheet = responses_();
  const h = headers_(sheet);
  const tsCol = h.indexOf('TIMESTAMP');
  const nameCol = h.indexOf('FULL NAME');
  const assignedCol = h.indexOf('ASSIGNED TO');
  const today = dayKey_(new Date());
  const data = sheet.getDataRange().getValues();
  const run = [];

  withLock_(() => {
    for (let i = HEADER_ROW; i < data.length; i++) {
      const ts = data[i][tsCol];
      if (!(ts instanceof Date) || dayKey_(ts) !== today) continue;
      if (!String(data[i][nameCol]).trim() || String(data[i][assignedCol]).trim()) continue;
      const worker = assignRow_(sheet, i + 1);
      if (worker) run.push(worker);
    }
  });
  notifyAssignSummary_(run);
  ui.alert(run.length + " of today's guest(s) assigned.");
}

function showNextWorker() {
  const workers = activeWorkers_();
  const ui = SpreadsheetApp.getUi();
  if (!workers.length) { ui.alert('No active workers. Add one under PCU > Workers.'); return; }
  const next = Number(PropertiesService.getScriptProperties().getProperty('NEXT_INDEX') || 0) % workers.length;
  ui.alert('Next guest goes to: ' + workers[next].name + ' (' + workers[next].email + ')');
}

/** Counts guests per worker: assigned today and assigned in total. */
function showSummary() {
  const sheet = responses_();
  const h = headers_(sheet);
  const assignedCol = h.indexOf('ASSIGNED TO');
  const dateCol = h.indexOf('ASSIGNED DATE');
  const today = dayKey_(new Date());
  const data = sheet.getDataRange().getValues().slice(HEADER_ROW);
  const names = {};
  allWorkers_().forEach(w => { names[w.email] = w.name; });

  const counts = {};
  const notWorker = []; // rows where ASSIGNED TO holds something that is not a worker's email
  data.forEach((r, i) => {
    const email = String(r[assignedCol]).trim().toLowerCase();
    if (!email) return;
    if (!(email in names)) { notWorker.push(i + HEADER_ROW + 1); return; }
    counts[email] = counts[email] || { today: 0, total: 0 };
    counts[email].total++;
    if (dateCol >= 0 && r[dateCol] instanceof Date && dayKey_(r[dateCol]) === today) counts[email].today++;
  });

  const lines = Object.keys(counts).map(e =>
    names[e] + ': ' + counts[e].today + ' today, ' + counts[e].total + ' in total');
  let msg = lines.length ? lines.join('\n') : 'No guests have been assigned yet.';
  if (notWorker.length) {
    msg += '\n\nNot counted: ' + notWorker.length + ' row(s) where ASSIGNED TO is not a worker email (row ' +
           notWorker.slice(0, 10).join(', ') + (notWorker.length > 10 ? ', ...' : '') + ').';
  }
  SpreadsheetApp.getUi().alert(msg);
}

/* ------------------------------------------------------------------ */
/* Workers                                                             */
/* ------------------------------------------------------------------ */

function addWorker() {
  const ui = SpreadsheetApp.getUi();
  const name = ask_('Add worker', 'Full name:'); if (name === null) return;
  const email = ask_('Add worker', 'Gmail address (the one they will sign in with):'); if (email === null) return;
  const phone = ask_('Add worker', 'Phone number:'); if (phone === null) return;

  const cleanEmail = email.trim().toLowerCase();
  if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(cleanEmail)) { ui.alert('That email does not look right. Nothing was added.'); return; }
  if (allWorkers_().some(w => w.email === cleanEmail)) { ui.alert('That email is already on the Workers tab.'); return; }

  const ws = workersSheet_();
  const ids = ws.getDataRange().getValues().slice(HEADER_ROW)
    .map(r => Number(String(r[0]).replace(/\D/g, '')) || 0);
  const nextId = 'W' + String(Math.max(0, ...ids) + 1).padStart(3, '0');

  ws.appendRow([nextId, name.trim(), cleanEmail, "'" + phone.trim(), 'Worker', 'Yes']);
  ui.alert(name.trim() + ' added as ' + nextId + '. They will start getting new guests now.\n' +
           'Remember to also share the AppSheet app with ' + cleanEmail + '.');
}

function deactivateWorker() { setActive_('No'); }
function reactivateWorker() { setActive_('Yes'); }

function setActive_(value) {
  const ui = SpreadsheetApp.getUi();
  const title = value === 'No' ? 'Remove worker' : 'Bring worker back';
  const email = ask_(title, "Worker's email:"); if (email === null) return;

  const ws = workersSheet_();
  const data = ws.getDataRange().getValues();
  const h = data[HEADER_ROW - 1].map(x => String(x).trim().toUpperCase());
  const emailCol = h.indexOf('EMAIL'), activeCol = h.indexOf('ACTIVE'), nameCol = h.indexOf('NAME');

  for (let i = HEADER_ROW; i < data.length; i++) {
    if (String(data[i][emailCol]).trim().toLowerCase() === email.trim().toLowerCase()) {
      ws.getRange(i + 1, activeCol + 1).setValue(value);
      ui.alert(value === 'No'
        ? data[i][nameCol] + ' will get no new guests. Their past guests and feedback stay as they are.'
        : data[i][nameCol] + ' is back in the rotation.');
      return;
    }
  }
  ui.alert('No worker with that email on the Workers tab.');
}

function listWorkers() {
  const all = allWorkers_();
  const active = all.filter(w => w.active).map(w => '  ' + w.id + '  ' + w.name + ' (' + w.role + ')');
  const off = all.filter(w => !w.active).map(w => '  ' + w.id + '  ' + w.name);
  SpreadsheetApp.getUi().alert(
    'Active (' + active.length + '):\n' + (active.join('\n') || '  none') +
    '\n\nNot active (' + off.length + '):\n' + (off.join('\n') || '  none'));
}

/* ------------------------------------------------------------------ */
/* Always on: triggers that repair themselves                          */
/* ------------------------------------------------------------------ */

const BACKUP_EVERY_MINUTES = 5;

/**
 * Makes sure auto-assign is on: the form-submit trigger (assignOnSubmit), the
 * 5-minute backup (assignBackup) and the 6pm reminder (dailyReminder) exist.
 * Adds only what is missing. Called on every scheduled run, so a deleted
 * trigger comes back within minutes. Returns the handlers it added.
 */
function ensureAssignTriggers_() {
  const have = {};
  ScriptApp.getProjectTriggers().forEach(t => { have[t.getHandlerFunction()] = true; });
  const added = [];
  if (!have.assignOnSubmit) {
    ScriptApp.newTrigger('assignOnSubmit').forSpreadsheet(SpreadsheetApp.getActive()).onFormSubmit().create();
    added.push('assignOnSubmit');
  }
  if (!have.assignBackup) {
    ScriptApp.newTrigger('assignBackup').timeBased().everyMinutes(BACKUP_EVERY_MINUTES).create();
    added.push('assignBackup');
  }
  if (!have.dailyReminder) {
    ScriptApp.newTrigger('dailyReminder').timeBased().atHour(REMINDER_HOUR).everyDays(1).inTimezone(TZ).create();
    added.push('dailyReminder');
  }
  if (added.length) console.log('Triggers added: ' + added.join(', '));
  return added;
}

/** Same as ensureAssignTriggers_, but never fails the caller. */
function ensureAssignTriggersQuietly_() {
  try {
    return ensureAssignTriggers_();
  } catch (err) {
    console.warn('Could not check the triggers: ' + (err && err.message));
    return [];
  }
}

function triggerStatus() {
  const added = ensureAssignTriggers_();
  alert_('Auto-assign is always ON: every new form entry goes to the next active worker, and every ' +
    BACKUP_EVERY_MINUTES + ' minutes any guest still without a worker is assigned.' +
    (added.length ? '\n\nRepaired just now: ' + added.join(', ') + '.' : ''));
}

function resetRotation() {
  PropertiesService.getScriptProperties().setProperty('NEXT_INDEX', '0');
  alert_('Rotation restarted. The next guest goes to the first active worker on the list.');
}

/* ------------------------------------------------------------------ */
/* Testing (test copy only)                                            */
/* ------------------------------------------------------------------ */

/** Adds fake guests to the bottom of Form Responses 1 and assigns each one like a real form entry. */
function testAddGuests() {
  const HOW_MANY = 6;
  const sheet = responses_();
  const h = headers_(sheet);
  const col = name => h.indexOf(name);
  const run = [];

  withLock_(() => {
    for (let i = 1; i <= HOW_MANY; i++) {
      const row = new Array(h.length).fill('');
      const now = new Date();
      if (col('TIMESTAMP') >= 0) row[col('TIMESTAMP')] = now;
      if (col('SERVICE DATE') >= 0) row[col('SERVICE DATE')] = now;
      if (col('FULL NAME') >= 0) row[col('FULL NAME')] = TEST_PREFIX + ' ' + Utilities.formatDate(now, TZ, 'HHmmss') + '-' + i;
      if (col('PHONE NUMBER') >= 0) row[col('PHONE NUMBER')] = "'0800000000" + i;
      if (col('GENDER') >= 0) row[col('GENDER')] = i % 2 ? 'Female' : 'Male';
      if (col('MARITAL STATUS') >= 0) row[col('MARITAL STATUS')] = 'SINGLE';

      const newRow = sheet.getLastRow() + 1;
      sheet.getRange(newRow, 1, 1, row.length).setValues([row]);
      SpreadsheetApp.flush();
      const worker = assignRow_(sheet, newRow);
      if (worker) run.push(worker);
    }
  });
  notifyAssignSummary_(run);
  alert_(HOW_MANY + ' test guests added and assigned. Scroll to the bottom of ' + RESPONSES_SHEET + '.');
}

/** Deletes every row whose FULL NAME starts with "TEST Guest". */
function removeTestGuests() {
  const ui = SpreadsheetApp.getUi();
  const sheet = responses_();
  const nameCol = headers_(sheet).indexOf('FULL NAME');
  const data = sheet.getDataRange().getValues();
  const rows = [];
  for (let i = HEADER_ROW; i < data.length; i++) {
    if (String(data[i][nameCol]).indexOf(TEST_PREFIX) === 0) rows.push(i + 1);
  }
  if (!rows.length) { ui.alert('No test guests found.'); return; }
  if (ui.alert('Delete ' + rows.length + ' test guest row(s)?', ui.ButtonSet.YES_NO) !== ui.Button.YES) return;
  rows.reverse().forEach(r => sheet.deleteRow(r));
  ui.alert(rows.length + ' test guest row(s) deleted.');
}

/* ------------------------------------------------------------------ */
/* Helpers                                                             */
/* ------------------------------------------------------------------ */

function responses_() {
  const s = SpreadsheetApp.getActive().getSheetByName(RESPONSES_SHEET);
  if (!s) throw new Error('No "' + RESPONSES_SHEET + '" tab found');
  return s;
}

function workersSheet_() {
  const s = SpreadsheetApp.getActive().getSheetByName(WORKERS_SHEET);
  if (!s) throw new Error('No "' + WORKERS_SHEET + '" tab found');
  return s;
}

function headers_(sheet) {
  return sheet.getRange(HEADER_ROW, 1, 1, sheet.getLastColumn()).getValues()[0]
    .map(x => String(x).trim().toUpperCase());
}

/** Every row of the Workers tab as {id, name, email, role, active}. */
function allWorkers_() {
  const data = workersSheet_().getDataRange().getValues();
  const h = data[HEADER_ROW - 1].map(x => String(x).trim().toUpperCase());
  const c = n => h.indexOf(n);
  if (c('EMAIL') < 0 || c('ACTIVE') < 0) throw new Error('Workers tab needs Email and Active headers');
  return data.slice(HEADER_ROW)
    .filter(r => String(r[c('EMAIL')]).trim())
    .map(r => ({
      id: c('ID') >= 0 ? String(r[c('ID')]) : '',
      name: c('NAME') >= 0 ? String(r[c('NAME')]) : '',
      email: String(r[c('EMAIL')]).trim().toLowerCase(),
      role: c('ROLE') >= 0 ? String(r[c('ROLE')]) : '',
      active: String(r[c('ACTIVE')]).trim().toUpperCase() === 'YES'
    }));
}

/**
 * Only active workers with role 'Worker' get assigned guests.
 * Admins/HODs (e.g. Opeyemi Olanite) are strictly excluded from round-robin rotation.
 */
function activeWorkers_() {
  return allWorkers_().filter(w => w.active && String(w.role).trim().toLowerCase() === 'worker');
}

function dayKey_(d) { return Utilities.formatDate(d, TZ, 'yyyy-MM-dd'); }

function withLock_(fn) {
  const lock = LockService.getScriptLock();
  lock.waitLock(30000); // two entries at the same moment still go to different workers
  try { fn(); } finally { lock.releaseLock(); }
}

function ask_(title, prompt) {
  const ui = SpreadsheetApp.getUi();
  const res = ui.prompt(title, prompt, ui.ButtonSet.OK_CANCEL);
  if (res.getSelectedButton() !== ui.Button.OK || !res.getResponseText().trim()) return null;
  return res.getResponseText();
}

/** Shows a message when run from the menu; stays silent when run by a trigger. */
function alert_(msg) {
  try { SpreadsheetApp.getUi().alert(msg); } catch (e) { console.log(msg); }
}
