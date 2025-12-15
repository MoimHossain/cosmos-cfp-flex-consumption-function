package eventhubtrigger

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/MoimHossain/cosmos-cfp-flex-consumption-function/JarService/utility"
)

// Handler processes Event Hubs trigger invocations arriving via the custom handler shim.
func Handler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	w.Header().Set("Content-Type", "application/json")

	body, err := io.ReadAll(r.Body)
	if err != nil {
		writeResponse(w, http.StatusBadRequest, nil, fmt.Errorf("read_body_failed: %w", err))
		return
	}

	invID := r.Header.Get("X-Azure-Functions-InvocationId")
	if invID != "" {
		fmt.Printf("eventhub meta=invocation id=%s\n", invID)
	}
	fmt.Printf("eventhub stage=received raw_bytes=%d\n", len(body))
	fmt.Printf("eventhub payload_preview=%s\n", previewBody(body, 2048))

	messages, err := extractEventHubMessages(body)
	if err != nil {
		writeResponse(w, http.StatusBadRequest, nil, fmt.Errorf("payload_parse_failed: %w", err))
		return
	}

	if len(messages) == 0 {
		writeResponse(w, http.StatusOK, []string{"no events supplied"}, nil)
		return
	}

	logs := make([]string, 0, len(messages))
	failing := false

	for _, msg := range messages {
		evt, doc, derr := convertToTransaction(msg)
		if derr != nil {
			failing = true
			logLine := fmt.Sprintf("eventhub error=decode_failed err=%v", derr)
			logs = append(logs, logLine)
			fmt.Println(logLine)
			continue
		}

		fmt.Printf("eventhub doc id=%s transaction=%s account=%s amount=%.2f user=%s\n",
			evt.ID, evt.Transaction, evt.Account, evt.Amount, evt.UserID)

		switch strings.ToLower(strings.TrimSpace(evt.Transaction)) {
		case "fail":
			fmt.Printf("eventhub doc_status id=%s transaction=fail action=will_fail_invocation\n", evt.ID)
			logs = append(logs, fmt.Sprintf("id=%s transaction=fail", evt.ID))
			failing = true
		case "pass":
			fmt.Printf("eventhub doc_status id=%s transaction=pass\n", evt.ID)
			logs = append(logs, fmt.Sprintf("id=%s transaction=pass", evt.ID))
		default:
			fmt.Printf("eventhub doc_status id=%s transaction=%s (no special action)\n", evt.ID, evt.Transaction)
			logs = append(logs, fmt.Sprintf("id=%s transaction=%s", evt.ID, evt.Transaction))
		}

		utility.PublishVisualizationEvent(doc)
	}

	duration := time.Since(start).Milliseconds()
	logs = append([]string{fmt.Sprintf("processed %d events duration_ms=%d", len(messages), duration)}, logs...)

	resp := map[string]any{
		"Outputs": map[string]any{},
		"Logs":    logs,
		"ReturnValue": map[string]any{
			"eventCount": len(messages),
			"durationMs": duration,
		},
	}

	status := http.StatusOK
	if failing {
		status = http.StatusInternalServerError
	}

	w.WriteHeader(status)
	json.NewEncoder(w).Encode(resp)
}

func writeResponse(w http.ResponseWriter, status int, logs []string, err error) {
	msg := map[string]any{
		"Outputs":     map[string]any{},
		"Logs":        logs,
		"ReturnValue": map[string]any{},
	}

	if err != nil {
		line := fmt.Sprintf("error=%v", err)
		if len(logs) == 0 {
			msg["Logs"] = []string{line}
		} else {
			msg["Logs"] = append(logs, line)
		}
		fmt.Println(line)
	} else if logs == nil {
		msg["Logs"] = []string{}
	}

	w.WriteHeader(status)
	json.NewEncoder(w).Encode(msg)
}

func previewBody(body []byte, limit int) string {
	if limit <= 0 || len(body) <= limit {
		return sanitizePreview(string(body))
	}

	truncated := fmt.Sprintf("%s...<truncated %d bytes>", string(body[:limit]), len(body)-limit)
	return sanitizePreview(truncated)
}

func sanitizePreview(s string) string {
	s = strings.ReplaceAll(s, "\r", " ")
	s = strings.ReplaceAll(s, "\n", " ")
	s = strings.ReplaceAll(s, "\t", " ")
	return s
}
