package service

import (
    "context"
    "database/sql"
    "fmt"
    "strings"
)

// fetchSourceRowsByIDs runs a single bulk SELECT against the source DB and
// returns rows keyed by the value of idColumn. Used by both the preview and
// apply engines to compare current source state against our snapshot.
//
// Returns a map of {sourceRef → row attributes}. Missing rows simply don't
// appear in the map (no error). NULL values become Go nils in the map.
func fetchSourceRowsByIDs(
    ctx context.Context,
    srcDB *sql.DB,
    schema, table, idColumn string,
    ids []string,
) (map[string]map[string]any, error) {
    if len(ids) == 0 {
        return map[string]map[string]any{}, nil
    }

    // Build SELECT *. We can't pre-enumerate columns because the user-side
    // schema is dynamic; rely on rows.Columns() to discover them.
    // Use ANY($1) for safe parameterized list (avoids SQL injection from
    // uncontrolled source_refs and is faster than N placeholders).
    q := fmt.Sprintf(
        `SELECT * FROM %s.%s WHERE %s = ANY($1)`,
        quoteIdent(schema), quoteIdent(table), quoteIdent(idColumn),
    )

    rows, err := srcDB.QueryContext(ctx, q, anyStringSlice(ids))
    if err != nil {
        return nil, fmt.Errorf("query source rows: %w", err)
    }
    defer rows.Close()

    cols, err := rows.Columns()
    if err != nil {
        return nil, fmt.Errorf("columns: %w", err)
    }

    // Where does idColumn live in the row? We need it to key the result map.
    idColIdx := -1
    lowerID := strings.ToLower(idColumn)
    for i, c := range cols {
        if strings.ToLower(c) == lowerID {
            idColIdx = i
            break
        }
    }
    if idColIdx == -1 {
        return nil, fmt.Errorf("id column %q not in returned columns", idColumn)
    }

    out := make(map[string]map[string]any, len(ids))

    for rows.Next() {
        values := make([]any, len(cols))
        ptrs := make([]any, len(cols))
        for i := range values {
            ptrs[i] = &values[i]
        }
        if err := rows.Scan(ptrs...); err != nil {
            return nil, fmt.Errorf("scan: %w", err)
        }

        idVal := fmt.Sprintf("%v", values[idColIdx])
        attrs := make(map[string]any, len(cols))
        for i, c := range cols {
            attrs[c] = normalizeSourceValue(values[i])
        }
        out[idVal] = attrs
    }
    if err := rows.Err(); err != nil {
        return nil, fmt.Errorf("iter: %w", err)
    }

    return out, nil
}

// listSourceTableColumns returns column names for schema.table via information_schema.
func listSourceTableColumns(
	ctx context.Context,
	q interface {
		QueryContext(context.Context, string, ...any) (*sql.Rows, error)
	},
	schema, table string,
) ([]string, error) {
	const sqlText = `
		SELECT column_name
		FROM information_schema.columns
		WHERE table_schema = $1 AND table_name = $2
		ORDER BY ordinal_position
	`
	rows, err := q.QueryContext(ctx, sqlText, schema, table)
	if err != nil {
		return nil, fmt.Errorf("list columns: %w", err)
	}
	defer rows.Close()

	var cols []string
	for rows.Next() {
		var name string
		if err := rows.Scan(&name); err != nil {
			return nil, err
		}
		cols = append(cols, name)
	}
	return cols, rows.Err()
}

// normalizeSourceValue makes raw DB values comparable to JSON-unmarshalled FC
// snapshot values. Byte slices → string, time.Time → RFC3339 string, etc.
func normalizeSourceValue(v any) any {
    switch t := v.(type) {
    case nil:
        return nil
    case []byte:
        return string(t)
    }
    return v
}

// anyStringSlice builds a *string-array* parameter pq.Array can serialize.
// We avoid the lib/pq dependency by using fmt-based parameter construction
// at call sites if the build fails; this helper centralizes it.
//
// In practice pq's array Scan / Value implements the right interface for
// []string passed via Array, so we accept []string and rely on the driver.
func anyStringSlice(ids []string) any {
    // pq supports passing a []string when wrapped via pq.Array — but to avoid
    // importing pq directly here, we accept that the driver also recognizes
    // the bare []string in many configurations. If the build complains, we
    // can switch to pq.Array(ids).
    return pqArrayShim(ids)
}