-- Phase 1: additive schema and RPCs. Safe to apply before deploying the new
-- mobile client; access hardening is a separate manual script.
BEGIN;

ALTER TABLE public.trivias
  ADD COLUMN IF NOT EXISTS explanation text,
  ADD COLUMN IF NOT EXISTS source_url text;

CREATE TABLE IF NOT EXISTS public.trivia_point_ledger (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  source_type text NOT NULL
    CHECK (source_type IN ('correct_answer', 'daily_challenge')),
  source_key text NOT NULL,
  points integer NOT NULL CHECK (points > 0),
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT trivia_point_ledger_source_unique
    UNIQUE (user_id, source_type, source_key)
);

CREATE TABLE IF NOT EXISTS public.user_trivia_question_state (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  trivia_id integer NOT NULL REFERENCES public.trivias(id) ON DELETE CASCADE,
  review_stage smallint NOT NULL DEFAULT -1
    CHECK (review_stage BETWEEN -1 AND 4),
  next_review_at timestamp with time zone NOT NULL DEFAULT now(),
  last_answered_at timestamp with time zone,
  mastered_at timestamp with time zone,
  PRIMARY KEY (user_id, trivia_id)
);

CREATE INDEX IF NOT EXISTS user_trivia_question_due_idx
  ON public.user_trivia_question_state (user_id, next_review_at);

CREATE INDEX IF NOT EXISTS trivia_point_ledger_user_idx
  ON public.trivia_point_ledger (user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS trivia_attempts_user_correct_idx
  ON public.trivia_attempts (user_id, trivia_id)
  WHERE is_correct;

ALTER TABLE public.trivia_point_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_trivia_question_state ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.trivia_point_ledger
  FROM PUBLIC, anon, authenticated;
REVOKE ALL ON public.user_trivia_question_state
  FROM PUBLIC, anon, authenticated;

-- Import previously awarded XP as the initial milestone for each question.
INSERT INTO public.trivia_point_ledger (
  user_id,
  source_type,
  source_key,
  points,
  created_at
)
SELECT
  user_id,
  'correct_answer',
  trivia_id::text || ':0',
  max(points_awarded),
  min(created_at)
FROM public.trivia_attempts
WHERE is_correct
  AND points_awarded > 0
GROUP BY user_id, trivia_id
ON CONFLICT (user_id, source_type, source_key) DO NOTHING;

-- The current mobile client stores correct-answer counts in this aggregate.
-- Seed one initial reward per previously answered question with a correct
-- response, without multiplying it by the historical attempt count.
INSERT INTO public.trivia_point_ledger (
  user_id,
  source_type,
  source_key,
  points,
  created_at
)
SELECT
  progress.user_id,
  'correct_answer',
  progress.trivia_id::text || ':0',
  coalesce(trivia.points, 10),
  coalesce(progress.last_attempt, now())
FROM public.user_trivia_progress AS progress
JOIN public.trivias AS trivia
  ON trivia.id = progress.trivia_id
WHERE progress.correct_attempts > 0
ON CONFLICT (user_id, source_type, source_key) DO NOTHING;

-- Previously correct answers begin at the first spaced-review stage.
INSERT INTO public.user_trivia_question_state (
  user_id,
  trivia_id,
  review_stage,
  next_review_at,
  last_answered_at,
  mastered_at
)
SELECT
  user_id,
  trivia_id,
  0,
  now() + interval '1 day',
  max(created_at),
  min(created_at)
FROM public.trivia_attempts
WHERE is_correct
GROUP BY user_id, trivia_id
ON CONFLICT (user_id, trivia_id) DO NOTHING;

INSERT INTO public.user_trivia_question_state (
  user_id,
  trivia_id,
  review_stage,
  next_review_at,
  last_answered_at,
  mastered_at
)
SELECT
  progress.user_id,
  progress.trivia_id,
  0,
  now() + interval '1 day',
  progress.last_attempt,
  coalesce(progress.last_attempt, now())
FROM public.user_trivia_progress AS progress
WHERE progress.correct_attempts > 0
ON CONFLICT (user_id, trivia_id) DO NOTHING;

CREATE OR REPLACE FUNCTION public.get_public_trivias()
RETURNS TABLE (
  id integer,
  question text,
  options jsonb,
  category text,
  difficulty text,
  points integer,
  species_id integer,
  explanation text,
  source_url text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    t.id,
    t.question,
    to_jsonb(t.options),
    t.category,
    t.difficulty,
    coalesce(t.points, 10),
    t.species_id,
    t.explanation,
    t.source_url
  FROM public.trivias AS t
  ORDER BY t.id;
$function$;

REVOKE ALL ON FUNCTION public.get_public_trivias() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_trivias() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.submit_trivia_answer(
  p_trivia_id integer,
  p_selected_option integer
)
RETURNS TABLE (
  is_correct boolean,
  correct_answer integer,
  points_awarded integer,
  review_stage smallint,
  next_review_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_correct_answer integer;
  v_points integer;
  v_option_count integer;
  v_is_correct boolean;
  v_review_stage smallint;
  v_next_review_at timestamp with time zone;
  v_new_review_stage smallint;
  v_candidate_points integer;
  v_points_awarded integer := 0;
  v_inserted_rows integer;
BEGIN
  IF p_trivia_id IS NULL OR p_selected_option IS NULL THEN
    RAISE EXCEPTION 'La pregunta y la opción elegida son obligatorias.';
  END IF;

  SELECT
    t.correct_answer,
    coalesce(t.points, 10),
    jsonb_array_length(to_jsonb(t.options))
  INTO v_correct_answer, v_points, v_option_count
  FROM public.trivias AS t
  WHERE t.id = p_trivia_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La trivia solicitada no existe.';
  END IF;

  IF v_points <= 0 THEN
    RAISE EXCEPTION 'La trivia debe tener una recompensa positiva.';
  END IF;

  IF v_correct_answer IS NULL
    OR v_option_count IS NULL
    OR v_option_count = 0
    OR v_correct_answer < 0
    OR v_correct_answer >= v_option_count
    OR p_selected_option < 0
    OR p_selected_option >= v_option_count
  THEN
    RAISE EXCEPTION 'La opción elegida no es válida.';
  END IF;

  v_is_correct := p_selected_option = v_correct_answer;

  IF v_user_id IS NULL THEN
    RETURN QUERY
    SELECT
      v_is_correct,
      v_correct_answer,
      0,
      NULL::smallint,
      NULL::timestamp with time zone;
    RETURN;
  END IF;

  INSERT INTO public.user_trivia_question_state (user_id, trivia_id)
  VALUES (v_user_id, p_trivia_id)
  ON CONFLICT (user_id, trivia_id) DO NOTHING;

  SELECT state.review_stage, state.next_review_at
  INTO v_review_stage, v_next_review_at
  FROM public.user_trivia_question_state AS state
  WHERE state.user_id = v_user_id
    AND state.trivia_id = p_trivia_id
  FOR UPDATE;

  v_new_review_stage := v_review_stage;

  IF v_is_correct
    AND v_review_stage = -1
    AND v_next_review_at <= now()
  THEN
    v_new_review_stage := 0;
    v_candidate_points := v_points;
  ELSIF v_is_correct
    AND v_review_stage < 4
    AND v_next_review_at <= now()
  THEN
    v_new_review_stage := v_review_stage + 1;
    v_candidate_points := greatest(1, ceil(v_points * 0.25)::integer);
  ELSE
    v_candidate_points := 0;
  END IF;

  IF v_candidate_points > 0 THEN
    INSERT INTO public.trivia_point_ledger (
      user_id,
      source_type,
      source_key,
      points
    )
    VALUES (
      v_user_id,
      'correct_answer',
      p_trivia_id::text || ':' || v_new_review_stage::text,
      v_candidate_points
    )
    ON CONFLICT (user_id, source_type, source_key) DO NOTHING;

    GET DIAGNOSTICS v_inserted_rows = ROW_COUNT;
    IF v_inserted_rows = 1 THEN
      v_points_awarded := v_candidate_points;
    END IF;
  END IF;

  IF v_is_correct THEN
    UPDATE public.user_trivia_question_state AS state
    SET
      review_stage = v_new_review_stage,
      next_review_at = CASE
        WHEN v_new_review_stage > v_review_stage
          OR (
            v_review_stage = 4
            AND v_next_review_at <= now()
          )
        THEN now() + CASE
          WHEN v_new_review_stage = 0 THEN interval '1 day'
          WHEN v_new_review_stage = 1 THEN interval '3 days'
          WHEN v_new_review_stage = 2 THEN interval '7 days'
          ELSE interval '30 days'
        END
        ELSE state.next_review_at
      END,
      last_answered_at = now(),
      mastered_at = CASE
        WHEN v_new_review_stage >= 0 THEN coalesce(state.mastered_at, now())
        ELSE state.mastered_at
      END
    WHERE state.user_id = v_user_id
      AND state.trivia_id = p_trivia_id;
  ELSE
    UPDATE public.user_trivia_question_state AS state
    SET
      review_stage = CASE
        WHEN state.review_stage > 0 THEN state.review_stage - 1
        WHEN state.review_stage = 0 THEN -1
        ELSE state.review_stage
      END,
      next_review_at = now() + interval '10 minutes',
      last_answered_at = now()
    WHERE state.user_id = v_user_id
      AND state.trivia_id = p_trivia_id;
  END IF;

  INSERT INTO public.trivia_attempts (
    user_id,
    trivia_id,
    selected_option,
    is_correct,
    points_awarded
  )
  VALUES (
    v_user_id,
    p_trivia_id,
    p_selected_option,
    v_is_correct,
    v_points_awarded
  );

  INSERT INTO public.user_trivia_progress AS existing_progress (
    user_id,
    trivia_id,
    attempts,
    correct_attempts,
    last_attempt
  )
  VALUES (
    v_user_id,
    p_trivia_id,
    1,
    CASE WHEN v_is_correct THEN 1 ELSE 0 END,
    now()
  )
  ON CONFLICT (user_id, trivia_id)
  DO UPDATE SET
    attempts = coalesce(existing_progress.attempts, 0) + 1,
    correct_attempts = coalesce(existing_progress.correct_attempts, 0)
      + CASE WHEN v_is_correct THEN 1 ELSE 0 END,
    last_attempt = now();

  RETURN QUERY
  SELECT
    v_is_correct,
    v_correct_answer,
    v_points_awarded,
    state.review_stage,
    state.next_review_at
  FROM public.user_trivia_question_state AS state
  WHERE state.user_id = v_user_id
    AND state.trivia_id = p_trivia_id;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_trivia_answer(integer, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_trivia_answer(integer, integer)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_trivia_summary()
RETURNS TABLE (
  total_points bigint,
  mastered_questions bigint,
  total_attempts bigint,
  correct_attempts bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    coalesce((
      SELECT sum(ledger.points)
      FROM public.trivia_point_ledger AS ledger
      WHERE ledger.user_id = auth.uid()
    ), 0),
    (
      SELECT count(*)
      FROM public.user_trivia_question_state AS state
      WHERE state.user_id = auth.uid()
        AND state.mastered_at IS NOT NULL
    ),
    coalesce((
      SELECT sum(progress.attempts)
      FROM public.user_trivia_progress AS progress
      WHERE progress.user_id = auth.uid()
    ), 0),
    coalesce((
      SELECT sum(progress.correct_attempts)
      FROM public.user_trivia_progress AS progress
      WHERE progress.user_id = auth.uid()
    ), 0);
$function$;

REVOKE ALL ON FUNCTION public.get_my_trivia_summary()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_trivia_summary()
  TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_trivia_review_queue()
RETURNS TABLE (
  trivia_id integer,
  review_stage smallint,
  next_review_at timestamp with time zone
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    state.trivia_id,
    state.review_stage,
    state.next_review_at
  FROM public.user_trivia_question_state AS state
  WHERE state.user_id = auth.uid()
    AND state.next_review_at <= now()
  ORDER BY state.next_review_at, state.trivia_id;
$function$;

REVOKE ALL ON FUNCTION public.get_my_trivia_review_queue()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_trivia_review_queue()
  TO authenticated;

COMMIT;
