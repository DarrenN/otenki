;;;; load-vendor.lisp — register vendor ASDF systems before loading otenki
;;;; Loaded by Makefile targets before otenki.asd so that tuition and
;;;; openweathermap are found from the vendor/ submodules rather than
;;;; whatever version Quicklisp might have cached.

(let ((vendor (merge-pathnames "vendor/" (truename *load-truename*))))
  (dolist (sub (directory (merge-pathnames "*/" vendor)))
    (pushnew sub asdf:*central-registry* :test #'equal)))
