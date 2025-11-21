package cosmoschangetrigger

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/MoimHossain/cosmos-cfp-flex-consumption-function/JarService/utility"
)

func Handler(w http.ResponseWriter, r *http.Request) {
	start := time.Now()
	verbose := true
	if v, ok := os.LookupEnv("COSMOS_VERBOSE"); ok {
		lv := strings.ToLower(strings.TrimSpace(v))
		if lv == "0" || lv == "false" || lv == "off" || lv == "no" {
			verbose = false
		}
	}

	body, err := io.ReadAll(r.Body)
	if err != nil {
		fmt.Printf("cosmos error=read_body_failed err=%v\n", err)
	}

	invID := r.Header.Get("X-Azure-Functions-InvocationId")
	if invID != "" {
		fmt.Printf("cosmos meta=invocation id=%s\n", invID)
	}

	if verbose {
		fmt.Printf("cosmos stage=received raw_bytes=%d payload=%s\n", len(body), string(body))
	} else {
		fmt.Printf("cosmos stage=received raw_bytes=%d\n", len(body))
	}

	var env cosmosEnvelope
	if err := json.Unmarshal(body, &env); err != nil {
		fmt.Printf("cosmos error=envelope_unmarshal err=%v\n", err)
	}

	docs, derr := unescapeDocuments(env.Data.InputDocuments)
	if derr != nil {
		fmt.Printf("cosmos error=input_docs_parse err=%v\n", derr)
	}

	retryCount := env.Metadata.RetryContext.RetryCount
	attempt := retryCount + 1
	failing := false
	logSummaries := []string{}

	for _, d := range docs {
		id, _ := d["id"].(string)
		txn, _ := d["transaction"].(string)

		fmt.Printf("cosmos doc_attempt id=%s attempt=%d retryCount=%d\n", id, attempt, retryCount)
		if txn == "fail" {
			fmt.Printf("cosmos doc_status id=%s transaction=fail action=will_fail_invocation\n", id)
			logSummaries = append(logSummaries, fmt.Sprintf("id=%s transaction=fail", id))
			failing = true
		} else if txn == "pass" {
			fmt.Printf("cosmos doc_status id=%s transaction=pass\n", id)
			logSummaries = append(logSummaries, fmt.Sprintf("id=%s transaction=pass", id))
		} else {
			fmt.Printf("cosmos doc_status id=%s transaction=%s (no special action)\n", id, txn)
			logSummaries = append(logSummaries, fmt.Sprintf("id=%s transaction=%s", id, txn))
		}

		utility.PublishVisualizationEvent(d)
	}

	durMs := time.Since(start).Milliseconds()
	if failing {
		fmt.Printf("cosmos final status=failure docs=%d duration_ms=%d\n", len(docs), durMs)
	} else {
		fmt.Printf("cosmos final status=success docs=%d duration_ms=%d\n", len(docs), durMs)
	}

	w.Header().Set("Content-Type", "application/json")
	resp := map[string]any{
		"Outputs":     map[string]any{},
		"Logs":        append([]string{fmt.Sprintf("processed %d docs attempt=%d", len(docs), attempt)}, logSummaries...),
		"ReturnValue": map[string]any{"documentCount": len(docs), "attempt": attempt, "retryCount": retryCount},
	}

	b, _ := json.Marshal(resp)
	if failing {
		w.WriteHeader(http.StatusInternalServerError)
	} else {
		w.WriteHeader(http.StatusOK)
	}
	w.Write(b)
}
