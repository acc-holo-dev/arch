SHELL := /usr/bin/env bash
PROJECT_ROOT := $(shell pwd)
SOURCES := $(shell find cli core stages -name '*.sh') config/config.yaml config/generate.sh

.PHONY: lint shellcheck format test run package config

lint: shellcheck

shellcheck:
	@shellcheck $(SOURCES)

format:
	@shfmt -w $(SOURCES)

config:
	@$(PROJECT_ROOT)/config/generate.sh

test: config
	@bash tests/smoke.sh

run: config
	@$(PROJECT_ROOT)/cli/install.sh --dry-run

package: config
	@mkdir -p dist
	@tar czf dist/arch-installer.tar.gz cli core stages config docs README.md Makefile bin hooks tests
	@echo "Created dist/arch-installer.tar.gz"
