BEGIN;
CREATE TABLE public.runline_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.runline_users(id) ON DELETE CASCADE,
  client_run_id text NOT NULL CHECK (length(client_run_id) BETWEEN 1 AND 128),
  started_at timestamptz NOT NULL,
  finished_at timestamptz NOT NULL CHECK (finished_at >= started_at),
  active_microseconds bigint NOT NULL CHECK (active_microseconds >= 0),
  distance_meters numeric NOT NULL CHECK (distance_meters >= 0 AND distance_meters < 'Infinity'::numeric),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, client_run_id)
);
CREATE INDEX runline_runs_history_idx ON public.runline_runs (user_id, finished_at DESC, id DESC);
CREATE TABLE public.runline_run_details (
  run_id uuid PRIMARY KEY REFERENCES public.runline_runs(id) ON DELETE CASCADE,
  points jsonb NOT NULL CHECK (jsonb_typeof(points) = 'array'),
  segment_starts jsonb NOT NULL CHECK (jsonb_typeof(segment_starts) = 'array'),
  goal jsonb,
  route jsonb,
  navigation jsonb
);
COMMIT;
