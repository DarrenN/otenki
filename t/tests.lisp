;;;; tests.lisp — FiveAM test suites for otenki

(defpackage #:otenki.tests
  (:use #:cl)
  (:import-from #:fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:run!)
  (:export #:run-all-tests))

(in-package #:otenki.tests)

(def-suite all-tests :description "All otenki tests")

(defun run-all-tests ()
  "Run all tests. Returns T if all passed (or none ran), NIL on failure."
  (let ((results (run! 'all-tests)))
    (not (null results))))

;;;; --- Model Tests ---

(def-suite model-tests :description "Model tests" :in all-tests)
(in-suite model-tests)

;;; Unit conversion tests

(test kelvin-to-celsius
  "Convert Kelvin to Celsius"
  (is (< (abs (- (otenki.model:kelvin-to-celsius 273.15) 0.0)) 0.01))
  (is (< (abs (- (otenki.model:kelvin-to-celsius 373.15) 100.0)) 0.01))
  (is (< (abs (- (otenki.model:kelvin-to-celsius 0.0) -273.15)) 0.01)))

(test kelvin-to-fahrenheit
  "Convert Kelvin to Fahrenheit"
  (is (< (abs (- (otenki.model:kelvin-to-fahrenheit 273.15) 32.0)) 0.01))
  (is (< (abs (- (otenki.model:kelvin-to-fahrenheit 373.15) 212.0)) 0.01)))

(test format-temp-metric
  "Format temperature for metric display"
  (is (string= (otenki.model:format-temp 295.15 :metric) "22°C")))

(test format-temp-imperial
  "Format temperature for imperial display"
  (is (string= (otenki.model:format-temp 295.15 :imperial) "72°F")))

(test format-wind-speed-metric
  "Format wind speed for metric display"
  (is (string= (otenki.model:format-wind-speed 3.2 :metric) "3.2 m/s")))

(test format-wind-speed-imperial
  "Format wind speed for imperial display"
  (is (string= (otenki.model:format-wind-speed 3.2 :imperial) "7.2 mph")))

;;; Struct creation tests

(test make-weather-card-basic
  "Create a weather-card struct"
  (let ((card (otenki.model:make-weather-card
               :location-name "Tokyo"
               :latitude 35.6762
               :longitude 139.6503
               :current-temp 295.15
               :feels-like 293.15
               :humidity 65
               :wind-speed 3.2
               :wind-direction 180
               :condition-id 800
               :condition-text "Clear sky"
               :hourly-forecast nil)))
    (is (string= (otenki.model:weather-card-location-name card) "Tokyo"))
    (is (= (otenki.model:weather-card-humidity card) 65))
    (is (null (otenki.model:weather-card-error-message card)))))

(test make-hourly-entry-basic
  "Create an hourly-entry struct"
  (let ((entry (otenki.model:make-hourly-entry
                :hour 14
                :temp 296.0
                :condition-id 801
                :pop 0.2)))
    (is (= (otenki.model:hourly-entry-hour entry) 14))
    (is (= (otenki.model:hourly-entry-pop entry) 0.2))))

;;;; --- Config Tests ---

(def-suite config-tests :description "Config tests" :in all-tests)
(in-suite config-tests)

(test default-config
  "Default config values"
  (let ((cfg (otenki.config:make-app-config)))
    (is (eql (otenki.config:app-config-units cfg) :metric))
    (is (= (otenki.config:app-config-refresh-interval cfg) 600))
    (is (null (otenki.config:app-config-locations cfg)))
    (is (not (otenki.config:app-config-json-mode-p cfg)))))

(test parse-config-plist
  "Parse a config plist"
  (let ((cfg (otenki.config:parse-config-plist
              '(:units :imperial :refresh-interval 300
                :locations ("Tokyo" "London")))))
    (is (eql (otenki.config:app-config-units cfg) :imperial))
    (is (= (otenki.config:app-config-refresh-interval cfg) 300))
    (is (equal (otenki.config:app-config-locations cfg)
               '("Tokyo" "London")))))

(test parse-cli-args-locations
  "CLI args with location names yield config and :locations in explicit-fields"
  (multiple-value-bind (cfg explicit-fields)
      (otenki.config:parse-cli-args '("Tokyo" "London"))
    (is (equal (otenki.config:app-config-locations cfg) '("Tokyo" "London")))
    (is (not (otenki.config:app-config-json-mode-p cfg)))
    (is (member :locations explicit-fields))))

(test parse-cli-args-json-flag
  "CLI args with --json flag sets json-mode-p and records :json-mode-p"
  (multiple-value-bind (cfg explicit-fields)
      (otenki.config:parse-cli-args '("--json" "Tokyo"))
    (is (otenki.config:app-config-json-mode-p cfg))
    (is (equal (otenki.config:app-config-locations cfg) '("Tokyo")))
    (is (member :json-mode-p explicit-fields))))

(test parse-cli-args-units-flag
  "CLI args with --units flag records value and :units in explicit-fields"
  (multiple-value-bind (cfg explicit-fields)
      (otenki.config:parse-cli-args '("--units" "imperial"))
    (is (eql (otenki.config:app-config-units cfg) :imperial))
    (is (member :units explicit-fields))))

(test parse-cli-args-units-missing-arg
  "Missing argument after --units signals an error"
  (fiveam:signals error
    (otenki.config:parse-cli-args '("--units"))))

(test parse-cli-args-units-invalid-value
  "Invalid --units value signals an error"
  (fiveam:signals error
    (otenki.config:parse-cli-args '("--units" "kelvin"))))

(test merge-configs-explicit-overrides-file
  "merge-configs: explicit CLI fields override file config"
  (let ((file-cfg (otenki.config:make-app-config
                   :units :metric
                   :locations '("Paris")))
        (cli-cfg (otenki.config:make-app-config
                  :units :imperial
                  :locations '("Tokyo"))))
    (let ((merged (otenki.config:merge-configs
                   file-cfg cli-cfg '(:units :locations))))
      (is (eql (otenki.config:app-config-units merged) :imperial))
      (is (equal (otenki.config:app-config-locations merged) '("Tokyo"))))))

(test merge-configs-no-explicit-keeps-file
  "merge-configs: without explicit-fields, file config values are kept"
  (let ((file-cfg (otenki.config:make-app-config
                   :units :imperial
                   :refresh-interval 300
                   :locations '("Paris")))
        (cli-cfg (otenki.config:make-app-config)))
    (let ((merged (otenki.config:merge-configs file-cfg cli-cfg)))
      (is (eql (otenki.config:app-config-units merged) :imperial))
      (is (= (otenki.config:app-config-refresh-interval merged) 300))
      (is (equal (otenki.config:app-config-locations merged) '("Paris"))))))

(test merge-configs-json-mode-is-ored
  "merge-configs: json-mode-p is OR'd from both sources"
  (let ((file-cfg (otenki.config:make-app-config :json-mode-p t))
        (cli-cfg (otenki.config:make-app-config)))
    (let ((merged (otenki.config:merge-configs file-cfg cli-cfg)))
      (is (otenki.config:app-config-json-mode-p merged)))))
