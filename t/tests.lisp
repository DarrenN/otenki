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
  "Run all tests. Returns T if all passed (or none ran), NIL on failure."
  (let ((results (run! 'all-tests)))
    (cond
      ;; No tests were defined — FiveAM returns T
      ((eq results t) t)
      ;; Empty list — no tests ran
      ((null results) t)
      ;; Normal case — check each result
      (t (every #'fiveam::test-passed-p results)))))
