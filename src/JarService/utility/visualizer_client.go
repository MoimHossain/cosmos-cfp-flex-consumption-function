package utility

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

const visualizerEndpoint = "https://cosmosdb-changefeed-visualizer.wonderfulplant-6b5cf838.northeurope.azurecontainerapps.io/api/publishEvents"

func PublishVisualizationEvent(doc map[string]any) {
	payload := map[string]any{}

	if v, ok := doc["id"]; ok {
		payload["id"] = v
	}
	if v, ok := doc["transaction"]; ok {
		payload["transaction"] = v
	}
	if v, ok := doc["account"]; ok {
		payload["account"] = v
	}
	if v, ok := doc["amount"]; ok {
		payload["amount"] = v
	}

	b, err := json.Marshal(payload)
	if err != nil {
		fmt.Printf("visualizer error=marshal err=%v\n", err)
		return
	}

	client := &http.Client{Timeout: 5 * time.Second}
	req, err := http.NewRequest(http.MethodPost, visualizerEndpoint, bytes.NewReader(b))
	if err != nil {
		fmt.Printf("visualizer error=request_build err=%v\n", err)
		return
	}

	req.Header.Set("Content-Type", "application/json")
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("visualizer error=post err=%v\n", err)
		return
	}
	defer resp.Body.Close()
	io.Copy(io.Discard, resp.Body)

	fmt.Printf("visualizer status=posted id=%v http_status=%d\n", payload["id"], resp.StatusCode)
}
