# Workflow

Workflow is a modular people-and-work management platform. Its first configuration is **PCU Workflow**, used for guest intake, fair assignment, calling, follow-up, retention, and leadership reporting in a church Pastoral Care Unit.

The product uses neutral internal concepts so future organizations can supply their own display terminology:

| Internal concept | PCU label |
| --- | --- |
| organization owner | Pastor |
| location | Campus |
| unit manager | HOD |
| operator | Worker |
| contact | Guest |

## Current implementation status

The foundational naming migration and organization structure management are implemented:

- Active data paths use `contacts`, `organizationId`, `locationId`, `unitId`, and `assignedOperatorId`.
- A Pastor can create or edit the organization and create, edit, or soft-archive locations and units.
- Google Sheet intake writes the neutral Firestore schema and assigns only active operator memberships.
- Firebase rules and required composite indexes are versioned in the repository.
- Assignment writes are server-only; manual reassignment will use the planned `assign-guest` Edge Function.
- A Pastor can manage delegated access per unit from Manage Structure.
- An HOD with `permissions.delegate` can appoint assistants from Home using permission presets or a custom subset.
- The access list is sanitized and paginated by `manage-access`; Flutter never reads other users' memberships directly.
- Removing delegated access restores an existing member's saved baseline or deactivates a delegation-only membership, with every change audited.
- Android and Web are configured for Firebase project pcu-workflow; Firestore rules and committed indexes have been deployed.

The old `team` feature is still on the deprecated Supabase/Postgres pattern and must not be treated as production-ready.

## Architecture

```text
Firebase Authentication  -> identity and login
Cloud Firestore          -> application data and authorization source of truth
Supabase Storage         -> media and files only
Supabase Edge Functions  -> trusted intake, assignment, access, and integration workflows
Flutter + BLoC           -> mobile application and presentation state
```

The Flutter client never uses Supabase PostgREST for application data. Edge Functions verify a Firebase ID token sent in the request body before privileged work. The Google Sheet intake endpoint uses a separate shared intake secret.

## Project layout

```text
lib/
  core/                         design tokens, routing, terminology, backend clients
  features/
    access_control/             capabilities, presets, memberships
    auth/                       Firebase Auth and profile/access resolution
    call_workflow/              dialer handoff and immutable interaction capture
    guests/                     contact list, detail, and lifecycle updates
    organization_structure/     organization/location/unit CRUD
    reports/                    Firestore reporting queries
    team/                       legacy; Firestore migration pending
supabase/functions/
  guest-sync/                   Sheet intake and fair assignment
  manage-access/                paginated list + guarded grant/revoke + audit logs
firestore.rules                 tenant and capability enforcement
firestore.indexes.json          required composite indexes
firebase.json                   Firebase deploy paths
```

The existing `features/` folder name is intentionally retained until the planned one-time rename to `modules/`.

## Firestore model

Core collections are:

- `profiles/{userId}`
- `organization_owners/{organizationId}_{userId}`
- `organization_memberships/{organizationId}_{userId}`
- `team_memberships/{unitId}_{userId}`
- `organizations/{organizationId}`
- `locations/{locationId}`
- `units/{unitId}`
- `contacts/{contactId}`
- `assignments/{assignmentId}`
- `interactions/{interactionId}`
- `follow_ups/{followUpId}`
- `contact_status_history/{eventId}`
- `audit_logs/{logId}`

All runtime fields use camelCase. Legacy snake_case names are accepted only at the Google Sheet intake boundary during rollout; they are never written back to Firestore.

## Access model

A base role is a ceiling; the membership capability map is the actual authority.

- **Pastor / organization owner:** highest authority, structure management, appoints HODs.
- **HOD / unit manager:** manages the assigned unit within granted capabilities.
- **Delegate:** receives a selected subset, such as assignment or reporting access.
- **Worker / operator:** receives contacts, calls them, and records feedback.
- **Viewer:** read-only access where explicitly granted.

The client only hides or shows controls. Firestore Rules and trusted Edge Functions enforce the real permissions. Owner-only capabilities cannot be delegated. The Deputy Manager preset copies the HOD's operational capabilities but intentionally excludes re-delegation. The assistant screen cannot demote or modify an HOD; HOD appointment remains a Pastor-level management flow. Revoked users lose organization-level structure access when their last active membership is removed.

## Local setup

1. Install Flutter dependencies:

   ```powershell
   flutter pub get
   ```

2. Firebase is already connected for Android and Web. To refresh those files:

   ```powershell
   dart pub global activate flutterfire_cli
   flutterfire configure --yes --project=pcu-workflow --platforms=android,web
   ```

3. Copy `.env.example` to `.env` and provide only the public Supabase URL and anon key. Never put a service-role key or Firebase service account in the Flutter app.

4. The Firebase CLI is bound to `pcu-workflow`; redeploy rules and indexes after changing them with:

   ```powershell
   firebase use --add
   firebase deploy --only firestore:rules,firestore:indexes
   ```

5. Bootstrap the first Pastor in the Firebase console:

   ```text
   organization_owners/{organizationId}_{firebaseUid}
     organizationId: {organizationId}
     userId: {firebaseUid}
   ```

6. Configure Edge Function secrets and deploy:

   ```powershell
   supabase secrets set FIREBASE_SERVICE_ACCOUNT='<service-account-json>'
   supabase secrets set WORKFLOW_INTAKE_SECRET='<strong-random-secret>'
   supabase functions deploy guest-sync manage-access
   ```

7. Run the app:

   ```powershell
   flutter run
   ```

## Performance conventions

- Feature BLoCs are route-scoped and disposed when their screens close.
- Structure reads start concurrently and lists are sorted once in the datasource.
- Fair assignment uses denormalized assignment counts instead of one count query per worker.
- Stable Firebase UIDs are stored as operator IDs, avoiding membership-document/identity mismatches.
- Firestore queries are scope-filtered and backed by committed composite indexes.
- Delegation lists load in bounded pages and the feature BLoC is disposed when its route closes.
- Structure records are soft-archived instead of deleted.

## Verification

Focused model tests live in `test/naming_and_structure_test.dart` and `test/access_control/delegation_models_test.dart`. Run:

```powershell
flutter test
flutter analyze
```

The last completed validation run passed all 7 Flutter tests, and targeted analysis of the delegation screen reported no issues. `firebase_options.dart` now exists, removing the previous full-project analyzer error. On 2026-08-29, fresh full `flutter analyze` and `flutter test` runs stalled locally and were stopped, so no newer passing result is claimed. Deno 2.9.5 previously type-checked `guest-sync` and `manage-access`, all five TypeScript files passed `deno fmt --check`, all Dart files passed the formatting check, and `firestore.indexes.json` parsed successfully. Flutter still warns that the currently empty `assets/images/` and `assets/icons/` directories do not exist.

## Next implementation work

1. Implement the server-only `assign-guest` manual reassignment function.
2. Migrate `team` from deprecated Supabase/Postgres calls to Firestore.
3. Complete the terminology sweep across detail, call, team, and report screens.
4. Rename `lib/features` to `lib/modules` in one controlled refactor.
