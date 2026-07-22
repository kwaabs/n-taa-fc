export interface InlineConnection {
    host: string;
    port: number;
    database: string;
    username: string;
    password: string;
    ssl_mode: string;
  }
  
  export interface ConnectionRef {
    connection_id?: string;
    inline?: InlineConnection;
  }
  
  export interface DiscoveredColumn {
    name: string;
    data_type: string;
    udt_name?: string;
    is_primary_key: boolean;
    is_nullable: boolean;
    is_enum: boolean;
    enum_values?: string[];
    is_geometry: boolean;
  }
  
  export interface DiscoveredTable {
    schema: string;
    name: string;
    qualified_name: string;
    geometry_column?: string;
    geometry_type?: string;       // POINT, LINESTRING, POLYGON, MULTIPOLYGON, etc.
    srid?: number;
    is_spatial: boolean;
    row_count: number;
    columns: DiscoveredColumn[];
  }
  
  export interface TableConfig {
    qualified_name: string;          // for keying
    schema: string;
    name: string;
    layer_name: string;
    geometry_type: string;           // point, line, polygon (lowercase, our convention)
    geometry_column?: string;
    lat_column?: string;
    lng_column?: string;
    id_column: string;
    editable: boolean;
    included_columns: string[];
    excluded_columns: string[];      // informational; ones the admin explicitly excluded
    filter_clause: string;
    generate_form: boolean;
    schedule_minutes: number;
  }
  
  export interface ImportJobProgress {
    current: number;
    total: number;
    message?: string;
    per_table?: Record<string, TableProgress>;
  }
  
  export interface TableProgress {
    status: "pending" | "running" | "success" | "failed" | "skipped";
    inserted: number;
    total: number;
    layer_id?: string;
    form_id?: string;
    data_source_id?: string;
    error?: string;
  }
  
  export interface ImportJobResult {
    layers_created: number;
    forms_created: number;
    features_imported: number;
    table_results: Record<string, TableProgress>;
    errors?: string[];
  }
  
  export interface ImportJob {
    id: string;
    project_id: string;
    connection_id?: string;
    job_type: string;
    status: "pending" | "running" | "success" | "partial" | "failed";
    config: any;
    progress: ImportJobProgress;
    result?: ImportJobResult;
    error_message?: string;
    started_at?: string;
    finished_at?: string;
    created_at: string;
    updated_at: string;
  }
  
  // Maps a PostGIS geometry type to our internal type
  export function normalizeGeometryType(pgType?: string): "point" | "line" | "polygon" {
    const t = (pgType || "").toUpperCase();
    if (t.includes("POINT")) return "point";
    if (t.includes("LINE")) return "line";
    if (t.includes("POLY")) return "polygon";
    return "point";
  }
  
  export function humanize(s: string): string {
    return s
      .split("_")
      .filter(Boolean)
      .map((p) => p.charAt(0).toUpperCase() + p.slice(1))
      .join(" ");
  }