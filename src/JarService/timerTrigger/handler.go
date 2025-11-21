package timertrigger

import (
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

func Handler(w http.ResponseWriter, r *http.Request) {
	fmt.Printf("Timer trigger handler called: %s %s\n", r.Method, r.URL.Path)
	t := time.Now()
	fmt.Printf("Timer trigger executed at: %s\n", t.Format("2006-01-02 15:04:05"))
	fmt.Printf("Current timestamp: %d\n", t.Unix())

	invocationid := r.Header.Get("X-Azure-Functions-InvocationId")
	if invocationid != "" {
		fmt.Printf("Timer trigger invocation ID: %s\n", invocationid)
	}

	fmt.Println("Headers:")
	for k, v := range r.Header {
		fmt.Printf("  %s: %v\n", k, v)
	}

	response := map[string]interface{}{
		"Outputs": map[string]interface{}{},
		"Logs": []string{
			fmt.Sprintf("Timer executed at %s", t.Format("2006-01-02 15:04:05")),
		},
		"ReturnValue": nil,
	}

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
