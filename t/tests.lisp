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
    (cond
      ;; No tests were defined — FiveAM returns T
      ((eq results t) t)
      ;; Empty list — no tests ran
      ((null results) t)
      ;; Normal case — check each result
      (t (every #'fiveam::test-passed-p results)))))

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
