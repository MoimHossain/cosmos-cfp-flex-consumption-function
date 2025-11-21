package cosmoschangetrigger

import (
	"encoding/json"
	"strconv"
	"strings"
)

// cosmosEnvelope models only the fields we care about for logging & retry behavior.
type cosmosEnvelope struct {
	Data struct {
		InputDocuments string `json:"inputDocuments"`
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
