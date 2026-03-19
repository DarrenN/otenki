# Daily Forecast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add 7-day daily forecast (day name, icon, high/low temps) to weather cards, mirroring the existing hourly pattern.

**Architecture:** New `daily-entry` struct in model, parsed from the existing OWM One Call 3.0 `daily` array, rendered as a 3-row block (day names / icons / temps) below the hourly row, and serialized in `--json` mode.

**Tech Stack:** Common Lisp, SBCL, FiveAM, cl-tuition (TEA), openweathermap client

**Spec:** `docs/superpowers/specs/2026-03-19-daily-forecast-design.md`

---

## File Structure

| File | Role | Change |
|------|------|--------|
| `src/package.lisp` | Package wiring | Export/import new daily symbols |
| `src/model.lisp` | Data structures | Add `daily-entry` struct, `daily-forecast` slot |
| `src/api.lisp` | API parsing | Add `unix-to-day-name`, `parse-daily-entry`, update `parse-onecall-response` |
| `src/view.lisp` | TUI rendering | Add `render-daily-row`, update `render-weather-card` |
| `src/json.lisp` | JSON output | Add `daily-entry-to-ht`, update `weather-card-to-ht` |
| `t/fixtures/onecall.json` | Test fixture | Add `"daily"` array |
| `t/tests.lisp` | Tests | Add daily tests for model, api, view, json |

---

### Task 1: Package Wiring & Data Model

**Files:**
- Modify: `src/package.lisp`
- Modify: `src/model.lisp`
- Modify: `t/tests.lisp`

- [ ] **Step 1: Update package exports for daily-entry**

In `src/package.lisp`, add to `otenki.model` exports after the hourly-entry block:

```lisp
           #:daily-entry
           #:make-daily-entry
           #:daily-entry-day-name
           #:daily-entry-temp-min
           #:daily-entry-temp-max
           #:daily-entry-condition-id
           #:weather-card-daily-forecast
```

- [ ] **Step 2: Write failing test for daily-entry struct**

In `t/tests.lisp`, add after the `make-hourly-entry-basic` test (still in `model-tests` suite):

```lisp
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::make-daily-entry-basic))'`
Expected: Error — `daily-entry` struct not yet defined.

- [ ] **Step 4: Add daily-entry struct and daily-forecast slot to model**

In `src/model.lisp`, add after the `hourly-entry` struct:

```lisp
(defstruct daily-entry
  "One day of forecast data."
  (day-name "" :type string)          ; "Mon", "Tue", etc.
  (temp-min 0.0 :type float)         ; Kelvin
  (temp-max 0.0 :type float)         ; Kelvin
  (condition-id 0 :type integer))    ; OWM condition code
```

Add a new slot to `weather-card`, after `hourly-forecast`:

```lisp
  (daily-forecast nil :type list)     ; list of daily-entry
```

- [ ] **Step 5: Run test to verify it passes**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::make-daily-entry-basic))'`
Expected: PASS

- [ ] **Step 6: Run full test suite to check for regressions**

Run: `make test`
Expected: All tests pass (the new `daily-forecast` slot defaults to NIL, so existing `make-weather-card` calls are unaffected).

- [ ] **Step 7: Commit**

```bash
git add src/package.lisp src/model.lisp t/tests.lisp
git commit -m "feat: add daily-entry struct and daily-forecast slot on weather-card"
```

---

### Task 2: Test Fixture & API Parsing

**Files:**
- Modify: `t/fixtures/onecall.json`
- Modify: `src/package.lisp`
- Modify: `src/api.lisp`
- Modify: `t/tests.lisp`

- [ ] **Step 1: Add daily array to onecall fixture**

In `t/fixtures/onecall.json`, add a `"daily"` array after the `"hourly"` array. The fixture's `timezone_offset` is `32400` (JST, UTC+9). The existing `"current"."dt"` is `1709700000` (2024-03-06 06:00 UTC = 15:00 JST, a Wednesday).

Use 3 daily entries for testing (matching the fixture's 3-entry hourly pattern):

```json
  "daily": [
    {
      "dt": 1709700000,
      "temp": {"min": 281.15, "max": 291.15},
      "weather": [{"id": 800, "main": "Clear", "description": "clear sky"}],
      "pop": 0.0
    },
    {
      "dt": 1709786400,
      "temp": {"min": 279.15, "max": 289.15},
      "weather": [{"id": 801, "main": "Clouds", "description": "few clouds"}],
      "pop": 0.2
    },
    {
      "dt": 1709872800,
      "temp": {"min": 280.15, "max": 290.15},
      "weather": [{"id": 500, "main": "Rain", "description": "light rain"}],
      "pop": 0.7
    }
  ]
```

Verify day names for these timestamps at JST (UTC+9):
- `1709700000` + 32400 = `1709732400` → 2024-03-06 15:00 JST → **Wed**
- `1709786400` + 32400 = `1709818800` → 2024-03-07 15:00 JST → **Thu**
- `1709872800` + 32400 = `1709905200` → 2024-03-08 15:00 JST → **Fri**

- [ ] **Step 2: Update otenki.api package for daily imports/exports**

In `src/package.lisp`, update the `otenki.api` package:

Add `#:make-daily-entry` to the `:import-from #:otenki.model` list.

Add `#:unix-to-day-name` to the `:export` list (after `#:parse-geocoding-response`).

- [ ] **Step 3: Write failing tests for unix-to-day-name**

In `t/tests.lisp`, in the `api-tests` suite, add after `parse-geocoding-empty-response`:

```lisp
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
  ;; 1709700000 = 2024-03-06 06:00 UTC, minus 5h = 01:00 = still Wednesday
  (is (string= (otenki.api:unix-to-day-name 1709700000 -18000) "Wed")))

(test unix-to-day-name-day-boundary
  "unix-to-day-name respects day boundary with timezone offset"
  ;; 1709683200 = 2024-03-06 01:20 UTC = Tuesday in UTC-5 (2024-03-05 20:20)
  (is (string= (otenki.api:unix-to-day-name 1709683200 -18000) "Tue")))
```

- [ ] **Step 4: Run tests to verify they fail**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::unix-to-day-name-wednesday))'`
Expected: Error — `unix-to-day-name` not defined.

- [ ] **Step 5: Implement unix-to-day-name**

In `src/api.lisp`, add after `unix-to-hour`:

```lisp
(defconstant +unix-to-universal-offset+ 2208988800
  "Seconds between CL universal time epoch (1900-01-01) and UNIX epoch (1970-01-01).")

(defvar *day-names* #("Mon" "Tue" "Wed" "Thu" "Fri" "Sat" "Sun")
  "3-letter day name abbreviations indexed by CL day-of-week (0=Mon, 6=Sun).")

(defun unix-to-day-name (unix-timestamp timezone-offset)
  "Convert a UNIX timestamp to a 3-letter day name (e.g. \"Wed\").
TIMEZONE-OFFSET is seconds east of UTC (as provided by OWM).
Uses CL's decode-universal-time for reliable day-of-week computation."
  (let* ((universal (+ unix-timestamp +unix-to-universal-offset+))
         (tz-hours (/ (- timezone-offset) 3600)))
    (multiple-value-bind (sec min hour date month year day)
        (decode-universal-time universal tz-hours)
      (declare (ignore sec min hour date month year))
      (aref *day-names* day))))
```

- [ ] **Step 6: Run unix-to-day-name tests to verify they pass**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::unix-to-day-name-wednesday))'`
Then: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::unix-to-day-name-day-boundary))'`
Expected: PASS

- [ ] **Step 7: Write failing test for parse-daily-entry**

In `t/tests.lisp`, in `api-tests` suite:

```lisp
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
```

- [ ] **Step 8: Run test to verify it fails**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::parse-daily-entry-basic))'`
Expected: Error — `parse-daily-entry` not defined.

- [ ] **Step 9: Implement parse-daily-entry**

In `src/api.lisp`, add after `parse-hourly-entry`:

```lisp
(defun parse-daily-entry (entry timezone-offset)
  "Parse a single daily forecast hash-table into a daily-entry struct."
  (let ((weather-vec (openweathermap:ht-get entry "weather"))
        (temp-ht (openweathermap:ht-get entry "temp")))
    (make-daily-entry
     :day-name (unix-to-day-name (openweathermap:ht-get entry "dt") timezone-offset)
     :temp-min (float (openweathermap:ht-get temp-ht "min") 0.0)
     :temp-max (float (openweathermap:ht-get temp-ht "max") 0.0)
     :condition-id (if (and weather-vec (plusp (length weather-vec)))
                       (openweathermap:ht-get (aref weather-vec 0) "id")
                       0))))
```

- [ ] **Step 10: Run test to verify it passes**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::parse-daily-entry-basic))'`
Expected: PASS

- [ ] **Step 11: Write failing test for parse-onecall-response daily integration**

In `t/tests.lisp`, add after `parse-onecall-response`:

```lisp
(test parse-onecall-response-daily
  "parse-onecall-response includes daily forecast entries"
  (let* ((data (load-fixture "onecall.json"))
         (card (otenki.api:parse-onecall-response data "Tokyo")))
    (let ((daily (otenki.model:weather-card-daily-forecast card)))
      (is (= (length daily) 3))
      (is (string= (otenki.model:daily-entry-day-name (first daily)) "Wed"))
      (is (< (abs (- (otenki.model:daily-entry-temp-max (first daily)) 291.15)) 0.01))
      (is (string= (otenki.model:daily-entry-day-name (third daily)) "Fri")))))
```

- [ ] **Step 12: Run test to verify it fails**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::parse-onecall-response-daily))'`
Expected: FAIL — `daily-forecast` is NIL (not yet parsed).

- [ ] **Step 13: Update parse-onecall-response to include daily**

In `src/api.lisp`, modify `parse-onecall-response`. Add after the `hourly-data` binding:

```lisp
         (daily-data (openweathermap:ht-get data "daily"))
```

Add to the `make-weather-card` call, after `:hourly-forecast`:

```lisp
     :daily-forecast (when daily-data
                       (map 'list
                            (lambda (e)
                              (parse-daily-entry e timezone-offset))
                            (subseq daily-data 0
                                    (min 7 (length daily-data)))))
```

- [ ] **Step 14: Run test to verify it passes**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::parse-onecall-response-daily))'`
Expected: PASS

- [ ] **Step 15: Run full test suite**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 16: Commit**

```bash
git add t/fixtures/onecall.json src/package.lisp src/api.lisp t/tests.lisp
git commit -m "feat: parse daily forecast from OWM onecall response"
```

---

### Task 3: View Rendering

**Files:**
- Modify: `src/package.lisp`
- Modify: `src/view.lisp`
- Modify: `t/tests.lisp`

- [ ] **Step 1: Update package imports for view**

In `src/package.lisp`, update `otenki.view`'s `:import-from #:otenki.model` to add:

```lisp
                #:weather-card-daily-forecast
                #:daily-entry-day-name
                #:daily-entry-temp-min
                #:daily-entry-temp-max
                #:daily-entry-condition-id
```

- [ ] **Step 2: Write failing test for render-daily-row**

In `t/tests.lisp`, in `view-tests` suite, add:

```lisp
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
```

- [ ] **Step 3: Run test to verify it fails**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::render-daily-row-basic))'`
Expected: Error — `render-daily-row` not defined.

- [ ] **Step 4: Implement render-daily-row**

In `src/view.lisp`, add after `render-hourly-row` and before the `;;; --- Single Card Rendering ---` section:

```lisp
;;;; --- Daily Forecast Row ---

(defun render-daily-row (entries units)
  "Render a compact daily forecast as three rows: day names, icons, hi/lo temps.
ENTRIES is a list of daily-entry structs. UNITS is :metric or :imperial.
Each column is padded to the widest content in that column.
Returns a newline-separated string of three rows, or NIL if entries is empty."
  (when entries
    (let* ((days (mapcar #'daily-entry-day-name entries))
           (icons (mapcar (lambda (e) (condition-icon (daily-entry-condition-id e)))
                          entries))
           (temps (mapcar (lambda (e)
                            (let ((hi (round (kelvin-to-celsius (daily-entry-temp-max e))))
                                  (lo (round (kelvin-to-celsius (daily-entry-temp-min e)))))
                              (ecase units
                                (:metric (format nil "~D/~D°" hi lo))
                                (:imperial
                                 (let ((hi-f (round (+ (* hi 9/5) 32)))
                                       (lo-f (round (+ (* lo 9/5) 32))))
                                   (format nil "~D/~D°" hi-f lo-f))))))
                          entries))
           ;; Icon display width is 1 but string length includes ANSI codes.
           ;; Use day and temp widths for column sizing (icon is always narrower).
           (widths (mapcar (lambda (d tmp)
                             (max (length d) (length tmp)))
                           days temps))
           (day-strs (mapcar (lambda (d w)
                               (format nil "~VA" (1+ w) d))
                             days widths))
           (icon-strs (mapcar (lambda (ic w)
                                ;; Icons contain ANSI escapes; pad based on display width (1)
                                (let ((padding (- (1+ w) 1)))
                                  (format nil "~A~VA" ic padding "")))
                              icons widths))
           (temp-strs (mapcar (lambda (e w)
                                (let* ((hi (round (kelvin-to-celsius (daily-entry-temp-max e))))
                                       (lo (round (kelvin-to-celsius (daily-entry-temp-min e))))
                                       (hi-str (ecase units
                                                 (:metric (format nil "~D" hi))
                                                 (:imperial (format nil "~D" (round (+ (* hi 9/5) 32))))))
                                       (lo-str (ecase units
                                                 (:metric (format nil "~D" lo))
                                                 (:imperial (format nil "~D" (round (+ (* lo 9/5) 32))))))
                                       (colored-hi (tui:colored hi-str :fg (temp-color (daily-entry-temp-max e))))
                                       (colored-lo (tui:colored lo-str :fg (temp-color (daily-entry-temp-min e))))
                                       (formatted (format nil "~A/~A°" colored-hi colored-lo))
                                       (plain-len (+ (length hi-str) 1 (length lo-str) 1))) ; "hi/lo°"
                                  (let ((padding (- (1+ w) plain-len)))
                                    (if (plusp padding)
                                        (format nil "~A~VA" formatted padding "")
                                        formatted))))
                              entries widths)))
      (format nil "~{~A~}~%~{~A~}~%~{~A~}" day-strs icon-strs temp-strs))))
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::render-daily-row-basic))'`
Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::render-daily-row-nil-on-empty))'`
Expected: PASS

- [ ] **Step 6: Write failing test for render-weather-card with daily row**

In `t/tests.lisp`, update `make-test-card` to include a `:daily-forecast`:

```lisp
   :daily-forecast (list
                    (otenki.model:make-daily-entry :day-name "Wed" :temp-min 281.15
                                                   :temp-max 291.15 :condition-id 800)
                    (otenki.model:make-daily-entry :day-name "Thu" :temp-min 279.15
                                                   :temp-max 289.15 :condition-id 801))))
```

Add a new test:

```lisp
(test render-weather-card-contains-daily
  "Rendered card contains daily forecast day names"
  (let ((output (otenki.view:render-weather-card (make-test-card) :metric)))
    (is (search "Wed" output))
    (is (search "Thu" output))))
```

- [ ] **Step 7: Run test to verify it fails**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::render-weather-card-contains-daily))'`
Expected: FAIL — daily data exists on the card but `render-weather-card` doesn't render it yet.

- [ ] **Step 8: Update render-weather-card to include daily row**

In `src/view.lisp`, in `render-weather-card`, add after the `hourly` binding:

```lisp
             (daily (render-daily-row
                     (weather-card-daily-forecast card) units))
```

Update the `body` format string from:

```lisp
             (body (format nil "~A~%~%~A~%~A~%~A~@[~%~%~A~]"
                           hero-line humidity-line wind-line
                           condition-line hourly)))
```

to:

```lisp
             (body (format nil "~A~%~%~A~%~A~%~A~@[~%~%~A~]~@[~%~%~A~]"
                           hero-line humidity-line wind-line
                           condition-line hourly daily)))
```

- [ ] **Step 9: Run test to verify it passes**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::render-weather-card-contains-daily))'`
Expected: PASS

- [ ] **Step 10: Run full test suite**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 11: Commit**

```bash
git add src/package.lisp src/view.lisp t/tests.lisp
git commit -m "feat: render daily forecast row on weather cards"
```

---

### Task 4: JSON Serialization

**Files:**
- Modify: `src/package.lisp`
- Modify: `src/json.lisp`
- Modify: `t/tests.lisp`

- [ ] **Step 1: Update package imports for json**

In `src/package.lisp`, update `otenki.json`'s `:import-from #:otenki.model` to add:

```lisp
                #:weather-card-daily-forecast
                #:daily-entry-day-name
                #:daily-entry-temp-min
                #:daily-entry-temp-max
                #:daily-entry-condition-id
```

- [ ] **Step 2: Write failing test for daily-entry-to-ht**

In `t/tests.lisp`, in `json-tests` suite:

```lisp
(test daily-entry-to-ht-basic
  "daily-entry-to-ht returns a hash table with correct fields"
  (let* ((entry (otenki.model:make-daily-entry
                 :day-name "Wed"
                 :temp-min 281.15
                 :temp-max 291.15
                 :condition-id 800))
         (ht (otenki.json::daily-entry-to-ht entry)))
    (is (hash-table-p ht))
    (is (string= (gethash "day" ht) "Wed"))
    ;; 281.15K → 8.0°C, 291.15K → 18.0°C
    (is (< (abs (- (gethash "temp_min_c" ht) 8.0)) 0.1))
    (is (< (abs (- (gethash "temp_max_c" ht) 18.0)) 0.1))
    (is (= (gethash "condition_id" ht) 800))))
```

- [ ] **Step 3: Run test to verify it fails**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::daily-entry-to-ht-basic))'`
Expected: Error — `daily-entry-to-ht` not defined.

- [ ] **Step 4: Implement daily-entry-to-ht**

In `src/json.lisp`, add after `hourly-entry-to-ht`:

```lisp
(defun daily-entry-to-ht (entry)
  "Convert a daily-entry struct to a string-keyed hash table."
  (ht "day"          (daily-entry-day-name entry)
      "temp_min_c"   (round1 (kelvin-to-celsius (daily-entry-temp-min entry)))
      "temp_max_c"   (round1 (kelvin-to-celsius (daily-entry-temp-max entry)))
      "condition_id" (daily-entry-condition-id entry)))
```

- [ ] **Step 5: Run test to verify it passes**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::daily-entry-to-ht-basic))'`
Expected: PASS

- [ ] **Step 6: Write failing test for weather-card-to-ht daily key**

In `t/tests.lisp`, in `json-tests` suite:

```lisp
(test weather-card-to-ht-daily
  "weather-card-to-ht includes daily array"
  (let* ((card (make-test-card))
         (ht (otenki.json:weather-card-to-ht card)))
    (let ((daily (gethash "daily" ht)))
      (is (listp daily))
      (is (= (length daily) 2))
      (is (string= (gethash "day" (first daily)) "Wed")))))
```

- [ ] **Step 7: Run test to verify it fails**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::weather-card-to-ht-daily))'`
Expected: FAIL — no `"daily"` key in the hash table.

- [ ] **Step 8: Update weather-card-to-ht to include daily**

In `src/json.lisp`, add to the `weather-card-to-ht` function, after the `"hourly"` entry:

```lisp
      "daily"        (mapcar #'daily-entry-to-ht
                             (weather-card-daily-forecast card))
```

- [ ] **Step 9: Run test to verify it passes**

Run: `lisp-eval :otenki/tests '(5am:run! (quote otenki.tests::weather-card-to-ht-daily))'`
Expected: PASS

- [ ] **Step 10: Run full test suite**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 11: Commit**

```bash
git add src/package.lisp src/json.lisp t/tests.lisp
git commit -m "feat: include daily forecast in --json output"
```

---

### Task 5: Final Integration & Cleanup

**Files:**
- All modified files

- [ ] **Step 1: Run full test suite**

Run: `make test`
Expected: All tests pass.

- [ ] **Step 2: Run verbose tests to inspect output**

Run: `make test-verbose`
Expected: All tests pass with detailed per-test output. Verify new daily tests appear.

- [ ] **Step 3: Manual smoke test (if API key available)**

Run: `lisp-eval :otenki '(otenki.main:main)' -- Tokyo`
Expected: Weather card for Tokyo shows daily forecast row below hourly.

Run: `lisp-eval :otenki '(otenki.main:main)' -- --json Tokyo`
Expected: JSON output includes `"daily"` array with day entries.

- [ ] **Step 4: Commit any final adjustments**

If any fixes were needed from smoke testing, commit them.
