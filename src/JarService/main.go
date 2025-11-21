package main

import (
	"fmt"
	"log"
	"net/http"
	"os"

	simple "github.com/MoimHossain/cosmos-cfp-flex-consumption-function/JarService/SimpleHttpTrigger"
	cosmos "github.com/MoimHossain/cosmos-cfp-flex-consumption-function/JarService/cosmosChangeTrigger"
	timer "github.com/MoimHossain/cosmos-cfp-flex-consumption-function/JarService/timerTrigger"
)

func main() {
	customHandlerPort, exists := os.LookupEnv("FUNCTIONS_CUSTOMHANDLER_PORT")
	if exists {
		fmt.Println("FUNCTIONS_CUSTOMHANDLER_PORT: " + customHandlerPort)
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/SimpleHttpTrigger", simple.Handler)
	mux.HandleFunc("/api/cosmosChangeTrigger", cosmos.Handler)
	mux.HandleFunc("/cosmosChangeTrigger", cosmos.Handler)
	mux.HandleFunc("/Functions.cosmosChangeTrigger", cosmos.Handler)
	mux.HandleFunc("/api/Functions.cosmosChangeTrigger", cosmos.Handler)

	mux.HandleFunc("/api/timerTrigger", timer.Handler)
	mux.HandleFunc("/timerTrigger", timer.Handler)
	mux.HandleFunc("/api/TimerTrigger", timer.Handler)
	mux.HandleFunc("/TimerTrigger", timer.Handler)

	mux.HandleFunc("/Functions.timerTrigger", timer.Handler)
	mux.HandleFunc("/api/Functions.timerTrigger", timer.Handler)

	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Printf("Unhandled request: %s %s\n", r.Method, r.URL.Path)
		w.WriteHeader(http.StatusNotFound)
		w.Write([]byte(fmt.Sprintf("Path not found: %s", r.URL.Path)))
	})

	fmt.Println("Go server Listening...on FUNCTIONS_CUSTOMHANDLER_PORT:", customHandlerPort)
	log.Fatal(http.ListenAndServe(":"+customHandlerPort, mux))
}
