# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Changed
- Dependencies (cl-tuition, openweathermap) are now external — no more
  vendored submodules.

## [0.3.0] - 2026-03-19

### Added
- 7-day daily forecast row on each card (day name, icon, hi/lo with
  temperature coloring).
- Daily forecast included in `--json` output.

### Fixed
- Cards-per-row now computed from actual rendered widths instead of a
  hardcoded estimate.

## [0.2.0] - 2026-03-09

### Added
- Temperature-based gradient borders (cool blue → warm red).
- Dynamic window title showing refresh state.
- Card order preserved across refreshes (matches config order).

### Changed
- Migrated to cl-tuition v2.0.0 (declarative views, `key-press-msg`).
- Upgraded openweathermap client to v0.2.0 (jzon, string-keyed hash tables).

### Fixed
- Event-loop mutex safety on SBCL (getmsg+sleep polling).
- East-asian-wide table incorrectly doubled weather icon widths.
- Thread pool blocking shutdown on long-running tick commands.

## [0.1.0] - 2026-03-06

### Added
- Multi-location weather card grid with responsive terminal layout.
- Current conditions: temperature, feels-like, humidity, wind, description.
- 12-hour hourly forecast per card.
- Auto-refresh on configurable timer (default 10 minutes).
- `--json` mode for machine-readable output.
- Metric and imperial unit support.
- Inline error cards for failed location fetches.
- Config file at `~/.config/otenki/config.lisp`.
- Concise FiveAM test reporter for CI.
