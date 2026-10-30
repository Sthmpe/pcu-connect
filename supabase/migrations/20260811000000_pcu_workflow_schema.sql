-- PCU Workflow Complete Database Migration Schema
-- Performance Optimized with Row Level Security, Indexes, and Atomic Fair Assignment RPC

-- 1. ENUMS
CREATE TYPE user_role AS ENUM ('worker', 'hod', 'pastor_viewer', 'admin');
CREATE TYPE availability_status AS ENUM ('active', 'unavailable', 'inactive');
CREATE TYPE assignment_status AS ENUM ('active', 'completed', 'reassigned', 'cancelled');
CREATE TYPE guest_stage AS ENUM ('received', 'assigned', 'contacted', 'returned', 'retained', 'integrated', 'worker');
CREATE TYPE call_outcome AS ENUM ('connected', 'no_answer', 'busy', 'voicemail', 'wrong_number');

-- 2. ORGANIZATIONS, CAMPUSES, & TEAMS
CREATE TABLE public.organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.campuses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    code TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    campus_id UUID NOT NULL REFERENCES public.campuses(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. PROFILES & TEAM MEMBERSHIPS
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone_e164 TEXT,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.team_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    profile_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    campus_id UUID NOT NULL REFERENCES public.campuses(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    role user_role NOT NULL DEFAULT 'worker',
    availability_status availability_status NOT NULL DEFAULT 'active',
    unavailable_until TIMESTAMPTZ,
    last_assigned_at TIMESTAMPTZ,
    active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast fair assignment queries
CREATE INDEX idx_team_memberships_fair_assignment 
ON public.team_memberships(campus_id, team_id, availability_status, active, last_assigned_at);

-- 4. GUESTS
CREATE TABLE public.guests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES public.organizations(id) ON DELETE CASCADE,
    campus_id UUID NOT NULL REFERENCES public.campuses(id) ON DELETE CASCADE,
    team_id UUID NOT NULL REFERENCES public.teams(id) ON DELETE CASCADE,
    external_source TEXT NOT NULL DEFAULT 'sheets_intake',
    external_id TEXT NOT NULL,
    full_name TEXT NOT NULL,
    phone_original TEXT NOT NULL,
    phone_e164 TEXT NOT NULL,
    intake_type TEXT NOT NULL DEFAULT 'guest',
    service_name TEXT,
    received_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    current_stage guest_stage NOT NULL DEFAULT 'received',
    contacted_at TIMESTAMPTZ,
    returned_at TIMESTAMPTZ,
    retained_at TIMESTAMPTZ,
    integrated_at TIMESTAMPTZ,
    became_worker_at TIMESTAMPTZ,
    department TEXT,
    do_not_contact BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ,
    CONSTRAINT uq_guest_external_source UNIQUE (organization_id, external_source, external_id)
);

CREATE INDEX idx_guests_stage_campus ON public.guests(campus_id, current_stage) WHERE deleted_at IS NULL;

-- 5. ASSIGNMENTS
CREATE TABLE public.assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    worker_membership_id UUID NOT NULL REFERENCES public.team_memberships(id) ON DELETE CASCADE,
    status assignment_status NOT NULL DEFAULT 'active',
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    assigned_by UUID REFERENCES public.profiles(id),
    assignment_method TEXT NOT NULL DEFAULT 'auto_fair',
    previous_assignment_id UUID REFERENCES public.assignments(id),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Partial unique index: Guarantee exactly ONE active assignment per guest
CREATE UNIQUE INDEX uq_active_assignment_per_guest 
ON public.assignments(guest_id) WHERE status = 'active';

CREATE INDEX idx_assignments_worker ON public.assignments(worker_membership_id, status);

-- 6. INTERACTIONS & FOLLOW-UPS
CREATE TABLE public.interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES public.assignments(id) ON DELETE SET NULL,
    worker_membership_id UUID NOT NULL REFERENCES public.team_memberships(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'call',
    direction TEXT NOT NULL DEFAULT 'outgoing',
    status TEXT NOT NULL DEFAULT 'completed',
    outcome call_outcome NOT NULL,
    phone_e164 TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at TIMESTAMPTZ,
    duration_seconds INTEGER DEFAULT 0,
    duration_band TEXT,
    duration_type TEXT DEFAULT 'estimated',
    capture_source TEXT NOT NULL DEFAULT 'manual',
    platform TEXT DEFAULT 'flutter',
    notes TEXT,
    next_followup_at TIMESTAMPTZ,
    client_event_id TEXT,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE public.follow_ups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    guest_id UUID NOT NULL REFERENCES public.guests(id) ON DELETE CASCADE,
    assignment_id UUID REFERENCES public.assignments(id) ON DELETE SET NULL,
    interaction_id UUID REFERENCES public.interactions(id) ON DELETE SET NULL,
    owner_membership_id UUID NOT NULL REFERENCES public.team_memberships(id) ON DELETE CASCADE,
    due_at TIMESTAMPTZ NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending',
    completed_at TIMESTAMPTZ,
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. ATOMIC FAIR ASSIGNMENT RPC
CREATE OR REPLACE FUNCTION public.fair_assign_guest(
    p_organization_id UUID,
    p_campus_id UUID,
    p_team_id UUID,
    p_external_id TEXT,
    p_full_name TEXT,
    p_phone_original TEXT,
    p_phone_e164 TEXT,
    p_service_name TEXT DEFAULT NULL,
    p_intake_type TEXT DEFAULT 'guest'
) RETURNS JSONB AS $$
DECLARE
    v_guest_id UUID;
    v_target_worker_id UUID;
    v_target_worker_name TEXT;
    v_assignment_id UUID;
BEGIN
    -- 1. Upsert guest record idempotently
    INSERT INTO public.guests (
        organization_id, campus_id, team_id, external_source, external_id,
        full_name, phone_original, phone_e164, service_name, intake_type, received_at, current_stage
    )
    VALUES (
        p_organization_id, p_campus_id, p_team_id, 'sheets_intake', p_external_id,
        p_full_name, p_phone_original, p_phone_e164, p_service_name, p_intake_type, NOW(), 'received'
    )
    ON CONFLICT (organization_id, external_source, external_id) 
    DO UPDATE SET
        full_name = EXCLUDED.full_name,
        phone_e164 = EXCLUDED.phone_e164,
        updated_at = NOW()
    RETURNING id INTO v_guest_id;

    -- 2. Select eligible active worker with lowest open workload
    SELECT tm.id, p.full_name INTO v_target_worker_id, v_target_worker_name
    FROM public.team_memberships tm
    JOIN public.profiles p ON p.id = tm.profile_id
    LEFT JOIN public.assignments a ON a.worker_membership_id = tm.id AND a.status = 'active'
    WHERE tm.campus_id = p_campus_id
      AND tm.team_id = p_team_id
      AND tm.role = 'worker'
      AND tm.availability_status = 'active'
      AND tm.active = TRUE
    GROUP BY tm.id, p.full_name, tm.last_assigned_at
    ORDER BY COUNT(a.id) ASC, tm.last_assigned_at ASC NULLS FIRST, tm.id ASC
    LIMIT 1
    FOR UPDATE OF tm;

    -- 3. If worker found, create assignment and update last_assigned_at
    IF v_target_worker_id IS NOT NULL THEN
        -- Complete any existing active assignment for this guest if re-importing
        UPDATE public.assignments 
        SET status = 'completed', completed_at = NOW() 
        WHERE guest_id = v_guest_id AND status = 'active';

        INSERT INTO public.assignments (
            guest_id, worker_membership_id, status, assigned_at, assignment_method
        )
        VALUES (
            v_guest_id, v_target_worker_id, 'active', NOW(), 'auto_fair'
        )
        RETURNING id INTO v_assignment_id;

        UPDATE public.team_memberships 
        SET last_assigned_at = NOW() 
        WHERE id = v_target_worker_id;

        UPDATE public.guests 
        SET current_stage = 'assigned' 
        WHERE id = v_guest_id;
    END IF;

    RETURN jsonb_build_object(
        'guest_id', v_guest_id,
        'assignment_id', v_assignment_id,
        'worker_membership_id', v_target_worker_id,
        'worker_name', COALESCE(v_target_worker_name, 'Unassigned'),
        'status', CASE WHEN v_assignment_id IS NOT NULL THEN 'assigned' ELSE 'unassigned' END
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. ROW LEVEL SECURITY (RLS)
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.team_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.guests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.interactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users read own profile" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Workers read assigned guests" ON public.guests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.assignments a
            JOIN public.team_memberships tm ON tm.id = a.worker_membership_id
            WHERE a.guest_id = public.guests.id
              AND a.status = 'active'
              AND tm.profile_id = auth.uid()
        )
    );

CREATE POLICY "HODs and Admins read all campus guests" ON public.guests
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.team_memberships tm
            WHERE tm.profile_id = auth.uid()
              AND tm.campus_id = public.guests.campus_id
              AND tm.role IN ('hod', 'pastor_viewer', 'admin')
        )
    );
