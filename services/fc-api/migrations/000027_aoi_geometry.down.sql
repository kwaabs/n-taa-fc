ALTER TABLE projects
  ALTER COLUMN area_of_interest TYPE geometry(Polygon, 4326)
  USING CASE
    WHEN area_of_interest IS NULL THEN NULL
    WHEN GeometryType(area_of_interest) IN ('POLYGON', 'ST_Polygon') THEN area_of_interest::geometry(Polygon, 4326)
    ELSE ST_GeometryN(ST_Multi(area_of_interest), 1)::geometry(Polygon, 4326)
  END;
