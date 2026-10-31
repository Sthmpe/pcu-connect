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
