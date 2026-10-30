// Supabase Edge Function: Idempotent Contact Intake & Fair Assignment
// Triggered by Google Apps Script on new Google Sheet rows.
//
// Firestore is the source of truth. This function uses the Firebase Admin
// SDK (service-account credentials, server-side only) to upsert the contact
// and run fair assignment inside a Firestore transaction, so concurrent
// Sheet retries can never double-assign the same guest.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { cert, getApps, initializeApp } from "npm:firebase-admin@12/app";
import {
  FieldValue,
  getFirestore,
  Transaction,
} from "npm:firebase-admin@12/firestore";

const INTAKE_SECRET = Deno.env.get("WORKFLOW_INTAKE_SECRET") ?? "";
// Service account JSON stored as a Supabase Edge Function secret
// (`supabase secrets set FIREBASE_SERVICE_ACCOUNT='<json>'`) - never committed.
const SERVICE_ACCOUNT_JSON = Deno.env.get("FIREBASE_SERVICE_ACCOUNT") ?? "";

if (getApps().length === 0) {
  initializeApp({ credential: cert(JSON.parse(SERVICE_ACCOUNT_JSON)) });
}
const db = getFirestore();

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers":
          "authorization, x-client-info, apikey, content-type, x-workflow-secret",
      },
    });
  }

  try {
    const inboundSecret = req.headers.get("x-workflow-secret");
    if (!INTAKE_SECRET || inboundSecret !== INTAKE_SECRET) {
      return json({ error: "Unauthorized request" }, 401);
    }

    const payload = await req.json();
    // Accept legacy Sheet keys during rollout, but only write the neutral
    // camelCase schema to Firestore.
    const organizationId = payload.organizationId ?? payload.organization_id;
    const locationId = payload.locationId ?? payload.campus_id;
    const unitId = payload.unitId ?? payload.team_id;
    const externalId = payload.externalId ?? payload.external_id;
    const fullName = payload.fullName ?? payload.full_name;
    const phoneOriginal = payload.phoneOriginal ?? payload.phone_original;
    const serviceName = payload.serviceName ?? payload.service_name;
    const intakeType = payload.intakeType ?? payload.intake_type ?? "contact";

    if (
      !organizationId || !locationId || !unitId || !externalId || !fullName ||
      !phoneOriginal
    ) {
      return json({ error: "Missing required fields in intake payload" }, 400);
    }

    const phoneE164 = `+${String(phoneOriginal).replace(/\D/g, "")}`;

    // Idempotency key doubles as the guest doc ID - retries overwrite the
    // same doc/assignment instead of creating duplicates.
    const contactId = `${organizationId}_${externalId}`;

    const result = await db.runTransaction(async (tx: Transaction) => {
      const contactRef = db.collection("contacts").doc(contactId);
      const existingContact = await tx.get(contactRef);

      if (existingContact.exists) {
        const existingAssignment = existingContact.data()?.activeAssignmentId;
        return {
          contactId,
          assignmentId: existingAssignment ?? null,
          status: "already_synced",
        };
      }

      // Fair assignment uses the denormalized openAssignmentCount maintained
      // on each membership, avoiding one assignment query per operator.
      const operatorsSnap = await tx.get(
        db.collection("team_memberships")
          .where("organizationId", "==", organizationId)
          .where("locationId", "==", locationId)
          .where("unitId", "==", unitId)
          .where("baseRole", "==", "operator")
          .where("availabilityStatus", "==", "active")
          .where("active", "==", true),
      );

      if (operatorsSnap.empty) {
        tx.set(contactRef, {
          organizationId,
          locationId,
          unitId,
          externalId,
          fullName,
          phoneOriginal,
          phoneE164,
          intakeType,
          serviceName: serviceName ?? null,
          currentStage: "received",
          assignedOperatorId: null,
          activeAssignmentId: null,
          receivedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
        return { contactId, assignmentId: null, status: "unassigned_queue" };
      }

      let chosen = operatorsSnap.docs[0];
      let chosenOpenCount = chosen.data().openAssignmentCount ?? 0;
      for (let i = 1; i < operatorsSnap.docs.length; i++) {
        const operator = operatorsSnap.docs[i];
        const count = operator.data().openAssignmentCount ?? 0;
        const chosenLast = chosen.data().lastAssignedAt?.toMillis?.() ?? 0;
        const operatorLast = operator.data().lastAssignedAt?.toMillis?.() ?? 0;
        if (
          count < chosenOpenCount ||
          (count === chosenOpenCount && operatorLast < chosenLast) ||
          (count === chosenOpenCount && operatorLast === chosenLast &&
            operator.id < chosen.id)
        ) {
          chosen = operator;
          chosenOpenCount = count;
        }
      }

      const assignmentRef = db.collection("assignments").doc();
      const chosenOperatorId = chosen.data().userId as string;

      tx.set(contactRef, {
        organizationId,
        locationId,
        unitId,
        externalId,
        fullName,
        phoneOriginal,
        phoneE164,
        intakeType,
        serviceName: serviceName ?? null,
        currentStage: "assigned",
        assignedOperatorId: chosenOperatorId,
        assignedOperatorName: chosen.data().displayName ?? null,
        activeAssignmentId: assignmentRef.id,
        receivedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });

      tx.set(assignmentRef, {
        contactId,
        operatorId: chosenOperatorId,
        operatorMembershipId: chosen.id,
        unitId,
        locationId,
        organizationId,
        status: "active",
        assignmentMethod: "auto_fair",
        assignedAt: FieldValue.serverTimestamp(),
      });

      tx.update(chosen.ref, {
        lastAssignedAt: FieldValue.serverTimestamp(),
        openAssignmentCount: FieldValue.increment(1),
      });

      return {
        contactId,
        assignmentId: assignmentRef.id,
        operatorId: chosenOperatorId,
        operatorName: chosen.data().displayName ?? null,
        status: "assigned",
      };
    });

    return json({
      success: true,
      ...result,
      syncedAt: new Date().toISOString(),
    });
  } catch (err) {
    console.error("guest-sync error:", err);
    return json(
      { error: (err as Error).message || "Internal server error" },
      500,
    );
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
