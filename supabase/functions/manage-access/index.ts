// Supabase Edge Function: manage-access
//
// Trusted membership listing, delegation, and revocation. The Flutter client
// never writes team_memberships directly. Every operation verifies a Firebase
// ID token, resolves authority from server-owned documents, prevents rank or
// permission escalation, and records an immutable audit entry.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { FieldPath, FieldValue } from "npm:firebase-admin@12/firestore";
import { db } from "../_shared/firebase_admin.ts";
import { HttpError, verifyFirebaseToken } from "../_shared/verify_token.ts";
import { corsPreflight, json } from "../_shared/responses.ts";

const OWNER_ONLY = new Set([
  "organization.manage",
  "locations.manage",
  "managers.manage",
]);

const ROLE_RANK: Record<string, number> = {
  organization_owner: 4,
  unit_manager: 3,
  delegate: 2,
  viewer: 1,
  operator: 1,
};

const ALLOWED_BASE_ROLES = new Set(Object.keys(ROLE_RANK));
const ALL_CAPABILITIES = new Set([
  "organization.manage",
  "locations.manage",
  "units.manage",
  "managers.manage",
  "contacts.view_all",
  "contacts.edit",
  "contacts.confirm_status",
  "assignments.view",
  "assignments.manage",
  "followups.manage_own",
  "followups.manage_all",
  "workers.view",
  "workers.add",
  "workers.deactivate",
  "workers.manage_availability",
  "reports.view_unit",
  "reports.view_location",
  "reports.view_organization",
  "permissions.delegate",
  "audit.view",
]);

type DelegationBaseline = {
  baseRole: string;
  permissionPreset: string;
  permissions: Record<string, boolean>;
  availabilityStatus: string;
};

type MembershipData = {
  userId?: string;
  organizationId?: string;
  locationId?: string;
  unitId?: string;
  active?: boolean;
  baseRole?: string;
  permissionPreset?: string;
  permissions?: Record<string, boolean>;
  availabilityStatus?: string;
  openAssignmentCount?: number;
  lastAssignedAt?: unknown;
  displayName?: string;
  scope?: {
    organizationId?: string;
    locationIds?: string[];
    unitIds?: string[];
  };
  delegationBaseline?: DelegationBaseline | null;
};

type UnitAuthority = {
  organizationId: string;
  locationId: string;
  callerIsOwner: boolean;
  callerMembership: MembershipData | null;
  callerRank: number;
  delegablePermissions: string[];
};

serve(async (req) => {
  if (req.method === "OPTIONS") return corsPreflight();

  try {
    const payload = await req.json() as Record<string, unknown>;
    const firebaseIdToken = typeof payload.firebaseIdToken === "string"
      ? payload.firebaseIdToken
      : undefined;
    const caller = await verifyFirebaseToken(firebaseIdToken);
    const callerUid = caller.uid;

    switch (payload.action) {
      case "list":
        return await handleList(callerUid, payload);
      case "grant":
        return await handleGrant(callerUid, payload);
      case "revoke":
        return await handleRevoke(callerUid, payload);
      default:
        return json({ error: "Unknown action" }, 400);
    }
  } catch (err) {
    if (err instanceof HttpError) {
      return json({ error: err.message }, err.status);
    }
    console.error("manage-access error:", err);
    return json({ error: "Internal server error" }, 500);
  }
});

function requireIdentifier(value: unknown, label: string): string {
  if (
    typeof value !== "string" ||
    value.length === 0 ||
    value.length > 256 ||
    value.includes("/")
  ) {
    throw new HttpError(400, "Invalid " + label);
  }
  return value;
}

function validateReason(value: unknown): string | null {
  if (value == null) return null;
  if (typeof value !== "string" || value.length > 500) {
    throw new HttpError(400, "Reason must be at most 500 characters");
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? null : trimmed;
}

async function isOrgOwner(organizationId: string, uid: string) {
  const id = [organizationId, uid].join("_");
  return (await db().collection("organization_owners").doc(id).get()).exists;
}

async function getMembership(unitId: string, uid: string) {
  const id = [unitId, uid].join("_");
  const document = await db().collection("team_memberships").doc(id).get();
  return document.exists ? document.data() as MembershipData : null;
}

async function resolveAuthority(
  callerUid: string,
  unitId: string,
): Promise<UnitAuthority> {
  const unitDocument = await db().collection("units").doc(unitId).get();
  if (!unitDocument.exists) throw new HttpError(404, "Unit not found");

  const unit = unitDocument.data() as {
    organizationId?: string;
    locationId?: string;
    active?: boolean;
  };
  if (!unit.organizationId || !unit.locationId) {
    throw new HttpError(409, "Unit scope is incomplete");
  }
  if (unit.active === false) {
    throw new HttpError(409, "Access cannot be managed for an archived unit");
  }

  const callerIsOwner = await isOrgOwner(unit.organizationId, callerUid);
  const callerMembership = callerIsOwner
    ? null
    : await getMembership(unitId, callerUid);

  if (!callerIsOwner) {
    if (!callerMembership || callerMembership.active !== true) {
      throw new HttpError(403, "You have no active access to this unit");
    }
    if (callerMembership.permissions?.["permissions.delegate"] !== true) {
      throw new HttpError(403, "You are not permitted to manage access");
    }
    const scopedUnits = callerMembership.scope?.unitIds ?? [];
    if (scopedUnits.length > 0 && !scopedUnits.includes(unitId)) {
      throw new HttpError(403, "Outside your scope");
    }
  }

  const callerRank = callerIsOwner
    ? ROLE_RANK.organization_owner
    : ROLE_RANK[callerMembership?.baseRole ?? ""] ?? 0;
  const callerPermissions = callerMembership?.permissions ?? {};
  const delegablePermissions = [...ALL_CAPABILITIES]
    .filter((permission) =>
      !OWNER_ONLY.has(permission) &&
      (callerIsOwner || callerPermissions[permission] === true)
    )
    .sort();

  return {
    organizationId: unit.organizationId,
    locationId: unit.locationId,
    callerIsOwner,
    callerMembership,
    callerRank,
    delegablePermissions,
  };
}

async function handleList(
  callerUid: string,
  payload: Record<string, unknown>,
) {
  const unitId = requireIdentifier(payload.unitId, "unitId");
  const authority = await resolveAuthority(callerUid, unitId);
  const cursor = payload.cursor == null
    ? null
    : requireIdentifier(payload.cursor, "cursor");
  const requestedLimit = typeof payload.limit === "number" &&
      Number.isInteger(payload.limit)
    ? payload.limit
    : 50;
  const pageLimit = Math.min(100, Math.max(20, requestedLimit));

  let query = db()
    .collection("team_memberships")
    .where("unitId", "==", unitId)
    .where("active", "==", true)
    .orderBy(FieldPath.documentId())
    .limit(pageLimit + 1);
  if (cursor != null) {
    query = query.startAfter(
      db().collection("team_memberships").doc(cursor),
    );
  }

  const snapshot = await query.get();
  const hasMore = snapshot.docs.length > pageLimit;
  const membershipDocuments = snapshot.docs.slice(0, pageLimit);
  const profileReferences = membershipDocuments.map((document) =>
    db().collection("profiles").doc(
      (document.data() as MembershipData).userId ?? "",
    )
  );
  const profileDocuments = profileReferences.length === 0
    ? []
    : await db().getAll(...profileReferences);
  const profilesById = new Map(
    profileDocuments.map((document) => [document.id, document.data()]),
  );

  const members = membershipDocuments.map((document) => {
    const membership = document.data() as MembershipData;
    const userId = membership.userId ?? "";
    const profile = profilesById.get(userId) as
      | { fullName?: unknown }
      | undefined;
    const displayName = typeof profile?.fullName === "string" &&
        profile.fullName.trim().length > 0
      ? profile.fullName.trim()
      : membership.displayName?.trim() || userId;
    const targetRank = ROLE_RANK[membership.baseRole ?? "operator"] ?? 0;
    const canManage = userId !== callerUid &&
      targetRank < ROLE_RANK.unit_manager &&
      (authority.callerIsOwner || targetRank < authority.callerRank);

    return {
      membershipId: document.id,
      userId,
      displayName,
      baseRole: membership.baseRole ?? "operator",
      permissionPreset: membership.permissionPreset ?? "custom",
      permissions: Object.keys(membership.permissions ?? {})
        .filter((permission) => membership.permissions?.[permission] === true)
        .sort(),
      availabilityStatus: membership.availabilityStatus ?? "inactive",
      isDelegated: membership.delegationBaseline != null ||
        membership.baseRole === "delegate",
      canManage,
    };
  });

  return json({
    success: true,
    members,
    delegablePermissions: authority.delegablePermissions,
    nextCursor: hasMore && membershipDocuments.length > 0
      ? membershipDocuments[membershipDocuments.length - 1].id
      : null,
  });
}

async function handleGrant(
  callerUid: string,
  payload: Record<string, unknown>,
) {
  const recipientUserId = requireIdentifier(
    payload.recipientUserId,
    "recipientUserId",
  );
  const unitId = requireIdentifier(payload.unitId, "unitId");
  const baseRole = typeof payload.baseRole === "string" ? payload.baseRole : "";
  const permissionPreset = typeof payload.permissionPreset === "string"
    ? payload.permissionPreset
    : "custom";
  const permissions = payload.permissions;
  const reason = validateReason(payload.reason);

  if (recipientUserId === callerUid) {
    throw new HttpError(403, "You cannot change your own access");
  }
  if (!ALLOWED_BASE_ROLES.has(baseRole) || baseRole === "organization_owner") {
    throw new HttpError(400, "Invalid delegable base role");
  }
  if (permissionPreset.length === 0 || permissionPreset.length > 64) {
    throw new HttpError(400, "Invalid permission preset");
  }
  if (
    !Array.isArray(permissions) ||
    permissions.length === 0 ||
    permissions.length > ALL_CAPABILITIES.size ||
    permissions.some((permission) =>
      typeof permission !== "string" || !ALL_CAPABILITIES.has(permission)
    ) ||
    new Set(permissions).size !== permissions.length
  ) {
    throw new HttpError(400, "Unknown, empty, or duplicate permissions");
  }

  const authority = await resolveAuthority(callerUid, unitId);
  const requestedRank = ROLE_RANK[baseRole] ?? 0;
  if (!authority.callerIsOwner && requestedRank >= authority.callerRank) {
    throw new HttpError(403, "Cannot grant a role equal to or above your own");
  }

  for (const permission of permissions as string[]) {
    if (
      OWNER_ONLY.has(permission) ||
      !authority.delegablePermissions.includes(permission)
    ) {
      throw new HttpError(
        403,
        "Permission is not delegable by the caller: " + permission,
      );
    }
  }

  const membershipId = [unitId, recipientUserId].join("_");
  const membershipReference = db().collection("team_memberships").doc(
    membershipId,
  );
  const previousSnapshot = await membershipReference.get();
  const previous = previousSnapshot.exists
    ? previousSnapshot.data() as MembershipData
    : null;
  const targetRank = ROLE_RANK[previous?.baseRole ?? "operator"] ?? 0;
  if (
    previous != null &&
    !authority.callerIsOwner &&
    targetRank >= authority.callerRank
  ) {
    throw new HttpError(
      403,
      "Cannot change access for a role equal to or above your own",
    );
  }

  const permissionsMap: Record<string, boolean> = {};
  for (const permission of permissions as string[]) {
    permissionsMap[permission] = true;
  }

  const delegationBaseline = previous == null || previous.active !== true
    ? null
    : previous.delegationBaseline ??
      (previous.baseRole === "delegate" ? null : {
        baseRole: previous.baseRole ?? "operator",
        permissionPreset: previous.permissionPreset ?? "custom",
        permissions: previous.permissions ?? {},
        availabilityStatus: previous.availabilityStatus ?? "active",
      });

  await membershipReference.set({
    userId: recipientUserId,
    organizationId: authority.organizationId,
    locationId: authority.locationId,
    unitId,
    scope: {
      organizationId: authority.organizationId,
      locationIds: [authority.locationId],
      unitIds: [unitId],
    },
    baseRole,
    permissionPreset,
    permissions: permissionsMap,
    active: true,
    availabilityStatus: baseRole === "operator"
      ? previous?.availabilityStatus ?? "active"
      : "inactive",
    openAssignmentCount: previous?.openAssignmentCount ?? 0,
    lastAssignedAt: previous?.lastAssignedAt ?? null,
    delegationBaseline,
    delegatedBy: callerUid,
    delegatedAt: FieldValue.serverTimestamp(),
    grantedBy: callerUid,
    grantedAt: FieldValue.serverTimestamp(),
    permissionVersion: FieldValue.increment(1),
  }, { merge: true });

  const organizationMembershipId = [
    authority.organizationId,
    recipientUserId,
  ].join("_");
  await db().collection("organization_memberships")
    .doc(organizationMembershipId)
    .set({
      organizationId: authority.organizationId,
      userId: recipientUserId,
      active: true,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

  await db().collection("audit_logs").add({
    organizationId: authority.organizationId,
    unitId,
    action: "membership.delegation_grant",
    actorId: callerUid,
    targetUserId: recipientUserId,
    before: previous == null ? null : {
      baseRole: previous.baseRole ?? null,
      permissionPreset: previous.permissionPreset ?? null,
      permissions: previous.permissions ?? {},
    },
    after: { baseRole, permissionPreset, permissions: permissionsMap },
    reason,
    createdAt: FieldValue.serverTimestamp(),
  });

  return json({ success: true, membershipId });
}

async function handleRevoke(
  callerUid: string,
  payload: Record<string, unknown>,
) {
  const membershipId = requireIdentifier(payload.membershipId, "membershipId");
  const reason = validateReason(payload.reason);
  const membershipReference = db().collection("team_memberships").doc(
    membershipId,
  );
  const snapshot = await membershipReference.get();
  if (!snapshot.exists) throw new HttpError(404, "Membership not found");

  const membership = snapshot.data() as MembershipData;
  const unitId = requireIdentifier(membership.unitId, "membership unitId");
  const userId = requireIdentifier(membership.userId, "membership userId");
  if (userId === callerUid) {
    throw new HttpError(403, "You cannot change your own access");
  }

  const authority = await resolveAuthority(callerUid, unitId);
  if (
    membership.organizationId !== authority.organizationId ||
    membership.locationId !== authority.locationId
  ) {
    throw new HttpError(409, "Membership scope does not match its unit");
  }
  const targetRank = ROLE_RANK[membership.baseRole ?? "operator"] ?? 0;
  if (!authority.callerIsOwner && targetRank >= authority.callerRank) {
    throw new HttpError(
      403,
      "Cannot revoke a role equal to or above your own",
    );
  }

  const baseline = membership.delegationBaseline;
  const restored = baseline != null;
  if (baseline != null) {
    await membershipReference.set({
      baseRole: baseline.baseRole,
      permissionPreset: baseline.permissionPreset,
      permissions: baseline.permissions,
      availabilityStatus: baseline.availabilityStatus,
      active: true,
      delegationBaseline: FieldValue.delete(),
      delegatedBy: FieldValue.delete(),
      delegatedAt: FieldValue.delete(),
      revokedBy: callerUid,
      revokedAt: FieldValue.serverTimestamp(),
      permissionVersion: FieldValue.increment(1),
    }, { merge: true });
  } else {
    await membershipReference.update({
      active: false,
      delegatedBy: FieldValue.delete(),
      delegatedAt: FieldValue.delete(),
      revokedBy: callerUid,
      revokedAt: FieldValue.serverTimestamp(),
      permissionVersion: FieldValue.increment(1),
    });

    const remainingMemberships = await db()
      .collection("team_memberships")
      .where("organizationId", "==", authority.organizationId)
      .where("userId", "==", userId)
      .where("active", "==", true)
      .limit(1)
      .get();
    if (remainingMemberships.empty) {
      const organizationMembershipId = [
        authority.organizationId,
        userId,
      ].join("_");
      await db().collection("organization_memberships")
        .doc(organizationMembershipId)
        .set({
          organizationId: authority.organizationId,
          userId,
          active: false,
          updatedAt: FieldValue.serverTimestamp(),
        }, { merge: true });
    }
  }

  await db().collection("audit_logs").add({
    organizationId: authority.organizationId,
    unitId,
    action: restored ? "membership.delegation_restore" : "membership.revoke",
    actorId: callerUid,
    targetUserId: userId,
    before: {
      baseRole: membership.baseRole ?? null,
      permissionPreset: membership.permissionPreset ?? null,
      permissions: membership.permissions ?? {},
    },
    after: restored
      ? {
        baseRole: baseline.baseRole,
        permissionPreset: baseline.permissionPreset,
        permissions: baseline.permissions,
      }
      : { active: false },
    reason,
    createdAt: FieldValue.serverTimestamp(),
  });

  return json({ success: true, restored });
}
