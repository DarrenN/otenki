# Phase 2 + Card Order Stability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix card shuffle-on-refresh, add temperature-based gradient borders with light/dark palette support, and show a dynamic window title while fetching.

**Architecture:** Card order is fixed in the two `tui:update-message` handlers in `src/app.lisp` by sorting the updated card list against `otenki-model-locations` after each update. The gradient border is implemented as a new pure helper `temperature->border-colors` in `src/view.lisp` that returns 6 interpolated hex strings passed to `render-border :fg-colors`. The window title is set dynamically in the `tui:view` method based on `loading-p`.

**Tech Stack:** Common Lisp, cl-tuition v2 (tui:blend-colors, tui:darken-color, tui:light-dark, render-border :fg-colors), FiveAM tests.

---

### Task 1: Card Order Stability

**Files:**
- Modify: `src/app.lisp:119-151` (both update handlers)
- Modify: `t/tests.lisp` (add new `app-tests` suite before JSON tests)

**Background:** Both `weather-received-msg` and `weather-error-msg` handlers prepend the arriving card with `(cons card (remove-if ...))`. Whichever API response arrives first wins position 0. The fix: after building `updated`, sort it by each card's index in `otenki-model-locations`.

---

**Step 1: Write the failing test**

Add a new suite at line 340 of `t/tests.lisp` (just before `;;;; --- JSON Tests ---`):

```lisp
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
```

**Step 2: Run test to verify it fails**

```shell
make test
```

Expected: 2 new failures about "Tokyo" and "New York" or "Paris" ordering.

**Step 3: Implement the fix**

Replace the `weather-received-msg` handler in `src/app.lisp` (lines 119-133):

```lisp
;;; Handle a successful weather data arrival.
(defmethod tui:update-message ((model otenki-model) (msg weather-received-msg))
  "Replace or insert the arriving card in the model's card list,
then sort cards to match the configured location order."
  (let* ((card    (weather-received-msg-card msg))
         (name    (otenki.model:weather-card-location-name card))
         (updated (cons card
                        (remove-if (lambda (c)
                                     (string-equal
                                      (otenki.model:weather-card-location-name c)
                                      name))
                                   (otenki-model-cards model)))))
    (setf (otenki-model-cards       model)
          (sort updated #'<
                :key (lambda (c)
                       (or (position (otenki.model:weather-card-location-name c)
                                     (otenki-model-locations model)
                                     :test #'string-equal)
                           most-positive-fixnum)))
          (otenki-model-last-updated model) (get-universal-time)
          (otenki-model-loading-p    model) nil)
    (values model nil)))
```

Replace the `weather-error-msg` handler (lines 136-151):

```lisp
;;; Handle a weather fetch error by inserting an error card.
(defmethod tui:update-message ((model otenki-model) (msg weather-error-msg))
  "Insert an error weather-card so the view can display the failure inline,
then sort cards to match the configured location order."
  (let* ((location   (weather-error-msg-location msg))
         (err-text   (weather-error-msg-message  msg))
         (error-card (otenki.model:make-weather-card
                      :location-name location
                      :error-message err-text))
         (updated    (cons error-card
                           (remove-if (lambda (c)
                                        (string-equal
                                         (otenki.model:weather-card-location-name c)
                                         location))
                                      (otenki-model-cards model)))))
    (setf (otenki-model-cards    model)
          (sort updated #'<
                :key (lambda (c)
                       (or (position (otenki.model:weather-card-location-name c)
                                     (otenki-model-locations model)
                                     :test #'string-equal)
                           most-positive-fixnum)))
          (otenki-model-loading-p model) nil)
    (values model nil)))
```

**Step 4: Run tests to verify they pass**

```shell
make test
```

Expected: all previous tests still pass, 2 new tests pass.

**Step 5: Commit**

```shell
git add src/app.lisp t/tests.lisp
git commit -m "fix: preserve configured card order on weather data arrival"
```

---

### Task 2: Temperature Gradient Border

**Files:**
- Modify: `src/view.lisp:26-38` (add `temperature->border-colors` after `temp-color`)
- Modify: `src/view.lisp:106-108` (change normal-card `render-border` call)
- Modify: `t/tests.lisp` (add tests to `view-tests` suite)

**Background:** `render-border` accepts `:fg-colors` — a list of hex strings applied as a gradient across border characters. `tui:blend-colors` interpolates between two hex strings. `tui:light-dark` picks between two values based on terminal background detection. `tui:darken-color` darkens a hex color by a HSL lightness reduction. All temperatures stored in the model are in Kelvin; `kelvin-to-celsius` is already imported into `otenki.view`.

The gradient: the card's temperature maps to a position on the cold→hot spectrum (−20°C = 0.0, +40°C = 1.0, clamped). We interpolate between the cold and hot anchor colors to get a `mid-color` for this temperature. Then generate 6 colors ranging from `darken(mid-color, 0.4)` to `mid-color` for a subtle dimensional border.

Palettes (light terminal → muted; dark terminal → vibrant):
- Cold anchor: `(tui:light-dark "#2A6FA8" "#4A9FD4")`
- Hot anchor:  `(tui:light-dark "#C03030" "#E84040")`

---

**Step 1: Write the failing tests**

Add to the `view-tests` suite in `t/tests.lisp` (after line 338, before `;;;; --- App Tests ---`):

```lisp
(test temperature->border-colors-returns-6-strings
  "temperature->border-colors returns a list of exactly 6 hex strings"
  (let ((colors (otenki.view::temperature->border-colors 273.15)))
    (is (= (length colors) 6))
    (is (every #'stringp colors))
    (is (every (lambda (s) (char= (char s 0) #\#)) colors))))

(test temperature->border-colors-cold-differs-from-hot
  "Different temperatures produce different color lists"
  (let ((cold (otenki.view::temperature->border-colors 253.15))   ; -20°C
        (hot  (otenki.view::temperature->border-colors 313.15)))  ; +40°C
    (is (not (equal cold hot)))))

(test temperature->border-colors-extreme-clamp
  "Temperatures outside the -20 to +40 range are clamped, not crashed"
  (is (= 6 (length (otenki.view::temperature->border-colors 73.15))))   ; -200°C, below min
  (is (= 6 (length (otenki.view::temperature->border-colors 373.15))))) ; +100°C, above max
```

**Step 2: Run tests to verify they fail**

```shell
make test
```

Expected: 3 new failures about `temperature->border-colors` being undefined.

**Step 3: Implement `temperature->border-colors`**

Add after `temp-color` in `src/view.lisp` (after line 38, before the `;;;; --- Hourly Forecast Row ---` comment):

```lisp
(defun temperature->border-colors (temp-kelvin)
  "Return a list of 6 hex color strings for a card border gradient.
TEMP-KELVIN is the card temperature in Kelvin.
Maps temperature to a position on the cold (−20°C) → hot (+40°C) spectrum,
then generates a gradient from a darkened shade to the interpolated color.
Palette adapts to terminal background via tui:light-dark."
  (let* ((celsius   (kelvin-to-celsius temp-kelvin))
         (ratio     (max 0.0 (min 1.0 (/ (- celsius -20.0) 60.0))))
         (cold      (tui:light-dark "#2A6FA8" "#4A9FD4"))
         (hot       (tui:light-dark "#C03030" "#E84040"))
         (mid-color (tui:blend-colors cold hot ratio))
         (dark-end  (tui:darken-color mid-color 0.4)))
    (loop for i from 0 to 5
          collect (tui:blend-colors dark-end mid-color (/ i 5.0)))))
```

**Step 4: Update `render-weather-card` to use `:fg-colors`**

In `src/view.lisp`, change the final `tui:render-border` call in the normal-card branch (currently line 106-108) from:

```lisp
        (tui:render-border body tui:*border-rounded*
                           :title (tui:bold (weather-card-location-name card))
                           :fg-color tui:*fg-bright-black*))))
```

to:

```lisp
        (tui:render-border body tui:*border-rounded*
                           :title (tui:bold (weather-card-location-name card))
                           :fg-colors (temperature->border-colors
                                       (weather-card-current-temp card))))))
```

The error card branch keeps its `:fg-color tui:*fg-bright-black*` unchanged.

**Step 5: Run tests to verify they pass**

```shell
make test
```

Expected: all tests pass including the 3 new ones.

**Step 6: Commit**

```shell
git add src/view.lisp t/tests.lisp
git commit -m "feat: temperature-based gradient border on weather cards"
```

---

### Task 3: Dynamic Window Title

**Files:**
- Modify: `src/app.lisp:185-198` (`tui:view` method)

**Background:** `tui:make-view` accepts `:window-title STRING`. The model's `loading-p` slot is already set to `t` on fetch start and `nil` when the last card arrives. No model changes needed.

This task has no automated test (TUI runtime feature). Verify visually by running the app.

---

**Step 1: Implement the window title**

In `src/app.lisp`, change the `tui:view` method body (lines 185-198) from:

```lisp
(defmethod tui:view ((model otenki-model))
  "Delegate rendering to the pure view layer.
Returns a view-state with alt-screen enabled."
  (tui:make-view
   (render-app (otenki-model-cards            model)
               (otenki-model-units            model)
               (otenki-model-terminal-width   model)
               (otenki-model-last-updated     model)
               (otenki-model-next-refresh-time model)
               (get-universal-time)
               (otenki-model-loading-p        model)
               (otenki-model-error-message    model)
               (length (otenki-model-locations model)))
   :alt-screen t))
```

to:

```lisp
(defmethod tui:view ((model otenki-model))
  "Delegate rendering to the pure view layer.
Returns a view-state with alt-screen enabled and a dynamic window title."
  (tui:make-view
   (render-app (otenki-model-cards            model)
               (otenki-model-units            model)
               (otenki-model-terminal-width   model)
               (otenki-model-last-updated     model)
               (otenki-model-next-refresh-time model)
               (get-universal-time)
               (otenki-model-loading-p        model)
               (otenki-model-error-message    model)
               (length (otenki-model-locations model)))
   :alt-screen t
   :window-title (if (otenki-model-loading-p model)
                     "otenki [refreshing…]"
                     "otenki")))
```

**Step 2: Run tests**

```shell
make test
```

Expected: all tests still pass (no regressions).

**Step 3: Commit**

```shell
git add src/app.lisp
git commit -m "feat: dynamic window title shows refresh state"
```

---

### Task 4: Final Verification

**Step 1: Run full test suite**

```shell
make test
```

Expected: all tests pass (previous 77 + 5 new = 82 total).

**Step 2: Smoke-test the TUI interactively**

```shell
make run
```

Verify:
- Cards appear in the order listed in `~/.config/otenki/config.lisp`
- Press `r` — cards stay in position, only data updates in place
- Card borders show a gradient ranging from blue (cold locations) to red (hot locations)
- Window title bar shows `otenki [refreshing…]` briefly while fetching, then reverts to `otenki`
