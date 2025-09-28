# Copyright 2025 UmbraLogic Technologies LLC
#
# Adapted from Caravel User Project
#
# Copyright 2020-2024 Efabless Corporation
# SPDX-FileCopyrightText:
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

MAKEFLAGS += --warn-undefined-variables

# set shell to bash
SHELL := /bin/bash

ifeq ($(origin LIBRELANE_RUN_TAG), undefined)
export LIBRELANE_RUN_TAG := $(shell date '+%y_%m_%d_%H_%M')
endif
ifeq ($(origin CF_LIBRELANE_TAG), undefined)
export CF_LIBRELANE_TAG := CC2509c
endif

export CARAVEL_ROOT := $(CARAVEL_ROOT)
export PDK := $(PDK)
export PDK_ROOT := $(PDK_ROOT)

designs = $(shell cd $(PROJECT_ROOT)/openlane && find * -maxdepth 0 -type d)
current_design = null

LIBRELANE_USE_NIX ?= 0

librelane_args = \
	--run-tag $(LIBRELANE_RUN_TAG) \
	--manual-pdk \
	--pdk-root $(PDK_ROOT) \
	--pdk $(PDK)

docker_mounts = \
	-m $(PROJECT_ROOT) \
	-m $(PDK_ROOT) \
	-m $(CARAVEL_ROOT) \
	-m $(HOME)/.ipm

ifneq ($(MCW_ROOT),)
export MCW_ROOT:=$(MCW_ROOT)
docker_mounts += -m $(MCW_ROOT)
endif

ifeq ($(LIBRELANE_USE_NIX),1)
librelane_run = nix run github:chipfoundry/openlane-2/$(CF_LIBRELANE_TAG) --
else
librelane_docker_args = $(shell test -t 0 || echo "--docker-no-tty")
librelane_run = $(PROJECT_ROOT)/openlane/.venv/bin/python3 -m librelane $(docker_mounts) $(librelane_docker_args) --dockerized 
endif

list:
	@echo $(designs)

.PHONY: $(designs)
$(designs) : export current_design=$@
$(designs):
	@config_dir="$(PROJECT_ROOT)/openlane/$@"; \
	config=""; \
	for ext in yaml json tcl; do \
		if [ -f "$$config_dir/config.$$ext" ]; then \
			config="$$config_dir/config.$$ext"; break; \
		fi; \
	done; \
	if [ -n "$$config" ]; then \
		cmd='$(librelane_run) $(librelane_args) --ef-save-views-to $(PROJECT_ROOT) --overwrite "$$config"'; \
		echo "* Running LibreLane on $@ with $$config"; \
		echo $$cmd; \
		eval $$cmd; \
	fi

librelane: librelane-venv librelane-docker-image

.PHONY: librelane-docker-image
librelane-docker-image:
	@echo "LibreLane will automatically pull the appropriate Docker image as needed."

librelane-venv: $(PROJECT_ROOT)/openlane/.venv/manifest.txt
$(PROJECT_ROOT)/openlane/.venv/manifest.txt: $(PROJECT_ROOT)/openlane/.version-$(CF_LIBRELANE_TAG)
	rm -rf $(PROJECT_ROOT)/openlane/.venv
	python3 -m venv $(PROJECT_ROOT)/openlane/.venv
	PYTHONPATH= $(PROJECT_ROOT)/openlane/.venv/bin/python3 -m pip install --upgrade pip
	PYTHONPATH= $(PROJECT_ROOT)/openlane/.venv/bin/python3 -m pip install "https://github.com/chipfoundry/openlane-2/tarball/$(CF_LIBRELANE_TAG)"
	PYTHONPATH= $(PROJECT_ROOT)/openlane/.venv/bin/python3 -m pip freeze > $@
	
$(PROJECT_ROOT)/openlane/.version-$(CF_LIBRELANE_TAG):
	echo "$(CF_LIBRELANE_TAG)" > $@
	python3 -c 'import os; [os.remove(f) for f in os.listdir("$(@D)") if f.startswith(".version-") and f != os.path.basename("$@")]'

.PHONY: librelane-nix
librelane-nix:
	@if ! command -v nix > /dev/null; then\
		echo "Nix not found. Please install Nix using the LibreLane documentation:"; \
		echo "	https://librelane.readthedocs.io/en/latest/getting_started/common/nix_installation/index.html"; \
	else \
		echo "Activating LibreLane Nix environment…"; \
		nix develop github:chipfoundry/openlane-2/$(CF_LIBRELANE_TAG); \
	fi
