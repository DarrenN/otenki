# Contributing to otenki

Thanks for your interest in contributing! This guide covers what you need
to get started.

## Prerequisites

- [SBCL](https://www.sbcl.org/) (Steel Bank Common Lisp)
- [Quicklisp](https://www.quicklisp.org/)
- [cl-tuition](https://github.com/atgreen/cl-tuition) and
  [openweathermap](https://github.com/DarrenN/openweathermap) cloned
  into `~/quicklisp/local-projects/`

See the README for full setup instructions.

## Development workflow

1. Fork the repo and clone it into `~/quicklisp/local-projects/`.
2. Create a branch from `main`:
   ```sh
   git checkout -b feat/my-feature
   ```
3. Make your changes and run the test suite:
   ```sh
   make test
   ```
4. Commit using [Conventional Commits](https://www.conventionalcommits.org/)
   (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`, `style:`).
5. Open a pull request against `main`.

## Running tests

```sh
make test           # concise summary
make test-verbose   # full FiveAM output (useful for debugging)
```

All tests must pass before submitting a PR. Tests use canned JSON
fixtures — no API key or network access required.

## Code style

- Two-space indentation, max 100 columns.
- Lowercase with hyphens for names (`weather-card`, not `weatherCard`).
- `*special-variables*` for dynamic bindings, `+constants+` for constants.
- `when`/`unless` for single-branch conditionals, `cond` for many.
- Prefer `eql` over `eq`.

See [`docs/common-lisp.md`](docs/common-lisp.md) for the full style guide.

## Architecture

otenki follows **Functional Core, Imperative Shell** using cl-tuition's
TEA (The Elm Architecture) loop:

- **Pure functions** (`model.lisp`, `api.lisp`, `view.lisp`, `json.lisp`):
  no side effects, easy to test.
- **Imperative shell** (`app.lisp`, `main.lisp`, `config.lisp`):
  TEA wiring, CLI dispatch, file I/O.

New features should keep rendering and data logic pure. Side effects
belong in the shell layer.

## What's in scope

- Weather display features and UX improvements
- Additional data from the OpenWeatherMap API
- Accessibility and terminal compatibility
- Test coverage
- Documentation

If you're unsure whether something fits, open an issue to discuss before
investing time in a PR.

## Reporting bugs

Open a GitHub issue with:

- What you expected vs. what happened
- Terminal emulator and OS
- Steps to reproduce (a config snippet helps)
