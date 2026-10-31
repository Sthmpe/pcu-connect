# PCU Connect backend plan (phase 2: Firebase as the live database)

## Goal
Workers never wait on Apps Script. The app reads and writes Firestore directly. The Google Sheet stays the church's report book and the entry point for new guests.

## Roles of each part
- Google Form + sheet: new guests land in "Form Responses 1".
- Apps Script: assignment (existing script), sends guests to Firestore, syncs results back to the sheet, manages workers, HOD "Sync to sheet".
- Firestore: live data for the app.
- Firebase Auth: Google sign-in. Role comes from the users collection.
- No Cloud Functions, no billing needed.

## Field ownership
Each field has exactly one owner, so the sheet and Firestore never fight.

- **The sheet owns** ASSIGNED TO and the guest details: name, phone, service date. The 5-minute job copies these from the sheet to Firestore, including reassignments. The app never edits them.
- **Firebase owns** all work fields: calls, feedback, status, attendance, team, membership and points. The sync writes only these to the sheet.
- The sync never touches ASSIGNED TO, name or phone in the sheet.

| Sheet column | Owner | Direction |
| --- | --- | --- |
| GUEST ID, FULL NAME, PHONE NUMBER, SERVICE DATE, ASSIGNED TO, ASSIGNED DATE | Sheet | Sheet to Firestore (every 5 minutes) |
| CALL STATUS, MEMBERSHIP STATUS, FEEDBACK 1, FEEDBACK 2, FEEDBACK 1 DATE, FEEDBACK 2 DATE, FOLLOW-UP COUNT, LAST FEEDBACK, LAST FEEDBACK DATE, TEAM JOINED, MEMBERSHIP DATE | Firebase | Firestore to sheet (nightly, weekly, Sync to sheet) |
| Follow-ups tab (all columns, including Logged by) | Firebase | Firestore to sheet, append only |

## Flow
1. A guest lands in the sheet.
2. The existing assignment script assigns the guest in the sheet (admins never receive guests).
3. At the end of the assignment function, pcuPushGuest_ writes the guest's sheet-owned fields to Firestore (create or update). GUEST ID is the document id. A safety job every 5 minutes (pcuPushPendingGuests) sends any guest whose sheet-owned fields changed since the last send, including reassignments (uses a "SYNCED AT" column).
4. Workers use the app against Firestore. A follow-up is saved as one batch write: the follow-up document plus the guest's work fields (status, follow-up count, first call time, attendance dates, team, member date). Batches, unlike transactions, queue while offline and complete when the device reconnects.
5. Every night at 00:05 Africa/Lagos, pcuNightlySync first recalculates every touched guest's totals and each worker's points from followUps (correcting any drift from offline or concurrent saves), then writes yesterday's work to the sheet: append to the Follow-ups tab (safe to repeat, keyed by Follow-up ID) and update only the Firebase-owned guest columns.
6. Every Monday 01:00 Africa/Lagos, pcuWeeklySync writes last week's membership results and conversions to a "Weekly Report" tab.
7. The HOD dashboard shows the sheet sync status and warns when the sheet is more than a day behind. A "Sync to sheet" button calls the Apps Script action syncNow (admin only, verified Firebase token, script lock shared with the nightly job). It runs the same sync and returns counts.
8. Assignment is the only thing that is instant in the sheet. Everything else lags by design and only the HOD sees the lag.

## GUEST ID
- GUEST ID is the Firestore document id and the join key between the sheet and Firestore.
- If a row has no GUEST ID, Apps Script creates a stable one from a fixed formula and writes it to the sheet before sending:
  `G-` + first 8 hex characters of SHA-256 of (`TIMESTAMP` as `yyyy-MM-dd'T'HH:mm:ss` in Africa/Lagos + `|` + phone digits only).
- The same row always produces the same ID, so re-runs and retries never create duplicates.
- If two rows ever produce the same ID (same timestamp and phone), the second is logged and skipped for a human to check, never overwritten.

## Firestore data model
- users/{normalised email}: name, email, phone, role (admin or worker), active. Written only by Apps Script.
- guests/{guestId}: name, phone, serviceDate, month (yyyy-MM), assignedTo (normalised email), assignedDate, callStatus, membershipStatus, followUpCount, firstCallAt, lastFeedback, lastFeedbackDate, teamJoined, memberSince, sundayDates[], wednesdayDates[], sheetRow, syncedToSheetAt.
- followUps/{id}: guestId, worker (credited worker email), loggedBy (who actually saved it), callDate, month, outcome, note, attendedSunday, sundayDate, attendedWednesday, wednesdayDate, team, points, syncedToSheet (bool), createdAt.
- meta/sync: lastSheetSyncAt, lastResult, running.

## Emails
- Every email is normalised everywhere: trimmed and lowercased. This applies to users document ids, assignedTo, worker, loggedBy, the Workers tab and every comparison in Apps Script and the app.
- saveWorker and the 5-minute job write normalised emails to the Workers tab and the sheet-owned assignedTo value sent to Firestore.
- Sign-in requires `email_verified == true`.

## Time
- All day boundaries use Africa/Lagos time: "today", "yesterday", calendar month, the nightly and weekly runs, attendance "not in the future", and "first call within 3 days".
- "Within 3 days" compares Africa/Lagos calendar dates of the service date and the first call, not raw hours.
- The app formats and compares dates with the same Africa/Lagos rule, whatever the device time zone.

## Log on behalf (HOD)
Admin can log a follow-up for a guest. worker = the assigned worker (gets points and ranking credit), loggedBy = the admin. The timeline shows "Logged by admin" when they differ. The "Logged by" column on the Follow-ups tab already exists on the test sheet. Admins are never ranked.

## Security rules (Firestore)
- All access needs sign-in, `request.auth.token.email_verified == true`, and users/{normalised email}.active == true. The rules lowercase the token email before every lookup or comparison.
- Workers: read only guests where assignedTo == their email; create followUps only with worker == own email and loggedBy == own email; update only the Firebase-owned work fields on their own guests; points must be one of the allowed values.
- Admin: read all; create followUps for any worker with loggedBy == own email.
- No client may write name, phone, serviceDate, assignedTo or assignedDate on guests.
- users and meta: no client writes.
- Write rules tests with the Firebase emulator (rules-unit-testing).

## Business rules
Member = 4 distinct Sundays, or 3 Sundays and 2 Wednesdays, in one calendar month. Points: +10 first call within 3 days (else +5), +5 per follow-up, +10 per attendance, +20 team join, +30 member. Attendance on any past date, never future. Services: Sunday and Wednesday. Status order: Member > Not interested > Returning > Contacted > Unreachable > unchanged.
The app applies these when it builds the batch. The nightly job recalculates guest totals and points from followUps and corrects any drift. Ranking = sum of points by worker for the month, computed from followUps.

## Apps Script and Firestore access
- Only the owner is an editor of the Apps Script project. Nobody else gets edit access, because editors can read Script Properties.
- The service account has only the Cloud Datastore User role, nothing else.
- Store the key only in Script Properties, never in the repo. Apps Script signs a JWT, gets an access token and calls the Firestore REST API.
- Keep the Firebase ID token check for syncNow, saveWorker and setWorkerActive. Those two worker actions stay in Apps Script, write the Workers tab and the users documents, so the assignment script keeps reading the Workers tab unchanged.

### Rotating the service account key
Do this at least once a year, and immediately if the key may have leaked or an editor is removed.
1. In Google Cloud console, IAM and Admin, Service accounts, open the PCU service account and add a new JSON key.
2. In the Apps Script project, Project Settings, Script Properties, replace the key property with the new JSON. Nothing else changes.
3. Run the manual check function (a read of meta/sync) to confirm the new key works.
4. Back in the console, delete the old key.
5. Delete the downloaded JSON file from the computer. It must never be committed or emailed.

## Batch writes and long runs
- The migration, the 5-minute job and every sync use Firestore batch writes (commit with up to 500 writes per request).
- Each run stops before the Apps Script time limit (about 5 minutes of work) and stores a progress marker in Script Properties (job name, last processed row or document, started at).
- The next trigger continues from the marker. When a job finishes it clears its marker. A job never starts a second copy while its marker says it is running, unless the marker is older than 30 minutes (then it resumes).
- Every write is keyed by a stable id (GUEST ID, Follow-up ID), so a repeated batch changes nothing.

## Wording in the app
- Use "sync" for anything that moves data to the sheet. Never show technical terms such as export, push, upsert, transaction or reconcile in the UI.
- HOD button: "Sync to sheet". While running: "Syncing...". When done: "Synced 42 guests".
- Status line: "Last synced: today 12:05 AM". When older than a day, a gentle warning: "Sheet is a day behind. Sync now."
- All copy stays plain, short and friendly, in sentence case, with no em dashes.

## UI rule (applies to every phase)
Every backend change ships with the matching UI change in the same phase. No screen is left behind. When a phase changes data or behaviour, update every affected screen: lists, detail, dashboard, ranking, team, log screens, empty states, loading states, error messages, and the HOD sync status. The redesign quality bar applies to all new UI: clean, calm, intentional, consistent copy, Lucide icons only, design tokens only. A phase is not done until its UI checklist is ticked.

## Phases

### 0. Finish the redesign on the existing Apps Script API
Backend: real data for Team, Ranking and Dashboard top workers; month keys; outcomes matching the API; log on behalf with "Logged by"; redeploy Api.gs.

UI checklist:
- [x] Every worker and admin screen on the v2 design system
- [x] Today: progress ring, next call, chips with counts
- [x] Ranking: refined top three, own row highlighted, "How points work" sheet
- [x] Team, Dashboard top workers and Ranking use the real API
- [x] Guest timeline with the "Logged by admin" label
- [x] Admin "Log a follow-up for <worker>" on the guest screen
- [ ] Api.gs redeployed and checked from the app on the test sheet

### 1. Firestore setup and read only guests
Backend: Firestore project, rules, users sync with normalised emails, stable GUEST IDs, migration of the last 12 months of guests and follow-ups in batches with a progress marker, the 5-minute job for sheet-owned fields and reassignments. App reads guests from Firestore (read only).

Status (branch phase-1-firestore): code, rules and tests done; waiting on setup that needs the owner's accounts (see "Phase 1 setup" below).
Built so far:
- Switch: `--dart-define=DATA_SOURCE=firestore` (default `api`). Saving stays on the Apps Script API in phase 1, which then sends the change to Firestore, so the app works whichever way the switch is set.
- `firestore.rules` and `firestore.indexes.json` for the new model (old app rules kept in `legacy/`). 26 emulator tests in `firestore-tests/` (`npm test`).
- `backend/Firestore.gs`: REST client with service account JWT, batch commits of 500, resume markers, stable GUEST IDs, users sync with clean emails, 5-minute job with reassignments, migration. 41 checks in `backend/test/pcu_firestore_harness.js`.
- App: `FirestoreGuestRepository` (live lists, history from followUps), `FirestoreProfileSource` (role from users), `LagosTime`, mappers, live updates in GuestsBloc. Dart tests in `test/features/firestore_phase1_test.dart`.

UI checklist:
- [x] Today, Guests, Guest detail and admin Guests read from Firestore with no visible change in layout
- [x] Live updates: lists refresh on their own, no pull to refresh needed
- [x] A reassigned guest leaves the old worker's list and appears in the new one within minutes
- [x] Loading uses skeletons; first load after sign-in feels instant from cache
- [x] Empty states for "no guests yet" still read well with Firestore data
- [x] Error messages stay plain ("We could not load your guests. Try again.")
- [x] Sign-in copy for people not in users: "You are not on the team yet. Ask your HOD to add you."
- [ ] Checked end to end against the test project after setup

#### Phase 1 setup (owner only)
1. Firebase console, project pcu-workflow: Firestore Database exists (created earlier). Deploy the new rules and indexes: `firebase deploy --only firestore --project pcu-workflow`.
2. Google Cloud console, IAM and Admin, Service accounts: create `pcu-sheet-sync`, give it only the Cloud Datastore User role, then Keys, Add key, JSON.
3. Apps Script project of the TEST sheet: add `Firestore.gs`, replace `Api.gs` and `pcu_auto_assign.gs` with the repo versions.
4. Project Settings, Script Properties: add `FIRESTORE_SA_KEY` with the whole JSON key as the value. Delete the downloaded file.
5. In the editor run, in order: `pcuFirestoreCheck`, `pcuSetupSyncColumns`, `pcuMigrate` (repeat until the log says done), `pcuInstallFirestoreTriggers`.
6. Deploy, Manage deployments, Edit, New version (same URL).

### 2. Follow-ups written by the app
Backend: app writes follow-ups with batch writes (offline safe) and rules; log on behalf moves to Firestore; dates use Africa/Lagos.

UI checklist:
- [ ] Log follow-up saves instantly, online or offline
- [ ] Offline save shows a calm note ("Saved on this phone. It will send when you are back online.") and nothing is lost
- [ ] Points dialog shows the points from the saved follow-up
- [ ] Guest detail, Today counts, Ranking and Me stats update right after saving
- [ ] Admin log for a worker shows "It counts for <worker>" and the timeline label
- [ ] Validation messages (future date, missing outcome) in plain words

### 3. Syncing to the sheet
Backend: pcuNightlySync (recalculate, then sync work fields only), pcuWeeklySync, syncNow, meta/sync, batch writes with progress markers.

UI checklist:
- [ ] Dashboard status line: "Last synced: today 12:05 AM"
- [ ] Gentle warning when more than a day behind: "Sheet is a day behind. Sync now."
- [ ] "Sync to sheet" button: "Syncing..." while running, "Synced 42 guests" when done
- [ ] Clear message when a sync is already running or fails
- [ ] Points or counts corrected overnight show the new values without a confusing jump
- [ ] Workers never see sync status

### 4. Tidy up and go live
Backend: retire the old API actions, tests everywhere, security review (including editors and the key), then go live on the church sheet only with the owner's approval.

UI checklist:
- [ ] Remove any screen paths that still call the old API
- [ ] Full pass of every screen at phone and laptop width
- [ ] Copy review: no technical terms, sentence case, no em dashes
- [ ] Empty, loading and error states checked on every screen

## Testing
Node harness for Apps Script with mocked Firestore REST and mocked Sheets: field ownership (sync never writes ASSIGNED TO, name or phone), reassignment, stable GUEST ID generation, batches of 500, resume from a progress marker, Africa/Lagos day boundaries. Firebase emulator tests for the rules, including email case and email_verified. Flutter tests for the rules engine and repositories. Every sync must be safe to run twice.

## Safety
Test sheet only until go-live. Never delete sheet data. Create a separate Firebase project for the live church data before go-live.
