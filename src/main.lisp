;;;; main.lisp — entry point and CLI dispatch
(in-package #:otenki.main)

(defun print-usage ()
  "Print usage information to standard output."
  (format t "otenki — weather at a glance~%~%")
  (format t "Usage:~%")
  (format t "  otenki                     Launch TUI with config locations~%")
  (format t "  otenki Tokyo London        Show weather for specific locations~%")
  (format t "  otenki --json              JSON output for config locations~%")
  (format t "  otenki --json Tokyo        JSON output for specific locations~%")
  (format t "  otenki --units imperial    Override display units~%")
  (format t "  otenki -h                  Show this help~%~%")
  (format t "Configuration:~%")
  (format t "  File: ~~/.config/otenki/config.lisp~%")
  (format t "  API key: OPENWEATHER_API_KEY environment variable~%"))

(defun run-json-mode (config)
  "Fetch weather for all locations in CONFIG and print as JSON to standard output."
  (let ((locations (otenki.config:app-config-locations config)))
    (unless locations
      (format *error-output* "No locations specified.~%")
      (uiop:quit 1))
    (let ((cards (mapcar #'fetch-weather-for-location locations)))
      (format t "~A~%" (cards-to-json cards))
      (finish-output))))

(defun main ()
  "Entry point for the otenki executable.

Parses command-line arguments, resolves configuration, and dispatches to
either JSON output mode or the interactive TUI."
  (let ((args (uiop:command-line-arguments)))
    ;; Handle help flags before anything else.
    ;; Note: --help is intercepted by SBCL runtime, so we use -h.
    (when (or (member "-h" args :test #'string=)
              (member "help" args :test #'string=))
      (print-usage)
      (uiop:quit 0))
    ;; Ensure the API key is present before doing any network work.
    (handler-case
        (otenki.config:ensure-api-key)
      (error (e)
        (format *error-output* "~A~%" e)
        (uiop:quit 1)))
    ;; Merge file config with CLI args to get the resolved config.
    (let ((config (otenki.config:resolve-config args)))
      (if (app-config-json-mode-p config)
          ;; --json mode: fetch and print, then exit.
          (handler-case
              (run-json-mode config)
            (error (e)
              (format *error-output* "Error: ~A~%" e)
              (uiop:quit 1)))
          ;; Interactive TUI mode: require at least one location.
          (if (otenki.config:app-config-locations config)
              (run-tui config)
              (progn
                (format t "No locations configured.~%~%")
                (print-usage)
                (uiop:quit 1)))))))
