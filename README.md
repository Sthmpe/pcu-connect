# PCU Connect  -  Flutter Web + Google Sheet Backend

Guest follow-up, retention, and integration platform for the church Pastoral Care Unit (PCU). Built as a **Flutter Web** application backed directly by a Google Sheet database through a Google Apps Script web-app API (`backend/Api.gs`).

---

## 1. High-Level Architecture

```text
Flutter Web (Firebase Hosting)
   │
   │  1. Firebase Auth Google sign-in (popup) -> Firebase ID token
   │  2. HTTP POST (Content-Type: text/plain, JSON: { action, idToken, ...payload })
   ▼
Google Apps Script Web App (backend/Api.gs)
   │
   │  - Verifies token via oauth2.googleapis.com/tokeninfo
   │  - Enforces access: worker email must exist in "Workers" tab with Active = "Yes"
   │  - Evaluates business rules (Member rule, status transitions, points scoring)
   ▼
Google Sheet (Test Sheet ID: 1R9-l3GOw_NY8qIvn94mM3ZFxBpuuDl7lwSEnumdFU24)
   ├── Form Responses 1 (Guest rows, assigned worker, status, attendance)
   ├── Call Log (Detailed follow-up history)
   ├── Workers (Worker directory, role, active status)
   └── Leaderboard (Monthly points & rankings)
```

> **Why `text/plain`?** Browsers will not trigger a CORS preflight (`OPTIONS` request) when sending simple POST payloads as `text/plain`. Since Google Apps Script web apps cannot answer `OPTIONS` preflight calls, sending JSON strings with `Content-Type: text/plain` guarantees seamless cross-origin communication on the web.

---

## 2. Roles & Automatic Role Routing

Upon sign-in with Google, the app calls `api.me()` to determine the user's role:

- **Worker**:
  - Automatically routed to the **Worker App** (`TodayScreen`).
  - Sees only guests assigned to them.
  - Actions: **Call** (`tel:`) and **WhatsApp** (`https://wa.me/234...`), **NO SMS**.
  - Logs follow-ups, records Sunday & Wednesday attendance (rejecting future dates), tracks team joins.
  - Views the monthly podium (top 3) and their personal ranking card.
  - Cannot add or edit guest identity fields (intake is owned by Google Forms).
- **Admin / HOD**:
  - Automatically routed to the **Admin App** (`DashboardScreen`).
  - Sees 12-month analytics (New Guests, Members, Not Called, Team Joins) and conversion funnels.
  - Team management: views workloads, active status toggles, adds new workers.
  - Views all church guests with assigned worker attribution.
  - Never receives auto-assigned guests.
- **Unauthorized / Inactive**:
  - Access is restricted with the message: *"No access. Ask your HOD to add your email."*

---

## 3. Business Rules (Server-Enforced)

- **Member Rule**:
  - In one calendar month: **4 distinct Sundays attended, OR (3 Sundays AND ≥2 distinct Wednesdays)**.
  - Once qualified, the guest remains a Member and `MEMBERSHIP DATE` is stamped.
- **Status Evaluation Hierarchy**:
  1. Member rule (highest priority)
  2. Not interested (sticky)
  3. Returning (any attendance logged)
  4. Contacted (any "Reached" outcome)
  5. Unreachable (≥3 follow-ups with none reached)
  6. Unchanged
- **Attendance Dates**: Any past date or today (future dates strictly rejected).
- **Points Scoring System**:
  - `+10 pts` First call within 3 days
  - `+5 pts` Each follow-up logged
  - `+10 pts` Guest attends Sunday or Wednesday
  - `+20 pts` Guest joins Workforce / Evangelism
  - `+30 pts` Guest becomes a Member

---

## 4. Design System & Tokens

Pixel-perfect recreation of `design/PCU_Worker_App.html` and `design/PCU_Admin_App.html`:

- **Colors**:
  - Navy: `#0B1F3A`
  - Gold: `#E3B341`
  - App Background: `#F3F4F7`
  - Status Pills: Green (`#E4F4EA` / `#1B7A46`), Amber (`#FFF0D6` / `#8A5300`), Red (`#FBE5E3` / `#B3261E`), Blue (`#E6EBF4` / `#0B1F3A`), Gold (`#FFF3CC` / `#8A6A00`)
- **Typography**: Google Font **Rubik** (weights 400, 500, 600, 700).
- **Layout**: Centered responsive 390px–430px mobile shell (`ResponsiveWebShell`) on desktop web.

---

## 5. Clean Codebase Structure

```text
lib/
├── core/
│   ├── constants/             # AppColors, AppTextStyles, AppSizes, AppStrings
│   ├── network/               # ApiClient (CORS text/plain handler, redirect following)
│   ├── errors/                # Strongly-typed Failure hierarchy
│   ├── theme/                 # Material 3 Theme data
│   └── widgets/               # GuestCardWidget, GuestStatusPill, MetricTileWidget, FilterChipWidget, ResponsiveWebShell
├── domain/
│   ├── entities/              # GuestEntity, WorkerUser
│   └── repositories/          # IAuthRepository, IGuestRepository
├── data/
│   └── repositories/          # AuthRepositoryImpl, GuestRepositoryImpl
└── presentation/
    ├── auth/                  # AuthBloc, LoginScreen (with Google Sign-In & Dev Switchers)
    ├── worker/                # WorkerShellScreen, TodayTab, MyGuestsTab, GuestDetailScreen, LogFollowUpScreen, RankingTab, MeTab
    └── admin/                 # AdminShellScreen, AdminDashboardTab, AdminTeamTab, AdminGuestsTab
```

---

## 6. How to Run Locally

```bash
# Get dependencies
flutter pub get

# Run on Chrome
flutter run -d chrome
```

---

## 7. Mock Tokens (TEST sheet only)

`backend/Api.gs` accepts dev `mock_token` logins only when the Apps Script
Script Property `ALLOW_MOCK_TOKENS` is exactly `true` (lowercase, no spaces).
Any other value, or no property at all, returns `UNAUTHENTICATED`.

- Set it on the **TEST sheet** project only (Project Settings > Script properties).
- **Never** set it on the live church sheet.
- Verified by the Node harness: `node backend/test/pcu_api_harness.js backend/Api.gs`
