# Makefile for Nordic NCS / Zephyr project

SHELL := /usr/bin/env bash
.SHELLFLAGS := -eu -o pipefail -c

NCS_TC ?= /opt/nordic/ncs/toolchains/ef4fc6722e
ZEPHYR_SDK       ?= $(NCS_TC)/opt/zephyr-sdk
SDK_BIN          := $(ZEPHYR_SDK)/arm-zephyr-eabi/bin

APP_DIR          ?= $(CURDIR)/app
BOARD_ROOT       ?= $(CURDIR)/nfed
BOARD            ?= circuitdojo_feather_nrf9151/nrf9151/ns
MERGED_HEX       ?= $(CURDIR)/build/merged.hex

# NOTE: No trailing semicolon on the last line to avoid ';;' on expansion.
define EXPORT_ENV
  unset CFLAGS CXXFLAGS LDFLAGS CPPFLAGS PKG_CONFIG_PATH SDKROOT \
        ZEPHYR_TOOLCHAIN_VARIANT ZEPHYR_SDK_INSTALL_DIR GNUARMEMB_TOOLCHAIN_PATH; \
  export PATH="$(NCS_TC)/bin:$(SDK_BIN):$$PATH"; \
  export ZEPHYR_TOOLCHAIN_VARIANT=zephyr; \
  export ZEPHYR_SDK_INSTALL_DIR="$(ZEPHYR_SDK)"; \
  export BOARD_ROOT="$(BOARD_ROOT)"
endef

.PHONY: all help init build flash clean env
all: build

help:
	@echo "Targets:"
	@echo "  make init   - Setup NCS/Zephyr (west update/export, pip deps)"
	@echo "  make build  - Clean caches and build (sysbuild) for $(BOARD)"
	@echo "  make flash  - Flash $(MERGED_HEX) via probe-rs and reset"
	@echo "  make clean  - Remove build and Zephyr caches"
	@echo "  make env    - Print resolved tool paths/versions"

init:
	@export NCS_TOOLCHAIN_BIN="$(NCS_TC)/bin"; \
	export PATH="$$NCS_TOOLCHAIN_BIN:$$PATH"; \
	$$NCS_TOOLCHAIN_BIN/west update; \
	$$NCS_TOOLCHAIN_BIN/west zephyr-export; \
	$$NCS_TOOLCHAIN_BIN/west packages pip --install

build:
	@$(EXPORT_ENV); \
	echo "cmake: $$(command -v cmake)"; cmake --version | head -n1; \
	echo "gcc  : $$(command -v arm-zephyr-eabi-gcc)"; arm-zephyr-eabi-gcc --version | head -n1; \
	west --version; \
	rm -rf "$$HOME/Library/Caches/zephyr" "$$HOME/.cache/zephyr" "$(APP_DIR)/build"; \
	west update; \
	west zephyr-export; \
	west build -p always \
	  -b "$(BOARD)" \
	  --sysbuild "$(APP_DIR)" \
	  -- -DBOARD_ROOT="$(BOARD_ROOT)"

flash: $(MERGED_HEX)
	@probe-rs download --chip nRF9151_xxAA --binary-format hex "$(MERGED_HEX)"
	@probe-rs reset --chip nRF9151_xxAA

$(MERGED_HEX):
	@echo "ERROR: '$(MERGED_HEX)' not found. Run 'make build' first." >&2
	@exit 1

clean:
	@rm -rf "$(CURDIR)/build" "$(APP_DIR)/build" \
	  "$$HOME/Library/Caches/zephyr" "$$HOME/.cache/zephyr"

env:
	@$(EXPORT_ENV); \
	echo "Using:"; \
	echo "  NCS_TC      = $(NCS_TC)"; \
	echo "  ZEPHYR_SDK  = $(ZEPHYR_SDK)"; \
	echo "  SDK_BIN     = $(SDK_BIN)"; \
	echo "  APP_DIR     = $(APP_DIR)"; \
	echo "  BOARD_ROOT  = $(BOARD_ROOT)"; \
	echo "  BOARD       = $(BOARD)"; \
	echo "  MERGED_HEX  = $(MERGED_HEX)"; \
	echo "Tools:"; \
	echo "  west        = $$(command -v west || echo 'not found')"; \
	echo "  cmake       = $$(command -v cmake || echo 'not found')"; \
	echo "  arm-gcc     = $$(command -v arm-zephyr-eabi-gcc || echo 'not found')"; \
	echo "  probe-rs    = $$(command -v probe-rs || echo 'not found')"