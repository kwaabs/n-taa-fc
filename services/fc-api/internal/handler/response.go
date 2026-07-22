package handler

import (
	"encoding/json"
	"net/http"
)

// Response is the standard API response envelope.
type Response struct {
	Data  interface{}    `json:"data,omitempty"`
	Error *ErrorResponse `json:"error,omitempty"`
	Meta  *Meta          `json:"meta,omitempty"`
}

// ErrorResponse contains error details.
type ErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}

// Meta contains pagination and other metadata.
type Meta struct {
	Total  int `json:"total,omitempty"`
	Page   int `json:"page,omitempty"`
	Limit  int `json:"limit,omitempty"`
}

// RespondJSON writes a JSON response with the given status code and data.
func RespondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(Response{Data: data})
}

// RespondList writes a JSON response with pagination metadata.
func RespondList(w http.ResponseWriter, status int, data interface{}, total, page, limit int) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(Response{
		Data: data,
		Meta: &Meta{Total: total, Page: page, Limit: limit},
	})
}

// RespondError writes a JSON error response.
func RespondError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(Response{
		Error: &ErrorResponse{Code: code, Message: message},
	})
}

func RespondListWithMeta(w http.ResponseWriter, status int, data interface{}, total, offset, limit int) {
    page := (offset / max(limit, 1)) + 1
    RespondJSON(w, status, map[string]interface{}{
        "data": data,
        "meta": map[string]interface{}{
            "total":  total,
            "page":   page,
            "limit":  limit,
            "offset": offset,
        },
    })
}

func max(a, b int) int {
    if a > b {
        return a
    }
    return b
}