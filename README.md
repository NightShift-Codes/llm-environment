# llm-environment

Base environment for experimenting locally with LLMs

## Install

```bash
poetry install
```

## Basic environment

https://medium.com/nightshift-codes/getting-started-with-llms-d75a5cd370cb

### Mac
```bash
./start.sh
```

### Windows, Linux
```bash
docker run -it --rm --gpus all --network host -v "./notebooks:/home/user/llm-environment/notebooks" nightshiftcodes/llm-environment:intro
```

## LLaVA v1.6

https://medium.com/nightshift-codes/run-llava-v1-6-locally-48bfc68265db

### Mac
```bash
./llava.sh
```

### Windows, Linux
```bash
docker run -it \
  -v ~/.cache/huggingface:/home/user/.cache/huggingface \
  -p 7860:7860 \
  --gpus all \
  nightshiftcodes/llm-environment:llava
```
