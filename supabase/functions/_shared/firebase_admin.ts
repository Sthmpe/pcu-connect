// Shared Firebase Admin bootstrap for every Edge Function that needs to
// read/write Firestore or verify a Firebase ID token. Service account
// credentials come only from a Supabase secret - never hardcoded, never
// shipped in the app.
import {
  type App,
  cert,
  getApps,
  initializeApp,
} from "npm:firebase-admin@12/app";
import { getFirestore } from "npm:firebase-admin@12/firestore";
import { getAuth } from "npm:firebase-admin@12/auth";

let app: App;

export function firebaseApp(): App {
  if (getApps().length === 0) {
    const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";
    if (!raw) throw new Error("Missing FIREBASE_SERVICE_ACCOUNT secret");
    app = initializeApp({ credential: cert(JSON.parse(raw)) });
  } else {
    app = getApps()[0];
  }
  return app;
}

export function db() {
  return getFirestore(firebaseApp());
}

export function fbAuth() {
  return getAuth(firebaseApp());
}
