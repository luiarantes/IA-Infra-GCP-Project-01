FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Instala ferramentas essenciais: curl, jq, git, python, nodejs, npm
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    git \
    jq \
    gnupg \
    python3 \
    python3-pip \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Instala kubectl
RUN curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg \
    && echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' > /etc/apt/sources.list.d/kubernetes.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends kubectl \
    && rm -rf /var/lib/apt/lists/*

# Instala GitHub CLI (gh)
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | gpg --dearmor -o /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Instala Claude Code CLI
RUN npm install -g @anthropic-ai/claude-code

WORKDIR /workspace

COPY run-agent-local.sh /usr/local/bin/run-agent-local.sh
RUN chmod +x /usr/local/bin/run-agent-local.sh

ENTRYPOINT ["/usr/local/bin/run-agent-local.sh"]
