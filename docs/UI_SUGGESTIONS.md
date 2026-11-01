# PCU Connect: UI suggestions

A review of every screen in the Flutter app (login, Today, Guests, guest detail, log follow-up, ranking, notifications,
HOD dashboard, team, add worker, Sync to sheet) as of branch `phase-1-firestore`, 2026-11-01. Nothing here has been
built yet. Every suggestion keeps the brand: navy #0B1F3A, gold #E3B341, Rubik, Lucide icons, sentence case, plain words.

**How to read it.** Impact is how much it helps workers or the HOD (high, medium, low). Effort is a quick win (under an
hour), medium (about half a day) or large (one to three days). Within each list the best value comes first.

## Top 10 overall

| # | Screen | Change | Impact | Effort |
|---|---|---|---|---|
| 1 | Log follow-up | Pre-fill attendance with the most recent Sunday or Wednesday, not today | High | Quick |
| 2 | Guest detail | After a call, ask "How did the call with Ada go?" when the worker comes back to the app | High | Medium |
| 3 | Dashboard | "Needs attention": workers with outstanding guests, with counts | High | Medium |
| 4 | App-wide | "Add to Home Screen" card, so pushes work on iPhone and the app opens full screen | High | Medium |
| 5 | Log follow-up | Show the points before saving ("This call earns 15 points") | High | Quick |
| 6 | App-wide | Let text grow with the phone's text size (now capped at 90 percent on the web) | High | Quick |
| 7 | Today | A red "Outstanding" pill on each overdue row, not only the section title | Medium | Quick |
| 8 | Guest detail | WhatsApp with a ready, editable greeting | High | Medium |
| 9 | Notifications | Tapping a notice opens that guest | Medium | Medium |
| 10 | Dashboard | Move the "Sheet is a day behind" warning to the top when it shows | Medium | Quick |

## Quick wins (under an hour each)

### Log follow-up
- **Attendance date defaults to the last service.** Turning on "Sunday service" today pre-selects today's date, even on a
  Tuesday. Pre-fill the most recent Sunday (and the most recent Wednesday for the Wednesday switch), in Lagos time.
  Why: most calls are about last Sunday, so workers stop correcting the date and fewer wrong dates reach the sheet.
- **Points preview above the Save button.** The rules already run on the phone (FollowUpRules). Show "This call earns 15
  points" and update it as switches change. Why: it makes the scoring feel fair and rewards the extra step of
  recording attendance and team joins.
- **Outcomes as a two-column grid of large chips** instead of a list of six rows. Why: everything fits on one phone
  screen, so the worker can pick the outcome and save without scrolling.

### Today
- **A red "Outstanding" pill on each overdue row**, next to "Waiting 5 days for a call". Why: the section title scrolls
  away; the pill keeps the urgency visible on every row and in screenshots shared with the HOD.
- **Count in the bottom navigation.** A small gold dot or number on the Today tab when guests are outstanding. Why:
  workers see there is work waiting from any tab.

### Guests (worker)
- **Search by name or phone**, as the HOD's Guests screen already has. Why: workers with many guests find someone in a
  second when the guest calls back.
- **Long-press a phone number to copy it.** Why: helps when calling from a second phone or sharing with a team leader.

### Guest detail
- **Show the first visit as a date** ("Wednesday 28 October") instead of only the month. Why: workers know exactly how
  long the guest has waited and can mention the service in the call.

### Ranking
- **A soft gold highlight on your own row** when it is outside the top three. Why: the worker finds themselves at once,
  which is the main reason to open the screen.

### Notifications
- **Group the list into "Today" and "Earlier".** Why: easier to scan after a weekend of assignments.

### Dashboard
- **Raise the sync warning.** When "Sheet is a day behind. Sync now." shows, show it as a slim gold-outlined banner at the
  top, with the button. Why: the HOD sees it without scrolling to the bottom; when all is well, it stays down.

### Sync to sheet
- **Say what was synced** ("Synced 6 follow-ups for 4 guests") and add an "Open the sheet" link. Why: the HOD can check
  the result straight away and trusts the button.

### Add worker
- **After adding, offer "Share sign-in link"** (WhatsApp or copy) with a short message: "You are on PCU Connect. Sign in
  with this Google account: ...". Why: most first sign-in problems come from using a different Google account.

### Login
- **Line up the splash and the login logo.** The splash logo sits in the centre, then jumps up on the login screen. Put
  both at the same height and fade the navy into the light background. Why: the start feels smooth and deliberate
  instead of flashing.
- **Small version and help line at the bottom** ("Trouble signing in? Ask your HOD. v0.1.0"). Why: the HOD can tell
  which version someone has when helping on the phone.

### App-wide
- **Text size.** Raise the web text scale cap from 0.9 to about 1.3 and check the main screens at that size. Why: many
  volunteers set larger text on their phones; today the app ignores it.

## Bigger ideas

### Guest detail
- **"How did the call go?" on return (medium, high impact).** When the worker taps Call or WhatsApp and comes back to the
  app, show a bottom sheet with the four quick outcomes for that guest, then the full form if they want. Why: the most
  common miss is calling and forgetting to log; this closes the loop in one tap and protects their points.
- **WhatsApp with a ready greeting (medium, high impact).** Prefill "Hello Ada, this is David from PCU. Thank you for
  worshipping with us on Sunday..." with two or three templates the HOD can edit. Why: a warm, consistent first message
  in seconds, which matters most for new workers.
- **Road to membership as a mini calendar (medium, medium impact).** Show the month's Sundays and Wednesdays as dots,
  filled when attended, with "1 more Sunday to become a member". Why: the rule (4 Sundays, or 3 Sundays and 2
  Wednesdays) becomes obvious and gives the worker a clear goal for the next call.

### Today
- **A daily goal ring (medium, medium impact).** "3 of 5 calls today" in the hero, based on outstanding plus new guests.
  Why: a small, achievable target is more motivating than a long list.

### Dashboard (HOD)
- **"Needs attention" (medium, high impact).** A card listing workers with outstanding guests ("David, 4 outstanding,
  oldest 9 days") with a tap to that worker's guests. Why: the HOD sees who needs a nudge or support without opening
  every profile.
- **Twelve-month trend (medium, medium impact).** A small navy line for guests and a gold line for members, from data the
  backend already computes. Why: shows whether retention is improving over the year, which is what leaders ask about.

### Team
- **Outstanding badge per worker (medium, medium impact).** A red count on each row when they have outstanding guests.
  Why: fair, visible accountability, and the HOD can reassign before a guest is lost.

### Notifications
- **Open the guest from a notice (medium, medium impact).** "New guest for you: Ada Obi" opens Ada's screen, loading her
  if her month is not on screen. Why: the notice becomes the shortest path to the first call.

### App-wide
- **Add to Home Screen card (medium, high impact).** After the first successful save, a gentle card explains how to add
  the app to the home screen, with iPhone and Android steps. Why: on iPhone, web push only works after this, and the app
  then opens full screen like a native app.
- **Offline status chip (medium, medium impact).** A small "Offline, saves will sync" chip in the top bar while offline.
  Why: workers in church halls with weak signal know their saves are safe.
- **Celebrate milestones (large, medium impact).** A short gold confetti moment the first time a guest becomes a member
  through a worker's follow-ups, and a monthly "You helped 3 guests become members" card on Me. Why: the work is
  pastoral and slow; marking the wins keeps volunteers going.
- **Dark navy theme for evening calls (large, low impact).** Navy surfaces, gold accents, same tokens. Why: easier on the
  eyes during evening follow-up sessions; low priority until the core flow is polished.

## Notes for whoever builds these
- Keep using the design tokens (AppColors, AppTextStyles, AppSizes) and Lucide icons through AppIcons only.
- Every new label should be plain, sentence case and without em dashes, and say "sync" for anything that reaches the sheet.
- Check each change at phone width (390 px) and at the larger text size above.
