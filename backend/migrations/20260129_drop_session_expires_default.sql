-- Drop default 15s expiry for sessions so sessions can remain open until explicitly ended
ALTER TABLE public.sessions ALTER COLUMN expires_at DROP DEFAULT;
-- Optional manual migration: if you want to set existing sessions to have no expiry, run:
-- UPDATE public.sessions SET expires_at = NULL WHERE expires_at IS NOT NULL;