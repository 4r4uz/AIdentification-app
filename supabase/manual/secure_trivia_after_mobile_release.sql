-- Run only after the mobile app uses get_public_trivias and
-- submit_trivia_answer. Older app versions read/write tables directly.
BEGIN;

CREATE OR REPLACE FUNCTION public.is_trivia_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS profile
    WHERE profile.id = auth.uid()
      AND profile.role = 'admin'
      AND profile.is_active
  );
$function$;

REVOKE ALL ON FUNCTION public.is_trivia_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_trivia_admin() TO anon, authenticated;

ALTER TABLE public.trivias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trivia_admin_manage
  ON public.trivias;
CREATE POLICY trivia_admin_manage
  ON public.trivias
  AS PERMISSIVE
  FOR ALL
  TO authenticated
  USING (public.is_trivia_admin())
  WITH CHECK (public.is_trivia_admin());

DROP POLICY IF EXISTS trivia_admin_access_guard
  ON public.trivias;
CREATE POLICY trivia_admin_access_guard
  ON public.trivias
  AS RESTRICTIVE
  FOR ALL
  TO anon, authenticated
  USING (public.is_trivia_admin())
  WITH CHECK (public.is_trivia_admin());

REVOKE SELECT ON public.trivias FROM PUBLIC, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.trivias TO authenticated;

ALTER TABLE public.user_trivia_progress ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.user_trivia_progress FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_trivia_progress TO authenticated;

DROP POLICY IF EXISTS trivia_progress_read_own
  ON public.user_trivia_progress;
CREATE POLICY trivia_progress_read_own
  ON public.user_trivia_progress
  AS PERMISSIVE
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS trivia_progress_access_guard
  ON public.user_trivia_progress;
CREATE POLICY trivia_progress_access_guard
  ON public.user_trivia_progress
  AS RESTRICTIVE
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

REVOKE INSERT, UPDATE, DELETE ON public.user_trivia_progress
  FROM PUBLIC, anon, authenticated;

ALTER TABLE public.trivia_attempts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.trivia_attempts FROM PUBLIC, anon, authenticated;

COMMIT;
