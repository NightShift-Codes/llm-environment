FROM nvcr.io/nvidia/cuda:12.2.2-cudnn8-runtime-ubuntu22.04

USER root

SHELL [ "/bin/bash", "-c" ]

WORKDIR /root

RUN apt update \
    && apt upgrade -y \
    && apt install -y sudo \
    && echo 'user ALL = (ALL) NOPASSWD: ALL' >> /etc/sudoers \
    && useradd -m user \
    && apt clean

USER user
ENV PATH="/home/user/.local/bin:$PATH"
ENV SHELL="/bin/bash"
ENV DEBIAN_FRONTEND=noninteractive
ENV RUNNING_IN_DOCKER=1
WORKDIR /home/user/llm-environment

COPY --chown=1000:1000 ./pyproject.toml ./pyproject.toml
COPY --chown=1000:1000 ./poetry.lock ./poetry.lock
COPY --chown=1000:1000 ./hashpass.py ./hashpass.py

RUN sudo apt update \
    && sudo apt install -y software-properties-common \
    && sudo add-apt-repository ppa:deadsnakes/ppa \
    && sudo apt update \
    && sudo --preserve-env=DEBIAN_FRONTEND apt install -y \
         python3.12-minimal \
         python3.12-dev \
         pipx \
         pkg-config \
         build-essential \
         cmake \
         git \
         wget \
         curl \
    && pipx ensurepath --force \
    && pipx install poetry \
    && poetry install \
    && sudo apt remove -y \
         pkg-config \
         build-essential \
         cmake \
         python3.12-dev \
    && sudo apt autoremove -y \
    && rm -rf /home/user/.cache/pypoetry/artifacts/* \
    && rm -rf /home/user/.cache/pypoetry/cache/* \
    && sudo apt clean

ENV DEBIAN_FRONTEND=

COPY --chown=1000:1000 ./start.sh ./start.sh

ENTRYPOINT [ "/home/user/llm-environment/start.sh" ]

