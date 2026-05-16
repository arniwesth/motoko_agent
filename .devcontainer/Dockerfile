FROM ubuntu:24.04

ARG USERNAME=motoko
ARG USER_UID=1001
ARG USER_GID=$USER_UID

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git sudo sudo unzip\
    && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "$USER_GID" "$USERNAME" && \
    useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME" && \
    echo "$USERNAME ALL=(root) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" && \
    chmod 0440 "/etc/sudoers.d/$USERNAME"

ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.bun/bin:/usr/local/go/bin:${PATH}"

WORKDIR /tmp/motoko_agent
COPY --chown=${USERNAME}:${USERNAME} . /tmp/motoko_agent

USER ${USERNAME}
RUN ./scripts/install-prerequisites.sh

USER root
RUN rm -rf /tmp/motoko_agent /var/lib/apt/lists/*

USER ${USERNAME}
WORKDIR /workspaces/motoko_agent
