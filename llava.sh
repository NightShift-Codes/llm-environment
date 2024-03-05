#!/bin/bash

set -Eo pipefail

if [ -z "$INTERNAL_INIT_SCRIPT" ]; then
  # Create temporary screen config file to avoid conflicts with
  # user's .screenrc
  screencfg=$(mktemp)
  # Show status line at bottom of terminal
  echo hardstatus alwayslastline > "$screencfg"
  # Start script in a new screen session
  if [ -t 1 ]; then
    INTERNAL_INIT_SCRIPT=1 screen -mq -c "$screencfg" bash -c "$0 $@"
    # Store screen return code
    ret=$?
    # Remove temporary screen config file
    rm "$screencfg"
    # Exit with the same return code that screen exits with
    exit $ret
  fi
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if ! [ -z "$POETRY_ACTIVE" ]; then
    # the important bits from poetry's deactivate() function
 	unset -f pydoc > /dev/null 2>&1 || true
    PATH=${PATH//:$VIRTUAL_ENV\/bin:/}
    PATH=${PATH//:$VIRTUAL_ENV\/bin/}
    PATH=${PATH/#$VIRTUAL_ENV\/bin:/}
	export PATH
	if ! [ -z "${_OLD_VIRTUAL_PYTHONHOME+_}" ]
	then
		PYTHONHOME="$_OLD_VIRTUAL_PYTHONHOME"
		export PYTHONHOME
		unset _OLD_VIRTUAL_PYTHONHOME
	fi
	hash -r 2> /dev/null
	if ! [ -z "${_OLD_VIRTUAL_PS1+_}" ]
	then
		PS1="$_OLD_VIRTUAL_PS1"
		export PS1
		unset _OLD_VIRTUAL_PS1
	fi
	unset VIRTUAL_ENV
	unset VIRTUAL_ENV_PROMPT
	if [ ! "${1-}" = "nondestructive" ]
	then
		unset -f deactivate
	fi
    unset POETRY_ACTIVE
fi

statusline() {
    if [ ! -z "${INTERNAL_INIT_SCRIPT:-}" ]; then
        screen -X hardstatus string "$1"
    fi
}

pushd $SCRIPT_DIR >/dev/null 2>&1
if [ -d "LLaVA/venv/bin" ]; then
    source LLaVA/venv/bin/activate
else
    rm -rf LLaVA
    statusline "Cloning LLaVA repo..."
    git clone https://github.com/haotian-liu/LLaVA
    cd LLaVA
    python3 -m venv venv
    source venv/bin/activate
    statusline "Upgrading pip..."
    pip install --upgrade pip
    statusline "Installing LLaVA..."
    pip install -e "."
    statusline "Installing extra dependendencies..."
    pip install torch==2.1.0 torchvision==0.16.0
    pip uninstall -y bitsandbytes
fi
popd >/dev/null 2>&1

BOLD=$(tput -T screen bold)
REG=$(tput -T screen sgr0)
REV=$(tput -T screen rev)
BLACK=$(tput -T screen setaf 0)
RED=$(tput -T screen setaf 1)
GREEN=$(tput -T screen setaf 2)
YELLOW=$(tput -T screen setaf 3)


# wait on any of the above processes to exit. If they do, this script will exit and the container should restart
trap stop_llava INT
stop_llava() {
    echo ""
    echo -e "${RED}${REV}Stopping LLaVA...${REG}"
    set +Eu
    kill $STATUS_PID >/dev/null 2>&1
    pkill -9 -P $MODEL_WORKER_PID >/dev/null 2>&1
    kill -9 $CONTROLLER_PID >/dev/null 2>&1
    kill -9 $GRADIO_PID >/dev/null 2>&1
    kill -9 $MODEL_WORKER_PID >/dev/null 2>&1
    kill -9 $TAIL_PID >/dev/null 2>&1
    # pkill -P $$ >/dev/null 2>&1
    RET=$1
    echo "Press Ctrl+C to exit."
    mkdir -p logs
    mv controller.log gradio_web_server.log model_worker_*.log logs
    exit ${RET:-0}
}

set -Euo pipefail
mkdir -p /tmp/log
if [ "$#" == "1" ]; then
    MODEL="$1"
fi
DEFAULT_MODEL="liuhaotian/llava-v1.6-mistral-7b"
MODEL="${MODEL:-$DEFAULT_MODEL}"
LOGS=/tmp/log/{controller,gradio,model_worker}.log
rm -f /tmp/log/{controller,gradio,model_worker}.log
touch /tmp/log/{controller,gradio,model_worker}.log
tail -f /tmp/log/{controller,gradio,model_worker}.log & 
TAIL_PID=$!


# pauses the script until the specified command completes successfully
TOTAL=3
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
        statusline "[$cur/$TOTAL] Starting ${desc}${dots}"
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
    --port 10000 2>&1 | grep --line-buffered -Ev "heart[_ ]?beat") >/tmp/log/controller.log &
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

# start llava model worker
echo "
Starting llava worker (this may take a long time to download on first run)"
(python -m llava.serve.model_worker \
    --host 127.0.0.1 \
    --controller http://localhost:10000 \
    --port 40000 \
    --worker http://localhost:40000 \
    --model-path $MODEL \
    --multi-modal \
    --device mps 2>&1 | grep --line-buffered -Ev "(heart[_ ]?beat|worker_get_status)") >/tmp/log/model_worker.log &
MODEL_WORKER_PID=$!
await 3 "model worker (this may take a long time to download on first run)" curl -X POST -fs localhost:40000/worker_get_status

echo -e "
${REG}${BOLD}${REV}LLaVA is running!${REG}
${GREEN}${BOLD}${REV}http://localhost:7860${REG}
"

# print the running message along the bottom of the terminal
(while true; do
    statusline "LLaVA is running!  http://localhost:7860"
    sleep 1
done) &
STATUS_PID=$!

wait $CONTROLLER_PID $GRADIO_PID $MODEL_WORKER_PID $TAIL_PID $STATUS_PID
RET=$?
for pid in $CONTROLLER_PID $GRADIO_PID $MODEL_WORKER_PID $TAIL_PID $STATUS_PID; do
    if ! ps -p $pid >/dev/null; then
        blame=""
        case "$pid" in
        $CONTROLLER_PID)
            blame=controller
            ;;
        $GRADIO_PID)
            blame=gradio
            ;;
        $MODEL_WORKER_PID)
            blame=model_worker
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
        break
    fi
done
echo ""
echo -e "${RED}${REV}Process ${REG}[${BOLD}$blame${REG}]${RED}${REV}${BOLD} exited with code $RET${REG}" > err.log
stop_llava $RET
