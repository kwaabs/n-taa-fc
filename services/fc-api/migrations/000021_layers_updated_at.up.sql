-- Model Layer.UpdatedAt has always been mapped; base layers migration omitted the column.
ALTER TABLE public.layers
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT now();

UPDATE public.layers
SET updated_at = COALESCE(updated_at, created_at, now())
WHERE updated_at IS NULL;
