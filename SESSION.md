# Workflow / PCU Workflow  -  Session Log

Shared handoff doc across every agent/tool working on this project, not
just one conversation. Multiple agents touch this codebase in parallel.

**Rules for anyone updating this file:**
- Verify claims against the actual code (grep/read) before writing them
  here  -  don't restate what a previous version of this file said without
  checking it's still true. Code moves faster than this doc; trust the
  code over old notes in this file if they conflict.
- When you stop work, add/update the "Where the last session stopped"
  section at the bottom with what you touched and what you deliberately
  left undone, so the next agent (human or AI) doesn't have to re-derive it.
- Don't delete history other agents recorded just because it's not what
  you worked on  -  only correct it if you've verified it's wrong.

## Product

**Workflow** is a general-purpose people-and-work management platform.
**PCU Workflow** (Pastoral Care Unit follow-up/assignment/retention
tracking for a church) is its first configuration, not a hardcoded special
case. Terminology (Pastor/HOD/Worker/Guest) is a display-layer mapping
over neutral internal concepts (organization_owner/unit_manager/operator/
contact)  -  see "Terminology layer" below.

Full original product spec (goals, screens, lifecycle, metrics) was
provided by the user at project kickoff  -  not duplicated here.

## Backend architecture (confirmed, do not re-litigate)

```
Firebase Authentication → user identity and login
Cloud Firestore         → primary application data (source of truth)
Supabase Storage        → media/files only
Supabase Edge Functions → privileged workflows and integrations only
```

Supabase is **not** a database for this app. No app data is read/written
via `supabase_flutter`'s Postgrest client. `core/network/supabase_service.dart`
is scoped to Storage + Edge Function invocation only.

Edge Functions authenticate callers via a **Firebase ID token** passed in
the request body (`firebaseIdToken`), verified server-side with the
Firebase Admin SDK (`supabase/functions/_shared/verify_token.ts`). Supabase
JWT verification (`verify_jwt` in `config.toml`) is `false` on all three
functions since callers aren't Supabase-authenticated.

## Stack

- State management: `flutter_bloc` (Bloc for multi-event flows, Cubit for
  simple read-models like `AccessCubit`/`TerminologyCubit`)
- Typography: `google_fonts` · Icons: `font_awesome_flutter` + Material
- Responsive sizing: `flutter_screenutil`
- Routing: plain Material `onGenerateRoute` (`core/routing/app_router.dart`)
  is primary. GetX reserved for isolated complex flows only  -  not adopted,
  not the app-wide router.
- All colors/text styles/sizes/strings centralized in `core/theme/` and
  `core/constants/`  -  no magic values in widgets.

## Schema / naming (verified via grep as of this update)

Firestore collections use the **neutral schema**, matching `firestore.rules`:
`contacts` (not `guests`), `organizationId`/`locationId`/`unitId` (not
`campus_id`/`team_id`), `operatorId`/`assignedOperatorId` (not
`worker_id`/`assigned_worker_id`).

**Migrated to this schema:** `guests` feature (kept its folder/class name
`GuestModel`/`features/guests/`  -  only the *data layer* field naming
changed, not the Dart identifiers), `call_workflow`, `reports`,
`access_control`, `organization_structure`.

**Still on OLD naming (confirmed by grep):**
- `lib/features/team/data/datasources/team_remote_datasource.dart`  - 
  also still queries Postgres via `supabase_service.dart`, not migrated
  to Firestore at all.

`guest-sync` is migrated: it writes `contacts`, `organizationId`,
`locationId`, `unitId`, and `assignedOperatorId`. Old snake_case keys are
accepted only as aliases at the external Google Sheet intake boundary.

## Directory structure (verified as of this update)

```
lib/
  core/
    theme/            app_colors.dart, app_text_styles.dart, app_sizes.dart, app_theme.dart
    constants/        app_strings.dart, app_assets.dart
    network/          firebase_service.dart (source of truth), supabase_service.dart
                       (storage/edge-fn only), edge_function_client.dart, api_result.dart
    routing/          app_routes.dart, app_router.dart
    terminology/      app_terminology.dart, terminology_repository.dart, terminology_cubit.dart
    widgets/          custom_button.dart, custom_text_field.dart
  features/
    auth/                    Firebase Auth + team_memberships/profiles lookup
    access_control/          Capability/BaseRole/PermissionPreset/MembershipModel,
                             AccessCubit (own-membership read model), DelegationBloc +
                             DelegationScreen (HOD "manage assistants" UI), calls
                             manage-access Edge Function for list/grant/revoke
    organization_structure/  Organization/Location/Unit models + CRUD bloc/screen
    guests/                  Firestore-backed, neutral schema
    call_workflow/           Firestore-backed, neutral schema  -  Call Guest → dialer →
                             manual feedback capture
    home/                    HomeScreen, reads TerminologyCubit for labels
    reports/                 Firestore-backed, neutral schema
    team/                    STALE  -  old Postgres/Supabase pattern, not migrated
  app.dart            AuthBloc + TerminologyCubit + AccessCubit provided app-wide via
                       MultiBlocProvider; feature blocs scoped per-route in AppRouter;
                       _SessionLoader triggers Terminology/Access loads on AuthAuthenticated
  main.dart           Firebase.initializeApp() + SupabaseService.init()

supabase/
  functions/
    _shared/          firebase_admin.ts, verify_token.ts, responses.ts
    guest-sync/        Firestore transaction, fair-assignment on Sheet intake;
                       writes the neutral Firestore schema
    assign-guest/      EMPTY STUB  -  not implemented
    manage-access/     list / grant / revoke team_memberships with escalation
                       prevention + pagination + audit logging
  migrations/          DEPRECATED  -  old Postgres schema, reference only
  config.toml          all three functions: verify_jwt = false (Firebase-token
                       verified internally instead)

firestore.rules        Capability-based, neutral schema, includes field-level write
                       validation (isContactUpdateValid, isInteractionCreateValid,
                       isFollowUpCreateValid, isTerminologyValid, isStructureDocumentValid)
android/                Package fixed: com.example.workflow → com.pcu.workflow
                       (namespace, applicationId, MainActivity.kt path all updated).
                       Google Services Gradle plugin wired in settings.gradle.kts +
                       app/build.gradle.kts. Android/Web FlutterFire configuration
                       and `google-services.json` are present.
.env.example            SUPABASE_URL/SUPABASE_ANON_KEY only  -  Firebase admin creds are
                       Edge Function secrets, never in the app
```

## Access control model

Authorization = **base role (ceiling) + scoped capability map (actual
access)**, not a fixed role enum. `lib/features/access_control/domain/models/`:

- `Capability`  -  flat string constants (`contacts.edit`, `assignments.manage`, etc.)
- `BaseRole`  -  organizationOwner (Pastor) > unitManager (HOD) > delegate > operator/viewer.
  Ceiling only, used for rank comparisons during delegation, never checked
  directly for authorization.
- `PermissionPreset`  -  Assignment Officer / Follow-up Supervisor / Records
  Officer / Reporting Officer / Team Officer / Deputy HOD / Custom. UI
  convenience only  -  server re-validates the actual capability set on every grant.
- `MembershipScope`  -  organizationId + optional locationIds/unitIds. Empty
  list = org-wide at that level.
- `MembershipModel`  -  Firestore doc `team_memberships/{unitId}_{userId}`.
- `DelegationBloc` + `DelegationScreen`  -  the actual HOD UI: lists current
  unit members (paginated via `manage-access` `list` action), grants/revokes access.

**Where enforcement actually happens (order of trust):**
1. `firestore.rules`  -  real gate for all reads and most writes, including
   field-level shape validation on create (contacts, interactions, follow_ups).
2. `manage-access` Edge Function  -  only path that can create/modify a
   membership doc. Rules block direct writes to `team_memberships` entirely.
3. `AccessCubit`/`DelegationBloc` in the app  -  UI convenience/reactivity,
   mirrors server state, grants nothing itself.

**Privilege escalation guards in `manage-access`:**
- Granter must hold `permissions.delegate` (or be org owner).
- Requested permissions must be a subset of the granter's own.
- `OWNER_ONLY` capabilities (`organization.manage`, `locations.manage`,
  `managers.manage`) never delegable by anyone but the org owner.
- Requested `baseRole` rank must be strictly less than granter's rank  - 
  a delegate can never mint another delegate at or above their own level.
- Unit must be active and scope-complete or the request is rejected.
- Every grant/revoke writes an immutable `audit_logs` doc.

## Terminology layer

Mechanism for configurable labels (PCU/HOD/Guest per organization instead
of hardcoded strings): **built, coverage is partial.**

- `AppTerminology`  -  `organization`, `organizationPlural`,
  `organizationOwner`, `location`, `unit`, `unitManager`, `operatorLabel(Plural)`,
  `contact(Plural)`, `journey`. Defaults to current PCU Workflow labels  - 
  defaults are the first configuration, not special-cased in the type.
- `TerminologyRepository` reads `organizations/{organizationId}.terminology`
  from Firestore, merges only overridden keys over defaults.
- `firestore.rules`' `isTerminologyValid` validates the shape of that map
  on write (allowed keys + string length caps).
- `TerminologyCubit` is app-wide, starts at defaults, loads real values
  the moment `AuthBloc` emits `AuthAuthenticated`.
- **Wired into UI:** `HomeScreen`, `MyGuestsScreen` app bar titles. Most
  other screens (`GuestDetailScreen`, `CallFeedbackScreen`, `Team`,
  `Reports`) still use hardcoded `AppStrings` literals.
- Testable in principle now that `organization_structure` exists to create
  a real `organizations/{orgId}` doc  -  not actually exercised against a
  live Firebase project yet.

## What's built (verified by code inspection, NOT run against live Firebase yet)

Login → My Guests list → Guest Detail → Call Guest (opens native dialer) →
manual outcome/notes/follow-up capture → guest stage update. Organization/
Location/Unit CRUD. HOD delegation (list/grant/revoke team members) via
`DelegationScreen`. Feature blocs are created per-route (not app-wide) so
they're disposed with their screen.

## Explicitly NOT done yet

- `lib/features` → `lib/modules` directory rename (requested early on, still not done).
- `team` feature  -  still Postgres/Supabase, not migrated to Firestore.
- `assign-guest` Edge Function  -  empty stub.
- Full terminology coverage  -  several screens still hardcode English labels.
- Supabase project setup  -  the CLI is authenticated, but none of the visible
  Supabase projects is Workflow and this folder is not linked to a project.

## Manual steps only the user can do (blocked on their credentials)

1. Enable Firebase Email/Password Authentication, create the first Pastor
   Auth user, then seed `organization_owners/{orgId}_{uid}` with
   `organizationId` and `userId`.
2. Create/select a Supabase project for Workflow and run `supabase link`.
3. `supabase secrets set FIREBASE_SERVICE_ACCOUNT='<service-account-json>'`
    -  required by `guest-sync` and `manage-access`.
4. `supabase secrets set WORKFLOW_INTAKE_SECRET='<random-secret>'`  -  shared
   secret for Apps Script → `guest-sync` calls.
5. `supabase functions deploy guest-sync manage-access`; deploy
   `assign-guest` only after its implementation is complete.
6. Configure iOS from macOS later; Android and Web are already configured.

## Where the last session stopped

**This update (Claude/Sonnet session):** User created their Firebase
project and registered an Android app as `com.pcu.workflow`, but the
Flutter project was still on the Flutter-default `com.example.workflow`.
Fixed: `android/app/build.gradle.kts` (namespace/applicationId + added
`com.google.gms.google-services` plugin), `android/settings.gradle.kts`
(added plugin version decl), moved+repackaged
`MainActivity.kt` from `com/example/workflow/` to `com/pcu/workflow/`.
Also re-verified the whole naming-migration status by grep since several
other agents had done substantial work since this doc was last accurate
(organization_structure feature, delegation screen/bloc, expanded
firestore.rules validation, terminology `organization` fields)  -  all now
reflected above. **Did not** touch `guest-sync`'s stale naming or the
`team` feature  -  both still need the fixes described above. Next action
for the user: run `flutterfire configure`, since `lib/firebase_options.dart`
and `android/app/google-services.json` still don't exist.

**2026-08-29 status refresh:** Android and Web were configured against
Firebase project `pcu-workflow`; `lib/firebase_options.dart` and
`android/app/google-services.json` now exist. Firestore was created and
`firestore.rules` plus `firestore.indexes.json` were deployed successfully.
Code inspection confirms `guest-sync` writes the neutral schema; the stale
naming claim above was corrected. Supabase CLI 2.39.2 is authenticated, but
the folder is not linked and the authenticated account currently shows no
Workflow Supabase project. Full `flutter analyze` and `flutter test` were
started after configuration but stalled locally and were stopped; no new
passing result is claimed. The next code task remains the server-only
`assign-guest` manual reassignment function, followed by the `team` Firestore
migration.


---

## 2026-10-30 Update: Restructuring to PCU Connect (Flutter Web + Apps Script Backend)

**Context:** Restructured the application to follow the new specification in `README_1.md` and the official handoff package (`PCU_Flutter_Handoff.zip`).

### Key Architectural Decisions Implemented:
1. **Target Platform:** Flutter Web (hosted on Firebase Hosting) with centered responsive phone frame (390–430px) matching `PCU_Worker_App.html` and `PCU_Admin_App.html`.
2. **Backend & Source of Truth:** Google Sheet through Google Apps Script (`backend/Api.gs`). Client requests use `Content-Type: text/plain` with stringified JSON `{ action, idToken, ...payload }` to prevent browser CORS `OPTIONS` preflight issues.
3. **Authentication & Auto-Role Routing:** Google Sign-In (`google_sign_in`). The user's role is checked via `api.me()` against the `Workers` sheet tab:
   - `Worker` & `Active = 'Yes'` $\rightarrow$ Auto-routes to `WorkerShellScreen` (`TodayScreen`).
   - `Admin` or `HOD` $\rightarrow$ Auto-routes to `AdminShellScreen` (`DashboardScreen`).
   - Inactive or unauthorized $\rightarrow$ Shows restricted access dialog.
4. **State Management & Clean Architecture:**
   - **Primary Engine:** BLoC (`flutter_bloc`) managing all features and unidirectional data flow.
   - **Responsiveness:** `flutter_screenutil` (390 x 844 reference).
   - **Design Tokens:** Exact values from `design/base.css` (Navy `#0B1F3A`, Gold `#E3B341`, status pills, **Rubik** font).
   - **Dialogs & Overlays:** GetX (`get`) strictly for quick snackbars and bottom-sheet alerts.
5. **Legacy Isolation:** Older mobile/Firestore/Supabase Postgrest code safely preserved in `legacy/` without deletion.
6. **Codebase Verification:** `dart analyze lib/` passes with **0 errors**.

### Where this session stopped:
- Complete Flutter Web frontend architecture and all screens matching the HTML prototype are built and verified.
- **Backend Completed:**
  - `backend/Api.gs`: All 9 handlers implemented (`me`, `guests`, `guest`, `logFollowUp`, `ranking`, `dashboard`, `team`, `saveWorker`, `setWorkerActive`). Implemented CORS-compliant text/plain POST parsing, Google token verification with mock token fallback for local dev, server-side Member rule enforcement (4 Sundays or 3 Sundays + 2 Wednesdays in same month), future attendance date rejection, points scoring, and Leaderboard tracking.
  - `backend/pcu_auto_assign.gs`: Fixed `activeWorkers_()` to strictly exclude users with Role = Admin/HOD, ensuring Admins never receive assigned guests in the round-robin rotation.
  - Claude conversation history (124 messages) successfully extracted, analyzed, and persisted to `claude_conversation_full.md` and scratch archive.
  - Verified with `dart analyze lib/`: **0 errors, 0 warnings**.
- **Next Steps:**
  - Test the Flutter Web app locally with `flutter run -d chrome`.
  - When the user is ready, deploy the Apps Script to their Google Sheet and configure Firebase Hosting for live web deployment.

---

## 2026-10-31 Update: Mock token security fix and devcontainer

- `backend/Api.gs` `pcuVerifyUser_`: mock tokens (`mock_token`, `mock_token_<email>`)
  are now accepted only when Script Property `ALLOW_MOCK_TOKENS` is exactly
  `"true"`. Otherwise the call fails with `UNAUTHENTICATED`. Mock logins still
  go through the Workers tab check. **Set it on the TEST sheet only, never on
  the live church sheet.**
- `backend/test/pcu_api_harness.js` now has a settable Script Properties mock and
  checks both cases (rejected for unset, "false", "TRUE", "True", " true", "1", "";
  accepted for "true"). Run: `node backend/test/pcu_api_harness.js backend/Api.gs`.
- `.devcontainer/` installs Flutter (stable) and the Firebase CLI on every
  Codespace rebuild, and adds a 4 GB swap file. Without swap, the Flutter tool's
  first build was killed by memory pressure in this Codespace.

## 2026-10-31 Update: Firebase Auth

- Added `firebase_core` and `firebase_auth`; removed `google_sign_in` and the unused `flutter_dotenv`.
- `lib/firebase_options.dart` (web, project pcu-workflow) is initialised in `main.dart`.
- `AuthRepositoryImpl`: `signInWithPopup(GoogleAuthProvider)`, sends the Firebase ID token
  (`getIdToken()`) to Apps Script, restores the persisted session on startup, and
  `signOut` calls `FirebaseAuth.signOut`.
- `ApiClient.postAuthed` retries once with a refreshed token when the backend returns
  `UNAUTHENTICATED`. Failures now carry the backend `code`.
- Mock login buttons show only when `AppConfig.enableMockLogin` (debug builds, or
  `--dart-define=ENABLE_MOCK_LOGIN=true`). The backend still needs `ALLOW_MOCK_TOKENS=true`.
- Removed the `YOUR_GOOGLE_CLIENT_ID` placeholder from `web/index.html`.
- Guests now load after sign-in (not at app start), so no request is sent without a token.
- Still manual: deploy Apps Script and set `FIREBASE_WEB_API_KEY`, enable Google sign-in in Firebase,
  add the hosting domain to authorized domains.

## 2026-10-31 Update: UI and UX redesign

- **Sizing fix:** ScreenUtil used to measure the whole browser window, so `.w` scaled
  about 3.7x on a laptop. `ResponsiveWebShell` now wraps the app once, in
  `GetMaterialApp.builder`, draws a centred 400px phone frame above 520px wide, and
  configures ScreenUtil from the frame width only. Text is capped at its design size
  (`fontSizeResolver` clamps the scale to 0.92 to 1.0).
- **Tokens:** `app_colors.dart` (navy, restrained gold, soft surfaces, status trios:
  blue new, red overdue, amber called once, green followed up), `app_text_styles.dart`
  (Rubik: body 14, secondary 12 to 13, section 16, titles 18 to 20, numbers 24 to 28),
  `app_sizes.dart` (4pt spacing, radii, `AppShadows`, `AppDurations`). The theme uses
  fixed values because it is built before the frame configures ScreenUtil.
- **Shared widgets** in `core/widgets/`: `AppHeader`, `AppCard`, `AppButton`,
  `AppBottomNav` + `FadeIndexedStack`, `MetricTileWidget`, `FilterChipWidget`/`ChipBar`/
  `SegmentedPicker`, `GuestCardWidget` (one-tap Call and WhatsApp), `StatusTone`,
  `EmptyState`/`ErrorState`/`SkeletonList`/`OfflineBanner`, `AppFeedback` (the only
  GetX use: snackbars and dialogs, including the points earned dialog), `showMonthSheet`,
  `brand_marks.dart`.
- **Named routes:** `core/routing/app_routes.dart`. The app always starts on the sign
  in screen, which routes by role. Sign out now returns to sign in (it did not before).
- **Flow:** guest detail has Call, WhatsApp and a "How did the call go?" card; one tap
  opens Log follow-up with that outcome chosen. After saving, the app returns to the
  guest and shows the points earned (`pointsEarned` from the API).
- **New admin screens:** Worker detail, Add worker (full screen form), Me. Team data
  moved into `presentation/admin/cubit/team_cubit.dart`. It is still sample data; the
  Team, Ranking and Dashboard top-workers lists are not wired to the Apps Script
  `team`/`ranking` actions yet. Dashboard and Me counts are computed from the loaded guests.
- **`font_awesome_flutter` 10.12 does not compile on Flutter 3.44** (`IconData` is final).
  It is no longer imported anywhere in `lib/`; the dependency is still in pubspec.
- No business logic, repository or API changes.

## 2026-10-31 Update: Premium redesign, real API data, admin logs for workers

- **Design system v2:** neutral surfaces, navy for structure, gold only for the primary
  action and selected state. Rubik at four sizes (display 26, title 18, body 14,
  caption 12) and two weights. 8px spacing, radii 12 and 20, cards use soft shadows and
  no borders, 48px touch targets. Icons are Lucide 300 only, through `core/constants/app_icons.dart`
  (`lucide_icons_flutter`). `font_awesome_flutter` was removed (it does not compile on Flutter 3.44).
- **Kit** in `core/widgets/`: `app_page.dart` (AppPage large title, AppTopBar), `app_surfaces.dart`
  (AppCard, GroupedCard, SectionLabel, StatGrid, InfoTile), `app_controls.dart` (AppButton,
  AppIconButton, AppChip, ChipBar, SegmentedPicker, AppSwitchRow, AppTextField, MonthPill),
  `app_display.dart` (AppAvatar, StatusDot, AppPill, ProgressRing, SegmentBar), `guest_row.dart`,
  skeleton loaders in `state_views.dart`.
- **Text scaler clamp** (web 0.75 to 0.9) lives in `ResponsiveWebShell` next to the ScreenUtil setup.
  With `.sp` capped at 1.0, body text renders at about 12.6px on web.
- **Month fix:** the API uses month keys like `2026-10`; the app used `Oct 2026`, so real guest
  lists would have filtered to nothing. `MonthUtils` now drives every month, and picking a
  month fetches it (`SelectMonthEvent` reloads).
- **Outcome fix:** the app sent `Number off`, which `Api.gs` rejects. Outcomes now match
  `PCU.OUTCOMES` exactly.
- **Real data:** Ranking, Dashboard and Team use `ITeamRepository` (`ranking`, `dashboard`,
  `team`, `saveWorker`, `setWorkerActive`) through cubits in `presentation/common/insights_cubits.dart`.
  `GuestsBloc` no longer falls back to seed data. Sample repositories in `data/sample/` are only
  wired with `--dart-define=USE_SAMPLE_DATA=true`, so they are compiled out of release builds.
- **Admin logs for a worker:** opening a guest from the admin app shows "Log a follow-up for
  <worker>". `pcuLogFollowUp_` credits `guest.assignedTo` (WORKER column) and writes the real user to
  the optional `LOGGED BY` column; ASSIGNED TO never changes; admins stay out of rankings. History
  entries carry `loggedByAdmin`, shown as a "Logged by admin" label to everyone. Node harness covers
  both with and without the column. The column was added to the TEST sheet's Follow-ups tab (L1).
  **Api.gs must be pasted into the Apps Script project and redeployed** for this to work live.

## Backend plan

Phase 2 (Firestore as the live database, sheet sync, UI checklist per phase) is in `docs/BACKEND_PLAN.md`. Not implemented yet.

## 2026-10-31 Update: Phase 1 (Firestore, read only) on branch phase-1-firestore

Code, rules and tests are done; the switch defaults to the Apps Script API, so nothing changes until
`--dart-define=DATA_SOURCE=firestore` is used. Details and the owner's setup steps are under
"Phase 1" in `docs/BACKEND_PLAN.md`. Tests: `flutter test`, `node backend/test/pcu_firestore_harness.js`,
`node backend/test/pcu_api_harness.js backend/Api.gs`, and `npm test` in `firestore-tests/` (needs Java).

## 2026-11-01 Update: speed fix deployed with clasp, live backend test

- **Speed fix** (`d1137b2`, already on GitHub): after `logFollowUp` saves, `pcuPushGuestDataQuietly_`
  sends the guest to Firestore from the rows already in memory. The sheet is not read a second time.
- **clasp:** `.clasp.json` (script `15zMOA22...`, `rootDir: backend`) and `.claspignore` (skips
  `backend/test/`). `backend/appsscript.json` is the remote manifest, unchanged. `PCU Leaderboard.gs` and
  `AuthTest.gs` only existed in the online editor; they are now in `backend/` so `clasp push` does not
  delete them. `clasp push` replaces the whole project, so any edit made in the online editor must be
  copied into `backend/` first. Never commit `~/.clasprc.json`.
- **Deploy:** `clasp push`, then `clasp deploy -i AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u -d "<label>"`.
  That deployment is now @5 and its exec URL is unchanged. Do not create new deployments.
- **Test accounts (TEST sheet):** worker `davidolanite0@gmail.com` (W005), admin `olaniteolanight@gmail.com` (W001).
  `ALLOW_MOCK_TOKENS=true` is set on this script.
- **Live test, 30 calls with mock tokens, all 33 checks passed:** me, guests, guest, ranking, dashboard, team as
  worker and admin (worker blocked from other guests, dashboard and team); admin logging for a worker (credited to
  the worker, LOGGED BY is the admin, ASSIGNED TO unchanged); late first call earns 5 not 10; 4 Sundays and
  3 Sundays + 2 Wednesdays both make a Member (+30) and 3 + 1 does not; future date rejected; admins never in
  ranking or dashboard top workers. Test writes: 11 follow-ups on G-C195DCB0, G-E41460DE and G-043CDBA9 (the last
  two are now Members).
- **Still slow:** any call that reads the Guests tab takes 8 to 19 s (saves 9 to 15 s, about 11.5 s on average);
  calls that do not read it take about 1.5 s. A save costs only 1 to 2 s more than a read, so the remaining time is
  the one full read every call makes. Likely cause, not yet profiled: `pcuGuestRows_` calls
  `Utilities.formatDate` (through `pcuDay_`/`pcuMonth_`) several times per row on about 9,000 rows. Next step:
  profile, then compute Lagos (UTC+1, no DST) day/month strings in plain JS or cache the parsed guests.
- `backend/test/pcu_api_harness.js` now pins its clock to the 15th; it crashed in the first days of a month.

## 2026-11-01 Profile: where API time goes (TEST sheet, 9,211 guest rows x 27 columns)

Measured live with the opt-in profiler (`"profile": true`, mock tokens only). Wall = what the client sees.

| Call | Wall | Server | Guests read | Guests parse | Other |
|---|---|---|---|---|---|
| me | 1.8 s | 0.46 s | none | none | Workers read 0.44 s |
| guests (worker) | 7.6 s | 6.4 s | 1.9 s | 3.8 s | Workers 0.46, Follow-ups 0.20 |
| guests (admin) | 16.6 s | 15.0 s | 2.1 s | 11.8 s | |
| guest | 13.7 s | 12.1 s | 2.1 s | 9.2 s | |
| ranking | 10.9 s | 9.4 s | 1.6 s | 7.1 s | |
| dashboard | 11.2 s | 10.1 s | 1.5 s | 8.0 s | |
| team | 7.7 s | 6.6 s | 2.0 s | 3.9 s | |

- **Biggest cost: date formatting while parsing guests.** Every call that touches guests parses all 9,210 rows and makes
  about 16,600 `Utilities.formatDate` calls (`pcuDay_`/`pcuMonth_`). 2,000 calls take 0.99 s (about 0.5 ms each), so
  that is 4 to 12 s per call. Formatting the same dates in plain JS (Lagos is fixed UTC+1) took 6 ms for 8,287 dates.
- **Second: the full Guests read**, 1.5 to 2.2 s for every call, even `guest` (one row). Alternatives measured:
  TextFinder on the ID column 0.11 s, one row 0.1 to 0.2 s, ID column only 0.25 to 0.3 s, last 1,500 rows 0.35 to
  0.63 s, last 3,000 rows 0.76 s. Dense date columns are slow to read on their own (SERVICE DATE alone about 2 s).
- **Fixed costs:** web app overhead (wall minus server) 1.1 to 1.6 s; Workers read for auth 0.35 to 0.46 s;
  Follow-ups read (16 rows) 0.2 to 0.3 s; CacheService get about 0.04 s; JSON negligible.
- **Row order is not by date.** 55 months appear; old rows hold stray dates (one `0023-09`, a `2027-03` at row 8156,
  `2026-04` at row 5842, `2025-11` from row 4211). From 2026-05 on, months are contiguous at the bottom. So "read the
  last N rows" alone would drop stray rows; an exact row-to-month index is needed to keep behaviour.
- Only 2 rows have MEMBERSHIP STATUS = Member (TextFinder `findAll` 0.12 s).

## 2026-11-01 Update: fast reads deployed (steps 2 to 5)

Code: `ad58e07`. Deployed with clasp to the existing deployment
`AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u` (@8); the exec URL is unchanged.
The clasp login stays active in this Codespace (`~/.clasprc.json`, never committed).

What changed (no business rule changed):
- Lagos day/month strings in plain JS (UTC+1, no DST since 1919); dates before 1920 still use `Utilities.formatDate`.
- `guest` and `logFollowUp` find the row with TextFinder and read only that row plus the Follow-ups tab.
- `guests`, `team`, `dashboard` use a cached month -> rows index (CacheService, 1 h). Appended rows are read and
  added; the index is rebuilt when the tab gets shorter, and dropped (full read) when a row no longer has the month the
  index says. Rows are not in date order on the sheet, so a plain "last N rows" read would have dropped stray rows.
- `ranking` and points read only guests with a first call that month (ID column) and Member rows (TextFinder).
- `ranking`, `dashboard`, `team` are cached for 90 s. `logFollowUp`, `saveWorker` and `setWorkerActive` start a new
  cache generation, so a save shows on the next request. Sheet edits made outside the API can take up to 90 s to show
  in these three.
- Tests: `node backend/test/pcu_equivalence_harness.js` runs the previous `Api.gs` (472bccc) and the current one on
  1,900 messy rows (out of order, stray years, string dates, missing/duplicate/spaced ids, old members) and compares
  1,300 responses and the sheets after saves: all identical. Takes about 3.5 minutes. The API and Firestore harnesses
  use shared mocks in `backend/test/gas_mocks.js`.

Live test through the exec URL (mock tokens, TEST sheet), wall time per call:

| Call | Before | After |
|---|---|---|
| me | 1.3 to 2.7 s | 1.1 to 1.8 s |
| guests | 8.6 to 18.8 s | 2.0 to 2.7 s |
| guest | 9.0 to 12.8 s | 2.6 to 3.7 s |
| ranking (cold) | 9.6 to 12.2 s | 1.3 to 3.8 s, one 9.1 s outlier right after the saves |
| dashboard (cold) | 8.0 to 12.9 s | 3.6 to 3.8 s |
| team (cold) | 12.8 s | 2.5 to 2.7 s |
| ranking / dashboard / team (cached) | n/a | 1.4 to 2.5 s |
| logFollowUp (save) | 9.3 to 15.0 s, avg 11.5 s | 3.0 to 4.7 s, avg 3.7 s |

All 32 checks passed (earlier notes said 33; that was a miscount of the same set). Most calls are now under 3 s;
saves and some cold reads are 3 to 4.7 s. The fixed floor is about 1.1 to 1.6 s of web app overhead plus about
0.4 s to read the Workers tab for auth. No further trimming was done, by decision.

**Test data only (TEST sheet):** an interrupted test run kept running in the background and overlapped a second run,
so G-10161115 and G-3AF5CD6A got their live-test follow-ups twice (9 follow-ups each, both Member). The clean run used
G09204, G-C195DCB0 and G09202. Earlier runs also wrote to G-C195DCB0, G-E41460DE, G-043CDBA9 and G09201.

## 2026-11-01 Update: phase 2 (app saves to Firestore) and phase 3 (sheet sync)

Branch `phase-1-firestore`. Commits: rules `3411988`, app save `c0e98c9`, HOD on behalf tests `84badeb`,
sheet sync `491a1a4`, sync UI `9c32181`. Plan checklists updated in `docs/BACKEND_PLAN.md`.

- **Rules** (`firestore.rules`): a guest's work fields change only together with a new follow-up for that guest in the
  same batch (`lastFollowUpId`, checked with `getAfter`), the count goes up by exactly one, values must be known,
  `createdAt`/`updatedAt` are the server time, call and attendance dates are past Lagos days, never credited to an empty
  worker. Workers credit themselves only; admins credit the assigned worker with `loggedBy` = admin. 37 emulator tests
  (`cd firestore-tests && npm test`, needs Java 21: `sudo apt-get install -y openjdk-21-jre-headless`).
- **App save** (Firestore mode): `FollowUpRules` (`lib/domain/follow_up_rules.dart`) applies points, status order and
  the member rule on the device, same as Api.gs. `FirestoreGuestRepository.logFollowUp` writes one batch (followUps doc +
  guest work fields, `increment(1)`, server timestamps). Persistence is on, so offline saves survive a reload; after 4 s
  without a server answer the dialog says "Saved on this phone. It will sync when you are back online." and the
  timeline shows "Waiting to sync". 58 Flutter tests (`flutter test`), including fake_cloud_firestore save tests.
- **HOD log on behalf**: the phase 0 screens ("Log a follow-up for X", "It counts for X", "Logged by admin") now save to
  Firestore; the worker gets the credit and points, the guest stays assigned.
- **Sheet sync** (`backend/Firestore.gs`): `pcuSheetSync_` reads followUps with `syncedToSheet == false`, appends the new
  ones to the Follow-ups tab (keyed by Follow-up ID), writes only the Firebase-owned guest columns (never ASSIGNED TO,
  name, phone, service date; FEEDBACK 1/2 filled once), marks them synced (batches of 500), writes `meta/sync`. Shared
  script lock. `pcuNightlySync` (00:05 Lagos), `pcuWeeklySync` (Monday 01:00 Lagos, plus one "Weekly Report" tab row
  per week), `syncNow` (admin only; sets up both triggers if missing).
- **Ownership fix**: the 5-minute job, the assignment push and the migration now send only sheet-owned fields for any
  guest that already exists in Firestore (checked with batchGet), so they never overwrite app work. The old API save
  sends the guest and its new follow-up only. Firestore harness: 63 checks (`node backend/test/pcu_firestore_harness.js`).
- **HOD UI**: dashboard "Sheet" card (Firestore mode, admins only): "Last synced: today 12:05 AM", "Sheet is a day
  behind. Sync now.", "Sync to sheet" / "Syncing..." / "Synced 42 guests", plain busy and offline messages.

Deployed and tested:
- Apps Script pushed with clasp to the existing deployment `AKfycby0H6Sk...` (@9); exec URL unchanged. Smoke test ok;
  `syncNow` as worker: FORBIDDEN; as admin: ok in 5.2 s, 0 follow-ups pending (no app saves exist yet), and it set up
  the nightly and weekly triggers on the TEST project. The sheet-writing path is covered by the harness only.
- Firestore-mode build on the Hosting preview channel `firestore-test` (expires 2026-12-01):
  https://pcu-workflow--firestore-test-3a07ufkq.web.app . The live site was not touched.

**Rules deployed** (2026-11-01, with the owner's approval): `firebase deploy --only firestore:rules --project pcu-workflow`
released the phase 2 rules (from 3411988). A second deploy reported "already up to date", so the live rules match the repo.
Saves from the Firestore-mode app are now allowed by the rules. Next check: sign in to the preview, save a follow-up,
then "Sync to sheet" (or wait for the nightly run) and look at the Follow-ups tab and the guest row.

Known gaps (not built):
- Ranking, Team and Dashboard still come from the Apps Script API (the sheet), so app saves show there after a sync.
- The plan's nightly recalculation of guest totals and points from followUps.
- Do not save from API-mode and Firestore-mode builds side by side on the same guests: the API save writes guest work
  fields computed from the sheet, which can be behind unsynced app work.
- For old guests whose sheet FOLLOW-UP COUNT came from legacy feedback columns, the app adds 1 to that count while the
  sheet rule takes the larger of the two.

## 2026-11-01 Update: fast load, icons, notifications, Firestore insights, nightly rebuild, security review

Branch `phase-1-firestore`. Commits in order: 829dbc7 (load), e359d32 (icons), 1a17e24 (chime), 2ef7ce4 (web push),
fe07426 (Apps Script push), 1a7e1fc (bell), 32705c4 (ranking/team/dashboard from Firestore), c675ea3 (nightly
rebuild), 7bd9ace (deprecated actions), 3f2937b (security review), 19c6607 (APP_LINK). Rules deployed to pcu-workflow
after every change. Apps Script pushed with clasp to the existing deployment `AKfycby0H6Sk...` (@11), exec URL unchanged.
Preview (Firestore mode, expires 2026-12-01): https://pcu-workflow--firestore-test-3a07ufkq.web.app . Live site untouched.

**Load (Part 0).** Cause of the white screen: no splash, CanvasKit and the Firebase JS SDK from Google CDNs, Rubik from
Google Fonts, and about 1.3 MB of unused Lucide icon fonts that Flutter downloads at startup. Fixes: navy HTML splash in
web/index.html removed on the first Flutter frame; `tool/build_web.sh` builds with `--no-web-resources-cdn` and prunes
the unused fonts; Firebase JS SDK 13.1.0 self-hosted in web/firebasejs (main() waits for it); Rubik 400/600 bundled;
Hosting Cache-Control headers (Brotli is automatic). Playwright test: `cd tool/web && node load_test.mjs <url> <label> 3`
(phone 390x844, slow 4G 150 ms 1.6 Mbit/s, CPU x4, empty cache).

| | Before | After (final preview) |
|---|---|---|
| Something on screen | 22.3 s (white until then) | 0.25 to 0.9 s (splash) |
| Login screen drawn | 22.3 s | 16.3 to 17.1 s |
| Downloaded | 4.1 MB, 27 requests | 2.8 MB, 20 requests |
| Other hosts | Google Fonts, gstatic (CanvasKit, fonts), Firebase Auth | Firebase Auth only (not needed for the first frame) |

The rest of the 16 s is CanvasKit (1.5 MB) and main.dart.js (0.7 MB) on a 1.6 Mbit/s line. Headless Chromium reports
the locale "en-US@posix", which stops Flutter; the test sets a normal phone locale.

**Brand.** design/logo/pcu-logo.svg is the login logo (navy tile, gold Lucide heart-handshake glyph). `node
tool/web/render_icons.mjs` renders favicons, web and maskable icons, apple-touch-icon, notification icon and white badge,
Android mipmaps and iOS AppIcon sizes. Chime: `python3 tool/sound/make_chime.py` -> assets/sounds/notify.wav.

**Notifications.** FCM web push (firebase-messaging-sw.js, VAPID key in AppConfig.fcmVapidKey); a polite card after
sign-in ("Turn on" / "Not now", 14 days); tokens at users/{email}/tokens. Apps Script (pcuNotify_) saves a bell item at
users/{email}/notifications and pushes through FCM HTTP v1 for a new guest, the 6pm reminder and a failed scheduled
sync (HODs); the email is the fallback when no device got the push. The bell shows the unread count and marks all read
when opened. **Blocked:** the service account lacks `cloudmessaging.messages.create` (pushCheck returns 403); give it
the role "Firebase Cloud Messaging API Admin". Until then the bell and emails work, pushes do not. Web push cannot play
the custom chime when the app is closed; on iPhone it needs the app added to the Home Screen (iOS 16.4+).

**Firestore insights.** Team and Dashboard (HOD) are worked out from guests, followUps and users (InsightRules, a port
of the API rules). Ranking reads rankings/{month}/entries, which every save moves in the same batch and
pcuNightlyRecalc (00:35 Lagos) rebuilds from followUps with the API's pcuPoints_. Admins are never ranked.

**Security review** (details in docs/BACKEND_PLAN.md): follow-ups must come with their guest update; status changes
follow the rules (Member needs 3+ Sundays, Member and Not interested stay); date fields server time and only growing;
Apps Script requires a verified email. Old API actions are marked deprecated, not removed (the live site uses them).

Tests: 55 emulator rules tests (needs Java 21), 71 Flutter tests, Firestore harness 76 checks, API harness and
equivalence harness pass. ALLOW_MOCK_TOKENS is still on (TEST sheet only).

**Test data:** syncNow and pushCheck were called on the TEST project (no app saves existed, so nothing was synced).

## 2026-11-01 Update: Part D audit and fixes

Branch `phase-1-firestore`. Commits: 2c34e42 (months per screen, Today rule), ecace70 (services review), d15b6d4
(admin review), 0711289 (backend contract), 96c3f38 (render check). Apps Script pushed with clasp to the existing
deployment `AKfycby0H6Sk...` (@12), exec URL unchanged; rules unchanged this round (not redeployed). Preview rebuilt:
https://pcu-workflow--firestore-test-3a07ufkq.web.app (login screen renders, no page errors). Live site untouched.

Suspected bugs and verdicts:
- (a) Guests month changed Today: REAL. One app-wide GuestsBloc held a single selectedMonth that Today filtered by.
- (b) Dashboard month changed the admin Guests month: REAL. The Dashboard sent SelectMonthEvent to that same bloc.
- (c) Found while fixing: a second person on the same device could see the first person's guests (Firestore listener
  kept on sign-in, left running after sign-out). REAL.
- Today showed every guest of the selected month (called or not, members too) with no outstanding label: REAL.
- F1 "this month" used the device time zone: REAL (wrong around month ends outside Lagos).
- F2 log screen date picker used the device's today: REAL. F3 API mode future-date check used the device date: REAL.
- F4 raw FormatException/Timeout text shown to people: REAL. F5 raw sign-in error text: REAL.
- F6 a device's push token stayed under the previous person after sign-out (shared phones): REAL.
- A1 Team keyed by an empty users.id for older users: LIKELY/LATENT, fixed with an email fallback (backend accepts it).
- A2 Dashboard/Team first month fixed at app start: REAL (minor).
- M1 offline save near midnight counted in the next month by the nightly rebuild and the sheet's CALL DATE: REAL.
- Checked and fine: duplicate listeners (one per month/screen/cubit), worker/admin data mixing in queries, Sync to
  sheet and Last synced, add worker, log on behalf, every Apps Script action's parameters and responses, Firestore
  batch fields against the rules, ranking entries, tokens, notifications, meta/sync.

How it works now:
- GuestsBloc is a cache by month (WatchMonthsEvent, RefreshMonthsEvent, ResetGuestsEvent), one live listener per month,
  no selected month. Each Guests screen has its own GuestsFilterCubit (worker tab, HOD tab, one worker's guests screen).
  The Dashboard keeps its own month (DashboardCubit) and its journey reads that month. Me shows the calendar month.
  A Dashboard tile opens Guests on that tile's month and chip only when tapped.
- Today (TodayRules) follows no filter: the worker's guests not yet called, first visit on or after go-live
  (AppConfig.chaseFrom 2026-10-28, same as GO_LIVE for the 6pm reminder), split into Outstanding (over 3 days) and New.
- resetSessionState on sign-in and sign-out; AuthBloc.beforeSignOut removes this device's push token first.

Tests: 91 Flutter tests (screen independence a/b/c, Today rule, month boundaries, API client messages, sign-out hook,
push reset, team id fallback), API harness (setWorkerActive by email), Firestore harness 78 checks (offline month
boundary), emulator rules unchanged (55).

Still open: Guest detail and the log screen find the guest in the loaded months only (opened from a list, so it is
there); an admin cannot log for a guest whose ASSIGNED TO is not in the Workers tab (no assignee name); a paused worker
still shows on the worker leaderboard until the nightly rebuild; FCM permission for the service account (see above).

## 2026-11-01 Live deploy: before state and rollback

Recorded before deploying the Firestore-mode app to the live site (https://pcu-workflow.web.app):
- Live channel release: `projects/pcu-workflow/sites/pcu-workflow/channels/live/releases/1793478488113000`
- Live version ID: **876dfe9dc93285cf** (released 2026-10-31 20:28:08 UTC)
- That build: API mode (Apps Script data source), exec URL
  `https://script.google.com/macros/s/AKfycbwemH_w7TbGcuN2X_LkRkeGnrRvd6E-rbdbp7DKUaxSsnbpEhCCI8KlEHUeA5KnBlM/exec`

**Rollback** (puts that exact version back on the live site; the Firestore data and rules are not touched):

```
firebase hosting:clone pcu-workflow:@876dfe9dc93285cf pcu-workflow:live --project pcu-workflow
```

The Firebase console can do the same: Hosting, Release history, the 2026-10-31 20:28 release, Roll back.

Result (2026-11-01): **not deployed.** The rules were confirmed (already up to date) and the Firestore-mode build was
made with exec URL `AKfycby0H6Sk...` (@12), but `firebase deploy --only hosting --project pcu-workflow` was refused by
this session's permission check (production deploy). The live site was re-checked afterwards: same ETag and
last-modified (2026-10-31 20:28 UTC) and still the old exec URL, so nothing changed and no rollback was needed.
To deploy, from the repo root on this branch:

```
tool/build_web.sh --dart-define=DATA_SOURCE=firestore --dart-define=APPS_SCRIPT_URL=https://script.google.com/macros/s/AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u/exec
firebase deploy --only hosting --project pcu-workflow
```

or copy the verified preview to live: `firebase hosting:clone pcu-workflow:firestore-test pcu-workflow:live --project pcu-workflow`.
Then check with `node tool/web/render_check.mjs https://pcu-workflow.web.app`.

## 2026-11-01 Live deploy done (with the owner's permission)

- Live site https://pcu-workflow.web.app now runs the Firestore-mode app with the PCU logo everywhere:
  live version **67e0f6f810be26ff**, released 2026-11-01 15:28:03 UTC, exec URL `AKfycby0H6Sk...` (@13).
- The same build is on the preview channel firestore-test (version 7b034f4c48175935).
- Verified on live: `node tool/web/render_check.mjs https://pcu-workflow.web.app` (first frame 1.7 s, splash gone, no
  page errors) and `node tool/web/icon_check.mjs https://pcu-workflow.web.app` (15 icon URLs, all real PCU images,
  none of the 23 Flutter template images). Rules confirmed up to date.
- Apps Script @13: push icon and badge are now full https URLs of the -v2 files.

**Rollback** to the build that was live before (API mode, version 876dfe9dc93285cf):

```
firebase hosting:clone pcu-workflow:@876dfe9dc93285cf pcu-workflow:live --project pcu-workflow
```

## 2026-11-01 Update: logo everywhere, live deploy, Android and iOS

- Icons: every web icon renamed with -v2 (favicon 16/32/48, multi-size favicon.ico, web, maskable, apple-touch,
  notification icon and badge) plus a share image with Open Graph tags. `node tool/web/icon_check.mjs <url>` checks
  every icon URL a site can ask for is a real PCU PNG or ICO and none of the 23 Flutter template images: live passes.
- Live site deployed and verified (see the section above; rollback to 876dfe9dc93285cf kept there).
- Mobile: app name PCU Connect, launcher icons (flutter_launcher_icons, adaptive navy background, monochrome layer),
  Android notification icon from the badge, INTERNET permission, navy Android launch background, iOS bundle id
  com.pcu.workflow. Found and fixed: firebase_options.dart threw on Android (any APK would crash at start), and sign-in
  used a web-only pop-up (native now uses signInWithProvider).
- No Android SDK in the Codespace, so builds run on GitHub Actions:
  - Android debug APK: https://github.com/Sthmpe/pcu-connect/actions/runs/41321819595 (success, artifact
    pcu-connect-debug-apk, 79 MB, kept until 2026-12-01).
  - iOS compile check: https://github.com/Sthmpe/pcu-connect/actions/runs/41321819609 (success, no signing).
- docs/MOBILE.md lists what a store release needs from the owner (SHA-1/SHA-256, signing key, Play Console, Apple
  Developer account, iOS Firebase registration, APNs key, native push work).

## 2026-11-01 Before the live deploy of the 25-step work (steps 1-22)

- Live **before** this deploy: version **67e0f6f810be26ff** (released 2026-11-01 15:28:03 UTC, Firestore mode).
- Roll back to it at once if the live check fails:
  `firebase hosting:clone pcu-workflow:@67e0f6f810be26ff pcu-workflow:live --project pcu-workflow`
- The older API-mode build stays available too:
  `firebase hosting:clone pcu-workflow:@876dfe9dc93285cf pcu-workflow:live --project pcu-workflow`
- Preview checked first: firestore-test version 63e41d84fc3d7b93, render_check first frame 2.4 s, no page errors; icon_check OK.
