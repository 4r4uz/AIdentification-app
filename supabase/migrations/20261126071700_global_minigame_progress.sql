BEGIN;

ALTER TABLE public.trivia_point_ledger
  ADD COLUMN IF NOT EXISTS game_code text NOT NULL DEFAULT 'trivia';

ALTER TABLE public.trivia_point_ledger
  DROP CONSTRAINT IF EXISTS trivia_point_ledger_game_code_check;

ALTER TABLE public.trivia_point_ledger
  ADD CONSTRAINT trivia_point_ledger_game_code_check
  CHECK (game_code ~ '^[a-z][a-z0-9_]{1,39}$');

ALTER TABLE public.trivia_point_ledger
  DROP CONSTRAINT IF EXISTS trivia_point_ledger_source_type_check;

ALTER TABLE public.trivia_point_ledger
  ADD CONSTRAINT trivia_point_ledger_source_type_check
  CHECK (
    source_type IN (
      'correct_answer',
      'minigame_reward',
      'daily_challenge'
    )
  );

DROP FUNCTION IF EXISTS public.submit_trivia_answer(integer, integer);

CREATE FUNCTION public.submit_trivia_answer(
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
    trivia.correct_answer,
    coalesce(trivia.points, 10),
    jsonb_array_length(to_jsonb(trivia.options))
  INTO v_correct_answer, v_points, v_option_count
  FROM public.trivias AS trivia
  WHERE trivia.id = p_trivia_id
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
      game_code,
      source_type,
      source_key,
      points
    )
    VALUES (
      v_user_id,
      'trivia',
      'minigame_reward',
      'trivia:' || p_trivia_id::text || ':'
        || v_new_review_stage::text,
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

CREATE OR REPLACE FUNCTION public.get_my_game_progress()
RETURNS TABLE (
  total_xp bigint,
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

REVOKE ALL ON FUNCTION public.get_my_game_progress()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_game_progress()
  TO authenticated;

COMMIT;
