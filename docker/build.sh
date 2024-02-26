#!/usr/bin/env bash

files=(start.sh pyproject.toml hashpass.py)

usage() {
    echo "usage: $0 DOCKERFILE"
    exit 1
}

if [ "$#" != "1" ]; then
    usage
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# copy context
for fn in ${files[@]}; do
    cp "$SCRIPT_DIR/../$fn" "$SCRIPT_DIR/$fn"
done

# build
docker build -t llm-environment:$(date +%Y%m%d) -f $1 .

# cleanup
for fn in ${files[@]}; do
    rm -f "$SCRIPT_DIR/$fn"
done
