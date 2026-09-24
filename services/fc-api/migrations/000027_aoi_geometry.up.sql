-- Allow Polygon or MultiPolygon AOI (e.g. union of selected districts).
ALTER TABLE projects
  ALTER COLUMN area_of_interest TYPE geometry(Geometry, 4326)
  USING area_of_interest;
