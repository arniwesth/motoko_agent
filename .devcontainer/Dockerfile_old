FROM ubuntu:24.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl build-essential ca-certificates rsync \
    && rm -rf /var/lib/apt/lists/*


# Go
ENV GO_VERSION=1.22.5
RUN ARCH=$(uname -m | sed 's/aarch64/arm64/; s/x86_64/amd64/') && \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -o /tmp/go.tar.gz && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"

# Bun
COPY --from=oven/bun:1 /usr/local/bin/bun /usr/local/bin/bun

# Node.js 22.x
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && rm -rf /var/lib/apt/lists/*

# context-mode CLI
RUN npm install -g context-mode

# AILANG runtime (clone + build from public fork)
RUN git clone --branch motoko https://github.com/arniwesth/ailang /opt/ailang && \
     cd /opt/ailang && go build ./cmd/ailang && \
     cp ailang /usr/local/bin/ailang

# Set up workspace
WORKDIR /workspaces/motoko_agent
