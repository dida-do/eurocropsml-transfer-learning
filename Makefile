.PHONY: help requirements install format lint test coverage

ifndef VIRTUAL_ENV
ifdef CONDA_PREFIX
$(warning "For better compatibility, consider using a plain Python venv instead of Conda")
VIRTUAL_ENV := $(CONDA_PREFIX)
else
$(error "This Makefile needs to be run inside a virtual environment")
endif
endif

SHELL := /bin/bash
PLATFORM := $(shell \
  if [[ -n $$(command -v nvidia-smi && nvidia-smi --list-gpus) ]]; then echo gpu; \
  elif [[ $$(uname -s) == Darwin ]]; then echo osx; \
  else echo cpu; \
  fi)

PIP_COMPILE_ARGS ?=

help:
	@echo "Available commands:"
	@echo "requirements       compile all requirements."
	@echo "install            install dev requirements."
	@echo "format             format code."
	@echo "lint               run linters."
	@echo "test               run unit tests."
	@echo "coverage           build coverage report."

requirements:
	pip install -q --upgrade pip==24.2 wheel pip-tools
	pip-compile -q ${PIP_COMPILE_ARGS} requirements/requirements.in \
	  --extra-index-url https://download.pytorch.org/whl/cpu \
	  --output-file requirements/requirements-cpu.txt \
	  --strip-extras \
	  --resolver=backtracking
	pip-compile -q ${PIP_COMPILE_ARGS} requirements/requirements.in \
	  --extra-index-url https://download.pytorch.org/whl/cu117 \
	  --output-file requirements/requirements-gpu.txt \
	  --strip-extras \
	  --resolver=backtracking
	pip-compile -q ${PIP_COMPILE_ARGS} requirements/requirements.in \
	  --output-file requirements/requirements-osx.txt \
	  --strip-extras \
	  --resolver=backtracking
	pip-compile -q ${PIP_COMPILE_ARGS} requirements/requirements-ci.in \
	  --strip-extras \
	  --resolver=backtracking
	pip-compile -q ${PIP_COMPILE_ARGS} requirements/requirements-dev.in \
	  --strip-extras \
	  --resolver=backtracking

$(VIRTUAL_ENV)/timestamp: requirements/*.txt
	@echo "Installing Python dependencies..."
	python -m pip install -q --upgrade pip==24.2 wheel pip-tools
ifdef GITHUB_ACTIONS
	pip-sync -q \
	  requirements/requirements-cpu.txt \
	  requirements/requirements-ci.txt
else
	pip-sync -q \
	  requirements/requirements-${PLATFORM}.txt \
	  requirements/requirements-ci.txt \
	  requirements/requirements-dev.txt
endif
ifneq ($(wildcard requirements/requirements-extra.txt),)
	pip install -q -r requirements/requirements-extra.txt
endif
	pip install -q -e .
	@touch $(VIRTUAL_ENV)/timestamp

install: $(VIRTUAL_ENV)/timestamp

format: install
	ruff check --select I --fix eurocropsmeta tests
	ruff format eurocropsmeta tests

lint: install
	ruff check eurocropsmeta tests
	mypy eurocropsmeta tests

test: install
	pytest -v

coverage: install
	coverage run --source eurocropsmeta -m pytest -v
	coverage combine
	coverage report
