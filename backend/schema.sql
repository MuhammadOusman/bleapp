-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.attendance (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  session_id uuid,
  student_id uuid,
  marked_at timestamp with time zone DEFAULT now(),
  CONSTRAINT attendance_pkey PRIMARY KEY (id),
  CONSTRAINT attendance_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.sessions(id),
  CONSTRAINT attendance_student_id_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.courses (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  course_code text NOT NULL UNIQUE,
  course_name text NOT NULL,
  teacher_id uuid,
  CONSTRAINT courses_pkey PRIMARY KEY (id),
  CONSTRAINT courses_teacher_id_fkey FOREIGN KEY (teacher_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.enrollments (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  course_id uuid NOT NULL,
  student_id uuid NOT NULL,
  enrolled_at timestamp with time zone DEFAULT now(),
  source text,
  CONSTRAINT enrollments_pkey PRIMARY KEY (id),
  CONSTRAINT enrollments_course_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id),
  CONSTRAINT enrollments_student_fkey FOREIGN KEY (student_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text NOT NULL UNIQUE,
  full_name text NOT NULL,
  role USER-DEFINED NOT NULL,
  lms_id text,
  device_signature text,
  created_at timestamp with time zone DEFAULT now(),
  blocked_signatures ARRAY DEFAULT '{}'::text[],
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
CREATE TABLE public.sessions (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  course_id uuid,
  session_number integer NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  expires_at timestamp with time zone,
  is_active boolean DEFAULT true,
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id)
);


-- 1. Create the function to check the role
CREATE OR REPLACE FUNCTION public.validate_course_teacher()
RETURNS TRIGGER AS $$
BEGIN
  -- Only check if a teacher_id is actually provided
  IF NEW.teacher_id IS NOT NULL THEN
    -- Check if the profile exists AND has the role 'teacher'
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = NEW.teacher_id AND role = 'teacher'
    ) THEN
      RAISE EXCEPTION 'Invalid Assignment: The user (ID: %) is not a Teacher.', NEW.teacher_id;
    END IF;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Attach the trigger to the courses table
DROP TRIGGER IF EXISTS check_teacher_role_trigger ON public.courses;
CREATE TRIGGER check_teacher_role_trigger
BEFORE INSERT OR UPDATE ON public.courses
FOR EACH ROW
EXECUTE FUNCTION public.validate_course_teacher();