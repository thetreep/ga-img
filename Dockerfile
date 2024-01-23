# Use the GitHub Actions runner base image
FROM --platform=linux/amd64 ghcr.io/actions/actions-runner:latest

# Set a specific Go version
ARG GO_VERSION="1.21.6"

# Install dependencies
RUN sudo apt-get update && \
    sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    git \
    gcc \
    tar \
    software-properties-common \
    lsb-release \
    g++-x86-64-linux-gnu \
    libc6-dev-amd64-cross

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
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.54.2

# Install go-junit-report
RUN go install github.com/jstemmer/go-junit-report/v2@latest

# Install gotext
RUN go install golang.org/x/text/cmd/gotext@latest

# Install Cloud SQL Proxy
RUN curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64 && \
    chmod +x cloud_sql_proxy && \
    sudo mv cloud_sql_proxy /usr/local/bin/

# Install GCloud CLI
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    sudo apt-get update -y && sudo apt-get install -y google-cloud-sdk

# Install kubectl
RUN sudo apt-get install -y kubectl

# Install Migrate tool
RUN curl -L https://github.com/golang-migrate/migrate/releases/download/v4.15.1/migrate.linux-amd64.tar.gz | tar xvz && \
    sudo mv migrate /usr/local/bin/

# Install go-swagger
RUN go install github.com/go-swagger/go-swagger/cmd/swagger@latest

# Clean up
RUN sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/*