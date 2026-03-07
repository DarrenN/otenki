# Vendor Update v0.2.0 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update vendored openweathermap to v0.2.0 (hash tables), swap jonathan for jzon, add concise test reporter.

**Architecture:** The parsing layer in api.lisp is the only boundary between vendor output and domain structs. We rewrite that layer from keyword-plist access to string-keyed hash table access using the vendor's `ht-get` helper. JSON output serialization switches from jonathan to jzon. A new test reporter gives concise output.

**Tech Stack:** SBCL, com.inuoe.jzon, openweathermap v0.2.0, FiveAM

**Design doc:** `docs/plans/2026-03-07-vendor-update-design.md`

---

### Task 1: Pin vendor submodule to v0.2.0

**Files:**
- Modify: `vendor/openweathermap` (submodule ref)

**Step 1: Fetch tags and checkout v0.2.0**

```bash
cd vendor/openweathermap && git fetch origin --tags && git checkout v0.2.0
```

**Step 2: Verify the pin**

```bash
cd vendor/openweathermap && git describe --tags --exact-match
```

Expected: `v0.2.0`

**Step 3: Stage the submodule change**

```bash
cd /Users/yuzu/quicklisp/local-projects/otenki
git add vendor/openweathermap
```

Do NOT commit yet — we commit after tests pass with the updated code.

---

### Task 2: Swap jonathan for jzon in system definition and packages

**Files:**
- Modify: `otenki.asd:9` — change `#:jonathan` to `#:com.inuoe.jzon`
- Modify: `src/package.lisp` — no local nicknames to change here (jonathan isn't aliased in package.lisp)
- Modify: `t/tests.lisp:11` — change `(#:jojo #:jonathan)` to `(#:jzon #:com.inuoe.jzon)`

**Step 1: Update otenki.asd**

Change line 9 from:

```lisp
               #:jonathan
```

to:

```lisp
               #:com.inuoe.jzon
```

**Step 2: Update test package nickname**

In `t/tests.lisp`, change line 11 from:

```lisp
  (:local-nicknames (#:jojo #:jonathan)
```

to:

```lisp
  (:local-nicknames (#:jzon #:com.inuoe.jzon)
```

**Step 3: Do NOT run tests yet — api.lisp and json.lisp still reference old formats**

---

### Task 3: Rewrite api.lisp parsing for hash tables

**Files:**
- Modify: `src/api.lisp:1-58` (all four parsing functions + header comment)

**Step 1: Rewrite the file**

Replace the entire pure-functions section (lines 1-58) with:

```lisp
;;;; api.lisp — openweathermap API wrapper
(in-package #:otenki.api)

;;;; --- Response Parsing (Pure Functions) ---
;;;;
;;;; The openweathermap v0.2.0 client returns string-keyed hash tables
;;;; (via com.inuoe.jzon).  JSON arrays are vectors.  We use the library's
;;;; ht-get helper for nested access.

(defun parse-geocoding-response (data)
  "Parse geocoding response (vector of hash-tables) into first result.
Returns a plist (:name :lat :lon) or NIL if no results."
  (when (and data
             (vectorp data)
             (plusp (length data)))
    (let ((entry (aref data 0)))
      (list :name (openweathermap:ht-get entry "name")
            :lat (float (openweathermap:ht-get entry "lat") 0.0)
            :lon (float (openweathermap:ht-get entry "lon") 0.0)))))

(defun unix-to-hour (unix-timestamp timezone-offset)
  "Extract hour (0-23) from a UNIX timestamp with timezone offset."
  (let ((local-time (+ unix-timestamp timezone-offset)))
    (mod (floor local-time 3600) 24)))

(defun parse-hourly-entry (entry timezone-offset)
  "Parse a single hourly forecast hash-table into an hourly-entry struct."
  (let ((weather-vec (openweathermap:ht-get entry "weather")))
    (make-hourly-entry
     :hour (unix-to-hour (openweathermap:ht-get entry "dt") timezone-offset)
     :temp (float (openweathermap:ht-get entry "temp") 0.0)
     :condition-id (if (and weather-vec (plusp (length weather-vec)))
                       (openweathermap:ht-get (aref weather-vec 0) "id")
                       0)
     :pop (float (or (openweathermap:ht-get entry "pop") 0.0) 0.0))))

(defun parse-onecall-response (data location-name)
  "Parse onecall API response hash-table into a weather-card struct."
  (let* ((current (openweathermap:ht-get data "current"))
         (weather-vec (openweathermap:ht-get current "weather"))
         (first-weather (when (and weather-vec (plusp (length weather-vec)))
                          (aref weather-vec 0)))
         (timezone-offset (or (openweathermap:ht-get data "timezone_offset") 0))
         (hourly-data (openweathermap:ht-get data "hourly")))
    (make-weather-card
     :location-name location-name
     :latitude (float (openweathermap:ht-get data "lat") 0.0)
     :longitude (float (openweathermap:ht-get data "lon") 0.0)
     :current-temp (float (openweathermap:ht-get current "temp") 0.0)
     :feels-like (float (openweathermap:ht-get current "feels_like") 0.0)
     :humidity (openweathermap:ht-get current "humidity")
     :wind-speed (float (openweathermap:ht-get current "wind_speed") 0.0)
     :wind-direction (or (openweathermap:ht-get current "wind_deg") 0)
     :condition-id (if first-weather
                       (openweathermap:ht-get first-weather "id")
                       0)
     :condition-text (if first-weather
                         (openweathermap:ht-get first-weather "description")
                         "unknown")
     :hourly-forecast (map 'list
                           (lambda (e)
                             (parse-hourly-entry e timezone-offset))
                           (subseq hourly-data 0
                                   (min 12 (length hourly-data)))))))
```

The imperative shell section (lines 60-86) stays unchanged.

---

### Task 4: Update json.lisp output serialization

**Files:**
- Modify: `src/json.lisp:28` — swap `jonathan:to-json` for `com.inuoe.jzon:stringify`

**Step 1: Replace cards-to-json**

Change line 26-28 from:

```lisp
(defun cards-to-json (cards)
  "Serialize a list of weather-card structs to a JSON string."
  (jonathan:to-json (mapcar #'weather-card-to-plist cards)))
```

to:

```lisp
(defun cards-to-json (cards)
  "Serialize a list of weather-card structs to a JSON string."
  (com.inuoe.jzon:stringify (mapcar #'weather-card-to-plist cards)))
```

Note: jzon's `stringify` handles plists natively — bar-symbol keys (`:|location|`) produce lowercase JSON keys, same as jonathan did.

---

### Task 5: Update test fixture loading

**Files:**
- Modify: `t/tests.lisp:181-200` — delete `normalize-json-keys`, rewrite `load-fixture`

**Step 1: Delete normalize-json-keys (lines 181-193)**

Remove the entire `normalize-json-keys` function.

**Step 2: Rewrite load-fixture (lines 195-200)**

Replace with:

```lisp
(defun load-fixture (name)
  "Load a JSON fixture file and parse it with jzon.
Returns string-keyed hash tables matching openweathermap v0.2.0 output."
  (let ((path (asdf:system-relative-pathname :otenki/tests
                                              (format nil "t/fixtures/~A" name))))
    (jzon:parse (uiop:read-file-string path))))
```

---

### Task 6: Run tests and verify all 61 pass

**Step 1: Clear FASL cache to avoid stale compiled files**

```bash
find ~/.cache/common-lisp/ -name "*.fasl" -delete
```

**Step 2: Run the test suite**

```bash
make test
```

Expected: all 61 tests pass. If failures occur, debug and fix before proceeding.

**Step 3: Commit all changes**

```bash
git add vendor/openweathermap otenki.asd src/package.lisp src/api.lisp src/json.lisp t/tests.lisp
git commit -m "refactor: update openweathermap to v0.2.0, swap jonathan for jzon

Breaking change in vendor: API responses are now string-keyed hash tables
instead of uppercase keyword plists. Updated all parsing functions in
api.lisp to use ht-get with string keys. Switched JSON serialization
from jonathan to com.inuoe.jzon."
```

---

### Task 7: Add concise FiveAM test reporter

**Files:**
- Create: `t/report-runner.lisp`
- Modify: `t/tests.lisp:1-13` — export `run-tests-report`
- Modify: `otenki.asd:28-30` — add report-runner to test system components

**Step 1: Write the failing test — verify run-tests-report doesn't exist yet**

```bash
make test
```

Confirm current output is verbose (per-test dots/lines from FiveAM).

**Step 2: Create t/report-runner.lisp**

```lisp
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
```

**Step 3: Export run-tests-report from test package**

In `t/tests.lisp`, add `#:run-tests-report` to the `:export` list (line 13):

```lisp
  (:export #:run-all-tests
           #:run-tests-report))
```

**Step 4: Add report-runner.lisp to .asd test system**

In `otenki.asd`, change the test system components (lines 28-30) from:

```lisp
  :components ((:module "t"
                :components
                ((:file "tests"))))
```

to:

```lisp
  :components ((:module "t"
                :components
                ((:file "tests")
                 (:file "report-runner"))))
```

**Step 5: Update Makefile test targets**

Replace the existing `test` target and add `test-verbose`:

```makefile
test: ## Run the test suite (concise output)
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki/tests)' \
		--eval '(unless (otenki.tests:run-tests-report) (uiop:quit 1))'

test-verbose: ## Run the test suite (full FiveAM output)
	$(SBCL) --load otenki.asd \
		--eval '(asdf:load-system :otenki/tests)' \
		--eval '(unless (otenki.tests:run-all-tests) (uiop:quit 1))'
```

**Step 6: Clear FASL cache and verify**

```bash
find ~/.cache/common-lisp/ -name "*.fasl" -delete
make test
```

Expected output:

```
TOTAL: 61 passed, 0 failed
```

**Step 7: Verify verbose still works**

```bash
make test-verbose
```

Expected: full FiveAM output with per-test details.

**Step 8: Commit**

```bash
git add t/report-runner.lisp t/tests.lisp otenki.asd Makefile
git commit -m "feat: add concise FiveAM test reporter

Add run-tests-report that suppresses per-test output and prints only
a summary line with failure details. Wire into make test (concise)
and make test-verbose (full FiveAM output)."
```

---

### Task 8: Final verification

**Step 1: Run full test suite one more time**

```bash
make test
```

Expected: `TOTAL: 61 passed, 0 failed`

**Step 2: Verify build still works**

```bash
make build
```

Expected: `bin/otenki` produced without errors.

**Step 3: Verify submodule is pinned correctly**

```bash
cd vendor/openweathermap && git describe --tags --exact-match
```

Expected: `v0.2.0`
