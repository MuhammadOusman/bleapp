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
  teacher_email text,
  CONSTRAINT courses_pkey PRIMARY KEY (id),
  CONSTRAINT courses_teacher_email_fkey FOREIGN KEY (teacher_email) REFERENCES public.master_teachers(email)
);

CREATE TABLE public.master_students (
  lms_id text NOT NULL,
  email text NOT NULL UNIQUE,
  full_name text NOT NULL,
  CONSTRAINT master_students_pkey PRIMARY KEY (lms_id)
);

CREATE TABLE public.master_teachers (
  email text NOT NULL,
  full_name text NOT NULL,
  CONSTRAINT master_teachers_pkey PRIMARY KEY (email)
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
  expires_at timestamp with time zone DEFAULT (now() + '00:00:15'::interval),
  is_active boolean DEFAULT true,
  CONSTRAINT sessions_pkey PRIMARY KEY (id),
  CONSTRAINT sessions_course_id_fkey FOREIGN KEY (course_id) REFERENCES public.courses(id)
);