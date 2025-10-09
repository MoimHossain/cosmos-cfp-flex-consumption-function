package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"
)

func simpleHttpTriggerHandler(w http.ResponseWriter, r *http.Request) {
	t := time.Now()
	fmt.Println(t.Month())
	fmt.Println(t.Day())
	fmt.Println(t.Year())
	ua := r.Header.Get("User-Agent")
	fmt.Printf("user agent is: %s \n", ua)
	invocationid := r.Header.Get("X-Azure-Functions-InvocationId")
	fmt.Printf("invocationid is: %s \n", invocationid)

	queryParams := r.URL.Query()

	for k, v := range queryParams {
		fmt.Println("k:", k, "v:", v)
	}

	w.Write([]byte("Hello World from go worker"))
}

func timerTriggerHandler(w http.ResponseWriter, r *http.Request) {
	fmt.Printf("Timer trigger handler called: %s %s\n", r.Method, r.URL.Path)
	t := time.Now()
	fmt.Printf("Timer trigger executed at: %s\n", t.Format("2006-01-02 15:04:05"))
	fmt.Printf("Current timestamp: %d\n", t.Unix())

	// Log some basic information
	invocationid := r.Header.Get("X-Azure-Functions-InvocationId")
	if invocationid != "" {
		fmt.Printf("Timer trigger invocation ID: %s\n", invocationid)
	}

	// Log all headers for debugging
	fmt.Println("Headers:")
	for k, v := range r.Header {
		fmt.Printf("  %s: %v\n", k, v)
	}

	// Create the proper response format for Azure Functions
	response := map[string]interface{}{
		"Outputs": map[string]interface{}{},
		"Logs": []string{
			fmt.Sprintf("Timer executed at %s", t.Format("2006-01-02 15:04:05")),
		},
		"ReturnValue": nil,
	}

	// Set proper content type and return JSON
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)

	jsonResponse, err := json.Marshal(response)
	if err != nil {
		fmt.Printf("Error marshaling response: %v\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	w.Write(jsonResponse)
}

// cosmosEnvelope models only the fields we care about for logging & retry behavior.
type cosmosEnvelope struct {
	Data struct {
		InputDocuments string `json:"inputDocuments"` // Escaped JSON string of array of docs
	} `json:"Data"`
	Metadata struct {
		RetryContext struct {
			RetryCount int `json:"RetryCount"`
		} `json:"RetryContext"`
	} `json:"Metadata"`
}

func unescapeDocuments(raw string) ([]map[string]any, error) {
	if raw == "" {
		return nil, nil
	}
	// The host sends an escaped JSON array embedded in a string
	s := raw
	if strings.HasPrefix(s, "\"") && strings.HasSuffix(s, "\"") {
		if uq, err := strconv.Unquote(s); err == nil {
			s = uq
		}
	}
	var arr []map[string]any
	if err := json.Unmarshal([]byte(s), &arr); err != nil {
		return nil, err
	}
	return arr, nil
}

func cosmosChangeTriggerHandler(w http.ResponseWriter, r *http.Request) {
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

	// Parse outer envelope
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
		// Attempt log
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
	}

	durMs := time.Since(start).Milliseconds()
	if failing {
		fmt.Printf("cosmos final status=failure docs=%d duration_ms=%d\n", len(docs), durMs)
	} else {
		fmt.Printf("cosmos final status=success docs=%d duration_ms=%d\n", len(docs), durMs)
	}

	// Build response (even on failure we include structured body; non-200 signals retry)
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

func main() {
	customHandlerPort, exists := os.LookupEnv("FUNCTIONS_CUSTOMHANDLER_PORT")
	if exists {
		fmt.Println("FUNCTIONS_CUSTOMHANDLER_PORT: " + customHandlerPort)
	}
	mux := http.NewServeMux()
	mux.HandleFunc("/api/SimpleHttpTrigger", simpleHttpTriggerHandler)
	mux.HandleFunc("/api/cosmosChangeTrigger", cosmosChangeTriggerHandler)
	mux.HandleFunc("/cosmosChangeTrigger", cosmosChangeTriggerHandler)
	mux.HandleFunc("/Functions.cosmosChangeTrigger", cosmosChangeTriggerHandler)
	mux.HandleFunc("/api/Functions.cosmosChangeTrigger", cosmosChangeTriggerHandler)

	// Register timer trigger with multiple possible paths
	mux.HandleFunc("/api/timerTrigger", timerTriggerHandler)
	mux.HandleFunc("/timerTrigger", timerTriggerHandler)
	mux.HandleFunc("/api/TimerTrigger", timerTriggerHandler)
	mux.HandleFunc("/TimerTrigger", timerTriggerHandler)

	// Try function name based paths (Azure might use Functions.functionName format)
	mux.HandleFunc("/Functions.timerTrigger", timerTriggerHandler)
	mux.HandleFunc("/api/Functions.timerTrigger", timerTriggerHandler)

	// Add a catch-all handler to debug what path is being requested
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Printf("Unhandled request: %s %s\n", r.Method, r.URL.Path)
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(fmt.Sprintf("Path not found: %s", r.URL.Path)))
	})

	fmt.Println("Go server Listening...on FUNCTIONS_CUSTOMHANDLER_PORT:", customHandlerPort)
	log.Fatal(http.ListenAndServe(":"+customHandlerPort, mux))
}
