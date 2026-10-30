/**
 * PCU Connect API — add to the SAME Apps Script project bound to the sheet.
 * Deploy: Deploy > New deployment > Web app > Execute as: Me > Access: Anyone.
 * Flutter calls it with POST { action, idToken, ...payload } (text/plain to avoid CORS preflight).
 * Sheet tabs: "Form Responses 1" (guests), "Call Log", "Workers", "Leaderboard".
 * Column names below come from the existing sheet; confirm against real headers before use.
 */
var GO_LIVE = new Date('2026-10-28');
var TZ = 'Africa/Lagos';

function doPost(e) {
  try {
    var req = JSON.parse(e.postData.contents);
    var user = verifyUser_(req.idToken);            // {email, worker:{id,name,role}}
    var map = {
      me: me_, guests: guests_, guest: guest_, logFollowUp: logFollowUp_,
      ranking: ranking_, dashboard: dashboard_, team: team_,
      saveWorker: saveWorker_, setWorkerActive: setWorkerActive_
    };
    if (!map[req.action]) throw new Error('Unknown action');
    return json_({ ok: true, data: map[req.action](user, req) });
  } catch (err) { return json_({ ok: false, error: String(err.message || err) }); }
}

function json_(o) { return ContentService.createTextOutput(JSON.stringify(o)).setMimeType(ContentService.MimeType.JSON); }

// 1. Verify Google ID token, then require the email to exist in Workers with Active=Yes.
function verifyUser_(idToken) {
  var r = UrlFetchApp.fetch('https://oauth2.googleapis.com/tokeninfo?id_token=' + encodeURIComponent(idToken), { muteHttpExceptions: true });
  if (r.getResponseCode() !== 200) throw new Error('Not signed in');
  var t = JSON.parse(r.getContentText());
  if (t.aud !== PropertiesService.getScriptProperties().getProperty('OAUTH_CLIENT_ID')) throw new Error('Bad client');
  var email = String(t.email).toLowerCase();
  var w = rows_('Workers').filter(function (x) { return String(x.Email).toLowerCase() === email; })[0];
  if (!w || w.Active !== 'Yes') throw new Error('No access. Ask your HOD to add your email.');
  return { email: email, worker: w };
}
function isAdmin_(u) { return u.worker.Role === 'Admin' || u.worker.Role === 'HOD'; }
function requireAdmin_(u) { if (!isAdmin_(u)) throw new Error('Admins only'); }

// 2. Sheet helpers: read a tab as array of objects keyed by header.
function rows_(tab) {
  var sh = SpreadsheetApp.getActive().getSheetByName(tab), v = sh.getDataRange().getValues(), h = v.shift();
  return v.map(function (r, i) { var o = { _row: i + 2 }; h.forEach(function (k, j) { o[k] = r[j]; }); return o; });
}

// 3. TODO (Codex): implement each handler. Rules are in README.md section "Business rules".
function me_(u) { return u.worker; }
function guests_(u, req) { /* workers: only rows where assigned worker = u.worker.Name/ID; admin: all. Attach computed fields (see README). */ throw new Error('TODO'); }
function guest_(u, req) { throw new Error('TODO'); }
function logFollowUp_(u, req) { /* append to Call Log, recompute guest status/fields, award points. Reject future dates. LockService. */ throw new Error('TODO'); }
function ranking_(u, req) { throw new Error('TODO'); }
function dashboard_(u, req) { requireAdmin_(u); throw new Error('TODO'); }
function team_(u, req) { requireAdmin_(u); throw new Error('TODO'); }
function saveWorker_(u, req) { requireAdmin_(u); throw new Error('TODO'); }
function setWorkerActive_(u, req) { requireAdmin_(u); throw new Error('TODO'); }
