.PHONY: build run test clean lint  dev  test-unit test-verbose test-coverage

VERSION := $(shell git describe --tags --abbrev=0)-$(shell git rev-parse --short HEAD)
# APP=$(shell basename $(shell git remote get-url origin) | sed 's/\.git$$//')
REGISTRY=ghcr.io/sarco3t
TARGETOS?=linux
TARGETARCH?=amd64
OUT = $(BUILD_DIR)/$(APP_NAME)$(if $(filter windows,$(TARGETOS)),.$('exe'))
VERSION?=1
APP?=kbot

# Include .env file if it exists (improved handling for comments)
ifneq (,$(wildcard .env))
include .env
endif

# Build and run settings

APP_NAME=kbot
CMD_PATH=./cmd/
BUILD_DIR=./build

# Migrations settings
MIGRATIONS_DIR=./migrations

# Test settings
TEST_PACKAGES?=./...
COVERAGE_FILE=coverage.out


build:	get
	@mkdir -p $(BUILD_DIR)
	@CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
	go build \
	  -o ${OUT} -ldflags "-X="github.com/sarco3t/kbot/cmd.appVersion=${VERSION}
	@chmod +x ${OUT}
	@echo "Build completed: ${OUT}"

run: build
	@echo "Running $(APP_NAME)..."
	TELE_TOKEN=$(TELE_TOKEN) ${OUT} $(ARGS)
get:
	@go get
test: test-deps
	@echo "Running tests..."
	@go test -race $(TEST_PACKAGES)

test-verbose: test-deps
	@echo "Running tests in verbose mode..."
	@go test -v -race $(TEST_PACKAGES)

test-coverage: test-deps
	@echo "Running tests with coverage report..."
	@go test -race -coverprofile=$(COVERAGE_FILE) $(TEST_PACKAGES)
	@go tool cover -html=$(COVERAGE_FILE)
	@rm $(COVERAGE_FILE)

test-deps:
	@echo "Checking for testify dependency..."
	@if ! grep -q "github.com/stretchr/testify" go.mod; then \
		echo "Installing testify package..."; \
		go get github.com/stretchr/testify; \
	fi
	@go mod tidy

lint:
	@command -v golangci-lint > /dev/null || go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
	@echo "Running linter..."
	@golangci-lint run

clean:
	rm -rf $(BUILD_DIR)
	@docker rmi -f ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH}  || true
setup: 
	@if [ -f .env ]; then \
		echo "A .env file already exists."; \
		read -p "Do you want to overwrite it? (y/n): " CONFIRM; \
		if [ "$$CONFIRM" != "y" ]; then \
			echo "Setup aborted."; \
			exit 1; \
		fi; \
	fi
	@if [ -f .env.example ]; then \
		echo "Creating .env file from .env.example..."; \
		cp .env.example .env; \
		echo ".env file created successfully. You may want to edit it with your specific values."; \
	else \
		echo "Error: .env.example file not found."; \
		exit 1; \
	fi


image:
	docker build --platform linux/amd64 . -t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH} --load
push:
	docker build --platform linux/amd64 . -t ${REGISTRY}/${APP}:${VERSION}-${TARGETOS}-${TARGETARCH}  --push
windows:
	TARGETOS=windows TARGETARCH=amd64 make build

windows-arm:
	TARGETOS=windows TARGETARCH=arm64 make build

linux:
	TARGETOS=linux TARGETARCH=amd64 make build
linux-arm:
	TARGETOS=linux TARGETARCH=arm64 make build
macos:
	TARGETOS=darwin TARGETARCH=amd64 make build
macos-arm:
	TARGETOS=darwin TARGETARCH=arm64 make build

image-windows-arm:
	TARGETOS=windows TARGETARCH=arm64 docker build . -t ${REGISTRY}/${APP}:${VERSION}