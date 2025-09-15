package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
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

// Structures to parse custom handler invocation wrapper for bindings
type cosmosInvocation struct {
	Data     map[string]json.RawMessage `json:"Data"`
	Metadata map[string]any             `json:"Metadata"`
}

type cosmosDoc struct {
	ID       string          `json:"id"`
	TenantID string          `json:"tenantId"`
	Data     json.RawMessage `json:"data"`
	Etag     string          `json:"_etag"`
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
		http.Error(w, "failed to read body", http.StatusBadRequest)
		return
	}
	if verbose {
		fmt.Printf("cosmos stage=received raw_bytes=%d payload=%s\n", len(body), string(body))
	} else {
		fmt.Printf("cosmos stage=received raw_bytes=%d\n", len(body))
	}

	invID := r.Header.Get("X-Azure-Functions-InvocationId")
	if invID != "" {
		fmt.Printf("cosmos meta=invocation id=%s\n", invID)
	}

	var inv cosmosInvocation
	if err := json.Unmarshal(body, &inv); err != nil {
		fmt.Printf("cosmos level=warn msg=wrapper_unmarshal_failed err=%v\n", err)
		// Try legacy direct array
		var direct []cosmosDoc
		if err2 := json.Unmarshal(body, &direct); err2 == nil {
			fmt.Printf("cosmos mode=direct_array docs=%d latency_ms=%d\n", len(direct), time.Since(start).Milliseconds())
			for i, d := range direct {
				if verbose {
					fmt.Printf("cosmos doc_index=%d id=%s tenantId=%s etag=%s data=%s\n", i, d.ID, d.TenantID, d.Etag, string(d.Data))
				} else {
					fmt.Printf("cosmos doc_index=%d id=%s tenantId=%s etag=%s\n", i, d.ID, d.TenantID, d.Etag)
				}
			}
		} else {
			fmt.Printf("cosmos level=error msg=direct_array_unmarshal_failed err=%v\n", err2)
		}
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("processed"))
		return
	}

	rawDocs, ok := inv.Data["inputDocuments"]
	if !ok {
		fmt.Printf("cosmos level=info msg=no_input_documents latency_ms=%d\n", time.Since(start).Milliseconds())
		w.WriteHeader(http.StatusOK)
		w.Write([]byte("no docs"))
		return
	}

	var docs []cosmosDoc
	if err := json.Unmarshal(rawDocs, &docs); err != nil {
		fmt.Printf("cosmos level=error msg=docs_unmarshal_failed err=%v raw_fragment=%s\n", err, string(rawDocs))
	} else {
		fmt.Printf("cosmos level=info msg=change_received doc_count=%d latency_ms=%d\n", len(docs), time.Since(start).Milliseconds())
		for i, d := range docs {
			if verbose {
				fmt.Printf("cosmos level=debug doc_index=%d id=%s tenantId=%s etag=%s size_bytes=%d data=%s\n", i, d.ID, d.TenantID, d.Etag, len(d.Data), string(d.Data))
			} else {
				fmt.Printf("cosmos level=debug doc_index=%d id=%s tenantId=%s etag=%s size_bytes=%d\n", i, d.ID, d.TenantID, d.Etag, len(d.Data))
			}
		}
	}

	// Build proper custom handler response object
	resp := map[string]any{
		"Outputs":     map[string]any{},
		"Logs":        []string{"cosmos change processed"},
		"ReturnValue": nil,
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	if b, err := json.Marshal(resp); err == nil {
		w.Write(b)
	} else {
		// Fallback minimal body (still JSON) if marshal fails
		w.Write([]byte("{\"Outputs\":{},\"Logs\":[\"marshal error\"],\"ReturnValue\":null}"))
	}
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
