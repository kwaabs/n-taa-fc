-- Martin MVT function used by FC map (source id: reference_features).
-- Martin connects as geo_app, so grant read + execute explicitly.

CREATE OR REPLACE FUNCTION public.reference_features(
    z integer,
    x integer,
    y integer,
    query_params json
)
RETURNS bytea
LANGUAGE plpgsql
STABLE PARALLEL SAFE
AS $$
DECLARE
    result bytea;
    _project_id uuid;
    _layer_id uuid;
    _tolerance float;
    _min_length float;
BEGIN
    _project_id := (query_params->>'project_id')::uuid;
    _layer_id := (query_params->>'layer_id')::uuid;

    IF _project_id IS NULL OR _layer_id IS NULL THEN
        RETURN NULL;
    END IF;

    -- Simplify at ~1 pixel resolution (aggressive)
    _tolerance := 40075016.686 / (POWER(2, z) * 256);

    -- Drop features whose bounding box diagonal is smaller than 2 pixels
    _min_length := _tolerance * 2;

    WITH bounds AS (
        SELECT ST_TileEnvelope(z, x, y) AS geom
    ),
    filtered AS (
        SELECT
            f.id,
            f.source_ref,
            ST_Transform(f.geometry, 3857) AS geom_3857
        FROM public.features f
        CROSS JOIN bounds
        WHERE
            f.project_id = _project_id
            AND f.layer_id = _layer_id
            AND f.source = 'reference'
            AND f.deleted_at IS NULL
            AND f.geometry && ST_Transform(bounds.geom, 4326)
    ),
    sized AS (
        SELECT * FROM filtered
        WHERE ST_XMax(geom_3857) - ST_XMin(geom_3857) > _min_length
           OR ST_YMax(geom_3857) - ST_YMin(geom_3857) > _min_length
    ),
    mvtgeom AS (
        SELECT
            ST_AsMVTGeom(
                ST_SimplifyPreserveTopology(geom_3857, _tolerance),
                bounds.geom,
                extent => 4096,
                buffer => 64,
                clip_geom => true
            ) AS geom,
            id::text AS id,
            source_ref
        FROM sized
        CROSS JOIN bounds
    )
    SELECT ST_AsMVT(mvtgeom.*, 'reference_features', 4096, 'geom')
    INTO result
    FROM mvtgeom
    WHERE geom IS NOT NULL;

    RETURN result;
END;
$$;

GRANT USAGE ON SCHEMA public TO geo_app;
GRANT SELECT ON TABLE public.features TO geo_app;
GRANT SELECT ON TABLE public.layers TO geo_app;
GRANT EXECUTE ON FUNCTION public.reference_features(integer, integer, integer, json) TO geo_app;
GRANT EXECUTE ON FUNCTION public.reference_features(integer, integer, integer, json) TO PUBLIC;
