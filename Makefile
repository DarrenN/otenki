.PHONY: deps repl test build install clean

QL_SETUP := ~/quicklisp/setup.lisp
SBCL     := sbcl --noinform --non-interactive \
                 --load $(QL_SETUP) \
                 --load load-vendor.lisp \
                 --load otenki.asd

deps:
	git submodule update --init --recursive

repl:
	rlwrap sbcl --noinform \
	    --load $(QL_SETUP) \
	    --load load-vendor.lisp \
	    --load otenki.asd \
	    --eval '(ql:quickload :otenki)'

test:
	$(SBCL) \
		--eval '(ql:quickload :otenki/tests)' \
		--eval '(unless (otenki.tests:run-all-tests) (uiop:quit 1))'

build:
	mkdir -p bin
	$(SBCL) \
		--eval '(ql:quickload :otenki)' \
		--eval '(sb-ext:save-lisp-and-die "bin/otenki" :toplevel (quote otenki.main:main) :executable t :compression t)'

install: build
	cp bin/otenki ~/bin/otenki

clean:
	rm -rf bin/
