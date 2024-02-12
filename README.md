# llm-environment

Base environment for experimenting locally with LLMs

## Install

```bash
poetry install
```

## Run (locally)

```bash
./start.sh
```

## Run (Docker)
```bash
docker run -it --rm --gpus all --network host -v "./notebooks:/root/llm-environment/notebooks" nightshiftcodes/llm-environment:intro
```
