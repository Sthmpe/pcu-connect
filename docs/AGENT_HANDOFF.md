# PCU Connect: handoff guide for coding agents

This is the single source of truth for any agent (Claude, Codex, Gemini CLI or another) taking over. It is written from
the repo on branch `phase-1-firestore` (2 November 2026). Commands marked **verified** were run while writing this
guide; anything marked **not verified** was not run (usually because it changes production or needs a sign-in).
Never write a secret, key or token into any file; this guide only names where they live.

## 1. The product

PCU Connect is the follow-up app of the Pastoral Care Unit (PCU) of COZA Ilorin. First-time guests fill a Google Form;
each guest is assigned to a worker, who calls them, logs the call, and keeps going until the guest becomes a member.

- **Workers** see Today (their to-do list), their Guests, Ranking and Me. They call or WhatsApp guests and log each
  follow-up.
- **The HOD (admin)** sees the Dashboard, Team, all Guests and Me: assigns and redistributes guests, nudges workers,
  edits WhatsApp messages and syncs to the sheet. Admins never receive guests.

Business rules (do not change them without the owner):

- **Services:** Sunday and Wednesday. All days and months use Africa/Lagos time.
- **Member rule:** 4 Sundays, or 3 Sundays and 2 Wednesdays, in one calendar month.
- **Statuses:** New guest, Contacted, Returning, Member, Not interested, Unreachable. Order of precedence on each save:
  Member (rule met, never goes back) > Not interested > Returning (attended a service) > Contacted (reached once) >
  Unreachable (3 calls without reaching) > unchanged. Same rules in `lib/domain/follow_up_rules.dart` and
  `pcuNextStatus_` in `backend/Api.gs`.
- **Call outcomes:** Reached, No answer, Busy, Switched off, Wrong number, Not interested.
- **Attendance:** a follow-up can mark Sunday and Wednesday attendance with a past date; the first visit counts.
- **Points** (per worker per month): first call within 3 days of the visit +10 (later +5); each other follow-up +5; each
  attendance +10; first team join (Workforce or Evangelism) +20; guest becomes a member +30.
- **Go-live date:** `2026-10-28` (`GO_LIVE` in `backend/pcu_auto_assign.gs`, `AppConfig.chaseFrom` in the app). Only
  guests from that day are chased by Today and the reminder.
- **Today** (`lib/domain/today_rules.dart`, constants in `lib/core/constants/work_rules.dart`): the worker's own guests
  since go-live, in four sections. New: never called, at most `OUTSTANDING_AFTER_DAYS` (3) days since the visit.
  Outstanding: never called, more than 3 days. Retry: last outcome in `NO_ANSWER_OUTCOMES` (No answer, Busy, Switched
  off), at least `RETRY_AFTER_DAYS` (1) day ago, fewer than `MAX_RETRIES` (3) calls. Follow-up due: called, status not
  in `NO_FOLLOWUP_STATUSES` (Member, Not interested, Unreachable), no call for `FOLLOWUP_DUE_AFTER_DAYS` (7) days.
  `ATTENTION_AFTER_DAYS` (7) turns the HOD's Needs attention line red.

## 2. Architecture and data flow

```
Google Form ──> Form Responses 1 (sheet) ──assignOnSubmit / assignBackup──> ASSIGNED TO (sheet owns assignment)
                       │                                                      │
                       │ every 5 min: pcuPushPendingGuests (sheet-owned fields, and users from the Workers tab)
                       v                                                      │
                 Firestore (live database) <──── Flutter web app (workers, HOD) ──── Apps Script web app (admin actions)
                       │                       reads/writes with Firebase Auth      health, nudge, assignRange,
                       │                       and security rules                   redistribute, syncNow, saveWorker...
                       │ 00:05 nightly pcuNightlySync, or the HOD's "Sync to sheet"
                       v
                 Follow-ups tab + Firebase-owned columns of Form Responses 1
```

- **Flutter web app** (`lib/`): BLoC, feature-first clean architecture. In Firestore mode
  (`--dart-define=DATA_SOURCE=firestore`, the live build) it reads Firestore directly and saves a follow-up as one
  batch (follow-up, guest work fields, ranking entry). It calls Apps Script only for admin actions.
- **Apps Script** (`backend/`, bound to the sheet, one web app deployment): assignment, sheet and Firestore sync,
  admin-only actions. Talks to Firestore through its REST API with a service account. No Cloud Functions.
- **Field ownership.** The sheet owns: GUEST ID, FULL NAME, PHONE NUMBER, GENDER, SERVICE DATE, ASSIGNED TO, ASSIGNED
  DATE (copied to Firestore every 5 minutes). Firebase owns the work: CALL STATUS, MEMBERSHIP STATUS, feedback and
  dates, FOLLOW-UP COUNT, TEAM JOINED, MEMBERSHIP DATE, attendance, points (written to the sheet nightly). The sync never
  writes ASSIGNED TO, name or phone.
- **Roles:** the Workers tab (`Role` = Worker, or Admin/HOD; `Active` = Yes/No) is copied to Firestore `users/{email}`
  with `role` `worker` or `admin`. The rules and the app read the role from there. Sign-in is Google (Firebase Auth);
  the email must be verified and active in users.
- **Firestore collections:**
  - `users/{email}`: id, name, email, phone, role, active. Subcollections `notifications/{id}` (title, body, tag, link,
    read, createdAt) and `tokens/{token}` (web push).
  - `guests/{guestId}`: name, phone, gender, serviceDate, month, assignedTo, assignedName, assignedDate, sheetRow, and
    work fields callStatus, membershipStatus, followUpCount, firstCallAt, lastFeedback, lastFeedbackDate, teamJoined,
    memberSince, sundayDates[], wednesdayDates[], lastFollowUpId, updatedAt, syncedToSheetAt.
  - `followUps/{id}`: guestId, worker (credited), loggedBy, callDate, month, outcome, note, attendedSunday, sundayDate,
    attendedWednesday, wednesdayDate, team, points, syncedToSheet, createdAt.
  - `rankings/{month}/entries/{email}`: email, name, points, lastFollowUpId, updatedAt.
  - `meta/sync`: lastSheetSyncAt, lastResult, running, sheetUrl.
  - `config/messageTemplates`: thanks, missedCall, checkIn, nudge, updatedAt, updatedBy.
  - `nudges/{id}`: worker, sentBy, sentAt, channel (`app` or `whatsapp`), outstanding, title, body, delivery flags.
  - `reassignments/{id}`: guestId, guestName, from, to, by, mode, at.
- **Sync both ways:** sheet to Firestore every 5 minutes for changed sheet-owned fields (fingerprint in SYNC KEY) and
  for users (fingerprint in the `USERS_KEY` property). Firestore to sheet nightly at about 00:05 (and the HOD's Sync to
  sheet): new follow-ups appended to Follow-ups, Firebase-owned guest columns written, follow-ups marked synced.
- **Triggers** (all check and re-install the assignment triggers): `assignOnSubmit` (form submit), `assignBackup`
  (5 min), `dailyReminder` (18:00), `pcuPushPendingGuests` (5 min), `pcuNightlySync` (00:05), `pcuNightlyRecalc`
  (00:35), `pcuWeeklySync` (Monday 01:00), `pcuRefreshLeaderboard` (hourly), `pcuSnapshotPreviousMonth` (1st, 01:00).
  Details in `docs/GO_LIVE.md` section 4.

## 3. Repo map

| Path | What it is |
| --- | --- |
| `lib/main.dart` | Startup, Firebase, repositories and cubits provided to the app |
| `lib/core/` | config (`app_config.dart`), constants (colours, sizes, icons, text styles, `work_rules.dart`), routing, network (Apps Script client), widgets (buttons, rows, badges), sync chip, install card, utils (Lagos time, launcher) |
| `lib/data/firestore/` | Firestore repositories (guests, team, notifications, push, nudges, message templates, sheet sync, mappers) |
| `lib/data/repositories/` | Apps Script repositories (auth, guests, team, assign, redistribute) |
| `lib/data/sample/` | Sample data for UI work only (`USE_SAMPLE_DATA=true`) |
| `lib/domain/` | Entities and pure rules: today, follow-up, insights (points), attention, membership progress, templates, nudge |
| `lib/presentation/` | Screens and blocs: `auth`, `worker` (Today, Guests, Ranking, Me, guest detail, log form), `admin` (Dashboard, Team, Guests, worker screens, sheets), `guests` (shared month cache), `common` |
| `test/` | Flutter unit and widget tests (`test/features`, `test/core`) |
| `backend/` | Apps Script: `Api.gs` (web app actions, sign-in check, sheet reads), `Firestore.gs` (Firestore REST, push, sync, migration, admin actions), `pcu_auto_assign.gs` (assignment, menu, reminder), `PCU Leaderboard.gs` (sheet leaderboard), `AuthTest.gs`, `appsscript.json` |
| `backend/test/` | Node harnesses with mocked Apps Script, Sheets and Firestore REST |
| `firestore.rules`, `firestore.indexes.json` | Security rules and indexes (deployed with the Firebase CLI) |
| `firestore-tests/` | Rules tests against the Firestore emulator |
| `tool/build_web.sh` | The release web build |
| `tool/web/` | `render_check.mjs`, `icon_check.mjs`, `live_release.mjs`, `api_call.mjs`, `prune_fonts.mjs`, `render_icons.mjs`, `load_test.mjs`, `sizes.mjs` (Playwright for the checks) |
| `web/` | `index.html` (bundled Firebase SDK loader, splash), service worker for push, icons, manifest |
| `android/`, `ios/`, `.github/workflows/` | Mobile shells and the GitHub Actions builds (`android.yml`, `ios.yml`) |
| `docs/` | `BACKEND_PLAN.md`, `ARCHITECTURE.md`, `GO_LIVE.md`, `MOBILE.md`, `UI_SUGGESTIONS.md`, this guide |
| `SESSION.md` | Running log of every session: what changed, what is live, rollback commands |
| `design/` | Original HTML mock-ups and the logo sources |
| `legacy/`, `supabase/` | Earlier designs (AppSheet era, Supabase), not used by the app |
| `.devcontainer/` | Codespace setup: Flutter, Firebase CLI, 4 GB swap |

## 4. Environments and identifiers (not secret)

| Item | Value |
| --- | --- |
| Firebase project | `pcu-workflow` |
| Live site | https://pcu-workflow.web.app |
| Preview channel | `firestore-test`: https://pcu-workflow--firestore-test-3a07ufkq.web.app |
| Apps Script script ID (TEST) | `15zMOA22UDlVbS4jeBIq5pQ7K6cBvzoalGX6sviiewxhqCJb2PbfdG8hL` (`.clasp.json`, rootDir `backend`) |
| Apps Script deployment (the only one to update) | `AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u` |
| Exec URL | `https://script.google.com/macros/s/AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u/exec` |
| TEST sheet ID | `1R9-l3GOw_NY8qIvn94mM3ZFxBpuuDl7lwSEnumdFU24` |
| Live Hosting release | `62471d389bc46c72` (2 November 2026); `node tool/web/live_release.mjs` prints the current one |
| Rollback | `firebase hosting:clone pcu-workflow:@475580cbd5acff07 pcu-workflow:live --project pcu-workflow` (the release before) |
| GitHub | https://github.com/Sthmpe/pcu-connect, working branch `phase-1-firestore` |

Secrets, by location only: `FIRESTORE_SA_KEY` and `FIREBASE_WEB_API_KEY` in the Apps Script Script Properties; the
clasp login in `~/.clasprc.json`; the Firebase CLI login in `~/.config/configstore/firebase-tools.json`. Never commit,
print or copy them.

## 5. How to do everything

Proved from a fresh clone of GitHub on 2 November 2026: `flutter pub get`, `flutter analyze` (no issues),
`flutter test` (242 pass), the three backend harnesses (all pass), `firestore-tests` `npm ci && npm test` (68 pass),
and `tool/web` `npm ci`, `npx playwright install chromium`, `node render_check.mjs` on the live site (no page errors).

Toolchain used (verified): Flutter 3.47.9 (Dart 3.13.7), Node 22, OpenJDK 21 (rules emulator), Firebase CLI 15.34.2,
clasp 3.4.1. In a Codespace, `.devcontainer/setup.sh` installs Flutter and the Firebase CLI.

```bash
flutter pub get                                  # verified
flutter analyze                                  # verified: No issues found
flutter test                                     # verified: all pass
node backend/test/pcu_api_harness.js backend/Api.gs        # verified: ALL PASSED
node backend/test/pcu_firestore_harness.js                 # verified: ALL PASSED
node backend/test/pcu_equivalence_harness.js               # verified: ALL PASSED (needs git history: commit 472bccc)
(cd firestore-tests && npm ci && npm test)                 # verified: needs Java 21; all pass
(cd tool/web && npm ci && npx playwright install chromium) # once, for the render checks
```

Build the live (Firestore mode) web app (verified):

```bash
tool/build_web.sh --dart-define=DATA_SOURCE=firestore \
  --dart-define=APPS_SCRIPT_URL=https://script.google.com/macros/s/AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u/exec
```

Other dart-defines: `USE_SAMPLE_DATA=true` (UI work only), `ENABLE_MOCK_LOGIN=true` (debug sign-in buttons; the
deployed script refuses mock tokens anyway), `FCM_VAPID_KEY` (override the public push key).

Deploy and check (verified, they change only the preview or need the owner's permission for live):

```bash
firebase hosting:channel:deploy firestore-test --project pcu-workflow --expires 30d   # preview
(cd tool/web && node render_check.mjs https://pcu-workflow--firestore-test-3a07ufkq.web.app)
node tool/web/live_release.mjs                     # note the current live release in SESSION.md first
firebase deploy --only hosting --project pcu-workflow   # LIVE: only with the owner's explicit permission in the chat
(cd tool/web && node render_check.mjs https://pcu-workflow.web.app && node icon_check.mjs https://pcu-workflow.web.app)
firebase hosting:clone pcu-workflow:@<previous version> pcu-workflow:live --project pcu-workflow   # rollback
firebase deploy --only firestore:rules --project pcu-workflow
firebase deploy --only firestore:indexes --project pcu-workflow
```

Apps Script:

```bash
clasp login --no-localhost        # only if not signed in (prints a URL; the owner signs in and pastes the code)
clasp push -f                     # verified
clasp deploy -i AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u -d "<label>"   # verified
```

Mobile: push to GitHub; the workflows in `.github/workflows/android.yml` (debug APK, Firestore mode) and `ios.yml`
build on GitHub Actions (there is no Android SDK in the Codespace). See `docs/MOBILE.md`. (Not re-run for this guide.)

## 6. Rules every agent must follow

- Brand: navy `#0B1F3A`, gold `#E3B341`, Rubik. Reuse the existing widgets (`AppButton`, `AppIconButton`, `AppCard`,
  `GroupedCard`, `GuestRow`, `AppPill`, `SectionLabel`) and sizes from `AppSizes`; do not invent new looks.
- No em dashes in any text (code comments, UI, docs, commits).
- GetX only for snackbars and dialogs (`AppFeedback`). State is BLoC/Cubit. Feature-first clean architecture.
- Sizes go through ScreenUtil (`.r`); the text scale is clamped in `responsive_web_shell.dart` (web 0.75 to 0.9,
  mobile 0.85 to 1.05).
- Say "sync" in UI text for anything syncing.
- Update the UI with every backend change; keep both data sources working where simple and list gaps.
- Never create a new Apps Script deployment (it changes the exec URL); always `clasp deploy -i <the one ID>`.
- Never run `clasp logout`, never log out of anything.
- Commit and push after each numbered step, even if not perfect.
- Never commit secrets (`~/.clasprc.json`, key files, tokens).
- Production deploys (live Hosting, real sheet changes) need the owner's explicit permission in the chat.
- The owner works from a phone: run every command yourself and ask only for sign-ins or approvals.
- Do not change the points or status rules. All dates in Africa/Lagos.

## 7. Current state

Built and live (site `62471d389bc46c72`, Apps Script @29): Today with four sections and the daily ring; Guests with
search, All months and outstanding indicators; guest detail with WhatsApp templates, membership calendar and the
"How did the call go?" sheet; Ranking; Me with milestones; HOD Dashboard (Needs attention, Top workers, trend chart,
unassigned guests card, sheet sync banner), Team, Assign guests, Redistribute, Nudge and Nudge on WhatsApp, outstanding
by worker; notifications (bell, push when the service account role allows); always-on auto-assign with a 5-minute backup;
health report; mock tokens removed.

Known gaps and open items: the go-live checklist in `docs/GO_LIVE.md`; the hard-coded environment values listed there;
`lib/core/config/app_config.dart` still has a comment saying the backend honours `ALLOW_MOCK_TOKENS` (it does not);
Apps Script mode lacks some Firestore-only features (sync chip, nudge history, trend calls); 2 TEST guests are assigned
to the admin (G09200, G09203); W006's name in the Workers tab is "david".

Decision log:

| Decision | Why |
| --- | --- |
| Firestore as the live database | The sheet was too slow for the app (seconds per read) and cannot work offline |
| The sheet still owns assignment and guest details | The HOD and the form already live in the sheet; one owner per field means no conflicts |
| Nightly sync to the sheet (plus Sync to sheet) | The sheet is for reports; saving straight to it made every save slow |
| No Cloud Functions | Free plan, and Apps Script already runs on the sheet with a service account |
| Always-on auto-assign with a 5-minute backup | A switched-off trigger silently left guests unassigned; the form trigger does not fire for every row |
| Redistribute only moves guests never called; waiting time stays from the service date; calls and points stay | Fairness to the worker who called, and the points rules stay unchanged |
| Mock tokens removed from the deployed script | The TEST sheet holds real names and phone numbers |
| Trend chart from the dashboard's own data | Separate count queries failed silently on the web |

## 8. Pitfalls already hit

- **Apps Script authorization:** new scopes (external requests, mail, triggers) need the owner to run a function once
  in the editor and approve; until then triggers fail with "authorization required".
- **A new deployment changes the exec URL:** the app then calls a dead URL. Always update the existing deployment.
- **The form trigger does not fire for rows written by a script or the Sheets API:** the 5-minute `assignBackup`
  covers them.
- **Firestore silently leaves out documents missing a queried or ordered field:** every query was audited
  (`docs/BACKEND_PLAN.md`, Query audit); keep new fields present on every document.
- **Month defaults hid data:** on 1 November every screen opened on an empty November; Guests now opens on All months.
- **clasp refuses a `rootDir` outside the project file's folder:** keep project files at the repo root.
- **Codespace memory and idle timeout:** the first Flutter build was killed without the 4 GB swap
  (`.devcontainer/swap.sh`); long builds can be cut by the idle timeout, so rerun them.
- **Production deploys were blocked until the owner granted permission in the chat.**
- **Tests:** `pumpAndSettle` never ends while a pulsing dot animates (use fixed pumps); widget tests that lay out the
  app need a phone-sized view (390 by 844) because of ScreenUtil.
- **Expired Firebase CLI token:** REST helpers return empty or 401; run any `firebase` command to refresh it.

## 9. Resuming after a stopped session

```bash
git status && git branch --show-current     # expect phase-1-firestore
git log --oneline -15
sed -n '1,40p' SESSION.md; tail -80 SESSION.md
```

First 10 minutes for a new agent:

1. Read this guide and the end of `SESSION.md`.
2. `git pull` on `phase-1-firestore`; check `git status` is clean.
3. `flutter pub get && flutter analyze && flutter test`.
4. Run the three backend harnesses and, if Java is there, the rules tests.
5. `node tool/web/live_release.mjs` to see what is live.
6. `clasp status` to confirm the clasp login (do not log out).
7. Read the owner's latest request in full; plan by numbered step.
8. Work step by step, commit and push after each.
9. Before any live deploy: ask for permission, note the live release in `SESSION.md`, keep the rollback ready.
10. End with a short report: what changed, what is live, the rollback command, anything the owner must do.
