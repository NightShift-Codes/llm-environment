#!/usr/bin/env bash

TOTAL=4
BOLD=$(tput -T screen bold)
REG=$(tput -T screen sgr0)
REV=$(tput -T screen rev)
INTERNAL_INIT_SCRIPT=${INTERNAL_INIT_SCRIPT:-}

# wait on any of the above processes to exit. If they do, this script will exit and the container should restart
trap stop_llava INT
stop_llava() {
    echo ""
    echo -e "🔴  \033[1;30mStopping LLaVA...\033[0m"
    set +Eu
    kill $STATUS_PID >/dev/null 2>&1
    pkill -9 -P $SGLANG_SERVER_PID >/dev/null 2>&1
    pkill -9 -P $SGLANG_WORKER_PID >/dev/null 2>&1
    kill -9 $CONTROLLER_PID >/dev/null 2>&1
    kill -9 $GRADIO_PID >/dev/null 2>&1
    kill -9 $SGLANG_SERVER_PID >/dev/null 2>&1
    kill -9 $SGLANG_WORKER_PID >/dev/null 2>&1
    kill -9 $TAIL_PID >/dev/null 2>&1
    # pkill -P $$ >/dev/null 2>&1
    RET=$1
    exit ${RET:-0}
}

if [ -z "$INTERNAL_INIT_SCRIPT" ]; then
  # Create temporary screen config file to avoid conflicts with
  # user's .screenrc
  screencfg=$(mktemp)
  # Show status line at bottom of terminal
  echo hardstatus alwayslastline > "$screencfg"
  # Start script in a new screen session
  if [ -t 1 ]; then
    INTERNAL_INIT_SCRIPT=1 screen -mq -c "$screencfg" /bin/bash -c "$0 $@"
    # Store screen return code
    ret=$?
    # Remove temporary screen config file
    rm "$screencfg"
    # Exit with the same return code that screen exits with
    exit $ret
  fi
fi


set -Euo pipefail
mkdir -p /tmp/log
LOGS=/tmp/log/{controller,gradio,sglang_server,sglang_worker}.log
rm -f /tmp/log/{controller,gradio,sglang_server,sglang_worker}.log
touch /tmp/log/{controller,gradio,sglang_server,sglang_worker}.log
tail -f /tmp/log/{controller,gradio,sglang_server,sglang_worker}.log & 
TAIL_PID=$!

statusline() {
    if [ ! -z "$INTERNAL_INIT_SCRIPT" ]; then
        screen -X hardstatus string "$1"
    fi
}

# pauses the script until the specified command completes successfully
await() {
    set +E
    tries=0
    cur=$1
    desc=$2
    shift
    shift
    while true; do
        ndots=$(( tries % 3 + 1 ))
        dots=""
        d=0
        while [ "$d" != "$ndots" ]; do
            dots=$dots"."
            d=$(( d + 1 ))
        done
        statusline "🟡  [$cur/$TOTAL] Starting ${BOLD}${desc}${REG}${REV}${dots}"
        tries=$(( tries + 1 ))
        $@ >/dev/null 2>&1
        if [ "$?" == "0" ]; then 
            break
        fi
        sleep 1
    done
    set -E
}

# start LLaVA controller server
echo "
Starting LLaVA controller"
(python -m llava.serve.controller \
    --host 127.0.0.1 \
    --port 10000 2>&1 | stdbuf -o0 grep -Ev "heart[_ ]?beat") >/tmp/log/controller.log &
CONTROLLER_PID=$!
await 1 "controller" curl -fs -X POST localhost:10000/list_models

# start gradio web server
echo "
Starting gradio web app"
(python -m llava.serve.gradio_web_server \
    --controller http://localhost:10000 \
    --model-list-mode "reload" 2>&1) >/tmp/log/gradio.log &
GRADIO_PID=$!
await 2 "gradio" curl -fs localhost:7860

# start sglang server
echo "
Starting sglang server"
(python -m sglang.launch_server \
    "$@" \
    --port 30000 2>&1 | stdbuf -o0 grep -v /generate) >/tmp/log/sglang_server.log &
SGLANG_SERVER_PID=$!
await 3 "sglang server (this may take a while on first run)" curl -fs localhost:30000/get_model_info

# start sglang worker
echo "
Starting sglang worker"
(python -m llava.serve.sglang_worker \
    --host 127.0.0.1 \
    --controller http://localhost:10000 \
    --port 40000 \
    --worker http://localhost:40000 \
    --sgl-endpoint http://127.0.0.1:30000 2>&1 | stdbuf -o0 grep -Ev "(heart[_ ]?beat|worker_get_status)") >/tmp/log/sglang_worker.log &
SGLANG_WORKER_PID=$!
await 4 "sglang worker" curl -X POST -fs localhost:40000/worker_get_status

echo -e "
\033[1;32mLLaVA is running!\033[0m
\033[1;30mhttp://localhost:7860\033[0m
"

echo -e "\033[0m"

# print the running message along the bottom of the terminal
(while true; do
    statusline "${REG}\033[1;32m${REV}🟢  ${BOLD}LLaVA 🌋 is running! ➡️  http://localhost:7860${REG}"
    sleep 1
done) &
STATUS_PID=$!

wait -p PID_EXITED -n $CONTROLLER_PID $GRADIO_PID $SGLANG_SERVER_PID $SGLANG_WORKER_PID $TAIL_PID $STATUS_PID
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
    $STATUS_PID)
        blame=tput
        ;;
    *)
        blame="<unknown>"
        ;;
    esac
echo ""
echo -e "🔴  \033[1;31mProcess \033[0m[\033[1;30m$blame\033[0m] \033[1;31mexited with code $RET\033[0m"
stop_llava $RET
