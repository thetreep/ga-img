# Use the GitHub Actions runner base image
FROM --platform=linux/amd64 ghcr.io/actions/actions-runner:latest

# Set a specific Go version
ARG GO_VERSION="1.25.0"

# Install dependencies
RUN sudo apt-get update && \
    sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    gcc \
    tar \
    xz-utils \
    software-properties-common \
    lsb-release \
    g++-x86-64-linux-gnu \
    libc6-dev-amd64-cross \
    make

# Set up the Docker repository and install Docker-compose plugin
RUN sudo install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    sudo chmod a+r /etc/apt/keyrings/docker.gpg

RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    sudo apt-get update && \
    sudo apt-get install -y docker-compose-plugin

# Install Go
RUN rm -rf /usr/local/go && \
    curl -L https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | sudo tar -C /usr/local -xzf -

# Set environment variables for Go
ENV GOPATH="/go"
ENV GOBIN="$GOPATH/bin"
ENV PATH="$GOBIN:/usr/local/go/bin:${PATH}"

# Create the directories in case they don't exist
RUN sudo mkdir -p "$GOPATH/src" "$GOPATH/bin" && sudo chmod -R 777 "$GOPATH"

# Install GolangCI-Lint
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v2.7.2

# Install go-junit-report
RUN go install github.com/jstemmer/go-junit-report/v2@latest

# Install gotext
RUN go install golang.org/x/text/cmd/gotext@latest

# Install Cloud SQL Proxy
RUN curl -o cloud_sql_proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.14.3/cloud-sql-proxy.linux.amd64 && \
    chmod +x cloud_sql_proxy && \
    sudo mv cloud_sql_proxy /usr/local/bin/

# Install GCloud CLI
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    sudo apt-get update -y && sudo apt-get install -y google-cloud-sdk

# Install GCloud GKE Auth Plugin
RUN sudo apt-get install -y google-cloud-sdk-gke-gcloud-auth-plugin

# Install kubectl
RUN sudo apt-get install -y kubectl

# Install Migrate tool
RUN curl -L https://github.com/golang-migrate/migrate/releases/download/v4.18.2/migrate.linux-amd64.tar.gz | tar xvz && \
    sudo mv migrate /usr/local/bin/

# Install Goose
RUN go install github.com/pressly/goose/v3/cmd/goose@latest

# Install go-swagger
RUN go install github.com/go-swagger/go-swagger/cmd/swagger@latest

# Install gotestsum
RUN go install gotest.tools/gotestsum@latest

ARG NODE_VERSION="22.14.0"
RUN ARCH='x64' && \
  curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" && \
  sudo tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner && \
  rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" && \
  node --version && npm --version

RUN sudo corepack enable && corepack prepare pnpm@10.27.0 --activate

ARG PLAYWRIGHT_VERSION="1.57.0"
RUN npx playwright@${PLAYWRIGHT_VERSION} install-deps chromium

# Clean up
RUN sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/*
