FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install required tools
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl ca-certificates gnupg make git docker.io && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Go
ENV GO_VERSION=1.24.0
ENV GOROOT=/usr/local/go
ENV PATH=$GOROOT/bin:$PATH

RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz | tar -C /usr/local -xz

# Install golangci-lint
ENV GOLANGCI_LINT_VERSION=v2.1.6
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | \
    sh -s -- -b /usr/local/bin ${GOLANGCI_LINT_VERSION}

# Default command for Kubernetes agent to keep container alive
CMD ["sleep", "infinity"]
