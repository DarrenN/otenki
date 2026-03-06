# Otenki Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a Common Lisp TUI weather app displaying multi-location weather cards with auto-refresh and a `--json` output mode.

**Architecture:** Functional Core (pure structs, transformations, view rendering) + Imperative Shell (TEA via cl-tuition, API calls, config I/O). Vendored dependencies via git submodules.

**Tech Stack:** SBCL, cl-tuition (TEA TUI framework), openweathermap (API client), FiveAM (testing), jonathan (JSON output)

**Note:** The openweathermap library uses env var `OPENWEATHER_API_KEY` (not `OPENWEATHERMAP_API_KEY`). Update CLAUDE.md and design doc accordingly.

---

### Task 1: Project Scaffolding — Git Submodules and ASDF

**Files:**
- Create: `otenki.asd`
- Create: `src/package.lisp`
- Modify: `.gitmodules` (via git submodule add)

**Step 1: Add vendor submodules**

```bash
git submodule add https://github.com/DarrenN/openweathermap.git vendor/openweathermap
git submodule add https://github.com/atgreen/cl-tuition.git vendor/cl-tuition
```

**Step 2: Create the ASDF system definition**

Create `otenki.asd`:

```lisp
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
  :perform (test-op (o c)
             (uiop:symbol-call :otenki.tests :run-all-tests)))
```

**Step 3: Create the package definitions**

Create `src/package.lisp`:

```lisp
;;;; package.lisp — package definitions for otenki

(defpackage #:otenki.model
  (:use #:cl)
  (:export #:weather-card
           #:make-weather-card
           #:weather-card-location-name
           #:weather-card-latitude
           #:weather-card-longitude
           #:weather-card-current-temp
           #:weather-card-feels-like
           #:weather-card-humidity
           #:weather-card-wind-speed
           #:weather-card-wind-direction
           #:weather-card-condition-id
           #:weather-card-condition-text
           #:weather-card-hourly-forecast
           #:weather-card-error-message
           #:hourly-entry
           #:make-hourly-entry
           #:hourly-entry-hour
           #:hourly-entry-temp
           #:hourly-entry-condition-id
           #:hourly-entry-pop
           #:kelvin-to-celsius
           #:kelvin-to-fahrenheit
           #:format-temp
           #:format-wind-speed))

(defpackage #:otenki.config
  (:use #:cl)
  (:export #:*default-config-path*
           #:app-config
           #:make-app-config
           #:app-config-units
           #:app-config-refresh-interval
           #:app-config-locations
           #:app-config-json-mode-p
           #:load-config-file
           #:parse-cli-args
           #:resolve-config
           #:ensure-api-key))

(defpackage #:otenki.api
  (:use #:cl)
  (:import-from #:otenki.model
                #:make-weather-card
                #:make-hourly-entry)
  (:export #:geocode-location
           #:fetch-weather-for-location
           #:parse-onecall-response
           #:parse-geocoding-response))

(defpackage #:otenki.view
  (:use #:cl)
  (:import-from #:otenki.model
                #:weather-card
                #:weather-card-location-name
                #:weather-card-current-temp
                #:weather-card-feels-like
                #:weather-card-humidity
                #:weather-card-wind-speed
                #:weather-card-wind-direction
                #:weather-card-condition-text
                #:weather-card-hourly-forecast
                #:weather-card-error-message
                #:hourly-entry-hour
                #:hourly-entry-temp
                #:hourly-entry-pop
                #:format-temp
                #:format-wind-speed)
  (:export #:render-weather-card
           #:render-card-grid
           #:render-status-bar
           #:render-app))

(defpackage #:otenki.json
  (:use #:cl)
  (:import-from #:otenki.model
                #:weather-card
                #:weather-card-location-name
                #:weather-card-latitude
                #:weather-card-longitude
                #:weather-card-current-temp
                #:weather-card-feels-like
                #:weather-card-humidity
                #:weather-card-wind-speed
                #:weather-card-wind-direction
                #:weather-card-condition-id
                #:weather-card-condition-text
                #:weather-card-hourly-forecast
                #:hourly-entry-hour
                #:hourly-entry-temp
                #:hourly-entry-condition-id
                #:hourly-entry-pop)
  (:export #:weather-card-to-plist
           #:cards-to-json))

(defpackage #:otenki.app
  (:use #:cl)
  (:import-from #:otenki.model
                #:weather-card
                #:make-weather-card)
  (:import-from #:otenki.config
                #:app-config
                #:app-config-units
                #:app-config-refresh-interval
                #:app-config-locations)
  (:import-from #:otenki.api
                #:fetch-weather-for-location)
  (:import-from #:otenki.view
                #:render-app)
  (:export #:otenki-model
           #:make-otenki-model
           #:run-tui))

(defpackage #:otenki.main
  (:use #:cl)
  (:import-from #:otenki.config
                #:parse-cli-args
                #:resolve-config
                #:ensure-api-key
                #:app-config-json-mode-p
                #:app-config-locations
                #:app-config-units)
  (:import-from #:otenki.app
                #:run-tui)
  (:import-from #:otenki.api
                #:fetch-weather-for-location)
  (:import-from #:otenki.json
                #:cards-to-json)
  (:export #:main))

(defpackage #:otenki.tests
  (:use #:cl #:fiveam)
  (:export #:run-all-tests))
```

**Step 4: Create ASDF source registry conf for vendor**

Create `vendor/source-registry.conf`:

```lisp
;;; ASDF source registry for vendored dependencies
(:source-registry
 (:tree (:here))
 :inherit-configuration)
```

We'll document in the README that users need to either:
- Symlink or register `vendor/` in their ASDF source registry, or
- The Makefile will set `CL_SOURCE_REGISTRY` env var before launching SBCL.

**Step 5: Create minimal stub files so the system loads**

Create `src/model.lisp`:
```lisp
;;;; model.lisp — pure data structures and transformations
(in-package #:otenki.model)
```

Create `src/config.lisp`:
```lisp
;;;; config.lisp — configuration loading and CLI arg parsing
(in-package #:otenki.config)
```

Create `src/api.lisp`:
```lisp
;;;; api.lisp — openweathermap API wrapper
(in-package #:otenki.api)
```

Create `src/view.lisp`:
```lisp
;;;; view.lisp — pure rendering functions
(in-package #:otenki.view)
```

Create `src/json.lisp`:
```lisp
;;;; json.lisp — JSON serialization for --json mode
(in-package #:otenki.json)
```

Create `src/app.lisp`:
```lisp
;;;; app.lisp — TEA wiring for the TUI
(in-package #:otenki.app)
```

Create `src/main.lisp`:
```lisp
;;;; main.lisp — entry point and CLI dispatch
(in-package #:otenki.main)
```

Create `t/tests.lisp`:
```lisp
;;;; tests.lisp — FiveAM test suites for otenki
(in-package #:otenki.tests)

(def-suite all-tests :description "All otenki tests")

(defun run-all-tests ()
  (run! 'all-tests))
```

**Step 6: Create Makefile**

Create `Makefile`:

```makefile
.PHONY: deps repl test build install clean

VENDOR_DIR := $(shell pwd)/vendor
CL_SOURCE_REGISTRY := $(VENDOR_DIR)//:$(VENDOR_DIR)/openweathermap//:$(VENDOR_DIR)/cl-tuition//
SBCL := CL_SOURCE_REGISTRY="$(CL_SOURCE_REGISTRY)" sbcl --noinform --non-interactive

deps:
	git submodule update --init --recursive

repl:
	CL_SOURCE_REGISTRY="$(CL_SOURCE_REGISTRY)" rlwrap sbcl --noinform --load otenki.asd \
		--eval '(asdf:load-system :otenki)'

test:
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki/tests)' \
		--eval '(unless (otenki.tests:run-all-tests) (uiop:quit 1))'

build:
	mkdir -p bin
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki)' \
		--eval '(sb-ext:save-lisp-and-die "bin/otenki" :toplevel #'"'"'otenki.main:main :executable t :compression t)'

install: build
	cp bin/otenki ~/bin/otenki

clean:
	rm -rf bin/
```

**Step 7: Verify system loads**

Run: `make deps && make test`
Expected: Submodules cloned, system loads, 0 tests run, 0 failures.

**Step 8: Commit**

```bash
git add -A
git commit -m "feat: scaffold project structure with ASDF, packages, and Makefile"
```

---

### Task 2: Model — Pure Data Structures and Unit Conversion

**Files:**
- Modify: `src/model.lisp`
- Modify: `t/tests.lisp`

**Step 1: Write failing tests for unit conversion**

Add to `t/tests.lisp`:

```lisp
(in-package #:otenki.tests)

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
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — functions not defined.

**Step 3: Implement model.lisp**

```lisp
;;;; model.lisp — pure data structures and transformations
(in-package #:otenki.model)

;;;; --- Data Structures ---

(defstruct weather-card
  "A single location's weather snapshot."
  (location-name "" :type string)
  (latitude 0.0 :type float)
  (longitude 0.0 :type float)
  (current-temp 0.0 :type float)       ; Kelvin
  (feels-like 0.0 :type float)         ; Kelvin
  (humidity 0 :type integer)           ; percentage
  (wind-speed 0.0 :type float)        ; m/s
  (wind-direction 0 :type integer)    ; degrees
  (condition-id 0 :type integer)      ; OWM condition code
  (condition-text "" :type string)
  (hourly-forecast nil :type list)    ; list of hourly-entry
  (error-message nil :type (or null string)))

(defstruct hourly-entry
  "One hour of forecast data."
  (hour 0 :type integer)              ; 0-23
  (temp 0.0 :type float)             ; Kelvin
  (condition-id 0 :type integer)
  (pop 0.0 :type float))             ; probability of precipitation

;;;; --- Unit Conversion (Pure Functions) ---

(defun kelvin-to-celsius (k)
  "Convert Kelvin to Celsius."
  (- k 273.15))

(defun kelvin-to-fahrenheit (k)
  "Convert Kelvin to Fahrenheit."
  (+ (* (kelvin-to-celsius k) 9/5) 32.0))

(defun format-temp (kelvin units)
  "Format a Kelvin temperature for display in UNITS (:metric or :imperial)."
  (ecase units
    (:metric (format nil "~D°C" (round (kelvin-to-celsius kelvin))))
    (:imperial (format nil "~D°F" (round (kelvin-to-fahrenheit kelvin))))))

(defun ms-to-mph (ms)
  "Convert meters/second to miles/hour."
  (* ms 2.237))

(defun format-wind-speed (speed units)
  "Format wind speed for display in UNITS (:metric or :imperial)."
  (ecase units
    (:metric (format nil "~,1F m/s" speed))
    (:imperial (format nil "~,1F mph" (ms-to-mph speed)))))
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All model tests PASS.

**Step 5: Commit**

```bash
git add src/model.lisp t/tests.lisp
git commit -m "feat: add model structs and unit conversion functions"
```

---

### Task 3: Config — File Loading and CLI Arg Parsing

**Files:**
- Modify: `src/config.lisp`
- Modify: `t/tests.lisp`

**Step 1: Write failing tests for config**

Add to `t/tests.lisp`:

```lisp
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
  "CLI args with location names"
  (let ((cfg (otenki.config:parse-cli-args '("Tokyo" "London"))))
    (is (equal (otenki.config:app-config-locations cfg) '("Tokyo" "London")))
    (is (not (otenki.config:app-config-json-mode-p cfg)))))

(test parse-cli-args-json-flag
  "CLI args with --json flag"
  (let ((cfg (otenki.config:parse-cli-args '("--json" "Tokyo"))))
    (is (otenki.config:app-config-json-mode-p cfg))
    (is (equal (otenki.config:app-config-locations cfg) '("Tokyo")))))

(test parse-cli-args-units-flag
  "CLI args with --units flag"
  (let ((cfg (otenki.config:parse-cli-args '("--units" "imperial"))))
    (is (eql (otenki.config:app-config-units cfg) :imperial))))

(test resolve-config-cli-overrides-file
  "CLI args override config file values"
  (let ((file-cfg (otenki.config:make-app-config
                   :units :metric
                   :locations '("Paris")))
        (cli-cfg (otenki.config:make-app-config
                  :units :imperial
                  :locations '("Tokyo"))))
    (let ((merged (otenki.config:merge-configs file-cfg cli-cfg)))
      (is (eql (otenki.config:app-config-units merged) :imperial))
      (is (equal (otenki.config:app-config-locations merged) '("Tokyo"))))))

(test resolve-config-cli-nil-keeps-file
  "CLI nil values fall back to config file"
  (let ((file-cfg (otenki.config:make-app-config
                   :units :imperial
                   :refresh-interval 300
                   :locations '("Paris")))
        (cli-cfg (otenki.config:make-app-config)))
    (let ((merged (otenki.config:merge-configs file-cfg cli-cfg)))
      (is (eql (otenki.config:app-config-units merged) :imperial))
      (is (= (otenki.config:app-config-refresh-interval merged) 300))
      (is (equal (otenki.config:app-config-locations merged) '("Paris"))))))
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — config functions not defined.

**Step 3: Implement config.lisp**

Update `src/package.lisp` to add `parse-config-plist` and `merge-configs` exports to `otenki.config`:
```lisp
;; Add to otenki.config exports:
#:parse-config-plist
#:merge-configs
```

```lisp
;;;; config.lisp — configuration loading and CLI arg parsing
(in-package #:otenki.config)

;;;; --- Data Structures ---

(defvar *default-config-path*
  (merge-pathnames ".config/otenki/config.lisp"
                   (user-homedir-pathname))
  "Default path to the otenki config file.")

(defstruct app-config
  "Application configuration."
  (units :metric :type keyword)
  (refresh-interval 600 :type integer)
  (locations nil :type list)
  (json-mode-p nil :type boolean))

;;;; --- Config File Parsing ---

(defun parse-config-plist (plist)
  "Parse a config plist into an app-config struct."
  (make-app-config
   :units (or (getf plist :units) :metric)
   :refresh-interval (or (getf plist :refresh-interval) 600)
   :locations (getf plist :locations)))

(defun load-config-file (&optional (path *default-config-path*))
  "Load config from file at PATH. Returns default config if file missing."
  (if (uiop:file-exists-p path)
      (handler-case
          (let ((plist (with-open-file (s path :direction :input)
                         (read s))))
            (parse-config-plist plist))
        (error ()
          (make-app-config)))
      (make-app-config)))

;;;; --- CLI Argument Parsing ---

(defun parse-cli-args (args)
  "Parse command-line arguments into an app-config struct.
Returns a config with only explicitly-set fields populated."
  (let ((units nil)
        (json-mode nil)
        (locations nil))
    (loop with i = 0
          while (< i (length args))
          for arg = (nth i args)
          do (cond
               ((string= arg "--json")
                (setf json-mode t)
                (incf i))
               ((string= arg "--units")
                (incf i)
                (when (< i (length args))
                  (setf units (intern (string-upcase (nth i args))
                                      :keyword))
                  (incf i)))
               (t
                (push arg locations)
                (incf i))))
    (make-app-config
     :units (or units :metric)
     :refresh-interval 600
     :locations (nreverse locations)
     :json-mode-p json-mode)))

;;;; --- Config Resolution ---

(defun merge-configs (file-cfg cli-cfg)
  "Merge file config with CLI config. CLI overrides when non-default."
  (let ((default (make-app-config)))
    (make-app-config
     :units (if (eql (app-config-units cli-cfg)
                     (app-config-units default))
                (app-config-units file-cfg)
                (app-config-units cli-cfg))
     :refresh-interval (if (= (app-config-refresh-interval cli-cfg)
                               (app-config-refresh-interval default))
                           (app-config-refresh-interval file-cfg)
                           (app-config-refresh-interval cli-cfg))
     :locations (if (app-config-locations cli-cfg)
                    (app-config-locations cli-cfg)
                    (app-config-locations file-cfg))
     :json-mode-p (app-config-json-mode-p cli-cfg))))

(defun resolve-config (cli-args)
  "Build final config by merging file config with CLI args."
  (let ((file-cfg (load-config-file))
        (cli-cfg (parse-cli-args cli-args)))
    (merge-configs file-cfg cli-cfg)))

(defun ensure-api-key ()
  "Ensure the OpenWeatherMap API key is available.
Reads from OPENWEATHER_API_KEY env var and configures the client.
Signals an error if not set."
  (let ((key (uiop:getenv "OPENWEATHER_API_KEY")))
    (unless key
      (error "Missing OPENWEATHER_API_KEY environment variable.~%~
              Get your API key at https://openweathermap.org/api"))
    (openweathermap:configure-api-key key)
    key))
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All config tests PASS.

**Step 5: Commit**

```bash
git add src/package.lisp src/config.lisp t/tests.lisp
git commit -m "feat: add config file loading and CLI argument parsing"
```

---

### Task 4: API Layer — Response Parsing with Fixtures

**Files:**
- Modify: `src/api.lisp`
- Modify: `t/tests.lisp`
- Create: `t/fixtures/geocoding.json`
- Create: `t/fixtures/onecall.json`

**Step 1: Create test fixtures**

Create `t/fixtures/geocoding.json`:
```json
[
  {
    "name": "Tokyo",
    "local_names": {"en": "Tokyo", "ja": "東京"},
    "lat": 35.6762,
    "lon": 139.6503,
    "country": "JP",
    "state": "Tokyo"
  }
]
```

Create `t/fixtures/onecall.json`:
```json
{
  "lat": 35.6762,
  "lon": 139.6503,
  "timezone": "Asia/Tokyo",
  "timezone_offset": 32400,
  "current": {
    "dt": 1709700000,
    "temp": 295.15,
    "feels_like": 293.15,
    "humidity": 65,
    "wind_speed": 3.2,
    "wind_deg": 180,
    "weather": [
      {"id": 800, "main": "Clear", "description": "clear sky", "icon": "01d"}
    ]
  },
  "hourly": [
    {
      "dt": 1709700000,
      "temp": 295.15,
      "weather": [{"id": 800, "main": "Clear", "description": "clear sky"}],
      "pop": 0.0
    },
    {
      "dt": 1709703600,
      "temp": 296.0,
      "weather": [{"id": 801, "main": "Clouds", "description": "few clouds"}],
      "pop": 0.1
    },
    {
      "dt": 1709707200,
      "temp": 294.5,
      "weather": [{"id": 802, "main": "Clouds", "description": "scattered clouds"}],
      "pop": 0.2
    }
  ]
}
```

**Step 2: Write failing tests for API response parsing**

Add to `t/tests.lisp`:

```lisp
(def-suite api-tests :description "API response parsing tests" :in all-tests)
(in-suite api-tests)

(defun load-fixture (name)
  "Load a JSON fixture file and parse it."
  (let ((path (asdf:system-relative-pathname :otenki/tests
                                              (format nil "t/fixtures/~A" name))))
    (jojo:parse (uiop:read-file-string path))))

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
```

**Step 3: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — API functions not defined.

**Step 4: Implement api.lisp**

Add `#:jonathan` nickname to the test package (or use `jojo:parse`). Note: jonathan uses `jojo` as its package nickname.

Update `otenki.tests` package to import jonathan:
```lisp
;; In package.lisp, update otenki.tests:
(defpackage #:otenki.tests
  (:use #:cl #:fiveam)
  (:local-nicknames (#:jojo #:jonathan))
  (:export #:run-all-tests))
```

Implement `src/api.lisp`:

```lisp
;;;; api.lisp — openweathermap API wrapper
(in-package #:otenki.api)

;;;; --- Response Parsing (Pure Functions) ---

(defun parse-geocoding-response (data)
  "Parse geocoding response (list of plists) into first result.
Returns a plist (:name :lat :lon) or NIL if no results."
  (when (and data (listp data) (first data))
    (let ((entry (first data)))
      (list :name (getf entry :|name|)
            :lat (getf entry :|lat|)
            :lon (getf entry :|lon|)))))

(defun unix-to-hour (unix-timestamp timezone-offset)
  "Extract hour (0-23) from a UNIX timestamp with timezone offset."
  (let ((local-time (+ unix-timestamp timezone-offset)))
    (mod (floor local-time 3600) 24)))

(defun parse-hourly-entry (entry timezone-offset)
  "Parse a single hourly forecast entry plist into an hourly-entry struct."
  (let ((weather-list (getf entry :|weather|)))
    (make-hourly-entry
     :hour (unix-to-hour (getf entry :|dt|) timezone-offset)
     :temp (float (getf entry :|temp|) 0.0)
     :condition-id (if weather-list
                       (getf (first weather-list) :|id|)
                       0)
     :pop (float (or (getf entry :|pop|) 0.0) 0.0))))

(defun parse-onecall-response (data location-name)
  "Parse onecall API response plist into a weather-card struct."
  (let* ((current (getf data :|current|))
         (weather-list (getf current :|weather|))
         (first-weather (when weather-list (first weather-list)))
         (timezone-offset (or (getf data :|timezone_offset|) 0))
         (hourly-data (getf data :|hourly|)))
    (make-weather-card
     :location-name location-name
     :latitude (float (getf data :|lat|) 0.0)
     :longitude (float (getf data :|lon|) 0.0)
     :current-temp (float (getf current :|temp|) 0.0)
     :feels-like (float (getf current :|feels_like|) 0.0)
     :humidity (getf current :|humidity|)
     :wind-speed (float (getf current :|wind_speed|) 0.0)
     :wind-direction (or (getf current :|wind_deg|) 0)
     :condition-id (if first-weather (getf first-weather :|id|) 0)
     :condition-text (if first-weather
                         (getf first-weather :|description|)
                         "unknown")
     :hourly-forecast (mapcar (lambda (e)
                                (parse-hourly-entry e timezone-offset))
                              (subseq hourly-data 0
                                      (min 12 (length hourly-data)))))))

;;;; --- API Calls (Imperative Shell) ---

(defun geocode-location (name)
  "Geocode a location name. Returns plist (:name :lat :lon) or NIL."
  (handler-case
      (let ((response (openweathermap:fetch-geocoding name :limit 1)))
        (parse-geocoding-response response))
    (error () nil)))

(defun fetch-weather-for-location (name)
  "Fetch complete weather data for a location name.
Returns a weather-card struct, possibly with error-message set."
  (handler-case
      (let ((geo (geocode-location name)))
        (unless geo
          (return-from fetch-weather-for-location
            (otenki.model:make-weather-card
             :location-name name
             :error-message (format nil "Location '~A' not found" name))))
        (let ((data (openweathermap:fetch-onecall
                     (getf geo :lat) (getf geo :lon))))
          (parse-onecall-response data (getf geo :name))))
    (error (e)
      (otenki.model:make-weather-card
       :location-name name
       :error-message (format nil "API error: ~A" e)))))
```

**Important note about JSON key casing:** The openweathermap library uses `jonathan:parse` which by default produces keyword keys. Depending on the exact jonathan version, keys might be `:|name|` (preserving case) or `:NAME` (uppercased). The fixtures test will reveal which format we get. Adjust the `getf` key symbols accordingly after the first test run.

**Step 5: Run tests to verify they pass**

Run: `make test`
Expected: All API tests PASS. If key casing is wrong, adjust `:|name|` vs `:NAME` etc.

**Step 6: Commit**

```bash
git add src/api.lisp src/package.lisp t/tests.lisp t/fixtures/
git commit -m "feat: add API response parsing with test fixtures"
```

---

### Task 5: View Layer — Card Rendering

**Files:**
- Modify: `src/view.lisp`
- Modify: `t/tests.lisp`

**Step 1: Write failing tests for view rendering**

Add to `t/tests.lisp`:

```lisp
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
    (is (search "22°C" output))))

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
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — view functions not defined.

**Step 3: Implement view.lisp**

```lisp
;;;; view.lisp — pure rendering functions
(in-package #:otenki.view)

;;;; --- Weather Card Rendering ---

(defun condition-icon (condition-id)
  "Map an OWM condition ID to a simple text icon."
  (cond
    ((< condition-id 300) "⛈")    ; thunderstorm
    ((< condition-id 400) "🌧")   ; drizzle
    ((< condition-id 600) "🌧")   ; rain
    ((< condition-id 700) "❄")    ; snow
    ((< condition-id 800) "🌫")   ; atmosphere
    ((= condition-id 800) "☀")    ; clear
    (t "☁")))                      ; clouds

(defun render-hourly-row (entries units)
  "Render a compact hourly forecast as two rows: hours and temps."
  (when entries
    (let ((hours (mapcar (lambda (e)
                           (format nil "~2,'0Dh" (hourly-entry-hour e)))
                         entries))
          (temps (mapcar (lambda (e)
                           (format-temp (hourly-entry-temp e) units))
                         entries)))
      (format nil "~{ ~A~}~%~{ ~A~}" hours temps))))

(defun render-weather-card (card units)
  "Render a single weather card as a bordered string.
CARD is a weather-card struct. UNITS is :metric or :imperial."
  (if (weather-card-error-message card)
      ;; Error card
      (tui:render-border
       (format nil "~A~%~%~A"
               (tui:bold (tui:colored "Error" :fg tui:*fg-red*))
               (weather-card-error-message card))
       tui:*border-rounded*
       :title (weather-card-location-name card))
      ;; Normal card
      (let* ((icon (condition-icon (weather-card-condition-id card)))
             (temp-line (format nil "~A ~A  feels ~A"
                                icon
                                (format-temp
                                 (weather-card-current-temp card) units)
                                (format-temp
                                 (weather-card-feels-like card) units)))
             (detail-line (format nil "Humidity: ~D%  Wind: ~A ~A"
                                  (weather-card-humidity card)
                                  (format-wind-speed
                                   (weather-card-wind-speed card) units)
                                  (weather-card-condition-text card)))
             (hourly (render-hourly-row
                      (weather-card-hourly-forecast card) units))
             (body (if hourly
                       (format nil "~A~%~A~%~%~A" temp-line detail-line hourly)
                       (format nil "~A~%~A" temp-line detail-line))))
        (tui:render-border body tui:*border-rounded*
                           :title (weather-card-location-name card)))))

;;;; --- Grid Layout ---

(defun render-card-grid (cards units terminal-width)
  "Render weather cards in a responsive grid layout."
  (let* ((card-width 36)
         (cards-per-row (max 1 (floor terminal-width card-width)))
         (rendered (mapcar (lambda (c) (render-weather-card c units)) cards))
         (rows (loop for i from 0 below (length rendered) by cards-per-row
                     collect (subseq rendered i
                                     (min (+ i cards-per-row)
                                          (length rendered))))))
    (tui:join-vertical tui:+left+
                       (mapcar (lambda (row)
                                 (apply #'tui:join-horizontal tui:+top+ row))
                               rows))))

;;;; --- Status Bar ---

(defun render-status-bar (last-updated refresh-interval loading-p)
  "Render the bottom status bar."
  (let* ((status (if loading-p
                     "Refreshing..."
                     (if last-updated
                         (multiple-value-bind (s m h)
                             (decode-universal-time last-updated)
                           (declare (ignore s))
                           (format nil "Updated: ~2,'0D:~2,'0D" h m))
                         "Not yet updated")))
         (keys "[r] Refresh  [q] Quit"))
    (format nil "~A    ~A" keys status)))

;;;; --- Full App Render ---

(defun render-app (cards units terminal-width last-updated
                   refresh-interval loading-p error-message)
  "Render the complete application view."
  (let* ((title (tui:bold "otenki"))
         (grid (if cards
                   (render-card-grid cards units terminal-width)
                   "No locations configured. Add locations to ~/.config/otenki/config.lisp"))
         (status (render-status-bar last-updated refresh-interval loading-p))
         (error-line (when error-message
                       (tui:colored error-message :fg tui:*fg-red*))))
    (tui:join-vertical tui:+left+
                       (remove nil (list title "" grid "" status error-line)))))
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All view tests PASS.

**Step 5: Commit**

```bash
git add src/view.lisp t/tests.lisp
git commit -m "feat: add view layer with card rendering and grid layout"
```

---

### Task 6: JSON Output Mode

**Files:**
- Modify: `src/json.lisp`
- Modify: `t/tests.lisp`

**Step 1: Write failing tests for JSON serialization**

Add to `t/tests.lisp`:

```lisp
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
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — JSON functions not defined.

**Step 3: Implement json.lisp**

```lisp
;;;; json.lisp — JSON serialization for --json mode
(in-package #:otenki.json)

(defun hourly-entry-to-plist (entry)
  "Convert an hourly-entry struct to a JSON-friendly plist."
  (list :|hour| (hourly-entry-hour entry)
        :|temp_kelvin| (hourly-entry-temp entry)
        :|condition_id| (hourly-entry-condition-id entry)
        :|precipitation_probability| (hourly-entry-pop entry)))

(defun weather-card-to-plist (card)
  "Convert a weather-card struct to a JSON-friendly plist."
  (list :|location| (weather-card-location-name card)
        :|latitude| (weather-card-latitude card)
        :|longitude| (weather-card-longitude card)
        :|temp_kelvin| (weather-card-current-temp card)
        :|feels_like_kelvin| (weather-card-feels-like card)
        :|humidity| (weather-card-humidity card)
        :|wind_speed_ms| (weather-card-wind-speed card)
        :|wind_direction_deg| (weather-card-wind-direction card)
        :|condition_id| (weather-card-condition-id card)
        :|condition_text| (weather-card-condition-text card)
        :|hourly_forecast| (mapcar #'hourly-entry-to-plist
                                   (weather-card-hourly-forecast card))))

(defun cards-to-json (cards)
  "Serialize a list of weather-card structs to a JSON string."
  (jonathan:to-json (mapcar #'weather-card-to-plist cards)))
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All JSON tests PASS.

**Step 5: Commit**

```bash
git add src/json.lisp t/tests.lisp
git commit -m "feat: add JSON serialization for --json output mode"
```

---

### Task 7: TEA App Wiring

**Files:**
- Modify: `src/app.lisp`

This task wires up the cl-tuition TEA architecture. Testing is limited since it requires a terminal — we rely on the unit-tested pure functions underneath.

**Step 1: Implement app.lisp**

```lisp
;;;; app.lisp — TEA wiring for the TUI
(in-package #:otenki.app)

;;;; --- Custom Messages ---

(tui:defmessage weather-received-msg
  ((card :initarg :card :reader weather-received-msg-card)))

(tui:defmessage weather-error-msg
  ((location :initarg :location :reader weather-error-msg-location)
   (message :initarg :message :reader weather-error-msg-message)))

(tui:defmessage refresh-msg ())

;;;; --- App Model ---

(defclass otenki-model ()
  ((cards
    :accessor otenki-model-cards
    :initarg :cards
    :initform nil
    :type list
    :documentation "List of weather-card structs")
   (units
    :accessor otenki-model-units
    :initarg :units
    :initform :metric
    :type keyword
    :documentation "Display units: :metric or :imperial")
   (locations
    :accessor otenki-model-locations
    :initarg :locations
    :initform nil
    :type list
    :documentation "List of location name strings to fetch")
   (last-updated
    :accessor otenki-model-last-updated
    :initarg :last-updated
    :initform nil
    :documentation "Universal time of last successful update")
   (refresh-interval
    :accessor otenki-model-refresh-interval
    :initarg :refresh-interval
    :initform 600
    :type integer
    :documentation "Auto-refresh interval in seconds")
   (error-message
    :accessor otenki-model-error-message
    :initarg :error-message
    :initform nil
    :documentation "Global error message or NIL")
   (loading-p
    :accessor otenki-model-loading-p
    :initarg :loading-p
    :initform nil
    :type boolean
    :documentation "Whether a fetch is in progress")
   (terminal-width
    :accessor otenki-model-terminal-width
    :initarg :terminal-width
    :initform 80
    :type integer
    :documentation "Current terminal width"))
  (:documentation "TEA model for the otenki weather TUI."))

(defun make-otenki-model (&key locations units refresh-interval)
  "Create an otenki-model from config."
  (make-instance 'otenki-model
                 :locations locations
                 :units (or units :metric)
                 :refresh-interval (or refresh-interval 600)
                 :loading-p t))

;;;; --- Commands ---

(defun make-fetch-cmd (location)
  "Create a command that fetches weather for a single location."
  (lambda ()
    (handler-case
        (let ((card (fetch-weather-for-location location)))
          (make-instance 'weather-received-msg :card card))
      (error (e)
        (make-instance 'weather-error-msg
                       :location location
                       :message (format nil "~A" e))))))

(defun make-fetch-all-cmd (locations)
  "Create a batch command to fetch weather for all locations."
  (apply #'tui:batch (mapcar #'make-fetch-cmd locations)))

;;;; --- TEA Protocol ---

(defmethod tui:init ((model otenki-model))
  "Initialize: start fetching weather for all locations."
  (if (otenki-model-locations model)
      (tui:batch
       (make-fetch-all-cmd (otenki-model-locations model))
       (tui:tick (otenki-model-refresh-interval model)
                 (lambda () (make-instance 'refresh-msg))))
      nil))

(defmethod tui:update-message ((model otenki-model) (msg weather-received-msg))
  "Handle a weather data arrival."
  (let* ((card (weather-received-msg-card msg))
         (name (otenki.model:weather-card-location-name card))
         (existing (otenki-model-cards model))
         (updated (cons card (remove-if
                              (lambda (c)
                                (string-equal
                                 (otenki.model:weather-card-location-name c)
                                 name))
                              existing))))
    (setf (otenki-model-cards model) updated
          (otenki-model-last-updated model) (get-universal-time)
          (otenki-model-loading-p model) nil)
    (values model nil)))

(defmethod tui:update-message ((model otenki-model) (msg weather-error-msg))
  "Handle a weather fetch error."
  (let ((location (weather-error-msg-location msg))
        (message (weather-error-msg-message msg)))
    (let* ((error-card (otenki.model:make-weather-card
                        :location-name location
                        :error-message message))
           (existing (otenki-model-cards model))
           (updated (cons error-card
                         (remove-if
                          (lambda (c)
                            (string-equal
                             (otenki.model:weather-card-location-name c)
                             location))
                          existing))))
      (setf (otenki-model-cards model) updated
            (otenki-model-loading-p model) nil))
    (values model nil)))

(defmethod tui:update-message ((model otenki-model) (msg refresh-msg))
  "Handle auto-refresh timer."
  (setf (otenki-model-loading-p model) t)
  (values model
          (tui:batch
           (make-fetch-all-cmd (otenki-model-locations model))
           (tui:tick (otenki-model-refresh-interval model)
                     (lambda () (make-instance 'refresh-msg))))))

(defmethod tui:update-message ((model otenki-model) (msg tui:key-msg))
  "Handle keyboard input."
  (let ((key (tui:key-msg-key msg)))
    (cond
      ;; Quit
      ((and (characterp key) (char= key #\q))
       (values model (tui:quit-cmd)))
      ;; Manual refresh
      ((and (characterp key) (char= key #\r))
       (setf (otenki-model-loading-p model) t)
       (values model (make-fetch-all-cmd (otenki-model-locations model))))
      ;; Ignore other keys
      (t (values model nil)))))

(defmethod tui:update-message ((model otenki-model) (msg tui:window-size-msg))
  "Handle terminal resize."
  (setf (otenki-model-terminal-width model) (tui:window-size-msg-width msg))
  (values model nil))

;;;; --- View ---

(defmethod tui:view ((model otenki-model))
  "Render the complete TUI."
  (render-app (otenki-model-cards model)
              (otenki-model-units model)
              (otenki-model-terminal-width model)
              (otenki-model-last-updated model)
              (otenki-model-refresh-interval model)
              (otenki-model-loading-p model)
              (otenki-model-error-message model)))

;;;; --- Entry Point ---

(defun run-tui (config)
  "Launch the TUI with the given app-config."
  (let* ((model (make-otenki-model
                 :locations (app-config-locations config)
                 :units (app-config-units config)
                 :refresh-interval (app-config-refresh-interval config)))
         (program (tui:make-program model :alt-screen t)))
    (tui:run program)
    (tui:join program)))
```

**Step 2: Verify system compiles**

Run: `make test`
Expected: System compiles without errors, all existing tests still pass.

**Step 3: Commit**

```bash
git add src/app.lisp
git commit -m "feat: add TEA app wiring with auto-refresh and keyboard handling"
```

---

### Task 8: Main Entry Point

**Files:**
- Modify: `src/main.lisp`

**Step 1: Implement main.lisp**

```lisp
;;;; main.lisp — entry point and CLI dispatch
(in-package #:otenki.main)

(defun print-usage ()
  "Print usage information."
  (format t "otenki — weather at a glance~%~%")
  (format t "Usage:~%")
  (format t "  otenki                     Launch TUI with config locations~%")
  (format t "  otenki Tokyo London        Show weather for specific locations~%")
  (format t "  otenki --json              JSON output for config locations~%")
  (format t "  otenki --json Tokyo        JSON output for specific locations~%")
  (format t "  otenki --units imperial    Override display units~%")
  (format t "  otenki --help              Show this help~%~%")
  (format t "Configuration:~%")
  (format t "  File: ~/.config/otenki/config.lisp~%")
  (format t "  API key: OPENWEATHER_API_KEY environment variable~%"))

(defun run-json-mode (config)
  "Fetch weather for all locations and print as JSON."
  (let ((locations (app-config-locations config)))
    (unless locations
      (format *error-output* "No locations specified.~%")
      (uiop:quit 1))
    (let ((cards (mapcar #'fetch-weather-for-location locations)))
      (format t "~A~%" (cards-to-json cards))
      (finish-output))))

(defun main ()
  "Entry point for the otenki executable."
  (let ((args (uiop:command-line-arguments)))
    ;; Handle --help
    (when (member "--help" args :test #'string=)
      (print-usage)
      (uiop:quit 0))
    ;; Ensure API key
    (handler-case
        (ensure-api-key)
      (error (e)
        (format *error-output* "~A~%" e)
        (uiop:quit 1)))
    ;; Resolve config
    (let ((config (resolve-config args)))
      (if (app-config-json-mode-p config)
          ;; JSON mode
          (handler-case
              (run-json-mode config)
            (error (e)
              (format *error-output* "Error: ~A~%" e)
              (uiop:quit 1)))
          ;; TUI mode
          (if (app-config-locations config)
              (run-tui config)
              (progn
                (format t "No locations configured.~%~%")
                (print-usage)
                (uiop:quit 1)))))))
```

**Step 2: Verify system compiles**

Run: `make test`
Expected: System compiles, all tests pass.

**Step 3: Commit**

```bash
git add src/main.lisp
git commit -m "feat: add main entry point with CLI dispatch and help text"
```

---

### Task 9: Build and Smoke Test

**Files:**
- Modify: `Makefile` (if needed)

**Step 1: Run full test suite**

Run: `make test`
Expected: All tests PASS.

**Step 2: Build the executable**

Run: `make build`
Expected: `bin/otenki` created.

**Step 3: Smoke test --help**

Run: `./bin/otenki --help`
Expected: Usage text printed.

**Step 4: Smoke test --json (requires API key)**

Run: `OPENWEATHER_API_KEY=your-key ./bin/otenki --json Tokyo`
Expected: JSON output with Tokyo weather data.

**Step 5: Smoke test TUI (requires API key)**

Run: `OPENWEATHER_API_KEY=your-key ./bin/otenki Tokyo`
Expected: TUI launches showing Tokyo weather card. Press `q` to quit.

**Step 6: Commit any fixes**

```bash
git add -A
git commit -m "fix: address issues found during smoke testing"
```

---

### Task 10: README and Final Cleanup

**Files:**
- Create: `README.org`
- Modify: `CLAUDE.md` (update env var name)

**Step 1: Create README.org**

Write the README with: project description, screenshot/mockup, installation instructions (clone with submodules, build, install to ~/bin), configuration section, usage examples, development section.

**Step 2: Update CLAUDE.md**

Fix the env var reference: the openweathermap library uses `OPENWEATHER_API_KEY` (not `OPENWEATHERMAP_API_KEY`).

**Step 3: Final test run**

Run: `make test`
Expected: All tests PASS.

**Step 4: Commit**

```bash
git add README.org CLAUDE.md
git commit -m "docs: add README and fix env var name in CLAUDE.md"
```
