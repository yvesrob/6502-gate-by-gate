FROM ubuntu:26.04

# TODO(siggi): base this container on davidsiaw/yosys-docker and
#   use devcontainer.json to specify user name.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

ENV CAD_SUITE_URL=https://github.com/YosysHQ/oss-cad-suite-build/releases/download/2026-11-20/oss-cad-suite-linux-x64-20261120.tgz
ENV PATH="${PATH}:/opt/oss-cad-suite/bin"

RUN \
    userdel ubuntu && \
    groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash && \
    apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
            ca-certificates \
            build-essential \
            cc65 \
            python3 \
            curl \
            git \
            ssh \
            wget \
            less \
            btop \
            --no-install-recommends && \
    wget --progress=bar:force -O /tmp/oss-cad-suite.tgz ${CAD_SUITE_URL} && \
    tar zxvf /tmp/oss-cad-suite.tgz && \
    mv oss-cad-suite /opt && \
    /opt/oss-cad-suite/py3bin/pip3 install --upgrade pip && \
    /opt/oss-cad-suite/py3bin/pip3 install numpy msgspec fastcrc
    
USER $USERNAME
