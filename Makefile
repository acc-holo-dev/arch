SHELL := /usr/bin/env bash
PROJECT_ROOT := $(shell pwd)
SOURCES := $(shell find bin lib modules -name '*.sh') config.sh

.PHONY: lint shellcheck run package

lint: shellcheck

shellcheck:
	@shellcheck $(SOURCES)

run:
	@$(PROJECT_ROOT)/bin/install.sh --dry-run

package:
	@mkdir -p dist
	@tar czf dist/arch-installer.tar.gz bin lib modules docs config.sh README.md Makefile .gitignore
	@echo "Created dist/arch-installer.tar.gz"
