;;;; report-runner.lisp — concise FiveAM test reporter
(in-package #:otenki.tests)

(defun run-tests-report ()
  "Run all tests with concise output: summary line + failure details only."
  (let* ((results (let ((5am:*test-dribble* nil))
                    (5am:run 'all-tests)))
         (passed (count-if (lambda (r) (typep r 'fiveam::test-passed)) results))
         (failed (count-if (lambda (r) (typep r 'fiveam::test-failure)) results))
         (failures (remove-if-not (lambda (r) (typep r 'fiveam::test-failure))
                                  results)))
    (format t "~&TOTAL: ~D passed, ~D failed~%" passed failed)
    (dolist (f failures)
      (format t "~&  FAIL: ~A~%" f)
      (5am:explain! (list f)))
    (null failures)))
