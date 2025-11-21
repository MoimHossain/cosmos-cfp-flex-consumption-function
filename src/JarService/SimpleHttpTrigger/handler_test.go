package simplehttptrigger

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHandler(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/api/SimpleHttpTrigger?foo=bar", nil)
	rec := httptest.NewRecorder()

	Handler(rec, req)

	if rec.Code != http.StatusOK {
		t.Fatalf("expected status 200, got %d", rec.Code)
	}

	if body := rec.Body.String(); !strings.Contains(body, "Hello World from go worker") {
		t.Fatalf("unexpected body: %q", body)
	}
}
