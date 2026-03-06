;;;; otenki.asd — system definition for otenki weather TUI

(asdf:defsystem #:otenki
  :description "A Common Lisp TUI for multi-location weather overview"
  :version "0.1.0"
  :license "MIT"
  :depends-on (#:tuition
               #:openweathermap
               #:jonathan
               #:alexandria
               #:uiop)
  :serial t
  :components ((:module "src"
                :components
                ((:file "package")
                 (:file "model")
                 (:file "config")
                 (:file "api")
                 (:file "view")
                 (:file "json")
                 (:file "app")
                 (:file "main"))))
  :in-order-to ((test-op (test-op #:otenki/tests))))

(asdf:defsystem #:otenki/tests
  :depends-on (#:otenki #:fiveam)
  :serial t
  :components ((:module "t"
                :components
                ((:file "tests"))))
  :perform (asdf:test-op (o c)
             (uiop:symbol-call :otenki.tests :run-all-tests)))
