;;;; tests.lisp — FiveAM test suites for otenki

(defpackage #:otenki.tests
  (:use #:cl)
  (:import-from #:fiveam
                #:def-suite
                #:in-suite
                #:test
                #:is
                #:run!)
  (:local-nicknames (#:jzon #:com.inuoe.jzon)
                    (#:tui #:tuition))
  (:export #:run-all-tests
           #:run-tests-report))

(in-package #:otenki.tests)

(def-suite all-tests :description "All otenki tests")

(defun run-all-tests ()
  "Run all tests with full FiveAM output. Returns T if all passed, NIL if any failed."
  (run! 'all-tests))

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

(test make-daily-entry-basic
  "Create a daily-entry struct"
  (let ((entry (otenki.model:make-daily-entry
                :day-name "Mon"
                :temp-min 281.15
                :temp-max 291.15
                :condition-id 800)))
    (is (string= (otenki.model:daily-entry-day-name entry) "Mon"))
    (is (< (abs (- (otenki.model:daily-entry-temp-min entry) 281.15)) 0.01))
    (is (< (abs (- (otenki.model:daily-entry-temp-max entry) 291.15)) 0.01))
    (is (= (otenki.model:daily-entry-condition-id entry) 800))))

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

(defun load-fixture (name)
  "Load a JSON fixture file and parse it with jzon.
Returns string-keyed hash tables matching openweathermap v0.2.0 output."
  (let ((path (asdf:system-relative-pathname :otenki/tests
                                              (format nil "t/fixtures/~A" name))))
    (jzon:parse (uiop:read-file-string path))))

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

(test parse-onecall-response-daily
  "parse-onecall-response includes daily forecast entries"
  (let* ((data (load-fixture "onecall.json"))
         (card (otenki.api:parse-onecall-response data "Tokyo")))
    (let ((daily (otenki.model:weather-card-daily-forecast card)))
      (is (= (length daily) 3))
      (is (string= (otenki.model:daily-entry-day-name (first daily)) "Wed"))
      (is (< (abs (- (otenki.model:daily-entry-temp-max (first daily)) 291.15)) 0.01))
      (is (string= (otenki.model:daily-entry-day-name (third daily)) "Fri")))))

(test unix-to-day-name-wednesday
  "unix-to-day-name returns Wed for 2024-03-06 at JST"
  (is (string= (otenki.api:unix-to-day-name 1709700000 32400) "Wed")))

(test unix-to-day-name-thursday
  "unix-to-day-name returns Thu for 2024-03-07 at JST"
  (is (string= (otenki.api:unix-to-day-name 1709786400 32400) "Thu")))

(test unix-to-day-name-utc
  "unix-to-day-name with zero offset"
  ;; 1709700000 = 2024-03-06 06:00 UTC = Wednesday
  (is (string= (otenki.api:unix-to-day-name 1709700000 0) "Wed")))

(test unix-to-day-name-negative-offset
  "unix-to-day-name with negative timezone offset (US Eastern = -18000)"
  ;; 1709700000 = 2024-03-06 04:40 UTC, minus 5h = 2024-03-05 23:40 = Tuesday
  (is (string= (otenki.api:unix-to-day-name 1709700000 -18000) "Tue")))

(test unix-to-day-name-day-boundary
  "unix-to-day-name respects day boundary with timezone offset"
  ;; 1709683200 = 2024-03-06 00:00 UTC = Tuesday in UTC-5 (2024-03-05 19:00)
  (is (string= (otenki.api:unix-to-day-name 1709683200 -18000) "Tue")))

(test parse-daily-entry-basic
  "parse-daily-entry extracts day-name, temps, and condition from fixture data"
  (let* ((data (load-fixture "onecall.json"))
         (daily-vec (gethash "daily" data))
         (tz-offset (gethash "timezone_offset" data))
         (entry (otenki.api::parse-daily-entry (aref daily-vec 0) tz-offset)))
    (is (string= (otenki.model:daily-entry-day-name entry) "Wed"))
    (is (< (abs (- (otenki.model:daily-entry-temp-min entry) 281.15)) 0.01))
    (is (< (abs (- (otenki.model:daily-entry-temp-max entry) 291.15)) 0.01))
    (is (= (otenki.model:daily-entry-condition-id entry) 800))))

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
                     (otenki.model:make-hourly-entry :hour 14 :temp 294.5 :condition-id 802 :pop 0.2))
   :daily-forecast (list
                    (otenki.model:make-daily-entry :day-name "Wed" :temp-min 281.15
                                                   :temp-max 291.15 :condition-id 800)
                    (otenki.model:make-daily-entry :day-name "Thu" :temp-min 279.15
                                                   :temp-max 289.15 :condition-id 801))))

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

(test render-daily-row-basic
  "render-daily-row produces output with day names and temps"
  (let* ((entries (list
                   (otenki.model:make-daily-entry :day-name "Wed" :temp-min 281.15
                                                  :temp-max 291.15 :condition-id 800)
                   (otenki.model:make-daily-entry :day-name "Thu" :temp-min 279.15
                                                  :temp-max 289.15 :condition-id 801)))
         (output (otenki.view::render-daily-row entries :metric)))
    (is (stringp output))
    (is (search "Wed" output))
    (is (search "Thu" output))
    ;; 291.15K → 18°C, 281.15K → 8°C
    (is (search "18" output))
    (is (search "8" output))))

(test render-daily-row-nil-on-empty
  "render-daily-row returns NIL for empty list"
  (is (null (otenki.view::render-daily-row nil :metric))))

(test render-weather-card-contains-daily
  "Rendered card contains daily forecast day names"
  (let ((output (otenki.view:render-weather-card (make-test-card) :metric)))
    (is (search "Wed" output))
    (is (search "Thu" output))))

(test render-weather-card-aligned-labels
  "Card contains aligned label columns"
  (let ((output (otenki.view:render-weather-card (make-test-card) :metric)))
    (is (search "Humidity" output))
    (is (search "Wind" output))
    (is (search "Condition" output))))

(test render-status-bar-contains-keys
  "Status bar contains keyboard shortcuts"
  (let ((output (otenki.view:render-status-bar
                 (get-universal-time) nil (get-universal-time) nil 3 :metric)))
    (is (search "[r]" output))
    (is (search "[q]" output))))

(test render-status-bar-contains-units
  "Status bar shows current units"
  (let ((output (otenki.view:render-status-bar
                 (get-universal-time) nil (get-universal-time) nil 3 :metric)))
    (is (search "metric" output))))

(test render-status-bar-contains-location-count
  "Status bar shows location count"
  (let ((output (otenki.view:render-status-bar
                 (get-universal-time) nil (get-universal-time) nil 3 :metric)))
    (is (search "3" output))))

(test render-status-bar-countdown
  "Status bar shows countdown derived from current-time, not the system clock"
  (let* ((current-time 1000)
         (next-refresh (+ current-time 90))  ; 1m 30s from now
         (output (otenki.view:render-status-bar
                  nil next-refresh current-time nil 3 :metric)))
    (is (search "Next in 1:30" output))))

(test condition-icon-returns-string
  "condition-icon returns a string"
  (is (stringp (otenki.view:condition-icon 800))))

(test condition-icon-clear-contains-sun
  "Clear sky icon contains the sun character"
  (is (search "☀" (otenki.view:condition-icon 800))))

(test condition-icon-rain-contains-umbrella
  "Rain icon contains the umbrella character"
  (is (search "☂" (otenki.view:condition-icon 500))))

(test condition-icon-snow-contains-snowflake
  "Snow icon contains the snowflake character"
  (is (search "❄" (otenki.view:condition-icon 600))))

(test temp-color-freezing
  "Freezing temperatures return blue"
  (is (eql (otenki.view:temp-color 273.15) tui:*fg-blue*)))

(test temp-color-cool
  "Cool temperatures (10°C) return cyan"
  (is (eql (otenki.view:temp-color 283.15) tui:*fg-cyan*)))

(test temp-color-mild
  "Mild temperatures (20°C) return green"
  (is (eql (otenki.view:temp-color 293.15) tui:*fg-green*)))

(test temp-color-warm
  "Warm temperatures (30°C) return yellow"
  (is (eql (otenki.view:temp-color 303.15) tui:*fg-yellow*)))

(test temp-color-hot
  "Hot temperatures (40°C) return red"
  (is (eql (otenki.view:temp-color 313.15) tui:*fg-red*)))

(test temperature->border-colors-returns-6-strings
  "temperature->border-colors returns a list of exactly 6 ANSI RGB color code strings"
  (let ((colors (otenki.view::temperature->border-colors 273.15)))
    (is (= (length colors) 6))
    (is (every #'stringp colors))
    ;; Each element should be an ANSI RGB foreground code like "38;2;R;G;B"
    (is (every (lambda (s) (not (null (search "38;2;" s)))) colors))))

(test temperature->border-colors-cold-differs-from-hot
  "Different temperatures produce different color lists"
  (let ((cold (otenki.view::temperature->border-colors 253.15))   ; -20°C
        (hot  (otenki.view::temperature->border-colors 313.15)))  ; +40°C
    (is (not (equal cold hot)))))

(test temperature->border-colors-extreme-clamp
  "Temperatures outside the -20 to +40 range are clamped, not crashed"
  (is (= 6 (length (otenki.view::temperature->border-colors 73.15))))   ; -200°C, below min
  (is (= 6 (length (otenki.view::temperature->border-colors 373.15))))) ; +100°C, above max

;;;; --- App Tests ---

(def-suite app-tests :description "App model and update handler tests" :in all-tests)
(in-suite app-tests)

(test card-order-preserved-on-weather-received
  "Cards stay in configured location order regardless of API response arrival order"
  (let* ((locations '("Tokyo" "New York" "London"))
         (model (otenki.app:make-otenki-model :locations locations))
         (card-ny (otenki.model:make-weather-card
                   :location-name "New York"
                   :latitude 40.7128 :longitude -74.0060
                   :current-temp 293.15 :feels-like 292.0
                   :humidity 60 :wind-speed 3.0 :wind-direction 270
                   :condition-id 800 :condition-text "clear" :hourly-forecast nil))
         (card-tokyo (otenki.model:make-weather-card
                      :location-name "Tokyo"
                      :latitude 35.6762 :longitude 139.6503
                      :current-temp 295.15 :feels-like 293.0
                      :humidity 65 :wind-speed 2.0 :wind-direction 180
                      :condition-id 800 :condition-text "clear" :hourly-forecast nil))
         ;; New York arrives first (out of configured order)
         ;;; Message classes are internal to otenki.app (not exported).
         (msg-ny     (make-instance 'otenki.app::weather-received-msg :card card-ny))
         (msg-tokyo  (make-instance 'otenki.app::weather-received-msg :card card-tokyo)))
    (tui:update-message model msg-ny)
    (tui:update-message model msg-tokyo)
    (let ((cards (otenki.app::otenki-model-cards model)))
      (is (string= (otenki.model:weather-card-location-name (first cards))  "Tokyo"))
      (is (string= (otenki.model:weather-card-location-name (second cards)) "New York")))))

(test card-order-preserved-on-weather-error
  "Error cards also sort to their configured position"
  (let* ((locations '("Tokyo" "Paris"))
         (model (otenki.app:make-otenki-model :locations locations))
         ;;; Message classes are internal to otenki.app (not exported).
         (msg-paris-err (make-instance 'otenki.app::weather-error-msg
                                       :location "Paris"
                                       :message "timeout"))
         (msg-tokyo-err (make-instance 'otenki.app::weather-error-msg
                                       :location "Tokyo"
                                       :message "timeout")))
    ;; Paris error arrives first
    (tui:update-message model msg-paris-err)
    (tui:update-message model msg-tokyo-err)
    (let ((cards (otenki.app::otenki-model-cards model)))
      (is (string= (otenki.model:weather-card-location-name (first cards))  "Tokyo"))
      (is (string= (otenki.model:weather-card-location-name (second cards)) "Paris")))))

;;;; --- JSON Tests ---

(def-suite json-tests :description "JSON output tests" :in all-tests)
(in-suite json-tests)

(test weather-card-to-ht-fields
  "weather-card-to-ht returns a hash table with new schema fields"
  (let* ((card (make-test-card))
         (ht (otenki.json:weather-card-to-ht card)))
    (is (hash-table-p ht))
    (is (string= (gethash "location" ht) "Tokyo"))
    (is (< (abs (- (gethash "lat" ht) 35.6762)) 0.001))
    (is (< (abs (- (gethash "lon" ht) 139.6503)) 0.001))
    ;; 295.15K → 22.0°C
    (is (< (abs (- (gethash "temp_c" ht) 22.0)) 0.1))
    (is (< (abs (- (gethash "feels_like_c" ht) 20.0)) 0.1))
    (is (= (gethash "humidity" ht) 65))
    (is (string= (gethash "condition" ht) "clear sky"))
    (is (listp (gethash "hourly" ht)))))

(test hourly-entry-to-ht-basic
  "hourly-entry-to-ht returns a hash table with new schema fields"
  (let* ((entry (otenki.model:make-hourly-entry
                 :hour 14
                 :temp 296.0
                 :condition-id 801
                 :pop 0.3))
         (ht (otenki.json::hourly-entry-to-ht entry)))
    (is (hash-table-p ht))
    (is (= (gethash "hour" ht) 14))
    ;; 296.0K → ~22.85°C, round1 gives 22.8 or 22.9 depending on float precision
    (is (< (abs (- (gethash "temp_c" ht) 22.85)) 0.1))
    (is (= (gethash "condition_id" ht) 801))
    (is (< (abs (- (gethash "pop" ht) 0.3)) 0.001))))

(test cards-to-json-produces-objects
  "cards-to-json output parses to an array of JSON objects"
  (let* ((card (make-test-card))
         (json-str (otenki.json:cards-to-json (list card)))
         (parsed (jzon:parse json-str))
         (obj (aref parsed 0)))
    (is (hash-table-p obj))
    (is (string= (gethash "location" obj) "Tokyo"))
    (is (= (gethash "humidity" obj) 65))
    (is (string= (gethash "condition" obj) "clear sky"))))
