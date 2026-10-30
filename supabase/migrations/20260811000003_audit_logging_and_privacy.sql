-- PCU Workflow Security & Immutable Audit Trail Trigger System

-- 1. AUDIT LOGS TABLE
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID REFERENCES public.organizations(id),
    actor_id UUID REFERENCES auth.users(id),
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    before_data JSONB,
    after_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_entity ON public.audit_logs(entity_type, entity_id);
CREATE INDEX idx_audit_logs_created_at ON public.audit_logs(created_at DESC);

-- 2. UNIVERSAL AUDIT TRIGGER FUNCTION
CREATE OR REPLACE FUNCTION public.process_audit_log()
RETURNS TRIGGER AS $$
DECLARE
    v_actor_id UUID;
    v_org_id UUID;
BEGIN
    v_actor_id := auth.uid();

    IF (TG_OP = 'DELETE') THEN
        v_org_id := OLD.organization_id;
        INSERT INTO public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, before_data)
        VALUES (v_org_id, v_actor_id, 'DELETE', TG_TABLE_NAME, OLD.id, to_jsonb(OLD));
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        v_org_id := NEW.organization_id;
        INSERT INTO public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, before_data, after_data)
        VALUES (v_org_id, v_actor_id, 'UPDATE', TG_TABLE_NAME, NEW.id, to_jsonb(OLD), to_jsonb(NEW));
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        v_org_id := NEW.organization_id;
        INSERT INTO public.audit_logs (organization_id, actor_id, action, entity_type, entity_id, after_data)
        VALUES (v_org_id, v_actor_id, 'INSERT', TG_TABLE_NAME, NEW.id, to_jsonb(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Attach Audit Triggers to Sensitive Tables
CREATE OR REPLACE TRIGGER audit_guests_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.guests
    FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

CREATE OR REPLACE TRIGGER audit_assignments_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.assignments
    FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

CREATE OR REPLACE TRIGGER audit_team_memberships_trigger
    AFTER INSERT OR UPDATE OR DELETE ON public.team_memberships
    FOR EACH ROW EXECUTE FUNCTION public.process_audit_log();

-- 3. PRIVACY PHONE MASKING FUNCTION FOR PASTOR / VIEWER ROLES
CREATE OR REPLACE FUNCTION public.mask_phone_number(p_phone TEXT)
RETURNS TEXT AS $$
BEGIN
    IF LENGTH(p_phone) < 8 THEN
        return '***';
    END IF;
    RETURN SUBSTRING(p_phone FROM 1 FOR 6) || ' *** ' || SUBSTRING(p_phone FROM LENGTH(p_phone) - 3);
END;
$$ LANGUAGE plpgsql IMMUTABLE SECURITY DEFINER;
