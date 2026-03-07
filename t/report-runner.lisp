;;;; report-runner.lisp — concise FiveAM test reporter
(in-package #:otenki.tests)

(defun run-tests-report ()
  "Run all tests with concise output: summary line + failure details only."
  (let* ((results (let ((5am:*test-dribble* nil))
                    (5am:run 'all-tests)))
         (passed (count-if (lambda (r)
                             (string= "TEST-PASSED"
                                      (symbol-name (type-of r))))
                           results))
         (failed (count-if (lambda (r)
                             (string= "TEST-FAILURE"
                                      (symbol-name (type-of r))))
                           results))
         (failures (remove-if-not (lambda (r)
                                    (string= "TEST-FAILURE"
                                             (symbol-name (type-of r))))
                                  results)))
    (format t "~&TOTAL: ~D passed, ~D failed~%" passed failed)
    (dolist (f failures)
      (format t "~&  FAIL: ~A~%" f)
      (5am:explain! f))
    (null failures)))
