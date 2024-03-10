#!/bin/bash

trap stop_llava INT
stop_llava() {
    echo ""
    echo -e "\033[1;30mStopping LLaVA...\033[0m"
    set +Eu
    pkill -9 -P $ollama_serve_pid >/dev/null 2>&1
    kill -9 $ollama_serve_pid >/dev/null 2>&1
    pkill -9 -P $ollama_run_pid >/dev/null 2>&1
    kill -9 $ollama_run_pid >/dev/null 2>&1
    docker rm -f open-webui
    RET=$1
    exit ${RET:-0}
}

await() {
    set +E
    while true; do
        "$@" >/dev/null 2>&1
        if [ "$?" == "0" ]; then 
            break
        fi
        sleep 1
    done
    set -E
}

brew install ollama

ollama serve &
ollama_serve_pid="$!"
await ollama list
ollama run llava &
ollama_run_pid="$!"
await curl -fs localhost:11434/api/generate -d '{"model":"llava","prompt":"hello", "stream":false, "options":{"num_predict":1}}'

docker run -d -p 3000:8080 --add-host=host.docker.internal:host-gateway -v open-webui:/app/backend/data --name open-webui --restart always ghcr.io/open-webui/open-webui:main
await curl localhost:3000
open http://localhost:3000
wait $ollama_serve_pid $ollama_run_pid
