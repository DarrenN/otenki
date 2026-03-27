.PHONY: repl test test-verbose build install clean config help

CL_SOURCE_REGISTRY := $(shell pwd)//
SBCL := CL_SOURCE_REGISTRY="$(CL_SOURCE_REGISTRY)" sbcl --noinform --non-interactive

repl: ## Start a REPL with otenki loaded
	CL_SOURCE_REGISTRY="$(CL_SOURCE_REGISTRY)" rlwrap sbcl --noinform --load otenki.asd \
		--eval '(asdf:load-system :otenki)'

test: ## Run the test suite (concise output)
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki/tests)' \
		--eval '(unless (otenki.tests:run-tests-report) (uiop:quit 1))'

test-verbose: ## Run the test suite (full FiveAM output)
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki/tests)' \
		--eval '(unless (otenki.tests:run-all-tests) (uiop:quit 1))'

build: ## Build standalone executable to bin/otenki
	mkdir -p bin
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki)' \
		--eval '(sb-ext:save-lisp-and-die "bin/otenki" :toplevel #'"'"'otenki.main:main :executable t :compression t)'

install: build ## Build and install to ~/bin/otenki
	cp bin/otenki ~/bin/otenki

CONFIG_DIR  := $(HOME)/.config/otenki
CONFIG_FILE := $(CONFIG_DIR)/config.lisp

config: ## Create a fresh config file at ~/.config/otenki/config.lisp
	@mkdir -p $(CONFIG_DIR)
	@if [ -f $(CONFIG_FILE) ]; then \
		echo "Config already exists: $(CONFIG_FILE)"; \
		echo "Remove it first if you want a fresh one."; \
		exit 1; \
	fi
	@printf '(:units :metric\n :refresh-interval 600\n :locations ("Tokyo"))\n' > $(CONFIG_FILE)
	@echo "Created $(CONFIG_FILE)"

clean: ## Remove build artifacts
	rm -f bin/otenki

help: ## Show available targets
	@printf '\nUsage: make <target>\n\n'
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk -F ':.*?## ' '{printf "  %-15s %s\n", $$1, $$2}'
	@echo
