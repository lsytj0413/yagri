# The old school Makefile, following are required targets. The Makefile is written
# to allow building multiple binaries. You are free to add more targets or change
# existing implementations, as long as the semantics are preserved.
#
#   make              - default to 'build' target
#   make lint         - code analysis
#   make test         - run unit test (or plus integration test)
#   make build        - alias to build-local target
#   make build-local  - build local binary targets
#   make build-linux  - build linux binary targets
#   make container    - build containers
#   $ docker login registry -u username -p xxxxx
#   make push         - push containers
#   make clean        - clean up targets
#
# Not included but recommended targets:
#   make e2e-test
#
# The makefile is also responsible to populate project version information.
#

#
# Tweak the variables based on your project.
#

# This repo's root import path (under GOPATH).
ROOT := github.com/lsytj0413/yagri

# Module name.
NAME := yagri


#
# These variables should not need tweaking.
#

# It's necessary to set this because some environments don't link sh -> bash.
export SHELL := /bin/bash

# It's necessary to set the errexit flags for the bash shell.
export SHELLOPTS := errexit

# Project main package location.
CMD_DIR := ./cmd

# Project output directory.
OUTPUT_DIR := ./bin

# Build directory.
BUILD_DIR := ./build


# Current version of the project.
VERSION      ?= $(shell git describe --tags --always --dirty)
BRANCH       ?= $(shell git branch | grep \* | cut -d ' ' -f2)
GITCOMMIT    ?= $(shell git rev-parse HEAD)
GITTREESTATE ?= $(if $(shell git status --porcelain),dirty,clean)
BUILDDATE    ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
appVersion   ?= $(VERSION)

# Available cpus for compiling, please refer to https://github.com/caicloud/engineering/issues/8186#issuecomment-518656946 for more information.
CPUS ?= $(shell /bin/bash hack/read_cpus_available.sh)

# Track code version with Docker Label.
DOCKER_LABELS ?= git-describe="$(shell date -u +v%Y%m%d)-$(shell git describe --tags --always --dirty)"

# Golang standard bin directory.
BIN_DIR := $(firstword $(subst :, , $(PATH)))
GOLANGCI_LINT := $(BIN_DIR)/golangci-lint

# Default golang flags used in build and test
# -count: run each test and benchmark 1 times. Set this flag to disable test cache
export GOFLAGS ?= -count=1

#
# Define all targets. At least the following commands are required:
#

# All targets.
.PHONY: lint test build container push

build: build-local

# more info about `GOGC` env: https://github.com/golangci/golangci-lint#memory-usage-of-golangci-lint
lint: $(GOLANGCI_LINT)
	@$(GOLANGCI_LINT) run

$(GOLANGCI_LINT):
	curl -sfL https://install.goreleaser.com/github.com/golangci/golangci-lint.sh | sh -s -- -b $(BIN_DIR) v1.41.0

test:
	@go test -v -race -gcflags=-l -coverpkg=./... -coverprofile=coverage.out ./...
	@go tool cover -func coverage.out | tail -n 1 | awk '{ print "Total coverage: " $$3 }'

build-local:
	@go build -v -o $(OUTPUT_DIR)/$(NAME)                                  \
	  -ldflags "-s -w -X $(ROOT)/pkg/utils/version.module=$(NAME)                \
	    -X $(ROOT)/pkg/utils/version.version=$(VERSION)                          \
	    -X $(ROOT)/pkg/utils/version.branch=$(BRANCH)                            \
	    -X $(ROOT)/pkg/utils/version.gitCommit=$(GITCOMMIT)                      \
	    -X $(ROOT)/pkg/utils/version.gitTreeState=$(GITTREESTATE)                \
	    -X $(ROOT)/pkg/utils/version.buildDate=$(BUILDDATE)"                     \
	  $(CMD_DIR);

build-linux:
	/bin/bash -c 'GOOS=linux GOARCH=amd64 GOPATH=/go GOFLAGS="$(GOFLAGS)"  \
	  go build -v -o $(OUTPUT_DIR)/$(NAME)                                 \
	    -ldflags "-s -w -X $(ROOT)/pkg/utils/version.module=$(NAME)              \
	      -X $(ROOT)/pkg/utils/version.version=$(VERSION)                        \
	      -X $(ROOT)/pkg/utils/version.branch=$(BRANCH)                          \
	      -X $(ROOT)/pkg/utils/version.gitCommit=$(GITCOMMIT)                    \
	      -X $(ROOT)/pkg/utils/version.gitTreeState=$(GITTREESTATE)              \
	      -X $(ROOT)/pkg/utils/version.buildDate=$(BUILDDATE)"                   \
		$(CMD_DIR)'

.PHONY: clean
clean:
	@-rm -vrf ${OUTPUT_DIR} output coverage.out coverage.out.tmp
