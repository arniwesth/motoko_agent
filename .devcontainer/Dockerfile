FROM mcr.microsoft.com/devcontainers/python:3.14

# Install basics
RUN apt-get update && apt-get install -y npm curl

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y gh

# Install Go (arch-aware)
RUN ARCH=$(dpkg --print-architecture) && \
    curl -fsSL "https://go.dev/dl/go1.24.2.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz && \
    ln -sf /usr/local/go/bin/go /usr/local/bin/go && \
    ln -sf /usr/local/go/bin/gofmt /usr/local/bin/gofmt
ENV PATH="/usr/local/go/bin:$PATH"
#RUN curl -fsSL https://bun.sh/install | bash
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bun
RUN pip install --upgrade pip
RUN python -m pip install jupyter_kernel_gateway ipykernel
RUN pip install uv

# FIX THE PATH (The correct way)
# This replaces the need for .bashrc
ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"
ENV PATH="/root/.bun/bin:$PATH"
RUN echo 'export PATH="$HOME/.bun/bin:$PATH"' >> ~/.bashrc

# Homebrew (must not run as root)
USER vscode
RUN NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
USER root
ENV PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"

# Install harnesses
RUN curl -fsSL https://claude.ai/install.sh | bash
RUN npm i -g @openai/codex
RUN bun install -g @oh-my-pi/pi-coding-agent
RUN npm install -g obsidian-headless
#RUN curl -fsSL https://ampcode.com/install.sh | bash
#RUN curl -fsSL https://junie.jetbrains.com/install.sh | bash
# curl -fsSL https://opencode.ai/install | bash

#RUN brew install ripgrep

#EXPOSE 8080
#RUN pip install gepa
