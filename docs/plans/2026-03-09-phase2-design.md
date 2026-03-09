# Phase 2 + Card Order Stability — Design Document

## Summary

Three improvements shipped together:

1. **Card order stability** — cards stay in configured location order regardless of API response timing
2. **Temperature-based border gradient** — each card's border color shifts cool→hot based on current temperature, adapting to light/dark terminals
3. **Dynamic window title** — title shows `otenki [refreshing…]` during fetches, reverts to `otenki` when idle

## Architecture

All changes touch two files only:

- `src/app.lisp` — card order sort (update handlers) + window title (`tui:view`)
- `src/view.lisp` — `temperature->border-colors` helper + `render-weather-card` border call

No model struct changes. No API layer changes. No new dependencies.

---

## Section 1: Card Order Stability

**Problem:** `weather-received-msg` and `weather-error-msg` handlers use `(cons card (remove-if ...))`, prepending the arriving card. First API response wins position 0, breaking configured order.

**Fix:** After building `updated` in both handlers, sort by the card's index in `otenki-model-locations`:

```lisp
(sort updated #'<
      :key (lambda (c)
             (or (position (otenki.model:weather-card-location-name c)
                           (otenki-model-locations model)
                           :test #'string-equal)
                 most-positive-fixnum)))
```

Cards whose name is not found (error cards with unexpected names) sort to the end.

---

## Section 2: Temperature Gradient Border + light-dark

**New function in `src/view.lisp`:**

```lisp
(defun temperature->border-colors (temp units)
  "Return a list of 6 hex color strings forming a cool→hot gradient
based on TEMP in the given UNITS (:metric or :imperial).
Adapts palette to terminal background via tui:light-dark.")
```

**Implementation:**
1. Normalize to °C: `(if (eq units :imperial) (/ (- temp 32) 1.8) temp)`
2. Clamp and normalize: `t = (clamp (/ (- temp-c -20) 60) 0.0 1.0)` (range: −20°C → 40°C)
3. Select palette via `(tui:light-dark cold-dark hot-dark cold-light hot-light)` — actually two calls to get start/end anchors:
   - Dark terminal: cold `"#4A9FD4"` → hot `"#E84040"`
   - Light terminal: cold `"#2A6FA8"` → hot `"#C03030"`
4. Generate 6 colors by interpolating `t` across the gradient using `tui:blend-colors`

**Error cards:** pass a fixed grey list `'("#707070" "#707070" "#707070" "#707070" "#707070" "#707070")`.

**`render-weather-card` change:** pass `:fg-colors (temperature->border-colors temp units)` to `render-border`. Cards with no temperature (nil) fall back to no `:fg-colors` (default border).

---

## Section 3: Dynamic Window Title

**In `tui:view` method (`src/app.lisp`):**

```lisp
(tui:make-view
  (render-app ...)
  :alt-screen t
  :window-title (if (otenki-model-loading-p model)
                    "otenki [refreshing…]"
                    "otenki"))
```

`loading-p` already toggles correctly: set to `t` on fetch start (init, refresh-msg, `r` keypress) and to `nil` when the last card arrives.

---

## Files Changed

| File | Change |
|------|--------|
| `src/app.lisp` | Sort cards in both update handlers; add `:window-title` to `tui:make-view` |
| `src/view.lisp` | Add `temperature->border-colors`; update `render-weather-card` border call |

## Testing

- Card order: configure 3+ locations, verify order matches config after initial load and after `r` refresh
- Gradient: test with temperatures across the range (−20, 0, 10, 20, 30, 40°C) — borders should progress blue → red
- light-dark: verify palette shifts when `COLORFGBG` env var changes
- Window title: title bar shows "otenki [refreshing…]" briefly on `r`, reverts when data arrives
