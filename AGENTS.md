# AGENTS.md (Codex and other agents)

The single source of truth is docs/AGENT_HANDOFF.md. Read it, then the end of SESSION.md, before changing anything.

The 10 most important rules:

1. Work on branch phase-1-firestore. Commit and push after each numbered step, even if not perfect.
2. Run every command yourself; the owner works from a phone. Ask only for sign-ins or approvals.
3. Production deploys (live Hosting, the real sheet) need the owner's explicit permission in the chat. Note the live release in SESSION.md first and keep the rollback ready.
4. Never create a new Apps Script deployment. Always: clasp deploy -i AKfycby0H6Sk-V1mCGJNtst4KzvraWplYqMn6exWDlLCybiINoGlXnSCUNdkNaJ8D4o0tC3u -d "<label>".
5. Never run clasp logout and never log out of anything.
6. Never commit or print secrets (Script Properties, ~/.clasprc.json, key files, tokens).
7. No em dashes in any text. Say "sync" in UI text for syncing.
8. Keep the look: navy #0B1F3A, gold #E3B341, Rubik, the existing widgets. GetX only for snackbars and dialogs; BLoC for state; ScreenUtil for sizes.
9. Do not change the points or status rules. All dates in Africa/Lagos.
10. Before finishing: flutter analyze, flutter test, the backend harnesses in backend/test, and the rules tests in firestore-tests.
