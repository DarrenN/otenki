# Otenki Design Document

**Date:** 2026-03-06
**Status:** Approved

## Overview

Otenki is a Common Lisp TUI for viewing weather information across multiple
locations. It uses the OpenWeatherMap API via the `openweathermap` client
library and `cl-tuition` for the terminal UI (Elm Architecture / TEA).

## Goals

- Multi-location weather overview as the primary screen
- Card-based grid layout with current conditions + today's hourly forecast
- Auto-refresh on a configurable timer
- `--json` flag for machine-readable output (agent/script friendly)
- Metric and imperial units, user-configurable
- Functional Core, Imperative Shell architecture

## Architecture

### Layers

1. **Config** (`otenki.config`) — reads env vars and config file, merges CLI args
2. **Model** (`otenki.model`) — pure data structures, transformations, unit conversion
3. **API** (`otenki.api`) — thin wrapper around `openweathermap`, returns domain structs
4. **View** (`otenki.view`) — pure rendering functions, model-to-string
5. **JSON** (`otenki.json`) — JSON serialization for `--json` mode
6. **App** (`otenki.app`) — TEA wiring: update handlers, command dispatching
7. **Main** (`otenki.main`) — entry point, CLI dispatch

### UI Mockup

```
┌─────────────────────────────────────────────────┐
│                  otenki                          │
│                                                  │
│  ┌─ Tokyo ──────┐  ┌─ New York ────┐            │
│  │ ☀ 22°C/72°F  │  │ ☁ 15°C/59°F  │            │
│  │ Humidity: 65% │  │ Humidity: 78% │            │
│  │ Wind: 3.2 m/s│  │ Wind: 5.1 m/s│            │
│  │──────────────│  │──────────────│            │
│  │ 12h 14h 16h  │  │ 12h 14h 16h  │            │
│  │ 23  24  22   │  │ 16  17  15   │            │
│  └──────────────┘  └──────────────┘            │
│                                                  │
│  [r] Refresh  [q] Quit    Updated: 14:30        │
│  Auto-refresh in 8:42                           │
└─────────────────────────────────────────────────┘
```

## Data Model

### Core Structs (Functional Core)

```lisp
(defstruct weather-card
  location-name     ; string — "Tokyo"
  latitude          ; float
  longitude         ; float
  current-temp      ; float — Kelvin (converted at display time)
  feels-like        ; float — Kelvin
  humidity          ; integer — percentage
  wind-speed        ; float — m/s
  wind-direction    ; integer — degrees
  condition-id      ; integer — OWM condition code
  condition-text    ; string — "Clear sky"
  hourly-forecast)  ; list of hourly-entry structs

(defstruct hourly-entry
  hour              ; integer — 0-23
  temp              ; float — Kelvin
  condition-id      ; integer
  pop)              ; float — probability of precipitation 0.0-1.0

(defstruct app-model
  cards             ; list of weather-card
  units             ; :metric or :imperial
  last-updated      ; universal-time
  refresh-interval  ; integer — seconds (default 600)
  error-message     ; string or nil
  loading-p)        ; boolean — show spinner during fetch
```

All temperatures stored internally in Kelvin. Conversion to metric/imperial
happens only in the view layer.

## Configuration

### Config File

Location: `~/.config/otenki/config.lisp`

```lisp
(:units :metric
 :refresh-interval 600
 :locations ("Tokyo" "New York" "London"))
```

### Environment Variable

`OPENWEATHERMAP_API_KEY` — required. Error with clear message if missing.

### CLI Arguments

- `otenki` — TUI with config locations
- `otenki Tokyo London` — override locations from CLI
- `otenki --units imperial` — override units for this session
- `otenki --json` — one-shot JSON output to stdout, no TUI
- `otenki --json Tokyo` — JSON output for specific locations

**Resolution order:** CLI args > config file > defaults (metric, 600s, no locations).

No locations provided → helpful message explaining setup.

## Data Flow (TEA)

```
Launch
  → init: create app-model with loading-p = t
  → cmd: spawn async fetch for each location

Messages:
  :weather-received card → update model, replace card in list
  :weather-error err     → set error-message on failed card
  :tick-refresh          → re-fetch all locations
  :key-pressed #\q       → quit
  :key-pressed #\r       → manual refresh
```

### JSON Mode

Bypasses TEA entirely: read config → geocode → fetch → serialize JSON → print → exit.

## API Integration

1. Geocode location names via `fetch-geocoding`
2. For each resolved location, call `fetch-onecall` (current + hourly in one request)
3. Transform responses into `weather-card` structs

## Error Handling

- Missing API key → clear error message, exit code 1
- Network failure → error shown in the failed card, other cards keep stale data
- Invalid location → "not found" in that card's slot
- Custom conditions: `otenki-config-error`, `otenki-api-error`

## Dependencies

Both `openweathermap` and `cl-tuition` are vendored as git submodules:

```
vendor/
├── openweathermap/    ; git submodule
└── cl-tuition/        ; git submodule
```

The `.asd` file configures ASDF source registry to find vendor systems.
Makefile includes `make deps` target for `git submodule update --init`.

## Building an Executable

The project compiles to a standalone SBCL image using `sb-ext:save-lisp-and-die`.
This produces a single binary that can be copied to `~/bin/otenki`.

The Makefile includes:
- `make build` — compile the executable to `bin/otenki`
- `make install` — copy the binary to `~/bin/`

The entry point (`otenki.main:main`) handles CLI arg parsing and dispatches
to either TUI mode or JSON mode.

## Testing (FiveAM)

### Test Suites

- `otenki.tests.config` — config parsing, CLI arg merging, defaults, missing API key
- `otenki.tests.model` — struct creation, temperature conversion, transformations
- `otenki.tests.api` — response parsing with canned JSON fixtures (no real API)
- `otenki.tests.view` — card rendering against known model states
- `otenki.tests.json` — JSON output structure validation

No tests require a running TUI or API key.

## Project Structure

```
otenki/
├── otenki.asd
├── Makefile
├── README.org
├── CLAUDE.md
├── vendor/
│   ├── openweathermap/
│   └── cl-tuition/
├── src/
│   ├── package.lisp
│   ├── config.lisp
│   ├── model.lisp
│   ├── api.lisp
│   ├── view.lisp
│   ├── json.lisp
│   ├── app.lisp
│   └── main.lisp
└── t/
    ├── fixtures/
    │   ├── geocoding.json
    │   └── onecall.json
    └── tests.lisp
```

### Package Hierarchy

- `otenki.config`
- `otenki.model`
- `otenki.api`
- `otenki.view`
- `otenki.json`
- `otenki.app`
- `otenki.main`
