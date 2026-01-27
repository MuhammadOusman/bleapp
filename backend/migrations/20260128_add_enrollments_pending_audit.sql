-- Add enrollments, pending_students, and audit_logs tables
-- Run in a transaction in staging before production
BEGIN;

-- Enrollments mapping table
CREATE TABLE IF NOT EXISTS public.enrollments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL,
  student_id uuid NOT NULL,
  enrolled_at timestamptz DEFAULT now(),
  source text,
  CONSTRAINT enrollments_pkey PRIMARY KEY (id),
  CONSTRAINT enrollments_course_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id) ON DELETE CASCADE,
  CONSTRAINT enrollments_student_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT enrollments_unique UNIQUE (course_id, student_id)
);
CREATE INDEX IF NOT EXISTS idx_enrollments_course ON public.enrollments(course_id);
CREATE INDEX IF NOT EXISTS idx_enrollments_student ON public.enrollments(student_id);

-- Pending students (imported from master_students or CSV)
CREATE TABLE IF NOT EXISTS public.pending_students (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  lms_id text,
  email text NOT NULL,
  full_name text NOT NULL,
  source text,
  status text DEFAULT 'pending', -- pending, approved, invited
  imported_by uuid,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT pending_students_unique_email UNIQUE (email)
);
CREATE INDEX IF NOT EXISTS idx_pending_lms ON public.pending_students(lms_id);

-- Audit logs for admin actions
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  actor_profile_id uuid NOT NULL,
  action text NOT NULL,
  target_type text,
  target_id text,
  details jsonb,
  created_at timestamptz DEFAULT now(),
  CONSTRAINT audit_logs_pkey PRIMARY KEY (id)
);
CREATE INDEX IF NOT EXISTS idx_audit_actor ON public.audit_logs (actor_profile_id);
CREATE INDEX IF NOT EXISTS idx_audit_created_at ON public.audit_logs (created_at);

COMMIT;
