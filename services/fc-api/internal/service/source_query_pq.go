package service

import "github.com/lib/pq"

// pqArrayShim wraps a []string for the PostgreSQL driver's array parameter
// handling. Centralised so we don't sprinkle pq.Array everywhere.
func pqArrayShim(ids []string) any {
    return pq.Array(ids)
}