FROM --platform=linux/amd64 ghcr.io/actions/actions-runner:latest

ARG GO_VERSION="1.27.3"
ARG NODE_VERSION="22.14.0"
ARG PLAYWRIGHT_VERSION="1.57.0"
ARG GOLANGCI_LINT_VERSION="v2.13.2"

RUN sudo apt-get update && \
    sudo apt-get install -y --no-install-recommends \
      ca-certificates curl gnupg git gcc tar xz-utils lsb-release make \
      g++-x86-64-linux-gnu libc6-dev-amd64-cross && \
    sudo install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
      | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list > /dev/null && \
    sudo apt-get update && \
    sudo CLOUDSDK_SKIP_PY_COMPILATION=1 apt-get install -y --no-install-recommends \
      docker-compose-plugin google-cloud-cli google-cloud-cli-gke-gcloud-auth-plugin kubectl && \
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/*

ENV GOPATH="/go"
ENV GOBIN="$GOPATH/bin"
ENV PATH="$GOBIN:/usr/local/go/bin:${PATH}"

RUN sudo rm -rf /usr/local/go && \
    curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | sudo tar -C /usr/local -xzf - && \
    sudo mkdir -p "$GOPATH/src" "$GOPATH/bin" && sudo chmod -R 777 "$GOPATH"

RUN curl -sSfL https://golangci-lint.run/install.sh | sh -s -- -b "$GOBIN" ${GOLANGCI_LINT_VERSION} && \
    go install github.com/jstemmer/go-junit-report/v2@latest && \
    go install golang.org/x/text/cmd/gotext@latest && \
    go install github.com/pressly/goose/v3/cmd/goose@latest && \
    go install github.com/go-swagger/go-swagger/cmd/swagger@latest && \
    go install gotest.tools/gotestsum@latest && \
    go clean -modcache -cache && \
    rm -rf "$HOME/.cache/go-build"

RUN curl -fsSL -o /tmp/cloud_sql_proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.3/cloud-sql-proxy.linux.amd64 && \
    sudo install -m 0755 /tmp/cloud_sql_proxy /usr/local/bin/cloud_sql_proxy && rm /tmp/cloud_sql_proxy && \
    curl -fsSL https://github.com/golang-migrate/migrate/releases/download/v4.18.2/migrate.linux-amd64.tar.gz \
      | sudo tar -xz -C /usr/local/bin migrate

RUN curl -fsSL "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-x64.tar.xz" \
      | sudo tar -xJ -C /usr/local --strip-components=1 --no-same-owner && \
    node --version && npm --version && \
    sudo corepack enable && corepack prepare pnpm@10.27.0 --activate && \
    npx -y playwright@${PLAYWRIGHT_VERSION} install-deps chromium && \
    sudo apt-get clean && sudo rm -rf /var/lib/apt/lists/* && \
    npm cache clean --force
