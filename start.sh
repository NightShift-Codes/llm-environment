#!/usr/bin/env bash

set -Eo pipefail
PASSWORD="luna"

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

NOTEBOOK_DIR="$(readlink -f $SCRIPT_DIR/notebooks)"
mkdir -p "$NOTEBOOK_DIR"
cd "$NOTEBOOK_DIR"

allowroot=""
no_browser=""
if [ ! -z "$RUNNING_IN_DOCKER" ]; then
    allowroot="--allow-root"
    no_browser="--no-browser"
fi

if [ -z "$POETRY_ACTIVE" ]; then
  hashed_password="$(poetry run python ../hashpass.py $PASSWORD)"
  poetry run jupyter lab --PasswordIdentityProvider.hashed_password="$hashed_password" --PasswordIdentityProvider.password_required=True --IdentityProvider.token="" $allowroot $no_browser $@
else
  hashed_password="$(python ../hashpass.py $PASSWORD)"
  jupyter lab --PasswordIdentityProvider.hashed_password="$hashed_password" --PasswordIdentityProvider.password_required=True --IdentityProvider.token="" $allowroot $no_browser $@
fi

