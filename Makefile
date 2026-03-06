.PHONY: deps repl test build install clean

VENDOR_DIR := $(shell pwd)/vendor
CL_SOURCE_REGISTRY := $(VENDOR_DIR)//:$(VENDOR_DIR)/openweathermap//:$(VENDOR_DIR)/cl-tuition//
SBCL := CL_SOURCE_REGISTRY="$(CL_SOURCE_REGISTRY)" sbcl --noinform --non-interactive

deps:
	git submodule update --init --recursive

repl:
	CL_SOURCE_REGISTRY="$(CL_SOURCE_REGISTRY)" rlwrap sbcl --noinform --load otenki.asd \
		--eval '(asdf:load-system :otenki)'

test:
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki/tests)' \
		--eval '(unless (otenki.tests:run-all-tests) (uiop:quit 1))'

build:
	mkdir -p bin
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki)' \
		--eval '(sb-ext:save-lisp-and-die "bin/otenki" :toplevel #'"'"'otenki.main:main :executable t :compression t)'

install: build
	cp bin/otenki ~/bin/otenki

clean:
	rm -rf bin/
