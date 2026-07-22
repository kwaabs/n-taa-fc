-- Let geo-api read FC features + attachments to surface media for dbo assets.
GRANT SELECT ON public.features TO geo_app;
GRANT SELECT ON public.feature_attachments TO geo_app;
GRANT SELECT ON public.layer_data_sources TO geo_app;
GRANT SELECT ON public.layers TO geo_app;
