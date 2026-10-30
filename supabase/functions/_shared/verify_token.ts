import { fbAuth } from "./firebase_admin.ts";

/// Verifies a Firebase ID token server-side. The app must never send a
/// bare UID as request data - a caller could put anyone's UID in a JSON
/// body. Only a cryptographically verified token is trusted as "who is
/// actually calling this function".
export async function verifyFirebaseToken(idToken: string | undefined) {
  if (!idToken) throw new HttpError(401, "Missing Firebase ID token");
  try {
    return await fbAuth().verifyIdToken(idToken, true /* checkRevoked */);
  } catch {
    throw new HttpError(401, "Invalid or expired Firebase ID token");
  }
}

export class HttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}
