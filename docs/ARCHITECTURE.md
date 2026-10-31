# PCU Connect Architecture

PCU Connect is built as a responsive Flutter Web application backed by a Google Sheet via a Google Apps Script web app API.

## 1. High-Level System Architecture

```text
Flutter Web (Firebase Hosting)
   |
   |  1. Firebase Auth Google sign-in (or Dev Switcher in Debug Mode) -> Firebase ID token
   |  2. HTTP POST (Content-Type: text/plain, JSON: { action, idToken, ...payload })
   v
Google Apps Script Web App (backend/Api.gs)
   |
   |  - Verifies token via Google Identity Toolkit (or mock token in debug)
   |  - Enforces access: worker email must exist in "Workers" tab with Active = "Yes"
   |  - Evaluates business rules (Member rule, status transitions, points scoring)
   v
Google Sheet (Test Sheet ID: 1R9-l3GOw_NY8qIvn94mM3ZFxBpuuDl7lwSEnumdFU24)
   +-- Form Responses 1 (Guest records, assigned worker, status, attendance)
   +-- Follow-ups (Detailed follow-up history)
   +-- Workers (Worker directory, role, active status)
   +-- Leaderboard (Monthly points and rankings)
```

## 2. Directory Structure and Clean Architecture

The codebase follows Clean Architecture with BLoC state management:

```text
lib/
+-- core/
|   +-- constants/        # AppColors, AppTextStyles, AppSizes, AppStrings
|   +-- errors/           # Failure hierarchy (ServerFailure, NetworkFailure, etc.)
|   +-- network/          # ApiClient (CORS text/plain handler, redirect following)
|   +-- storage/          # LocalCache (shared_preferences offline cache scoped by email)
|   +-- theme/            # Material 3 Theme data wired to Rubik and design tokens
|   +-- utils/            # PhoneUtils (E.164 normalization, WhatsApp formatting)
|   +-- widgets/          # GuestCardWidget, GuestStatusPill, MetricTileWidget, FilterChipWidget, ResponsiveWebShell
+-- domain/
|   +-- entities/         # GuestEntity, WorkerUser
|   +-- repositories/     # IAuthRepository, IGuestRepository
+-- data/
|   +-- repositories/     # AuthRepositoryImpl, GuestRepositoryImpl
+-- presentation/
    +-- auth/             # AuthBloc, LoginScreen (Firebase Google sign-in + debug-only Switchers)
    +-- worker/           # WorkerShellScreen, TodayTab, MyGuestsTab, GuestDetailScreen, LogFollowUpScreen, RankingTab, MeTab
    +-- admin/            # AdminShellScreen, AdminDashboardTab, AdminTeamTab, AdminGuestsTab
```

## 3. Data Flow: Logging a Follow-Up

```text
LogFollowUpScreen
  -> User enters outcome, notes, attendance dates, team selection
  -> Validates: attendance date cannot be in the future
  -> GuestRepository.logFollowUp()
    -> ApiClient.postAction('logFollowUp')
      -> Google Apps Script (backend/Api.gs):
         - Verifies Google token
         - Enforces Workers tab access
         - Acquires script lock (LockService)
         - Appends entry to 'Follow-ups' tab
         - Evaluates Member rule (4 Sundays, or 3 Sundays + 2 Wednesdays in same month)
         - Awards points and updates 'Leaderboard' tab
      <- Returns { ok: true, data: { guest, pointsEarned } }
  <- Displays points feedback and refreshes guest lists
```

## 4. Offline Caching (Stale-While-Revalidate)

- `LocalCache` wraps `SharedPreferences` and stores the last successful responses.
- Cache keys are scoped to the active user email (`pcu.cache.<email>.<key>`) so different users on the same computer never see each other's data.
- When loading guests, cached data is displayed instantly while a background request refreshes the list.
- When offline or displaying cached fallback data, a "Showing saved data" banner is displayed at the top of the guest list.

## 5. Roles and Automatic Role Routing

- **Worker**:
  - Automatically routed to the Worker App (`TodayTab`).
  - Sees only guests assigned to them (`ASSIGNED TO == worker.email`).
  - Actions: Call (`tel:`) and WhatsApp (`https://wa.me/234...`), no SMS.
  - Logs follow-ups, records Sunday and Wednesday attendance, tracks team joins.
  - Views the monthly podium (top 3) and their personal ranking card.
  - Guest identity fields are read-only (intake is owned by Google Forms).
- **Admin / HOD**:
  - Automatically routed to the Admin App (`AdminDashboardTab`).
  - Sees 12-month analytics (New Guests, Members, Not Called, Team Joins) and conversion funnels.
  - Team management: views workloads, active status toggles, adds new workers.
  - Views all church guests with assigned worker attribution.
  - Never receives auto-assigned guests (skipped in round-robin rotation).
- **Unauthorized / Inactive**:
  - Access is restricted with the message: "No access. Ask your HOD to add your email."

## 6. Business Rules (Server-Enforced)

- **Member Rule**:
  - In one calendar month: 4 distinct Sundays attended, OR (3 Sundays AND >= 2 distinct Wednesdays).
  - Once qualified, the guest remains a Member and MEMBERSHIP DATE is stamped.
- **Status Evaluation Hierarchy**:
  1. Member rule (highest priority)
  2. Not interested (sticky)
  3. Returning (any attendance logged)
  4. Contacted (any "Reached" outcome)
  5. Unreachable (>= 3 follow-ups with none reached)
  6. Unchanged
- **Attendance Dates**: Any past date or today (future dates strictly rejected).
- **Points Scoring System**:
  - +10 pts: First call within 3 days (otherwise +5 pts)
  - +5 pts: Each follow-up logged
  - +10 pts: Guest attends Sunday or Wednesday
  - +20 pts: Guest joins Workforce or Evangelism
  - +30 pts: Guest becomes a Member
  - Admins are excluded from rankings.

## 7. Developer Switchers

- During development, instant switchers for **David (Worker)** and **Opeyemi (Admin)** are available on the login screen.
- These buttons are guarded with `if (kDebugMode)` and are automatically excluded from production release builds.
