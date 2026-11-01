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
const APP_LINK = 'https://www.appsheet.com/start/37ecd84f-d7d6-44b0-bc88-2372b0933e3e';

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
    .addSubMenu(ui.createMenu('Auto-assign')
      .addItem('Switch on (run once)', 'setupTrigger')
      .addItem('Switch off', 'removeTrigger')
      .addItem('Check status', 'triggerStatus')
      .addItem('Restart rotation from first worker', 'resetRotation'))
    .addSubMenu(ui.createMenu('Notifications')
      .addItem('Switch on (new-guest emails + 6pm reminder)', 'notificationsOn')
      .addItem('Switch off', 'notificationsOff')
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

/** Runs on every form submission once auto-assign is switched on. */
function assignOnSubmit(e) {
  withLock_(() => {
    const sheet = e.range.getSheet();
    if (sheet.getName() !== RESPONSES_SHEET) return;
    assignRow_(sheet, e.range.getRow());
  });
}

/** Gives one row to the next active worker. Returns the email, or '' if nothing was done. */
function assignRow_(sheet, row) {
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
  if (idCol && typeof pcuPushGuestQuietly_ === 'function') {
    SpreadsheetApp.flush();
    pcuPushGuestQuietly_(String(sheet.getRange(row, idCol).getValue()).trim());
  }
  return worker;
}

/* ------------------------------------------------------------------ */
/* Notifications (email)                                               */
/* ------------------------------------------------------------------ */

function notificationsOn() {
  PropertiesService.getScriptProperties().setProperty('NOTIFY', 'ON');
  ScriptApp.getProjectTriggers().filter(t => t.getHandlerFunction() === 'dailyReminder')
    .forEach(t => ScriptApp.deleteTrigger(t));
  ScriptApp.newTrigger('dailyReminder').timeBased().atHour(REMINDER_HOUR).everyDays(1).inTimezone(TZ).create();
  alert_('Notifications are ON.\n- Each worker gets an email when a new guest is given to them.\n' +
         '- Every day at 6pm, each worker gets a list of their guests not called yet.');
}

function notificationsOff() {
  PropertiesService.getScriptProperties().setProperty('NOTIFY', 'OFF');
  ScriptApp.getProjectTriggers().filter(t => t.getHandlerFunction() === 'dailyReminder')
    .forEach(t => ScriptApp.deleteTrigger(t));
  alert_('Notifications are OFF. No emails will be sent.');
}

function notificationsStatus() {
  const on = PropertiesService.getScriptProperties().getProperty('NOTIFY') === 'ON';
  const daily = ScriptApp.getProjectTriggers().some(t => t.getHandlerFunction() === 'dailyReminder');
  alert_('New-guest emails: ' + (on ? 'ON' : 'OFF') + '\n6pm reminder: ' + (daily && on ? 'ON' : 'OFF') +
         '\nEmails left today (Google limit): ' + MailApp.getRemainingDailyQuota());
}

function notifyOn_() { return PropertiesService.getScriptProperties().getProperty('NOTIFY') === 'ON'; }

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
  let done = 0;
  withLock_(() => {
    for (let r = range.getRow(); r <= range.getLastRow(); r++) {
      if (assignRow_(sheet, r)) done++;
    }
  });
  ui.alert(done + ' guest(s) assigned. Rows that already had a worker were left alone.');
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
  let done = 0;

  withLock_(() => {
    for (let i = HEADER_ROW; i < data.length; i++) {
      const ts = data[i][tsCol];
      if (!(ts instanceof Date) || dayKey_(ts) !== today) continue;
      if (!String(data[i][nameCol]).trim() || String(data[i][assignedCol]).trim()) continue;
      if (assignRow_(sheet, i + 1)) done++;
    }
  });
  ui.alert(done + " of today's guest(s) assigned.");
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
/* Auto-assign switch                                                  */
/* ------------------------------------------------------------------ */

function setupTrigger() {
  removeTriggerSilently_();
  ScriptApp.newTrigger('assignOnSubmit')
    .forSpreadsheet(SpreadsheetApp.getActive())
    .onFormSubmit()
    .create();
  alert_('Auto-assign is ON. Every new form entry will go to the next active worker.');
}

function removeTrigger() {
  const n = removeTriggerSilently_();
  alert_(n ? 'Auto-assign is OFF. New form entries will stay unassigned.' : 'Auto-assign was already off.');
}

function triggerStatus() {
  const on = ScriptApp.getProjectTriggers().some(t => t.getHandlerFunction() === 'assignOnSubmit');
  alert_(on ? 'Auto-assign is ON.' : 'Auto-assign is OFF.');
}

function resetRotation() {
  PropertiesService.getScriptProperties().setProperty('NEXT_INDEX', '0');
  alert_('Rotation restarted. The next guest goes to the first active worker on the list.');
}

function removeTriggerSilently_() {
  const ts = ScriptApp.getProjectTriggers().filter(t => t.getHandlerFunction() === 'assignOnSubmit');
  ts.forEach(t => ScriptApp.deleteTrigger(t));
  return ts.length;
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
      assignRow_(sheet, newRow);
    }
  });
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
