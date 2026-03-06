# UX Polish Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refresh the otenki TUI with colored Unicode weather icons, adaptive temperature colors, aligned card content, and an enhanced status bar.

**Architecture:** All visual changes live in `src/view.lisp` (pure rendering). One model change in `src/app.lisp` adds `next-refresh-time` for countdown display. The `otenki.view` package gains two new exports: `condition-icon` and `temp-color`.

**Tech Stack:** Common Lisp, cl-tuition (`tui:colored`, `tui:*fg-*` color constants, `tui:bold`, `tui:render-border`), FiveAM tests.

---

### Task 1: Colored Unicode Weather Icons

**Files:**
- Modify: `src/view.lisp:10-23` (replace `condition-icon`)
- Test: `t/tests.lisp` (add icon tests to `view-tests` suite)

**Step 1: Write the failing tests**

Add to `t/tests.lisp` after the existing view tests (before `;;;; --- JSON Tests ---`):

```lisp
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
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: 4 FAIL — `condition-icon` is not exported and returns plain text, not Unicode.

**Step 3: Export `condition-icon` from `otenki.view`**

In `src/package.lisp`, add `#:condition-icon` to the `otenki.view` `:export` list:

```lisp
(:export #:condition-icon
         #:render-weather-card
         #:render-card-grid
         #:render-status-bar
         #:render-app)
```

**Step 4: Replace `condition-icon` in `src/view.lisp`**

Replace lines 10-23 with:

```lisp
;;;; --- Condition Icons ---

(defun condition-icon (condition-id)
  "Map an OWM condition ID to a colored Unicode weather icon.
Returns a pre-colored string via tui:colored. Single-width characters only.
Condition ranges follow OWM documentation:
  2xx — Thunderstorm, 3xx — Drizzle, 5xx — Rain,
  6xx — Snow, 7xx — Atmosphere (fog/mist), 800 — Clear, 8xx — Clouds."
  (cond
    ((< condition-id 300) (tui:colored "⚡" :fg tui:*fg-magenta*))
    ((< condition-id 400) (tui:colored "☂" :fg tui:*fg-cyan*))
    ((< condition-id 600) (tui:colored "☂" :fg tui:*fg-blue*))
    ((< condition-id 700) (tui:colored "❄" :fg tui:*fg-bright-white*))
    ((< condition-id 800) (tui:colored "≋" :fg tui:*fg-bright-black*))
    ((= condition-id 800) (tui:colored "☀" :fg tui:*fg-yellow*))
    (t                    (tui:colored "☁" :fg tui:*fg-bright-black*))))
```

**Step 5: Run tests to verify they pass**

Run: `make test`
Expected: All pass (existing view tests still pass since `condition-icon` return value still contains the icon text, just with ANSI wrapping).

**Step 6: Commit**

```bash
git add src/view.lisp src/package.lisp t/tests.lisp
git commit -m "feat: replace text weather icons with colored Unicode symbols"
```

---

### Task 2: Temperature Color Function

**Files:**
- Modify: `src/view.lisp` (add `temp-color` function after `condition-icon`)
- Modify: `src/package.lisp` (export `temp-color`)
- Test: `t/tests.lisp` (add `temp-color` tests)

**Step 1: Write the failing tests**

Add to `t/tests.lisp` after the icon tests:

```lisp
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
```

Note: `temp-color` takes Kelvin (same as all internal temps). Add `#:tui` as a local nickname to the test package for the color constants. Add to the test package definition:

```lisp
(:local-nicknames (#:jojo #:jonathan)
                  (#:tui #:cl-tuition))
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `temp-color` does not exist.

**Step 3: Export `temp-color` from `otenki.view`**

In `src/package.lisp`, add `#:temp-color` to the `otenki.view` `:export` list (after `#:condition-icon`).

**Step 4: Implement `temp-color` in `src/view.lisp`**

Add after the `condition-icon` function:

```lisp
;;;; --- Temperature Colors ---

(defun temp-color (kelvin)
  "Return a foreground color parameter based on temperature in Kelvin.
Converts to Celsius internally for threshold comparison.
  ≤5°C → blue, 5-15°C → cyan, 15-25°C → green, 25-35°C → yellow, >35°C → red."
  (let ((celsius (otenki.model:kelvin-to-celsius kelvin)))
    (cond
      ((<= celsius 5.0)  tui:*fg-blue*)
      ((<= celsius 15.0) tui:*fg-cyan*)
      ((<= celsius 25.0) tui:*fg-green*)
      ((<= celsius 35.0) tui:*fg-yellow*)
      (t                  tui:*fg-red*))))
```

Also add `#:kelvin-to-celsius` to the `otenki.view` package `:import-from #:otenki.model` list in `src/package.lisp`.

**Step 5: Run tests to verify they pass**

Run: `make test`
Expected: All pass.

**Step 6: Commit**

```bash
git add src/view.lisp src/package.lisp t/tests.lisp
git commit -m "feat: add temp-color function for temperature-based coloring"
```

---

### Task 3: Card Content Alignment

**Files:**
- Modify: `src/view.lisp:42-74` (replace `render-weather-card`)
- Test: `t/tests.lisp` (existing view tests should still pass)

**Step 1: Write a failing test for aligned layout**

Add to `t/tests.lisp` in the view-tests suite:

```lisp
(test render-weather-card-aligned-labels
  "Card contains aligned label columns"
  (let ((output (otenki.view:render-weather-card (make-test-card) :metric)))
    (is (search "Humidity" output))
    (is (search "Wind" output))
    (is (search "Condition" output))))
```

**Step 2: Run tests to verify current state**

Run: `make test`
Expected: This test should already pass since "Humidity" and "Wind" already appear. This confirms our refactor won't break things. If the test passes, that's fine — we're refactoring, not adding new behavior.

**Step 3: Replace `render-weather-card` in `src/view.lisp`**

Replace the normal-card branch of `render-weather-card` (the `let*` form inside the else branch):

```lisp
(defun render-weather-card (card units)
  "Render a single weather card as a bordered string.
CARD is a weather-card struct. UNITS is :metric or :imperial.
Returns a multi-line string suitable for terminal display.

Error cards display only the error message inside a border.
Normal cards show a hero line (icon + temp + feels-like), aligned detail
rows (humidity, wind, condition), and an hourly forecast row."
  (if (weather-card-error-message card)
      ;; Error card: show only the error message
      (tui:render-border
       (format nil "Error~%~%~A" (weather-card-error-message card))
       tui:*border-rounded*
       :title (weather-card-location-name card)
       :fg-color tui:*fg-bright-black*)
      ;; Normal card
      (let* ((icon (condition-icon (weather-card-condition-id card)))
             (temp-fg (temp-color (weather-card-current-temp card)))
             (temp-str (tui:colored (format-temp (weather-card-current-temp card) units)
                                    :fg temp-fg))
             (feels-str (tui:colored (format-temp (weather-card-feels-like card) units)
                                     :fg temp-fg))
             (hero-line (format nil "~A ~A  feels ~A"
                                icon temp-str feels-str))
             (humidity-line (format nil "~14A~D%" "Humidity" (weather-card-humidity card)))
             (wind-line (format nil "~14A~A" "Wind"
                                (format-wind-speed (weather-card-wind-speed card) units)))
             (condition-line (format nil "~14A~A" "Condition"
                                     (weather-card-condition-text card)))
             (hourly (render-hourly-row
                      (weather-card-hourly-forecast card) units))
             (body (format nil "~A~%~%~A~%~A~%~A~@[~%~%~A~]"
                           hero-line humidity-line wind-line
                           condition-line hourly)))
        (tui:render-border body tui:*border-rounded*
                           :title (tui:bold (weather-card-location-name card))
                           :fg-color tui:*fg-bright-black*))))
```

**Step 4: Run tests to verify they pass**

Run: `make test`
Expected: All existing and new view tests pass. The tests check for substrings like "Tokyo", "22", "65%", "clear sky" which are all still present.

**Step 5: Commit**

```bash
git add src/view.lisp t/tests.lisp
git commit -m "feat: align card content with fixed-width label columns and colors"
```

---

### Task 4: Enhanced Status Bar

**Files:**
- Modify: `src/view.lisp:99-114` (replace `render-status-bar`)
- Modify: `src/view.lisp:118-141` (update `render-app` to pass new params)
- Modify: `src/app.lisp` (add `next-refresh-time` slot, update `tui:view`)
- Test: `t/tests.lisp` (update status bar tests)

**Step 1: Write failing tests for the new status bar**

Add to `t/tests.lisp` in the view-tests suite:

```lisp
(test render-status-bar-contains-keys
  "Status bar contains keyboard shortcuts"
  (let ((output (otenki.view:render-status-bar
                 (get-universal-time) nil nil 3 :metric)))
    (is (search "[r]" output))
    (is (search "[q]" output))))

(test render-status-bar-contains-units
  "Status bar shows current units"
  (let ((output (otenki.view:render-status-bar
                 (get-universal-time) nil nil 3 :metric)))
    (is (search "metric" output))))

(test render-status-bar-contains-location-count
  "Status bar shows location count"
  (let ((output (otenki.view:render-status-bar
                 (get-universal-time) nil nil 3 :metric)))
    (is (search "3" output))))
```

**Step 2: Run tests to verify they fail**

Run: `make test`
Expected: FAIL — `render-status-bar` currently takes 3 args, not 5.

**Step 3: Replace `render-status-bar` in `src/view.lisp`**

```lisp
(defun render-status-bar (last-updated next-refresh-time loading-p
                          location-count units)
  "Render the bottom status bar.
LAST-UPDATED is a universal-time integer or NIL.
NEXT-REFRESH-TIME is the universal-time of the next auto-refresh, or NIL.
LOADING-P is T when a background refresh is in progress.
LOCATION-COUNT is the number of configured locations.
UNITS is :metric or :imperial."
  (let* ((keys (tui:colored "[r] Refresh  [q] Quit" :fg tui:*fg-bright-black*))
         (info (format nil "~D location~:P · ~(~A~)" location-count units))
         (updated (cond
                    (loading-p "Refreshing...")
                    (last-updated
                     (multiple-value-bind (s m h)
                         (decode-universal-time last-updated)
                       (declare (ignore s))
                       (format nil "Updated ~2,'0D:~2,'0D" h m)))
                    (t "Not yet updated")))
         (countdown (when (and next-refresh-time (not loading-p))
                      (let ((remaining (- next-refresh-time (get-universal-time))))
                        (when (plusp remaining)
                          (format nil "Next in ~D:~2,'0D"
                                  (floor remaining 60)
                                  (mod remaining 60))))))
         (time-section (if countdown
                           (format nil "~A · ~A" updated countdown)
                           updated)))
    (format nil "~A  │  ~A  │  ~A" keys info time-section)))
```

**Step 4: Update `render-app` in `src/view.lisp`**

The signature changes — add `next-refresh-time`, `location-count`, and `units` parameters:

```lisp
(defun render-app (cards units terminal-width last-updated
                   next-refresh-time loading-p error-message
                   location-count)
  "Render the complete application view as a single string.
CARDS is a list of weather-card structs (may be NIL).
UNITS is :metric or :imperial.
TERMINAL-WIDTH is the number of terminal columns.
LAST-UPDATED is a universal-time integer or NIL.
NEXT-REFRESH-TIME is the universal-time of the next auto-refresh, or NIL.
LOADING-P is T when a background fetch is running.
ERROR-MESSAGE, if non-NIL, is appended in red below the status bar.
LOCATION-COUNT is the number of configured locations."
  (let* ((title (tui:bold "otenki"))
         (grid (cond
                 (cards
                  (render-card-grid cards units terminal-width))
                 (loading-p
                  "Loading weather data...")
                 (t
                  "No locations configured. Add locations to ~/.config/otenki/config.lisp")))
         (status (render-status-bar last-updated next-refresh-time
                                    loading-p location-count units))
         (parts (list title "" grid "" status)))
    (when error-message
      (setf parts (append parts (list (tui:colored error-message :fg tui:*fg-red*)))))
    (apply #'tui:join-vertical tui:+left+ parts)))
```

**Step 5: Add `next-refresh-time` slot to `otenki-model` in `src/app.lisp`**

Add after the `refresh-interval` slot:

```lisp
   (next-refresh-time
    :accessor otenki-model-next-refresh-time
    :initarg  :next-refresh-time
    :initform nil
    :documentation "Universal time of the next scheduled refresh, or NIL.")
```

**Step 6: Update TEA methods in `src/app.lisp` to set `next-refresh-time`**

In `tui:init` method, after the `tui:tick` call, set the time:

```lisp
(defmethod tui:init ((model otenki-model))
  "Initialize the program: kick off fetches for all configured locations and
schedule the first auto-refresh tick."
  (setf (otenki-model-next-refresh-time model)
        (+ (get-universal-time) (otenki-model-refresh-interval model)))
  (when (otenki-model-locations model)
    (tui:batch
     (make-fetch-all-cmd (otenki-model-locations model))
     (tui:tick (otenki-model-refresh-interval model)
               (lambda () (make-instance 'refresh-msg))))))
```

In the `refresh-msg` handler:

```lisp
(defmethod tui:update-message ((model otenki-model) (msg refresh-msg))
  "Trigger a full re-fetch and schedule the next timer tick."
  (setf (otenki-model-loading-p model) t
        (otenki-model-next-refresh-time model)
        (+ (get-universal-time) (otenki-model-refresh-interval model)))
  (values model
          (tui:batch
           (make-fetch-all-cmd (otenki-model-locations model))
           (tui:tick (otenki-model-refresh-interval model)
                     (lambda () (make-instance 'refresh-msg))))))
```

**Step 7: Update `tui:view` in `src/app.lisp` to pass new params**

```lisp
(defmethod tui:view ((model otenki-model))
  "Delegate rendering to the pure view layer."
  (render-app (otenki-model-cards            model)
              (otenki-model-units            model)
              (otenki-model-terminal-width   model)
              (otenki-model-last-updated     model)
              (otenki-model-next-refresh-time model)
              (otenki-model-loading-p        model)
              (otenki-model-error-message    model)
              (length (otenki-model-locations model))))
```

**Step 8: Run tests to verify they pass**

Run: `make test`
Expected: All pass. The existing `render-app` is not directly tested (only via `render-weather-card` and `render-card-grid`), so adding params won't break anything.

**Step 9: Commit**

```bash
git add src/view.lisp src/app.lisp t/tests.lisp
git commit -m "feat: enhance status bar with countdown, location count, and units"
```

---

### Task 5: Clean Up and Final Verification

**Files:**
- Review: all modified files

**Step 1: Run full test suite**

Run: `make test`
Expected: All tests pass (original + new).

**Step 2: Build the executable**

Run: `make build`
Expected: Compiles without errors.

**Step 3: Commit any remaining changes**

If any cleanup was needed, commit with:

```bash
git commit -m "chore: clean up after UX polish implementation"
```
