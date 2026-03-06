# UX Polish Design

**Date:** 2026-03-06
**Status:** Approved

## Overview

A visual refresh of the otenki TUI covering four areas: weather icons, color
theming, card content alignment, and status bar enhancements. All changes are
confined to `otenki.view` (pure rendering) with one small addition to the app
model for refresh countdown support.

## 1. Weather Icons

Replace text labels with single-width Unicode characters, colored per condition.

| OWM Range | Condition    | Icon | Foreground Color    |
|-----------|-------------|------|---------------------|
| 2xx       | Thunderstorm | ⚡   | `*fg-magenta*`      |
| 3xx       | Drizzle      | ☂    | `*fg-cyan*`         |
| 5xx       | Rain         | ☂    | `*fg-blue*`         |
| 6xx       | Snow         | ❄    | `*fg-bright-white*` |
| 7xx       | Fog/mist     | ≋    | `*fg-bright-black*` |
| 800       | Clear        | ☀    | `*fg-yellow*`       |
| 8xx       | Clouds       | ☁    | `*fg-bright-black*` |

`condition-icon` returns a pre-colored string via `tui:colored`. Callers are
unchanged.

## 2. Adaptive Color Palette

Use `tui:adaptive-color` so colors render well on both dark and light terminals.

### Temperature colors

Applied to temperature values in card rendering:

| Range (Celsius) | Color  |
|-----------------|--------|
| ≤ 5             | blue   |
| 5–15            | cyan   |
| 15–25           | green  |
| 25–35           | yellow |
| > 35            | red    |

A `temp-color` function takes Kelvin and units, converts to Celsius internally,
and returns the appropriate foreground color parameter.

### Other elements

- **Card borders:** bright-black (subtle on both terminal backgrounds)
- **Location title:** bold, default terminal color
- **Status bar keys:** dim
- **Error text:** red (unchanged)

## 3. Card Content Alignment

Restructure the card interior for consistent label/value alignment.

```
╭─ Tokyo ──────────────────╮
│ ☀ 22°C  feels 18°C       │
│                           │
│ Humidity       65%        │
│ Wind           3.2 m/s    │
│ Condition      Clear sky  │
│                           │
│ 12h  14h  16h  18h  20h  │
│ 23°  24°  22°  21°  20°  │
╰───────────────────────────╯
```

- Hero line (icon + temp + feels-like) stays as a single formatted line
- Detail lines use a fixed-width label column (~14 chars) with values right-aligned
  in the remaining space
- Blank line separates details from hourly forecast

## 4. Status Bar

Replace the current minimal status bar with a richer single-line format:

```
[r] Refresh  [q] Quit  │  3 locations · metric  │  Updated 14:30 · Next in 5:32
```

- Keys section: rendered with dim color
- Pipe separators (`│`) for visual grouping
- Location count and current units indicator
- Countdown to next auto-refresh

### App model change

Add `next-refresh-time` (universal-time) to `otenki-model` in `app.lisp`. Set
it when scheduling the refresh tick. The view computes the countdown by
subtracting current time from `next-refresh-time`.

`render-status-bar` gains two new parameters: `location-count` and `units`.
The `refresh-interval` parameter (currently ignored) is replaced by
`next-refresh-time`.

## Files Changed

| File | Change |
|------|--------|
| `src/view.lisp` | Icons, colors, card alignment, status bar |
| `src/app.lisp` | Add `next-refresh-time` slot, pass new params to view |
| `src/package.lisp` | Export `temp-color` if needed |
| `t/tests.lisp` | Update view tests for new rendering format |

## Testing

- Existing view tests updated to match new card format
- New tests for `condition-icon` (returns colored string containing icon char)
- New tests for `temp-color` (boundary values)
- Status bar tests updated for new format
