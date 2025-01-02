# Use the GitHub Actions runner base image
FROM --platform=linux/amd64 ghcr.io/actions/actions-runner:latest

# Set a specific Go version
ARG GO_VERSION="1.23.1"

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
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.61.0

# Install go-junit-report
RUN go install github.com/jstemmer/go-junit-report/v2@latest

# Install gotext
RUN go install golang.org/x/text/cmd/gotext@latest

# Install Cloud SQL Proxy
RUN curl -o cloud_sql_proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.8.2/cloud-sql-proxy.linux.amd64 && \
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
RUN curl -L https://github.com/golang-migrate/migrate/releases/download/v4.17.0/migrate.linux-amd64.tar.gz | tar xvz && \
    sudo mv migrate /usr/local/bin/

# Install Goose
RUN go install github.com/pressly/goose/v3/cmd/goose@latest

# Install go-swagger
RUN go install github.com/go-swagger/go-swagger/cmd/swagger@latest

# Install gotestsum
RUN go install gotest.tools/gotestsum@latest


# Install nodejs
ARG NODE_VERSION="20.17.0"
RUN ARCH= && dpkgArch="$(dpkg --print-architecture)" \
  && case "${dpkgArch##*-}" in \
    amd64) ARCH='x64';; \
    ppc64el) ARCH='ppc64le';; \
    s390x) ARCH='s390x';; \
    arm64) ARCH='arm64';; \
    armhf) ARCH='armv7l';; \
    i386) ARCH='x86';; \
    *) echo "unsupported architecture"; exit 1 ;; \
  esac \
  # use pre-existing gpg directory, see https://github.com/nodejs/docker-node/pull/1895#issuecomment-1550389150
  && export GNUPGHOME="$(mktemp -d)" \
  # gpg keys listed at https://github.com/nodejs/node#release-keys
  && set -ex \
  && for key in \
    4ED778F539E3634C779C87C6D7062848A1AB005C \
    141F07595B7B3FFE74309A937405533BE57C7D57 \
    74F12602B6F1C4E913FAA37AD3A89613643B6201 \
    DD792F5973C6DE52C432CBDAC77ABFA00DDBF2B7 \
    61FC681DFB92A079F1685E77973F295594EC4689 \
    8FCCA13FEF1D0C2E91008E09770F7A9A5AE15600 \
    C4F0DFFF4E8C1A8236409D08E73BC641CC11F4C8 \
    890C08DB8579162FEE0DF9DB8BEAB4DFCF555EF4 \
    C82FA3AE1CBEDC6BE46B9360C43CEC45C17AB93C \
    108F52B48DB57BB0CC439B2997B01419BD92F80A \
    A363A499291CBBC940DD62E41F10027AF002F8B0 \
    CC68F5A3106FF448322E48ED27F5E38D5B0A215F \
  ; do \
      gpg --batch --keyserver hkps://keys.openpgp.org --recv-keys "$key" || \
      gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "$key" ; \
  done \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/node-v$NODE_VERSION-linux-$ARCH.tar.xz" \
  && curl -fsSLO --compressed "https://nodejs.org/dist/v$NODE_VERSION/SHASUMS256.txt.asc" \
  && gpg --batch --decrypt --output SHASUMS256.txt SHASUMS256.txt.asc \
  && gpgconf --kill all \
  && rm -rf "$GNUPGHOME" \
  && grep " node-v$NODE_VERSION-linux-$ARCH.tar.xz\$" SHASUMS256.txt | sha256sum -c - \
  && sudo tar -xJf "node-v$NODE_VERSION-linux-$ARCH.tar.xz" -C /usr/local --strip-components=1 --no-same-owner \
  && rm "node-v$NODE_VERSION-linux-$ARCH.tar.xz" SHASUMS256.txt.asc SHASUMS256.txt \
  && sudo ln -s /usr/local/bin/node /usr/local/bin/nodejs \
  # smoke tests
  && node --version \
  && npm --version

# Clean up
RUN sudo apt-get clean && \
    sudo rm -rf /var/lib/apt/lists/*