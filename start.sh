#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

NOTEBOOK_DIR="$(readlink -f $SCRIPT_DIR/notebooks)"
mkdir -p "$NOTEBOOK_DIR"
cd "$NOTEBOOK_DIR"

if [ -z "$POETRY_ACTIVE" ]; then
  poetry run jupyter lab --ServerApp.password="" --ServerApp.token="" --ip 127.0.0.1
else
  jupyter lab --ServerApp.password="" --ServerApp.token="" --ip 127.0.0.1
fi

