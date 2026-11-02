# Going live: from the TEST sheet to the real church sheet

Written from the code on branch `phase-1-firestore` (2 November 2026). No secret, key or token is written here, only
the names of where they live.

## 1. Goal

The real church sheet gets the same Apps Script files as the TEST sheet. The app stays the same. Going live is a
configuration job: point the scripts and the app at the real sheet and the right Firebase project, run a few setup
functions once, and check the triggers. Nothing is rebuilt from scratch.

## 2. Settings that differ between TEST and real

| Setting | TEST value (not secret) | Where it lives today | Real environment |
| --- | --- | --- | --- |
| Sheet ID | `1R9-l3GOw_NY8qIvn94mM3ZFxBpuuDl7lwSEnumdFU24` | The scripts are bound to the sheet (`SpreadsheetApp.getActive()`); also hard-coded once in `backend/PCU Leaderboard.gs` (`PCU_TEST_SPREADSHEET`) | The real sheet's own bound script |
| Apps Script project (script ID) | `15zMOA22UDlVbS4jeBIq5pQ7K6cBvzoalGX6sviiewxhqCJb2PbfdG8hL` | `.clasp.json` | A second project file for the real script (section 5) |
| Apps Script exec URL | deployment `AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u` | Passed to the app at build time: `--dart-define=APPS_SCRIPT_URL=...` | The real script's one web app deployment |
| Firebase project | `pcu-workflow` | `.firebaserc`, `lib/firebase_options.dart`, the service account key | Same project or a new one (section 6) |
| Service account key | (secret) | Script Property `FIRESTORE_SA_KEY` | A key for the chosen project, set as `FIRESTORE_SA_KEY` on the real script |
| Firebase web API key | (public, not secret, but kept out of docs) | Script Property `FIREBASE_WEB_API_KEY`; also in `lib/firebase_options.dart` | The chosen project's web API key |
| App address (APP_LINK) | `https://pcu-workflow.web.app` | Hard-coded: `APP_LINK` in `backend/pcu_auto_assign.gs`, `PCU_PUSH.DEFAULT_LINK` in `backend/Firestore.gs`, share links in `web/index.html` | The app address people will use |
| Go-live date | `2026-10-28` | Hard-coded twice: `GO_LIVE` in `backend/pcu_auto_assign.gs` and `AppConfig.chaseFrom` in `lib/core/config/app_config.dart` (fallback copy in `PCU_FS_GO_LIVE_` in `backend/Firestore.gs`) | The real go-live day |
| Sheet URL for "Open the sheet" | filled automatically | Script Property `SHEET_URL` (set once from the bound sheet by `pcuSheetUrl_`), shared through `meta/sync.sheetUrl` | Filled automatically on the first sync; check it |
| Notifications switch | `ON` | Script Property `NOTIFY` (only `OFF` stops them) | Leave unset or `ON` |
| FCM web push key (VAPID) | public | `AppConfig.fcmVapidKey` (override with `--dart-define=FCM_VAPID_KEY`) | Only changes with a new Firebase project |

Script Properties the scripts write for themselves (do not copy them from TEST): `NEXT_INDEX` (rotation),
`USERS_KEY` (last Workers tab copied to users), `PCU_JOB_*` (migration and push markers), `PCU_SNAPSHOT_*`
(leaderboard months frozen), `SHEET_URL`.

`ALLOW_MOCK_TOKENS` has no effect any more: delete it from the TEST script and never add it to the real one.

### Hard-coded environment values to turn into settings (checklist, no code changed yet)

- [ ] `PCU_TEST_SPREADSHEET` in `backend/PCU Leaderboard.gs`: use `SpreadsheetApp.getActive()` (the bound sheet) instead.
- [ ] `APP_LINK` in `backend/pcu_auto_assign.gs`: read a Script Property `APP_LINK`, falling back to the current value.
- [ ] `PCU_PUSH.DEFAULT_LINK` in `backend/Firestore.gs`: same property.
- [ ] `GO_LIVE` in `backend/pcu_auto_assign.gs` and `PCU_FS_GO_LIVE_` in `backend/Firestore.gs`: one Script Property `GO_LIVE`.
- [ ] `AppConfig.chaseFrom` in the app: a `--dart-define=GO_LIVE=...` with the current value as default.
- [ ] `og:url` and image links in `web/index.html`: update by hand if the app address changes.
- [ ] Stale comment in `lib/core/config/app_config.dart` still says the backend honours `ALLOW_MOCK_TOKENS`; it does not.

## 3. Tabs and columns the real sheet needs

Headers are matched by name, ignoring case and extra spaces; column order does not matter.

### Form Responses 1 (the Google Form writes here)

| Column | Meaning | Owner |
| --- | --- | --- |
| Timestamp | When the form was sent; fallback service date; part of the stable GUEST ID | Form |
| SERVICE DATE | The guest's first visit (Lagos day) | Form, sheet |
| FULL NAME | Guest name | Form, sheet |
| PHONE NUMBER | Guest phone | Form, sheet |
| GENDER | Male or Female; gives "sis" or "bro" in WhatsApp messages | Form, sheet |
| MARITAL STATUS, HOW DID YOU ARRIVE?, WHAT WAS THE MAJOR WAY YOU WERE INVITED TO CHURCH? ..., COULD YOU DESCRIBE YOUR COZA EXPERIENCE TODAY? | Form answers, not read by the app | Form |
| FEEDBACK 1, FEEDBACK 2 | Older feedback columns, read as fallback | Firebase (written by the sync) |
| ASSIGNED TO | Worker's email | **Sheet** (assignment script, HOD, Redistribute) |
| ASSIGNED DATE | When assigned or moved | **Sheet** |
| CALL STATUS | Last call outcome | Firebase |
| MEMBERSHIP STATUS | New guest, Contacted, Returning, Member, Not interested, Unreachable | Firebase |
| FEEDBACK 1 DATE, FEEDBACK 2 DATE | Older feedback dates | Firebase |
| MEMBERSHIP DATE | When the guest became a member | Firebase |
| GUEST ID | Stable ID, also the Firestore document ID; filled by the scripts | **Sheet** (scripts) |
| TEAM JOINED | Workforce or Evangelism | Firebase |
| FOLLOW-UP COUNT | Calls logged | Firebase |
| LAST FEEDBACK, LAST FEEDBACK DATE | Latest note | Firebase |
| SYNCED AT, SYNC KEY | When and what was last sent to Firestore | Scripts; created by `pcuSetupSyncColumns` |

The real sheet very likely already has the form columns and the older feedback columns. The work columns from ASSIGNED
TO onward must exist; add any that are missing by hand with these exact names. Add SYNCED AT and SYNC KEY with
`pcuSetupSyncColumns`.

### Workers (by hand)

`ID`, `Name`, `Email`, `Phone`, `Role` (`Worker` or `Admin`/`HOD`), `Active` (`Yes` or `No`). Phone is needed for
Nudge on WhatsApp. Admins never receive guests.

### Follow-ups (by hand, header row only)

`Follow-up ID`, `Guest`, `Worker`, `Call date`, `Call status`, `Note`, `Attended Sunday?`, `Sunday date`,
`Attended Wednesday?`, `Wednesday date`, `Joined team`, `Logged by`. Rows are appended by the sync.

### Created automatically

- `Reassignments` (`TIMESTAMP`, `GUEST ID`, `GUEST NAME`, `FROM`, `TO`, `BY`, `REASON`): created by the first Redistribute.
- `Weekly Report` (`WEEK`, `FROM`, `TO`, `FOLLOW-UPS`, `GUESTS CALLED`, `ATTENDANCES`, `TEAM JOINS`, `NEW MEMBERS`,
  `WRITTEN AT`): created by `pcuWeeklySync`.
- `Leaderboard` (`Month`, `Worker email`, `Worker name`, `Points`, `Rank`, `First-call-on-time`, `Follow-ups`,
  `Sunday/Wed attendances`, `Team joins`, `Members`, `Leaderboard ID`): written by `PCU Leaderboard.gs` (sheet copy of
  the points; the app reads Firestore rankings).

### Not needed by the app

`Call Log` is only an older fallback name read by the 6pm reminder and the sheet leaderboard (they use Follow-ups when it
is missing). The TEST sheet's other tabs (Form Responses 1 Cleaning up, Sheet9, END OF MONTH CALL, Decision, Membership,
REPORT, Sheet10, Months) are not read by the code.

## 4. Scripts to install on the real sheet

Files (all of `backend/` except `test/`): `Api.gs`, `Firestore.gs`, `pcu_auto_assign.gs`, `PCU Leaderboard.gs`,
`AuthTest.gs`, `appsscript.json`.

Run once, in this order, from the Apps Script editor (each one asks for authorization the first time; approve as the
sheet owner):

1. Set the Script Properties `FIREBASE_WEB_API_KEY` and `FIRESTORE_SA_KEY` (section 2).
2. `pcuFirestoreCheck`: writes the users from the Workers tab. Log says "Firestore OK".
3. `pcuSetupSyncColumns`: adds SYNCED AT and SYNC KEY.
4. `pcuMigrate`: copies 12 months of guests and follow-ups. Repeat until the log says "done". (`pcuMigrateRestart`
   clears the marker.)
5. `pcuInstallFirestoreTriggers`: the 5-minute sheet-to-Firestore copy.
6. `triggerStatus` (PCU menu, Auto-assign, Check status): installs the form trigger, the 5-minute assignment backup and
   the 6pm reminder.
7. `pcuSetupLeaderboard`: the sheet leaderboard (hourly) and its monthly snapshot.
8. In the app, as the HOD, tap "Sync to sheet" once: this installs the nightly sync, the nightly recalculation and the
   Monday weekly sync, and fills `SHEET_URL`.

Triggers that must exist afterwards (check in the editor, Triggers page):

| Handler | When | Installed by |
| --- | --- | --- |
| `assignOnSubmit` | On form submit | `ensureAssignTriggers_` (any scheduled run, or Check status) |
| `assignBackup` | Every 5 minutes | `ensureAssignTriggers_` |
| `dailyReminder` | Daily 18:00 Africa/Lagos | `ensureAssignTriggers_` |
| `pcuPushPendingGuests` | Every 5 minutes (sheet to Firestore, users too) | `pcuInstallFirestoreTriggers` |
| `pcuNightlySync` | Daily about 00:05 Africa/Lagos | `pcuEnsureSyncTriggers_` (first Sync to sheet) |
| `pcuNightlyRecalc` | Daily about 00:35 Africa/Lagos | `pcuEnsureSyncTriggers_` |
| `pcuWeeklySync` | Monday 01:00 Africa/Lagos | `pcuEnsureSyncTriggers_` |
| `pcuRefreshLeaderboard` | Hourly | `pcuSetupLeaderboard` |
| `pcuSnapshotPreviousMonth` | 1st of the month, 01:00 | `pcuSetupLeaderboard` |

How to check each: the Triggers page lists them with last run and errors. The admin-only API action `health` returns
the trigger list, sheet and Firestore counts and gaps (call it from the app's HOD session; mock tokens no longer work).
Submit one test form entry: within seconds it is assigned (form trigger) or within 5 minutes (backup), it appears in the
app, and the admins get one "1 guest assigned" summary.

## 5. Pushing the code to the real script with clasp

Keep `.clasp.json` for TEST. Add a second project file at the repo root, `.clasp.real.json` (it must sit next to
`backend/`: clasp refuses a `rootDir` outside the project file's folder):

```json
{ "scriptId": "<real script ID: real sheet, Extensions, Apps Script, Project settings>", "rootDir": "backend" }
```

Check what would be pushed: `clasp -P .clasp.real.json status` (verified: lists the six script files, skips
`backend/test/`). Push: `clasp -P .clasp.real.json push -f`.

The first time, create exactly one web app deployment in the editor (Deploy, New deployment, Web app, Execute as Me,
Who has access Anyone) and note its deployment ID. From then on always update that same deployment:
`clasp -P .clasp.real.json deploy -i <real deployment ID> -d "<label>"`. Never create a second deployment: a new
deployment means a new exec URL and the app would need a rebuild with the new `APPS_SCRIPT_URL`.

## 6. Firebase: same project or a new one

**Option A, keep `pcu-workflow`.** Fewer moving parts: the app build, authorized domains, push key and hosting stay.
Before go-live the TEST data must go: delete the guests, followUps, rankings, nudges, reassignments, meta and the
users that are not real workers (only the real Workers tab people may remain in users), then run the migration from the
real sheet. Steps: export first (`gcloud firestore export` to a bucket, needs the owner), delete the collections in the
console, point the real script's `FIRESTORE_SA_KEY` at the same project, run section 4.

**Option B, a new Firebase project for the church data.** Clean separation and TEST stays usable. More work: create the
project, enable Firestore and Google sign-in, add the hosting site, deploy `firestore.rules` and `firestore.indexes.json`
(`firebase deploy --only firestore:rules,firestore:indexes --project <new>`), create a service account with Cloud
Datastore User and Firebase Cloud Messaging API Admin, regenerate `lib/firebase_options.dart`
(`flutterfire configure --project <new>`), generate a new VAPID key, add the app address to Authorized domains, rebuild
and deploy hosting to the new project.

**Recommendation:** Option B. Real names and phone numbers never share a database with test runs, and TEST stays a safe
place to try changes. If time is short, Option A works, but only after the export and the full wipe.

## 7. Pre-go-live checklist

- [ ] Rotate the service account key: create a new key, set it as `FIRESTORE_SA_KEY`, run `pcuFirestoreCheck`, then
      delete the old key in the Google Cloud console and delete any downloaded key file from every computer.
- [ ] Wipe test data and TEST guests (PCU menu, Testing, Remove test guests on TEST; nothing TEST in the real sheet).
- [ ] Set APP_LINK to the app address (code change from the section 2 checklist, or edit the constant).
- [ ] Archive the old Apps Script deployments, keep only the one in use.
- [ ] Confirm the service account has Firebase Cloud Messaging API Admin, so pushes go out (the `pushCheck` action
      answers ok).
- [ ] Phone numbers for every worker in the Workers tab (Nudge on WhatsApp).
- [ ] Delete the unused `ALLOW_MOCK_TOKENS` Script Property.
- [ ] Only real workers in the Workers tab, with the right Role and Active.
- [ ] The HOD's approval to switch.

## 8. Rollback for each step

| Step | Rollback |
| --- | --- |
| Script Properties set | Delete or restore the previous values |
| `pcuFirestoreCheck`, migration | Firestore data can be deleted and migrated again; the sheet is never deleted from |
| Sync columns | Delete SYNCED AT and SYNC KEY (every guest is then sent again, harmless) |
| Triggers | Delete them on the Triggers page (auto-assign puts its three back within 5 minutes; delete `assignBackup` and the others in one go if you must stop it) |
| clasp push to the real script | Push the previous commit, or restore a version in the editor (Project history) |
| Web app deployment update | Edit the deployment and pick the previous version |
| App build with the new exec URL | `firebase hosting:clone pcu-workflow:@<previous version> pcu-workflow:live --project pcu-workflow` |
| Firebase option B | Point the app back to `pcu-workflow` and redeploy the previous hosting version |

## 9. Ideas parked for later

**Passwordless email sign-in.** Google sign-in does not load on some networks, such as Glo. Firebase email link
sign-in, or a one-time code by email, would let a person in the Workers tab sign in with their email only. The rules
already key everything on the verified email, so the database side does not change; the login screen and the auth
repository would. It needs testing on Glo before it replaces anything.

**Hosting on Vercel.** The Firebase site does not load well on some networks. Serving the same `build/web` from Vercel
changes the app address (update APP_LINK, the share links, and add the new domain to Firebase Authentication's
Authorized domains). Nothing changes in the Apps Script API or in Firestore.

**Android and iOS apps.** See `docs/MOBILE.md` and the GitHub Actions workflows in `.github/workflows/android.yml` and
`.github/workflows/ios.yml`.

## 10. Day of go-live, from a phone

1. Tell the workers the time; ask them to save their calls before then.
2. HOD: open the app, tap Sync to sheet, wait for "Synced ...".
3. In the real sheet, Extensions, Apps Script: check the Script Properties are set (section 2).
4. Run `pcuFirestoreCheck`, then `pcuSetupSyncColumns`, then `pcuMigrate` until "done".
5. Run `pcuInstallFirestoreTriggers`, then PCU menu, Auto-assign, Check status, then `pcuSetupLeaderboard`.
6. Ask the agent to push the code and update the one deployment, rebuild the app with the real exec URL and deploy it.
7. HOD: sign in, tap Sync to sheet once (installs the nightly triggers).
8. Submit one test form entry; watch it get assigned and appear in the app; then delete that row.
9. Check the Triggers page shows all nine triggers.
10. Tell the workers they can start. If anything is wrong, use the rollback for that step (section 8).
