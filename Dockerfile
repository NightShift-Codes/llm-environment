FROM nvcr.io/nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04

USER root

SHELL [ "/bin/bash", "-c" ]

ENV SHELL="/bin/bash"
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNING_IN_DOCKER=1

WORKDIR /root/llm-environment

COPY . .

ENV PATH="/root/.local/bin:$PATH"

RUN apt update \
    && apt upgrade -y \
    && apt install -y software-properties-common \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt update \
    && apt install -y \
         python3.12-minimal \
         python3.12-dev \
         pipx \
         pkg-config \
         build-essential \
         cmake \
    && pipx ensurepath --force \
    && pipx install poetry \
    && poetry install \
    && apt remove -y \
         pkg-config \
         build-essential \
         cmake \
         python3.12-dev \
    && apt autoremove -y \
    && apt install -y python3.12-minimal \
    && rm -rf /root/.cache/pypoetry/artifacts/* \
    && rm -rf /root/.cache/pypoetry/cache/* \
    && apt clean

ENV DEBIAN_FRONTEND=

ENTRYPOINT [ "/bin/bash", "-c" ]

CMD [ "./start.sh", "$@" ]
