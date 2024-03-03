#!/usr/bin/env bash

set -Euo pipefail

# wait on any of the above processes to exit. If they do, this script will exit and the container should restart
trap stop_llava INT
stop_llava() {
    echo "Stopping LLaVA..."
    set +Eu
    pkill -9 -P $SGLANG_SERVER_PID >/dev/null 2>&1
    pkill -9 -P $SGLANG_WORKER_PID >/dev/null 2>&1
    kill -9 $CONTROLLER_PID >/dev/null 2>&1
    kill -9 $GRADIO_PID >/dev/null 2>&1
    kill -9 $SGLANG_SERVER_PID >/dev/null 2>&1
    kill -9 $SGLANG_WORKER_PID >/dev/null 2>&1
    kill -9 $TAIL_PID >/dev/null 2>&1
    pkill -P $$ >/dev/null 2>&1
    kill -9 $$ >/dev/null 2>&1
    exit 0
}

mkdir -p /tmp/log
if [ "$#" == "1" ]; then
    MODEL="$1"
fi
DEFAULT_MODEL="SurfaceData/llava-v1.6-mistral-7b-sglang"
MODEL="${MODEL:-$DEFAULT_MODEL}"
LOGS=/tmp/log/{controller,gradio,sglang_server,sglang_worker}.log
rm -f /tmp/log/{controller,gradio,sglang_server,sglang_worker}.log
touch /tmp/log/{controller,gradio,sglang_server,sglang_worker}.log
tail -f /tmp/log/{controller,gradio,sglang_server,sglang_worker}.log &
TAIL_PID=$!

await() {
    set +E
    while true; do
        $@ >/dev/null 2>&1
        if [ "$?" == "0" ]; then break; fi
        sleep 1
    done
    set -E
}

# start LLaVA controller server
python -m llava.serve.controller \
    --host 127.0.0.1 \
    --port 10000 >/tmp/log/controller.log 2>&1 &
await curl -fs -X POST localhost:10000/list_models
CONTROLLER_PID=$!

# start gradio web server
python -m llava.serve.gradio_web_server \
    --controller http://localhost:10000 \
    --model-list-mode "reload" >/tmp/log/gradio.log 2>&1 &
GRADIO_PID=$!

# start sglang server
python -m sglang.launch_server \
    --model-path "$MODEL" \
    --chat-template "vicuna_v1.1" \
    --port 30000 >/tmp/log/sglang_server.log 2>&1 &
SGLANG_SERVER_PID=$!

# wait for the sglang server to start
await curl -fs localhost:30000/get_model_info

# start sglang worker
python -m llava.serve.sglang_worker \
    --host 127.0.0.1 \
    --controller http://localhost:10000 \
    --port 40000 \
    --worker http://localhost:40000 \
    --sgl-endpoint http://127.0.0.1:30000 >/tmp/log/sglang_worker.log 2>&1 &
SGLANG_WORKER_PID=$!
await curl -X POST -fs localhost:40000/worker_get_status

echo "
╔══════════════════════════════════╗
║              ✅✅✅              ║
║                                  ║
║      LLaVA is ready to go!       ║
║     ➡️   http://localhost:7860    ║
║                                  ║
║              ✅✅✅              ║
╚══════════════════════════════════╝
"

wait -p PID_EXITED -n $CONTROLLER_PID $GRADIO_PID $SGLANG_SERVER_PID $SGLANG_WORKER_PID $TAIL_PID
RET=$?
blame=""
case "$PID_EXITED" in
    $CONTROLLER_PID)
        blame=controller
        ;;
    $GRADIO_PID)
        blame=gradio
        ;;
    $SGLANG_SERVER_PID)
        blame=sglang_server
        ;;
    $SGLANG_WORKER_PID)
        blame=sglang_worker
        ;;
    $TAIL_PID)
        blame=tail
        ;;
    *)
        blame="<unknown>"
        ;;
esac

printf "Process [$blame] exited with code $RET\n"
stop_llava

exit $RET
