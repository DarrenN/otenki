;;;; tests.lisp — FiveAM test suites for otenki

(defpackage #:otenki.tests
  (:use #:cl)
  (:import-from #:fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:run!)
  (:local-nicknames (#:jojo #:jonathan))
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

;;;; --- API Tests ---

(def-suite api-tests :description "API response parsing tests" :in all-tests)
(in-suite api-tests)

(defun normalize-json-keys (value)
  "Normalize JSON keys to uppercase keywords to match openweathermap library output."
  (typecase value
    (cons
     ;; Check if it looks like a plist (keyword in car position)
     (if (keywordp (car value))
         ;; Plist: upcase keys, recurse values
         (loop for (k v) on value by #'cddr
               collect (intern (string-upcase (symbol-name k)) :keyword)
               collect (normalize-json-keys v))
         ;; Regular list: recurse each element
         (mapcar #'normalize-json-keys value)))
    (t value)))

(defun load-fixture (name)
  "Load a JSON fixture file and parse it.
Normalizes keys to uppercase keywords to match openweathermap library output."
  (let ((path (asdf:system-relative-pathname :otenki/tests
                                              (format nil "t/fixtures/~A" name))))
    (normalize-json-keys (jojo:parse (uiop:read-file-string path)))))

(test parse-geocoding-response
  "Parse geocoding API response into lat/lon"
  (let* ((data (load-fixture "geocoding.json"))
         (result (otenki.api:parse-geocoding-response data)))
    (is (not (null result)))
    (is (< (abs (- (getf result :lat) 35.6762)) 0.001))
    (is (< (abs (- (getf result :lon) 139.6503)) 0.001))
    (is (string= (getf result :name) "Tokyo"))))

(test parse-onecall-response
  "Parse onecall API response into a weather-card"
  (let* ((data (load-fixture "onecall.json"))
         (card (otenki.api:parse-onecall-response data "Tokyo")))
    (is (string= (otenki.model:weather-card-location-name card) "Tokyo"))
    (is (< (abs (- (otenki.model:weather-card-current-temp card) 295.15)) 0.01))
    (is (= (otenki.model:weather-card-humidity card) 65))
    (is (< (abs (- (otenki.model:weather-card-wind-speed card) 3.2)) 0.01))
    (is (= (otenki.model:weather-card-condition-id card) 800))
    (is (string= (otenki.model:weather-card-condition-text card) "clear sky"))
    ;; Check hourly forecast
    (let ((hourly (otenki.model:weather-card-hourly-forecast card)))
      (is (= (length hourly) 3))
      (is (< (abs (- (otenki.model:hourly-entry-temp (first hourly)) 295.15)) 0.01)))))

(test parse-geocoding-empty-response
  "Parse empty geocoding response"
  (let ((result (otenki.api:parse-geocoding-response nil)))
    (is (null result))))

;;;; --- View Tests ---

(def-suite view-tests :description "View rendering tests" :in all-tests)
(in-suite view-tests)

(defun make-test-card ()
  "Create a weather card for testing."
  (otenki.model:make-weather-card
   :location-name "Tokyo"
   :latitude 35.6762
   :longitude 139.6503
   :current-temp 295.15
   :feels-like 293.15
   :humidity 65
   :wind-speed 3.2
   :wind-direction 180
   :condition-id 800
   :condition-text "clear sky"
   :hourly-forecast (list
                     (otenki.model:make-hourly-entry :hour 12 :temp 295.15 :condition-id 800 :pop 0.0)
                     (otenki.model:make-hourly-entry :hour 13 :temp 296.0 :condition-id 801 :pop 0.1)
                     (otenki.model:make-hourly-entry :hour 14 :temp 294.5 :condition-id 802 :pop 0.2))))

(test render-weather-card-contains-location
  "Rendered card contains location name"
  (let ((output (otenki.view:render-weather-card (make-test-card) :metric)))
    (is (search "Tokyo" output))))

(test render-weather-card-contains-temp
  "Rendered card contains temperature"
  (let ((output (otenki.view:render-weather-card (make-test-card) :metric)))
    (is (search "22" output))))

(test render-weather-card-contains-humidity
  "Rendered card contains humidity"
  (let ((output (otenki.view:render-weather-card (make-test-card) :metric)))
    (is (search "65%" output))))

(test render-weather-card-error
  "Rendered error card shows error message"
  (let* ((card (otenki.model:make-weather-card
                :location-name "Nowhere"
                :error-message "Location not found"))
         (output (otenki.view:render-weather-card card :metric)))
    (is (search "Location not found" output))))

(test render-card-grid-multiple
  "Grid renders multiple cards"
  (let ((output (otenki.view:render-card-grid
                 (list (make-test-card) (make-test-card))
                 :metric 80)))
    (is (search "Tokyo" output))))

;;;; --- JSON Tests ---

(def-suite json-tests :description "JSON output tests" :in all-tests)
(in-suite json-tests)

(test weather-card-to-plist
  "Convert weather-card to a serializable plist"
  (let* ((card (make-test-card))
         (plist (otenki.json:weather-card-to-plist card)))
    (is (string= (getf plist :|location|) "Tokyo"))
    (is (< (abs (- (getf plist :|latitude|) 35.6762)) 0.001))
    (is (= (getf plist :|humidity|) 65))
    (is (listp (getf plist :|hourly_forecast|)))))

(test cards-to-json-valid
  "cards-to-json produces valid JSON string"
  (let* ((card (make-test-card))
         (json-str (otenki.json:cards-to-json (list card))))
    (is (stringp json-str))
    ;; Should start with [ since it's an array
    (is (char= (char (string-left-trim '(#\Space #\Newline) json-str) 0) #\[))))
