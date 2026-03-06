;;;; tests.lisp — FiveAM test suites for otenki

(defpackage #:otenki.tests
  (:use #:cl)
  (:import-from #:fiveam
                #:def-suite
                #:run!)
  (:export #:run-all-tests))

(in-package #:otenki.tests)

(def-suite all-tests :description "All otenki tests")

(defun run-all-tests ()
  (run! 'all-tests))
