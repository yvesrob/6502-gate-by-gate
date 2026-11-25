FROM davidsiaw/yosys-docker:20261124

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Add a vscode user and install cc65.
RUN \
    groupadd --gid $USER_GID $USERNAME && \
    useradd --uid $USER_UID --gid $USER_GID -m $USERNAME -s /bin/bash && \
    apt-get update && \
    apt-get upgrade -y && \
    apt install -y \
            cc65 \
            --no-install-recommends
