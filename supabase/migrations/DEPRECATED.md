Postgres is no longer the source of truth (Firestore is - see `/firestore.rules`
and `lib/core/network/firebase_service.dart`). The schema in this folder from
the earlier Supabase-as-database design is kept only for reference and is not
applied. Safe to delete once confirmed unneeded.
