package eventhubtrigger

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
)

type eventHubEnvelope struct {
	Data     json.RawMessage `json:"Data"`
	DataCopy json.RawMessage `json:"data"`
}

type eventHubRecord struct {
	Body string `json:"Body"`
}

type transactionEvent struct {
	ID          string  `json:"id"`
	Transaction string  `json:"transaction"`
	Account     string  `json:"account"`
	Amount      float64 `json:"amount"`
	UserID      string  `json:"userid"`
	Data        any     `json:"data"`
}

func extractEventHubMessages(payload []byte) ([]eventHubRecord, error) {
	var env eventHubEnvelope
	if err := json.Unmarshal(payload, &env); err == nil {
		data := env.Data
		if len(data) == 0 {
			data = env.DataCopy
		}

		if len(data) > 0 {
			if records, err := parseEventHubRecords(data); err == nil {
				return records, nil
			}
		}
	}

	return parseEventHubRecords(payload)
}

func parseEventHubRecords(raw json.RawMessage) ([]eventHubRecord, error) {
	trimmed := bytes.TrimSpace(raw)
	if len(trimmed) == 0 {
		return nil, nil
	}

	var array []eventHubRecord
	if err := json.Unmarshal(trimmed, &array); err == nil {
		return array, nil
	}

	var single eventHubRecord
	if err := json.Unmarshal(trimmed, &single); err == nil && single.Body != "" {
		return []eventHubRecord{single}, nil
	}

	var strArray []string
	if err := json.Unmarshal(trimmed, &strArray); err == nil {
		records := make([]eventHubRecord, 0, len(strArray))
		for _, val := range strArray {
			records = append(records, eventHubRecord{Body: val})
		}
		return records, nil
	}

	var strValue string
	if err := json.Unmarshal(trimmed, &strValue); err == nil {
		return []eventHubRecord{{Body: strValue}}, nil
	}

	var obj map[string]json.RawMessage
	if err := json.Unmarshal(trimmed, &obj); err == nil {
		for _, key := range []string{"events", "Events", "messages", "Messages", "body", "Body"} {
			if val, ok := obj[key]; ok {
				// try raw first
				if recs, err := parseEventHubRecords(val); err == nil {
					return recs, nil
				}

				var str string
				if err := json.Unmarshal(val, &str); err == nil {
					if recs, perr := parseEventHubRecords([]byte(str)); perr == nil {
						return recs, nil
					}

					normalized := normalizeLooseJSON(str)
					if recs, perr := parseEventHubRecords([]byte(normalized)); perr == nil {
						return recs, nil
					}
				}
			}
		}
	}

	return nil, errors.New("unsupported Event Hubs payload shape")
}

func normalizeLooseJSON(input string) string {
	builder := &bytes.Buffer{}
	inString := false
	for i := 0; i < len(input); i++ {
		ch := input[i]
		if ch == '\'' {
			builder.WriteByte('"')
			continue
		}
		if ch == '"' {
			inString = !inString
		}
		builder.WriteByte(ch)
	}
	return builder.String()
}

func (r eventHubRecord) decodeBody() ([]byte, error) {
	if r.Body == "" {
		return nil, errors.New("missing body")
	}

	decoded, err := base64.StdEncoding.DecodeString(r.Body)
	if err == nil {
		return decoded, nil
	}

	decoded, err = base64.StdEncoding.WithPadding(base64.NoPadding).DecodeString(r.Body)
	if err == nil {
		return decoded, nil
	}

	return []byte(r.Body), nil
}

func convertToTransaction(record eventHubRecord) (transactionEvent, map[string]any, error) {
	var evt transactionEvent

	payload, err := record.decodeBody()
	if err != nil {
		return evt, nil, fmt.Errorf("body_decode: %w", err)
	}

	if err := json.Unmarshal(payload, &evt); err != nil {
		var arr []transactionEvent
		if arrErr := json.Unmarshal(payload, &arr); arrErr == nil && len(arr) > 0 {
			evt = arr[0]
		} else {
			return evt, nil, fmt.Errorf("transaction_unmarshal: %w", err)
		}
	}

	doc := map[string]any{
		"id":          evt.ID,
		"transaction": evt.Transaction,
		"account":     evt.Account,
		"amount":      evt.Amount,
		"userid":      evt.UserID,
		"data":        evt.Data,
	}

	return evt, doc, nil
}
