# Copyright 2025 Sigurdur Asgeirsson <siggi@sort.is>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM ubuntu:26.04

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
