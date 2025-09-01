SHELL := /bin/bash
.ONESHELL:

# Package manager selection - can be 'conda' or 'uv'
PACKAGE_MANAGER ?= uv
VENV_NAME ?= ilab
ISAACSIM_SETUP := $$HOME/IsaacLab/_isaac_sim/setup_conda_env.sh
PYTHON_PATH := $$HOME/IsaacLab/_isaac_sim/kit/python/bin/python3

.PHONY: all deps gitman clean setup setup-conda setup-uv clean-conda clean-uv setup-aliases

all: deps gitman clean setup setup-aliases

deps:
	sudo apt-get update && sudo apt-get upgrade -y
	sudo apt-get install -y cmake build-essential
	sudo apt autoremove -y
	@if ! command -v gcc >/dev/null 2>&1 || [ $$(gcc -dumpversion | cut -d. -f1) -lt 11 ]; then \
		sudo apt-get install -y gcc-11 g++-11; \
		sudo update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-11 200; \
		sudo update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-11 200; \
	fi
	@if ! command -v uv >/dev/null 2>&1; then \
		curl -LsSf https://astral.sh/uv/install.sh | sh; \
	fi
	@export PATH="$$HOME/.local/bin:$$PATH"
	@if ! command -v gitman >/dev/null 2>&1; then \
		$$HOME/.local/bin/uv tool install --with regex==2025.7.34 gitman@latest; \
	fi

gitman:
	@cp _gitman.yml $$HOME/.gitman.yml && \
	cd $$HOME && \
	if ! echo "$$PATH" | grep -q "$$HOME/.local/bin"; then \
		PATH="$$HOME/.local/bin:$$PATH" GITMAN_CONFIG=.gitman.yml gitman update; \
	else \
		GITMAN_CONFIG=.gitman.yml gitman update; \
	fi

clean: clean-$(PACKAGE_MANAGER)
	@rm -f $$HOME/.gitman.yml

clean-conda:
	export CONDA_NO_PLUGINS=true; \
	source $$HOME/miniconda3/etc/profile.d/conda.sh; \
	if [ "$$CONDA_DEFAULT_ENV" = "$(VENV_NAME)" ]; then \
		conda deactivate; \
	fi; \
	if conda info --envs | grep -qE '^\s*$(VENV_NAME)\s'; then \
		conda remove -y --name $(VENV_NAME) --all; \
	fi; \

clean-uv:
	@if [ -d "$$HOME/IsaacLab/$(VENV_NAME)" ]; then \
		rm -rf $$HOME/IsaacLab/$(VENV_NAME); \
	fi

setup: setup-$(PACKAGE_MANAGER)

setup-conda:
	export CONDA_NO_PLUGINS=true; \
	source $$HOME/miniconda3/etc/profile.d/conda.sh; \
	cd $$HOME/IsaacLab && ./isaaclab.sh -c $(VENV_NAME); \
	conda run -n $(VENV_NAME) ./isaaclab.sh -i rsl_rl; \

setup-uv:
	@mkdir -p $$HOME/IsaacLab
	@export PATH="$$HOME/.local/bin:$$PATH" && \
	uv venv --clear --python $(PYTHON_PATH) $$HOME/IsaacLab/$(VENV_NAME)
	cat >> $$HOME/IsaacLab/$(VENV_NAME)/bin/activate <<-'EOF'
	if [[ "$${BASH_SOURCE[0]}" == /* ]]; then
	    ACTIVATE_SCRIPT_PATH="$${BASH_SOURCE[0]}"
	else
	    ACTIVATE_SCRIPT_PATH="$$(pwd)/$${BASH_SOURCE[0]}"
	fi
	ACTIVATE_SCRIPT_DIR="$$(dirname "$$(readlink -f "$$ACTIVATE_SCRIPT_PATH")")"
	ISAACLAB_ROOT="$$ACTIVATE_SCRIPT_DIR/../.."
	ISAACLAB_ROOT="$$(readlink -f "$$ISAACLAB_ROOT")"
	. "$$ISAACLAB_ROOT/_isaac_sim/setup_conda_env.sh"
	export ISAACLAB_PATH="$$ISAACLAB_ROOT"
	export CONDA_PREFIX="$$VIRTUAL_ENV"
	EOF
	cat > $$HOME/IsaacLab/$(VENV_NAME)/bin/isaaclab <<-'EOF'
	#!/usr/bin/env bash
	set -e
	if [[ "$$0" == /* ]]; then
	    SCRIPT_PATH="$$0"
	else
	    SCRIPT_PATH="$$(pwd)/$$0"
	fi
	SCRIPT_DIR="$$(dirname "$$(readlink -f "$$SCRIPT_PATH")")"
	ISAACLAB_SCRIPT="$$SCRIPT_DIR/../../isaaclab.sh"
	ISAACLAB_SCRIPT="$$(readlink -f "$$ISAACLAB_SCRIPT")"
	exec "$$ISAACLAB_SCRIPT" "$$@"
	EOF
	chmod +x $$HOME/IsaacLab/$(VENV_NAME)/bin/isaaclab
	source $$HOME/IsaacLab/$(VENV_NAME)/bin/activate \
	&& hash -r \
	&& export CONDA_PREFIX="$$VIRTUAL_ENV" \
	&& uv pip install --upgrade pip \
	&& python -m pip install --upgrade pip \
	&& isaaclab -i rsl_rl

conda:
	$(MAKE) PACKAGE_MANAGER=conda all

uv:
	$(MAKE) PACKAGE_MANAGER=uv all

setup-aliases:
	@echo "Setting up Isaac Sim aliases..."
	@if [ ! -f "$$HOME/.bashrc" ]; then \
		touch "$$HOME/.bashrc"; \
	fi
	@if [ ! -f "$$HOME/.bashrc.isaac.bak" ]; then \
		cp "$$HOME/.bashrc" "$$HOME/.bashrc.isaac.bak"; \
	fi
	@if ! grep -q "# Isaac Sim Aliases - Managed by isaac_manager" "$$HOME/.bashrc"; then \
		echo "" >> "$$HOME/.bashrc"; \
		echo "# Isaac Sim Aliases - Managed by isaac_manager" >> "$$HOME/.bashrc"; \
		echo "if [ -f \"$$HOME/isaacsim/_build/linux-x86_64/release/python.sh\" ]; then" >> "$$HOME/.bashrc"; \
		echo "    alias python=\"$$HOME/isaacsim/_build/linux-x86_64/release/python.sh\"" >> "$$HOME/.bashrc"; \
		echo "    alias ISAACSIM=\"$$HOME/isaacsim/_build/linux-x86_64/release/isaac-sim.sh\"" >> "$$HOME/.bashrc"; \
		echo "    alias ISAACSIM_PYTHON=\"$$HOME/isaacsim/_build/linux-x86_64/release/python.sh\"" >> "$$HOME/.bashrc"; \
		echo "fi" >> "$$HOME/.bashrc"; \
		echo "Aliases added and activating them now..."; \
		SHELL_NAME=$$(basename $$SHELL); \
		if [ "$$SHELL_NAME" = "bash" ]; then \
			source "$$HOME/.bashrc"; \
		fi \
	else \
		echo "Isaac Sim aliases already configured in .bashrc"; \
		SHELL_NAME=$$(basename $$SHELL); \
		if [ "$$SHELL_NAME" = "bash" ]; then \
			source "$$HOME/.bashrc"; \
		fi \
	fi
