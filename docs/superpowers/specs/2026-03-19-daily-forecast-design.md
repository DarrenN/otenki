# Daily Forecast Feature Design

## Overview

Add 7-day daily forecast information to weather cards. Data comes from the existing OWM One Call 3.0 `daily` array — no new API calls needed. Each day shows: day name, condition icon, and high/low temperatures.

## Decisions

| Question | Decision |
|----------|----------|
| Detail level | Minimal: day name, icon, hi/lo temps |
| Number of days | 7 (full week) |
| Card placement | Below hourly row (bottom of card) |
| Visibility | Always visible, no toggle |
| JSON output | Include daily array in `--json` mode |
| Architecture | Mirror the hourly pattern (struct, parsing, package wiring) — view rendering adds an icon row not present in hourly |

## Data Model

### New struct: `daily-entry` (model.lisp)

```lisp
(defstruct daily-entry
  "One day of forecast data."
  (day-name "" :type string)          ; "Mon", "Tue", etc.
  (temp-min 0.0 :type float)         ; Kelvin
  (temp-max 0.0 :type float)         ; Kelvin
  (condition-id 0 :type integer))    ; OWM condition code
```

### New slot on `weather-card`

```lisp
(daily-forecast nil :type list)      ; list of daily-entry
```

The `day-name` is a pre-formatted 3-letter abbreviation computed at parse time from the UNIX timestamp, keeping the view layer pure.

## API Parsing (api.lisp)

### `unix-to-day-name`

Converts a UNIX timestamp + timezone offset to a 3-letter day abbreviation using CL's `decode-universal-time` after UNIX-to-universal epoch conversion (+2208988800).

### `parse-daily-entry`

Mirrors `parse-hourly-entry`. Extracts from the OWM daily hash table:
- `"dt"` → day name via `unix-to-day-name`
- `"temp"."min"` → `:temp-min` (float, Kelvin)
- `"temp"."max"` → `:temp-max` (float, Kelvin)
- `"weather"[0]."id"` → `:condition-id`

Note: OWM daily entries nest temperature under a `"temp"` sub-object with `"min"`/`"max"` keys, unlike hourly which has a flat `"temp"` number.

### `parse-onecall-response` changes

Parse the `"daily"` array from the response (take first 7 entries), map through `parse-daily-entry`, and pass to `:daily-forecast` on `make-weather-card`.

## View Rendering (view.lisp)

### `render-daily-row`

Renders a compact daily forecast as three rows:

```
Mon  Tue  Wed  Thu  Fri  Sat  Sun
 ☀    ☁    ☂    ☀    ☀    ⚡   ☂
18/8 17/7 15/9 20/10 ...
```

- Row 1: 3-letter day names
- Row 2: condition icons (reusing existing `condition-icon`)
- Row 3: high/low temps (format: `high/low`, e.g. `18/8`), each colored via `temp-color`

Note: this is 3 rows vs hourly's 2 rows — the icon row is unique to daily because daily spans multiple days where conditions vary meaningfully. The "mirror" in the architecture decision refers to the struct/parsing/package pattern, not the rendering layout.

Column widths computed dynamically (same approach as `render-hourly-row`). Returns NIL if entries is empty.

### `render-weather-card` changes

Add daily row after hourly in the body format string using `~@[~%~%~A~]` conditional — if daily is NIL, it's omitted with no blank space.

```lisp
(body (format nil "~A~%~%~A~%~A~%~A~@[~%~%~A~]~@[~%~%~A~]"
              hero-line humidity-line wind-line
              condition-line hourly daily))
```

## JSON Serialization (json.lisp)

### `daily-entry-to-ht`

Converts a `daily-entry` to a string-keyed hash table:

```json
{"day": "Mon", "temp_min_c": 8.2, "temp_max_c": 18.5, "condition_id": 800}
```

Temperatures converted from Kelvin to Celsius with 1 decimal place (matching hourly pattern).

### `weather-card-to-ht` changes

Add `"daily"` key containing `(mapcar #'daily-entry-to-ht (weather-card-daily-forecast card))`.

## Package Exports (package.lisp)

### `otenki.model`

Export: `daily-entry`, `make-daily-entry`, `daily-entry-day-name`, `daily-entry-temp-min`, `daily-entry-temp-max`, `daily-entry-condition-id`, `weather-card-daily-forecast`.

### `otenki.api`

Add `make-daily-entry` to `:import-from otenki.model`. Export `unix-to-day-name` for direct testing.

### `otenki.view`

Add imports: `weather-card-daily-forecast`, `daily-entry-day-name`, `daily-entry-temp-min`, `daily-entry-temp-max`, `daily-entry-condition-id`.

### `otenki.json`

Add imports: `weather-card-daily-forecast`, `daily-entry-day-name`, `daily-entry-temp-min`, `daily-entry-temp-max`, `daily-entry-condition-id`.

No changes to `otenki.app`, `otenki.config`, or `otenki.main`.

## Testing

Tests mirror the existing hourly test patterns:

- **Model**: `daily-entry` construction, slot access
- **API**: `parse-daily-entry` with fixture data, `unix-to-day-name` edge cases (timezone offsets, day boundaries), `parse-onecall-response` includes daily entries
- **View**: `render-daily-row` output format, empty list returns NIL, column alignment
- **JSON**: `daily-entry-to-ht` Kelvin-to-Celsius conversion, `weather-card-to-ht` includes `"daily"` key

The existing onecall fixture (`t/fixtures/onecall.json`) needs a `"daily"` array added matching the OWM One Call 3.0 schema.

## Files Changed

| File | Change |
|------|--------|
| `src/model.lisp` | Add `daily-entry` struct, `daily-forecast` slot on `weather-card` |
| `src/api.lisp` | Add `unix-to-day-name`, `parse-daily-entry`, update `parse-onecall-response` |
| `src/view.lisp` | Add `render-daily-row`, update `render-weather-card` |
| `src/json.lisp` | Add `daily-entry-to-ht`, update `weather-card-to-ht` |
| `src/package.lisp` | Export/import new symbols in model, api, view, json packages |
| `t/fixtures/onecall.json` | Add `"daily"` array |
| `t/tests.lisp` | Add daily-entry tests for model, api, view, json |
