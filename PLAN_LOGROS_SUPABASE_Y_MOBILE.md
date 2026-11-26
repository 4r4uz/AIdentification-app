# Logros y Trivia de AnimalPedia: Supabase e implementación móvil

## Alcance

Este documento deja preparado el diseño para mejorar Trivia y añadir logros
más adelante. No aplica SQL ni modifica la aplicación. La migración incluida
es una base que debe probarse en un proyecto de desarrollo y ajustarse a las
políticas RLS ya existentes antes de ejecutarla en producción.

## Estado actual

El esquema ya contiene:

- `public.achievements`: catálogo con `id`, `name`, `description`, `icon_url`,
  `requirement_type` y `requirement_value`.
- `public.user_achievements`: logros obtenidos, con una clave primaria
  (`user_id`, `achievement_id`) que evita duplicar una obtención.
- `public.detections`: actividad de avistamientos.
- `public.user_trivia_progress`: contadores agregados por persona y trivia.
- `public.trivia_attempts`: detalle de las respuestas, incluida la respuesta
  elegida y si fue correcta.

En Mobile aún no existe un modelo, servicio o pantalla de logros. El acceso
desde Home abre un diálogo provisional en
`lib/mobile/features/home/presentation/screens/home_screen.dart`.
La respuesta de trivia se registra hoy desde
`lib/mobile/features/trivia/data/services/trivia_service.dart`: el cliente
calcula si fue correcta y escribe directamente los contadores agregados. La
pantalla de trivia carga todas las columnas de `trivias`, incluida
`correct_answer`.

El panel Web tiene un listado de logros, pero todavía no presenta una
experiencia móvil ni un sistema de desbloqueo automático.

## Diseño recomendado

1. `achievements` es el catálogo editable por administración y de solo lectura
   para los usuarios de la aplicación.
2. `user_achievements` es un registro de desbloqueos. El usuario puede leer
   solo sus filas; no puede otorgarse logros escribiendo desde Mobile.
3. Funciones y triggers de Postgres calculan requisitos y hacen los
   desbloqueos con `ON CONFLICT DO NOTHING`.
4. `requirement_type` usa claves estables, no texto de presentación:
   - `detection_count`: detecciones guardadas.
   - `species_count`: especies distintas identificadas en detecciones.
   - `trivia_attempt_count`: respuestas registradas.
   - `trivia_correct_count`: preguntas distintas respondidas correctamente.
5. Se empieza con logros acumulativos. Retos por fecha, rachas y colecciones
   por categoría necesitan datos adicionales que el esquema actual no mantiene.
6. Desactivar un logro lo quita del catálogo disponible, pero no revoca ni
   elimina las obtenciones históricas.

## Propuesta de producto para Trivia

### Qué debe conseguir el minijuego

Trivia debe ayudar a aprender sobre especies, no ser solo un cuestionario para
acumular puntos. Cada respuesta debe enseñar algo: indicar si fue correcta,
explicar brevemente el dato y ofrecer una ficha de la especie o una fuente para
seguir explorando. El bucle principal será:

1. Elegir un tema o continuar una recomendación.
2. Responder una ronda corta y recibir retroalimentación educativa.
3. Ver aciertos, repasos que consolidaron conocimiento, puntos y progreso de
   rango.
4. Recibir una sugerencia concreta para la siguiente ronda o un logro cercano.

### Modos de juego

- **Práctica:** conserva la configuración existente de categoría, dificultad,
  cantidad de preguntas y temporizador opcional. Es el modo libre para aprender
  sin presión; el tiempo no da puntos extra.
- **Reto diario (segunda etapa):** cinco preguntas distintas con tema común,
  iguales para todas las cuentas ese día. Se completa al responder las cinco;
  puede otorgar un bono pequeño una sola vez por cuenta y fecha. No debe
  lanzarse con recompensa hasta que Supabase registre y valide la sesión.
- **Expediciones por tema (etapa posterior):** series cortas sobre una especie,
  hábitat o grupo de fauna, vinculadas a fichas de especies y a objetivos de
  colección. Requieren suficiente contenido y datos de sesión para evitar
  repetir preguntas y reclamar recompensas.

Las cuentas gratuitas pueden jugar y guardar progreso. El invitado puede
practicar sin sincronización ni puntos persistentes; las recompensas, rangos y
retos se asocian a una cuenta. Las preguntas y categorías básicas no se
bloquean tras suscripción.

### Decisión sobre los puntos

Los puntos serán **XP de Naturalista**, no una moneda que se gasta. Se acumulan
de forma permanente, no se compran, no se transfieren y no se pierden al
repetir una respuesta incorrecta. Así el progreso es fácil de entender y no
requiere una tienda, saldos editables ni inflación de una economía virtual.

- **No descartar preguntas después de responderlas.** Se mantienen en el
  catálogo y vuelven a aparecer en una cola de repaso espaciado, intercaladas
  con preguntas nuevas y otras pendientes.
- Un primer acierto concede XP según `trivias.points`. Como valores iniciales,
  calibrar el catálogo a 10 puntos (fácil), 15 (medio) y 20 (difícil).
- Un acierto durante un repaso programado puede dar un bono pequeño de
  consolidación (por ejemplo, 25% del valor base, redondeado hacia arriba).
  Solo se entrega una vez por cada etapa espaciada, no por cada respuesta.
- Un acierto antes de que venza el siguiente repaso sirve para practicar y
  mostrar feedback, pero no adelanta el calendario ni da XP adicional.
- Una respuesta incorrecta da 0 XP, no quita puntos y vuelve a programar la
  pregunta pronto para intentarla de nuevo, con una explicación educativa.
- Sin bonificación por velocidad: mantiene accesibilidad y premia conocimiento,
  no solo rapidez.
- Reto diario futuro: bono de 20 XP al completar las cinco preguntas; se
  concede una vez por fecha y no multiplica las recompensas por respuesta.

### Repetición espaciada: recordar, no memorizar una sola vez

Cada cuenta tiene una planificación independiente por pregunta. El primer
acierto inicia la etapa de aprendizaje; cada acierto en su repaso debido avanza
la pregunta a un intervalo mayor. Propuesta inicial: repasar después de 1 día,
3 días, 7 días y 30 días. Al completar estas etapas la pregunta sigue disponible
en práctica y en repasos periódicos, pero ya no genera XP. Un error programa un
repaso corto (por ejemplo, en 10 minutos) y no concede recompensa. Ajustar los
intervalos con datos de uso y aprendizaje real.

La aplicación debe mezclar preguntas nuevas con las que ya toca repasar. El
usuario puede elegir una sesión de repaso cuando exista una cola vencida, o
practicar cualquier categoría en cualquier momento. Mostrar de forma clara
“Nuevas”, “Por repasar” y “Dominadas”, sin convertir las dominadas en preguntas
inaccesibles.

Para fomentar recuerdo activo y reducir la búsqueda de respuestas, mantener la
respuesta y explicación ocultas hasta responder; dar feedback después, evitar
puntos por velocidad y favorecer rondas mixtas. Una opción futura es un modo
“recuerdo” que oculte las alternativas hasta que la persona intente responder.
No se puede impedir que alguien consulte Google; el diseño debe hacer más
valioso recuperar la respuesta de memoria y volver a verla espaciadamente que
buscar una respuesta una sola vez. No usar castigos, vidas limitadas ni pérdida
de XP por fallar.

El XP desbloquea rangos y reconocimientos cosméticos, sin dar ventajas en la
identificación de especies ni en el resultado de las partidas. Propuesta
inicial de rangos basada en XP total ganado: Aprendiz (0), Explorador (100),
Naturalista (300), Investigador (700) y Experto de campo (1500). Los umbrales
son configurables y se deben ajustar según el tamaño real del catálogo. Como
primeras recompensas, usar títulos de perfil y distintivos; marcos o temas
visuales pueden venir después. No introducir una tienda de puntos en la primera
versión.

### Objetivos que motivan a volver

- **Dominio:** responder correctamente preguntas distintas, con hitos de 1, 10,
  25 y 50 especies o preguntas dominadas.
- **Repaso inteligente:** priorizar preguntas vencidas y dar un reconocimiento
  al consolidar una pregunta en los intervalos 1, 3, 7 y 30 días.
- **Constancia flexible:** un objetivo semanal, por ejemplo completar tres
  rondas en cualquier categoría. No quitar puntos ni reiniciar rangos por
  perder un día.
- **Exploración:** sugerir una categoría poco jugada o una trivia relacionada
  con la última especie identificada.
- **Reto diario:** cuando exista el registro server-side, completar cinco
  preguntas; la racha es opcional, solo cosmética y no debe castigar pausas.
- **Aprendizaje:** después de cada respuesta, mostrar explicación y una acción
  “Explorar especie”. El historial resume categorías fuertes y temas por
  practicar.

La primera versión debe priorizar Práctica, feedback explicativo, XP por
pregunta única, rangos y logros. El reto diario, objetivos semanales y rachas
requieren guardar sesiones y fechas de manera confiable en Supabase; no
simularlos solo con estado local.

## Preparación antes del SQL

### Revisar los criterios existentes

El catálogo puede contener valores históricos de `requirement_type` que no
están reflejados en el esquema compartido. Revisarlos primero:

```sql
SELECT id, name, requirement_type, requirement_value
FROM public.achievements
ORDER BY id;
```

Convertir cualquier tipo antiguo a una de las cuatro claves soportadas o
decidir expresamente cómo manejarlo. La migración aborta si encuentra tipos no
reconocidos, en vez de reinterpretar logros existentes silenciosamente.

### Revisar políticas RLS actuales

Las políticas permisivas de Postgres se combinan con `OR`. Antes de ejecutar la
migración, comprobar si hay políticas antiguas para estas tablas:

```sql
SELECT tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN (
    'achievements',
    'user_achievements',
    'user_trivia_progress',
    'trivia_attempts',
    'trivia_point_ledger'
  )
ORDER BY tablename, policyname;
```

Revisar y retirar políticas que permitan a `anon` o `authenticated` escribir
logros o alterar directamente el progreso de otra persona. No borrar políticas
sin revisar qué funciones de la aplicación ya dependen de ellas.

Comprobar también que todas las preguntas tengan un valor de recompensa
positivo antes de activar la RPC:

```sql
SELECT id, difficulty, points
FROM public.trivias
WHERE points IS NULL OR points <= 0
ORDER BY id;
```

Revisar la calibración propuesta por dificultad y ajustar manualmente las
preguntas que no coincidan:

```sql
SELECT id, difficulty, points
FROM public.trivias
WHERE points IS DISTINCT FROM CASE difficulty
  WHEN 'facil' THEN 10
  WHEN 'medio' THEN 15
  WHEN 'dificil' THEN 20
  ELSE points
END
ORDER BY id;
```

## SQL propuesto

> **Implementación por etapas:** el SQL ejecutable para Trivia está en
> `supabase/migrations/20261126030500_trivia_spaced_repetition.sql`. Ejecutar
> ese archivo primero desde Supabase SQL Editor. La restricción de lectura
> administrativa está separada en
> `supabase/manual/secure_trivia_after_mobile_release.sql`: ejecutarla solo
> después de publicar una versión móvil que use `get_public_trivias` y
> `submit_trivia_answer`. No ejecutar el bloque de referencia de abajo como
> migración adicional. La primera migración también importa el progreso
> histórico de `user_trivia_progress` como un único hito inicial por pregunta,
> porque la app anterior guardaba allí los aciertos y no en
> `trivia_attempts`.

El bloque asume los nombres de tablas y columnas del esquema compartido. Debe
probarse primero en staging. La parte de seguridad para `user_trivia_progress`
requiere desplegar Mobile con la llamada RPC descrita abajo en el mismo
lanzamiento; si se aplica antes, el guardado actual de trivias dejará de poder
escribir los contadores. El ledger es la fuente de verdad del XP y usa una
clave distinta por etapa de repaso. Los puntos históricos se importan como el
primer hito de cada pregunta y cuenta.

```sql
BEGIN;

-- Código estable para referenciar logros desde Mobile y semillas repetibles.
ALTER TABLE public.achievements
  ADD COLUMN IF NOT EXISTS code text;

UPDATE public.achievements
SET code = 'legacy-' || id::text
WHERE code IS NULL;

ALTER TABLE public.achievements
  ALTER COLUMN code SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS achievements_code_uidx
  ON public.achievements (code);

ALTER TABLE public.achievements
  ADD COLUMN IF NOT EXISTS is_active boolean NOT NULL DEFAULT true;

CREATE INDEX IF NOT EXISTS detections_user_species_idx
  ON public.detections (user_id, species_id)
  WHERE species_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS user_achievements_achievement_id_idx
  ON public.user_achievements (achievement_id);

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

-- Importa el máximo histórico por pregunta como hito inicial (etapa 0).
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

-- Las respuestas correctas históricas comienzan en la primera etapa de repaso.
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

DO $migration$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.achievements
    WHERE requirement_type IS NOT NULL
      AND requirement_type NOT IN (
        'detection_count',
        'species_count',
        'trivia_attempt_count',
        'trivia_correct_count'
      )
  ) THEN
    RAISE EXCEPTION
      'Hay requirement_type antiguos sin convertir. Revísalos antes de aplicar esta migración.';
  END IF;
END
$migration$;

ALTER TABLE public.achievements
  ADD CONSTRAINT achievements_requirement_type_supported
  CHECK (
    requirement_type IS NULL
    OR requirement_type IN (
      'detection_count',
      'species_count',
      'trivia_attempt_count',
      'trivia_correct_count'
    )
  ) NOT VALID;

ALTER TABLE public.achievements
  ADD CONSTRAINT achievements_requirement_value_positive
  CHECK (requirement_value IS NULL OR requirement_value > 0) NOT VALID;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT EXISTS (
    SELECT 1
    FROM public.profiles AS p
    WHERE p.id = (SELECT auth.uid())
      AND p.role = 'admin'
  );
$function$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_trivia_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivia_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trivia_point_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_trivia_question_state ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.achievements FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.achievements TO anon, authenticated;
GRANT INSERT, UPDATE, DELETE ON public.achievements TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.achievements_id_seq TO authenticated;

-- Public quiz reads exclude correct_answer; answer validation stays server-side.
REVOKE SELECT ON public.trivias FROM PUBLIC, anon, authenticated;
GRANT SELECT (
  id,
  question,
  options,
  category,
  difficulty,
  points,
  species_id,
  explanation,
  source_url
) ON public.trivias TO anon, authenticated;

REVOKE ALL ON public.user_achievements FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_achievements TO authenticated;

REVOKE ALL ON public.user_trivia_progress FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_trivia_progress TO authenticated;

REVOKE ALL ON public.trivia_attempts FROM PUBLIC, anon, authenticated;

REVOKE ALL ON public.trivia_point_ledger FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.trivia_point_ledger TO authenticated;

REVOKE ALL ON public.user_trivia_question_state
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.user_trivia_question_state TO authenticated;

DROP POLICY IF EXISTS achievements_read_available
  ON public.achievements;
CREATE POLICY achievements_read_available
  ON public.achievements
  FOR SELECT
  TO anon, authenticated
  USING (
    is_active
    OR public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.user_achievements AS ua
      WHERE ua.achievement_id = achievements.id
        AND ua.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS achievements_admin_manage
  ON public.achievements;
CREATE POLICY achievements_admin_manage
  ON public.achievements
  FOR ALL
  TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS user_achievements_read_own
  ON public.user_achievements;
CREATE POLICY user_achievements_read_own
  ON public.user_achievements
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS user_trivia_progress_read_own
  ON public.user_trivia_progress;
CREATE POLICY user_trivia_progress_read_own
  ON public.user_trivia_progress
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS trivia_point_ledger_read_own
  ON public.trivia_point_ledger;
CREATE POLICY trivia_point_ledger_read_own
  ON public.trivia_point_ledger
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS user_trivia_question_state_read_own
  ON public.user_trivia_question_state;
CREATE POLICY user_trivia_question_state_read_own
  ON public.user_trivia_question_state
  FOR SELECT
  TO authenticated
  USING (user_id = (SELECT auth.uid()));

-- Calcula los requisitos en la base de datos. Solo se llama desde triggers.
CREATE OR REPLACE FUNCTION public.evaluate_user_achievements(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_detection_count bigint;
  v_species_count bigint;
  v_trivia_attempt_count bigint;
  v_trivia_correct_count bigint;
  v_progress bigint;
  v_achievement record;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN;
  END IF;

  SELECT
    count(*),
    count(DISTINCT species_id)
  INTO v_detection_count, v_species_count
  FROM public.detections
  WHERE user_id = p_user_id;

  SELECT coalesce(sum(attempts), 0)
  INTO v_trivia_attempt_count
  FROM public.user_trivia_progress
  WHERE user_id = p_user_id;

  SELECT count(DISTINCT trivia_id)
  INTO v_trivia_correct_count
  FROM public.trivia_attempts
  WHERE user_id = p_user_id
    AND is_correct;

  FOR v_achievement IN
    SELECT id, requirement_type, requirement_value
    FROM public.achievements
    WHERE is_active
      AND requirement_type IS NOT NULL
      AND requirement_value IS NOT NULL
      AND requirement_value > 0
  LOOP
    v_progress := CASE v_achievement.requirement_type
      WHEN 'detection_count' THEN v_detection_count
      WHEN 'species_count' THEN v_species_count
      WHEN 'trivia_attempt_count' THEN v_trivia_attempt_count
      WHEN 'trivia_correct_count' THEN v_trivia_correct_count
      ELSE 0
    END;

    IF v_progress >= v_achievement.requirement_value THEN
      INSERT INTO public.user_achievements (user_id, achievement_id)
      VALUES (p_user_id, v_achievement.id)
      ON CONFLICT (user_id, achievement_id) DO NOTHING;
    END IF;
  END LOOP;
END;
$function$;

REVOKE ALL ON FUNCTION public.evaluate_user_achievements(uuid)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.refresh_achievements_after_activity()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  PERFORM public.evaluate_user_achievements(NEW.user_id);
  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.refresh_achievements_after_activity()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS detections_award_achievements
  ON public.detections;
CREATE TRIGGER detections_award_achievements
  AFTER INSERT ON public.detections
  FOR EACH ROW
  EXECUTE FUNCTION public.refresh_achievements_after_activity();

DROP TRIGGER IF EXISTS trivia_progress_award_achievements
  ON public.user_trivia_progress;
CREATE TRIGGER trivia_progress_award_achievements
  AFTER INSERT OR UPDATE ON public.user_trivia_progress
  FOR EACH ROW
  EXECUTE FUNCTION public.refresh_achievements_after_activity();

-- Registra y verifica respuestas desde servidor. El cliente no envía user_id
-- ni is_correct; ambos se obtienen/verifican con la sesión y la tabla trivias.
CREATE OR REPLACE FUNCTION public.submit_trivia_answer(
  p_trivia_id integer,
  p_selected_option integer
)
RETURNS TABLE (
  is_correct boolean,
  points_awarded integer,
  correct_answer integer
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
  v_points_awarded integer;
  v_review_stage smallint;
  v_next_review_at timestamp with time zone;
  v_new_review_stage smallint;
  v_candidate_points integer;
  v_inserted_rows integer;
BEGIN
  SELECT
    t.correct_answer,
    coalesce(t.points, 10),
    array_length(t.options, 1)
  INTO v_correct_answer, v_points, v_option_count
  FROM public.trivias AS t
  WHERE t.id = p_trivia_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La trivia solicitada no existe.';
  END IF;

  IF v_points <= 0 THEN
    RAISE EXCEPTION 'La trivia debe tener una recompensa positiva configurada.';
  END IF;

  IF v_option_count IS NULL
    OR p_selected_option < 0
    OR p_selected_option >= v_option_count
  THEN
    RAISE EXCEPTION 'La opción elegida no es válida.';
  END IF;

  v_is_correct := p_selected_option = v_correct_answer;
  v_points_awarded := 0;

  IF v_user_id IS NULL THEN
    RETURN QUERY SELECT v_is_correct, v_points_awarded, v_correct_answer;
    RETURN;
  END IF;

  INSERT INTO public.user_trivia_question_state (user_id, trivia_id)
  VALUES (v_user_id, p_trivia_id)
  ON CONFLICT (user_id, trivia_id) DO NOTHING;

  SELECT review_stage, next_review_at
  INTO v_review_stage, v_next_review_at
  FROM public.user_trivia_question_state
  WHERE user_id = v_user_id
    AND trivia_id = p_trivia_id
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
    UPDATE public.user_trivia_question_state
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
        ELSE next_review_at
      END,
      last_answered_at = now(),
      mastered_at = CASE
        WHEN v_new_review_stage >= 0 THEN coalesce(mastered_at, now())
        ELSE mastered_at
      END
    WHERE user_id = v_user_id
      AND trivia_id = p_trivia_id;
  ELSE
    UPDATE public.user_trivia_question_state
    SET
      review_stage = CASE
        WHEN review_stage > 0 THEN review_stage - 1
        WHEN review_stage = 0 THEN -1
        ELSE review_stage
      END,
      next_review_at = now() + interval '10 minutes',
      last_answered_at = now()
    WHERE user_id = v_user_id
      AND trivia_id = p_trivia_id;
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
    correct_attempts = coalesce(
      existing_progress.correct_attempts,
      0
    ) + CASE WHEN v_is_correct THEN 1 ELSE 0 END,
    last_attempt = now();

  RETURN QUERY
  SELECT v_is_correct, v_points_awarded, v_correct_answer;
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_trivia_answer(integer, integer)
  FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.submit_trivia_answer(integer, integer)
  TO anon, authenticated;

-- Progreso para la pantalla móvil. Devuelve únicamente datos de la sesión.
CREATE OR REPLACE FUNCTION public.get_my_achievement_progress()
RETURNS TABLE (
  achievement_id integer,
  code text,
  name text,
  description text,
  icon_url text,
  requirement_type text,
  current_value bigint,
  requirement_value integer,
  unlocked_at timestamp without time zone
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  WITH current_user_data AS (
    SELECT auth.uid() AS user_id
  ),
  user_progress AS (
    SELECT
      u.user_id,
      (
        SELECT count(*)
        FROM public.detections AS d
        WHERE d.user_id = u.user_id
      ) AS detection_count,
      (
        SELECT count(DISTINCT d.species_id)
        FROM public.detections AS d
        WHERE d.user_id = u.user_id
      ) AS species_count,
      (
        SELECT coalesce(sum(p.attempts), 0)
        FROM public.user_trivia_progress AS p
        WHERE p.user_id = u.user_id
      ) AS trivia_attempt_count,
      (
        SELECT count(DISTINCT a.trivia_id)
        FROM public.trivia_attempts AS a
        WHERE a.user_id = u.user_id
          AND a.is_correct
      ) AS trivia_correct_count
    FROM current_user_data AS u
  )
  SELECT
    a.id,
    a.code,
    a.name,
    a.description,
    a.icon_url,
    a.requirement_type,
    CASE a.requirement_type
      WHEN 'detection_count' THEN p.detection_count
      WHEN 'species_count' THEN p.species_count
      WHEN 'trivia_attempt_count' THEN p.trivia_attempt_count
      WHEN 'trivia_correct_count' THEN p.trivia_correct_count
      ELSE 0
    END,
    a.requirement_value,
    ua.unlocked_at
  FROM public.achievements AS a
  CROSS JOIN user_progress AS p
  LEFT JOIN public.user_achievements AS ua
    ON ua.achievement_id = a.id
    AND ua.user_id = p.user_id
  WHERE p.user_id IS NOT NULL
    AND (
      a.is_active
      OR ua.user_id IS NOT NULL
    )
  ORDER BY a.id;
$function$;

REVOKE ALL ON FUNCTION public.get_my_achievement_progress()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_achievement_progress()
  TO authenticated;

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
      SELECT sum(l.points)
      FROM public.trivia_point_ledger AS l
      WHERE l.user_id = auth.uid()
    ), 0),
    (
      SELECT count(*)
      FROM public.user_trivia_question_state AS s
      WHERE s.user_id = auth.uid()
        AND s.mastered_at IS NOT NULL
    ),
    coalesce((
      SELECT sum(p.attempts)
      FROM public.user_trivia_progress AS p
      WHERE p.user_id = auth.uid()
    ), 0),
    coalesce((
      SELECT sum(p.correct_attempts)
      FROM public.user_trivia_progress AS p
      WHERE p.user_id = auth.uid()
    ), 0);
$function$;

REVOKE ALL ON FUNCTION public.get_my_trivia_summary()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_trivia_summary()
  TO authenticated;

-- Otorga retroactivamente logros a personas que ya alcanzaron los requisitos.
DO $backfill$
DECLARE
  v_user_id uuid;
BEGIN
  FOR v_user_id IN
    SELECT user_id FROM public.detections
    UNION
    SELECT user_id FROM public.user_trivia_progress
  LOOP
    PERFORM public.evaluate_user_achievements(v_user_id);
  END LOOP;
END
$backfill$;

COMMIT;
```

### Consideraciones antes de aplicar

- Si el nombre real de la secuencia de `achievements.id` no es
  `achievements_id_seq`, ajustar el `GRANT` a la secuencia correcta. Consultarla
  con `pg_get_serial_sequence('public.achievements', 'id')`.
- La función asume que `trivias.options` es un arreglo PostgreSQL indexado desde
  cero en `correct_answer`, como indica el uso actual de Flutter
  (`selectedIndex == correctAnswer`). Confirmarlo con preguntas conocidas
  antes de desplegar.
- Confirmar que `trivia_attempts` y `user_trivia_progress` tienen exactamente
  las columnas del esquema compartido.
- Esta migración restringe las escrituras directas a `user_trivia_progress`.
  Desplegar la nueva llamada RPC en Mobile antes de aplicar esa restricción.
- Los permisos de administración de `achievements` permiten a los
  administradores del panel actual seguir gestionando el catálogo vía
  Supabase. Si existen otras políticas para estas tablas, conciliarlas para
  que no amplíen acceso.
- No borrar filas de `achievements` que ya tengan obtenciones relacionadas.
  Marcar `is_active = false` conserva el historial y es la opción recomendada.

## Datos de ejemplo para probar

Semillas idempotentes: se pueden ejecutar más de una vez sin duplicar logros.
Cambiar nombres, textos o requisitos antes de producción.

```sql
INSERT INTO public.achievements (
  code,
  name,
  description,
  requirement_type,
  requirement_value,
  is_active
)
VALUES
  (
    'first_detection',
    'Primer encuentro',
    'Guarda tu primera detección.',
    'detection_count',
    1,
    true
  ),
  (
    'field_explorer',
    'Explorador',
    'Guarda 10 detecciones.',
    'detection_count',
    10,
    true
  ),
  (
    'species_collector',
    'Coleccionista',
    'Descubre 5 especies distintas.',
    'species_count',
    5,
    true
  ),
  (
    'trivia_apprentice',
    'Aprendiz naturalista',
    'Domina 10 preguntas distintas.',
    'trivia_correct_count',
    10,
    true
  ),
  (
    'curious_mind',
    'Mente curiosa',
    'Responde 50 preguntas de trivia.',
    'trivia_attempt_count',
    50,
    true
  )
ON CONFLICT (code) DO NOTHING;
```

El evaluador se ejecuta al insertar una detección o al insertar/actualizar el
progreso de trivia. Los logros retroactivos se calculan al final de la
migración. `ON CONFLICT (user_id, achievement_id) DO NOTHING` hace que un
reintento de trigger no duplique una concesión.

El RPC de Trivia devuelve `is_correct`, `points_awarded` y `correct_answer`
solo después de que se envía la respuesta. A invitadas/os les devuelve la
evaluación sin guardar intentos ni otorgar XP; las cuentas autenticadas además
guardan el intento, el progreso, el estado del repaso y el XP en la misma
transacción. La clave única del ledger incluye la etapa de repaso: repetir
antes de tiempo no da XP, y cada hito programado puede premiarse una sola vez.

Como las semillas se insertan después de la migración principal, volver a
evaluar la actividad existente inmediatamente después de sembrar el catálogo:

```sql
DO $backfill$
DECLARE
  v_user_id uuid;
BEGIN
  FOR v_user_id IN
    SELECT user_id FROM public.detections
    UNION
    SELECT user_id FROM public.user_trivia_progress
  LOOP
    PERFORM public.evaluate_user_achievements(v_user_id);
  END LOOP;
END
$backfill$;
```

Repetir este backfill después de crear o cambiar requisitos de logros desde el
panel, de modo que las personas que ya cumplen el nuevo umbral no tengan que
generar actividad adicional para obtenerlo.

## Integración futura en Mobile

### Estructura sugerida

Mantener trivia y logros como features móviles separados, sin colocar Dart
directamente en `lib/` ni reutilizar pantallas administrativas Web:

```text
lib/mobile/features/trivia/
├── data/
│   ├── models/trivia_model.dart
│   └── services/trivia_service.dart
└── presentation/
    └── screens/trivia_screen.dart

lib/mobile/features/achievements/
├── data/
│   ├── models/achievement_progress_model.dart
│   └── services/achievement_service.dart
└── presentation/
    └── screens/achievements_screen.dart
```

Registrar los servicios en `lib/mobile/core/service_locator.dart`. Mantener
consultas y modelos bajo `lib/mobile/features/`; usar `SupabaseService` para
acceso al backend, de acuerdo con `lib/ARCHITECTURE.md`.

### Modelo y servicio

`AchievementProgressModel` debe representar:

- `achievementId`, `code`, `name`, `description` e `iconUrl`;
- `requirementType`, `currentValue` y `requirementValue`;
- `unlockedAt`, nullable para logros pendientes;
- un getter derivado `isUnlocked`, basado en `unlockedAt`, no en datos del
  cliente.

`AchievementService` debe:

1. Llamar a `get_my_achievement_progress` para leer el progreso de la sesión.
2. Mapear resultados a un modelo tipado y propagar errores para que la UI pueda
   ofrecer reintento.
3. No aceptar `userId` arbitrario ni escribir directamente en
   `user_achievements`.
4. Exponer el registro de respuesta de trivia como
   `submitTriviaAnswer(triviaId, selectedOption)`, sin enviar `userId` ni
   `isCorrect`.
5. Refrescar el progreso después de guardar una detección o recibir una
   respuesta de trivia confirmada.

`TriviaService` debe:

1. Cargar solo columnas públicas de `trivias`: id, pregunta, opciones,
   categoría, dificultad, puntos, especie, explicación y fuente. No mapear
   `correct_answer` en `TriviaModel`.
2. Exponer `submitAnswer(triviaId, selectedOption)`, llamar a la RPC y
   mapear su evaluación server-side.
3. Exponer un resumen privado con `get_my_trivia_summary`: XP total, preguntas
   dominadas y estadísticas de intentos/aciertos.
4. Leer las fechas de repaso vencidas llamando a
   `get_my_trivia_review_queue`; la función solo devuelve estado de la sesión.
5. Propagar errores de red o RPC. No devolver estadísticas cero como si una
   respuesta fallida fuera una cuenta sin actividad.

### Trivias, XP y validación segura

La implementación actual calcula `isCorrect` en Flutter, suma puntos locales
y persiste el resultado sin verificar la respuesta. Para corregirlo:

1. Enviar a `submit_trivia_answer` solo el ID de la pregunta y la opción
   elegida; el servidor deriva la identidad de `auth.uid()` y compara con
   `trivias.correct_answer`.
2. La RPC inserta el intento, actualiza `user_trivia_progress` y acredita XP
   solo para el primer acierto o una etapa de repaso vencida cuyo hito no se
   haya premiado previamente. Inserciones y estado de repaso ocurren en una
   transacción.
3. La pantalla espera la respuesta de la RPC antes de revelar acierto,
   respuesta correcta y puntos. Deshabilita opciones mientras envía; si falla,
   muestra error y permite reintentar sin pasar a la siguiente pregunta.
4. `trivia_attempts.points_awarded` registra lo acreditado en ese intento; los
   puntos concedidos en un acierto repetido antes de la fecha de repaso serán
   cero. Un acierto en un hito de repaso puede dar el bono de consolidación.
5. Después de desplegar Mobile, revocar escritura directa del cliente en `user_trivia_progress`,
   `trivia_attempts`, `trivia_point_ledger` y
   `user_trivia_question_state`. El ledger y el estado de repaso solo permiten
   lectura propia; las funciones `SECURITY DEFINER` hacen las escrituras
   validadas.
6. Revocar lectura general de `trivias` y conceder acceso de columna solo a
   los campos públicos. Si el panel Web necesita `correct_answer` para
   administrar preguntas, servirlo por una operación administrativa protegida,
   no con un permiso de lectura móvil.

La RPC acepta invitados solo para validar la respuesta y mostrar feedback:
no inserta registros, progreso, puntos ni desbloqueos si `auth.uid()` es nulo.
Las cuentas gratuitas autenticadas sí sincronizan el progreso y ganan XP. No
confiar en un puntaje guardado localmente.

`trivia_correct_count` y los logros de dominio se calculan con preguntas
distintas que se han respondido correctamente; `trivia_attempt_count` puede
contar todos los intentos para estadísticas de práctica. La cantidad de
preguntas dominadas se deriva de `user_trivia_question_state` con etapa >= 0.
No usar intentos repetidos para inflar XP: solo los hitos programados dan el
pequeño bono de consolidación.

### Pantalla y navegación

En `TriviaScreen`, conservar los filtros y el temporizador opcional, y añadir
un encabezado con XP total/rango y una indicación de preguntas ya dominadas.
Separar con claridad Práctica de los retos oficiales para que los resultados
personalizados no se confundan con una competición.

Después de cada respuesta:

- bloquear temporalmente la selección mientras la RPC valida;
- mostrar correcto/incorrecto, explicación, fuente y acceso a la ficha de la
  especie asociada cuando exista;
- mostrar si la respuesta inicia el aprendizaje, consolida un repaso o fue
  práctica sin XP porque todavía no vencía el siguiente intervalo;
- ofrecer una cola de repaso con preguntas vencidas mezcladas con preguntas
  nuevas, además de permitir practicar cualquier tema sin bloquear preguntas;
- ofrecer avance automático accesible, pausa y revisión al terminar.

El resultado de partida muestra aciertos, precisión, tiempo, preguntas nuevas
aprendidas, repasos consolidados y XP obtenido. Añadir barra al siguiente
rango, resumen por categoría, revisión de respuestas y una sugerencia de
siguiente actividad. Las respuestas fallidas no descuentan puntos.

El reto diario futuro necesita datos protegidos por servidor, no selección
local. Su esquema debe incluir un catálogo por fecha con cinco preguntas
ordenadas y una clave única por fecha/pregunta; también respuestas únicas por
cuenta, fecha y pregunta. La RPC verifica que las preguntas pertenecen al reto,
registra el resultado y acredita el bono con clave única por cuenta/fecha solo
cuando se completa la ronda. Esto evita cambiar la fecha, enviar preguntas
arbitrarias o reclamar el bono más de una vez. Mantener el reto fijo durante
todo el día para que todas las personas tengan las mismas preguntas. No añadir
rachas ni bono hasta probar esta validación.

1. Reemplazar el diálogo provisional `_openAchievements` en Home por una ruta a
   `AchievementsScreen`.
2. Mostrar logros desbloqueados y pendientes con icono, nombre, explicación y
   progreso `currentValue / requirementValue`.
3. Separar visualmente “Desbloqueados” y “Por descubrir”; un logro
   desactivado que ya fue obtenido debe seguir apareciendo en el historial.
4. Mostrar fecha de desbloqueo y animación/notificación breve al detectar un
   logro nuevo después de una acción.
5. Añadir carga inicial, estado vacío, error con reintento y actualización por
   gesto.
6. Si no hay sesión, permitir práctica con feedback, pero mostrar claramente
   que no se guardan puntos ni progreso; ofrecer crear cuenta gratis para
   sincronizar. No mostrar errores de RLS como si no hubiera logros.
7. Mantener el tema y widgets de Mobile; no importar componentes desde
   `lib/web/`.

### Actualización de progreso en cada acción

- **Detección:** el trigger corre tras insertar en `detections`. Después de
  guardar, Mobile vuelve a consultar progreso y compara IDs desbloqueados para
  presentar una notificación nueva.
- **Trivia:** la RPC registra la respuesta y actualiza contadores de forma
  atómica; el trigger evalúa logros en esa misma operación. Mobile consulta de
  nuevo la lista después de recibir una respuesta válida y refresca el resumen
  de XP.
- **Rango:** se deriva de `total_points` devuelto por `get_my_trivia_summary`;
  el rango no se guarda en el cliente ni se reduce. Los títulos desbloqueados
  se pueden representar como logros o recompensas de perfil.
- **Reapertura de la pantalla:** volver a consultar el RPC de progreso para
  sincronizar el estado entre dispositivos; no depender solo de memoria local.

## Secuencia de implementación

1. **Auditar datos y RLS**
   - Revisar tipos de requisito existentes, políticas, permisos, secuencia y
     tipo exacto de `trivias.options`.
   - Corregir el esquema del documento si el proyecto difiere del contexto
     compartido.
2. **Implementar y probar SQL en staging**
   - Aplicar columnas, ledger, importación de puntos históricos, RLS, RPC,
     función evaluadora y triggers.
   - Verificar que el primer acierto y cada etapa de repaso acreditan XP una
     sola vez, incluso con solicitudes simultáneas; los aciertos anticipados
     no dan XP y los intervalos avanzan correctamente.
   - Verificar que los puntos históricos se importan como etapa inicial y no
     se duplican al volver a aplicar el backfill.
   - Insertar datos de ejemplo y verificar obtención automática y retroactiva.
   - Comprobar que una persona no puede leer ni modificar obtenciones o ledger
     ajenos, ni leer `correct_answer` antes de enviar una respuesta.
3. **Implementar RPC de trivia y cambiar Mobile**
   - Integrar verificación server-side, XP idempotente y feedback explicativo.
   - Quitar escrituras directas a `user_trivia_progress`.
   - Retirar `correct_answer` de las consultas públicas del móvil.
4. **Añadir el feature Mobile**
   - Actualizar modelo, servicio, registro en `ServiceLocator`, ronda de
     Trivia, pantalla de logros y navegación desde Home.
   - Mostrar XP/rango y refrescar estadísticas después de cada respuesta.
5. **Añadir retos estructurados**
   - Crear las tablas/RPC de retos diarios y sus respuestas únicas.
   - Solo entonces habilitar el bono diario y objetivos semanales; probar
     límites de fecha, preguntas del reto y reclamaciones duplicadas.
6. **Desplegar en orden**
   - Desplegar funciones SQL/RPC y código móvil compatible.
   - Aplicar la migración que revoca escrituras directas.
   - Publicar Mobile y verificar comportamiento con una cuenta de prueba.
7. **Validar y monitorear**
   - Probar umbrales exactos, umbrales superados, usuarios antiguos, campos
     nulos, doble inserción, respuestas incorrectas y sesiones sin autenticar.
   - Confirmar que una misma obtención/recompensa no se duplica y que
     borrar/desactivar contenido no borra el historial del usuario.

## Criterios de aceptación

- Ningún cliente puede insertar o modificar directamente una fila de
  `user_achievements`.
- La misma actividad no duplica logros.
- Las respuestas incorrectas solo aumentan intentos; las correctas aumentan
  intentos y aciertos.
- Los contadores se actualizan de forma atómica y los premios se calculan en
  Postgres.
- El XP es permanente y no se puede comprar; los aciertos repetidos antes del
  repaso no dan XP, pero los repasos espaciados programados sí pueden conceder
  sus hitos únicos. El rango se calcula desde el ledger.
- Las preguntas respondidas siguen disponibles; el sistema prioriza repasos
  vencidos y mezcla estos con contenido nuevo, sin bloquear la práctica libre.
- La respuesta correcta no se envía al cliente hasta que este ha contestado.
- Los invitados reciben feedback, pero no generan registros, XP ni progreso
  persistente.
- Las recompensas del reto diario solo se habilitan cuando fecha, preguntas y
  finalización se validan en Supabase.
- Una persona solo puede consultar su propio progreso.
- Mobile presenta estados de carga, error, sin sesión, sin logros, progreso y
  desbloqueo nuevo.
- Las reglas y pantallas de Mobile permanecen bajo `lib/mobile/`; Web conserva
  su límite administrativo, según `lib/ARCHITECTURE.md`.
