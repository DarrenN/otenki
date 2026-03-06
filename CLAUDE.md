# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This project will produce a Common Lisp TUI for getting weather information on the command line. It will use https://github.com/DarrenN/openweathermap as the client to the Open Weather Map APIs. For the TUI we can use https://github.com/atgreen/cl-tuition

## Standards

- Use the Functional Core, Imperative Shell pattern.
- Follow the 12 Factor Apps philosophy.
- TDD: write tests before implementation, then run them.
- All code should be well documented.

### Makefile

- Every project needs a `Makefile` with dev/prod build, test, and cleanup targets.

### Git / GitHub

- Sync `main` with `origin:main` and create a working branch before starting new work.
- Run tests before every commit; fix failures before proceeding.
- Use Conventional Commits (`fix:`, `feat:`, `refactor:`, `chore:`, `style:`, `docs:`, `test:`).
- Prefer `README.org` over `README.md`.

### Tools

- Use `rg` instead of `grep` (`rg -h` for help).

### Docker / Containers

- Use explicit base image tags (never `latest`).
- Multi-stage builds; run final container as non-root user.
- Keep runtime path consistent (`/app` in image, entrypoint, and launcher).
- Add a `HEALTHCHECK` instruction that probes a health route.
- Include a `make docker-smoke` target: build → start → probe readiness.

#### Hadolint

- Run `hadolint Dockerfile` before commit (if not installed, install it).
- Fix findings by default; use inline `# hadolint ignore=RULE` only for intentional exceptions.

## Development Environment

```lisp
(ql:quickload :project-name)         ; load
(asdf:compile-system :project-name)  ; compile
```

```shell
sbcl --load project-name.asd  # or: ros run -l project-name.asd
```

Makefile must include `repl` and `test` targets.

## Testing (FiveAM)

```lisp
(ql:quickload :project-name/tests)
(5am:run! 'project-name/tests:all-tests)
```

Single test suite:

```lisp
(5am:run! 'project-name/tests:suite-name)
```

## Code Style

### Naming

- Lowercase with hyphens: `user-count` not `userCount`
- Special variables: `*variable*`
- Constants: `+constant+`
- Predicates: `abstractp` (single word), `largest-planet-p` (multi-word)
- Functions: use `&optional` and `&key` (never both together); avoid `&aux`. Use `&allow-other-keys` only in wrappers that forward a `&rest` plist.

### Formatting

- Two-space indentation
- Max 100 columns
- Comments: `;;;;` file, `;;;` section, `;;` within code, `;` inline

### Flow Control

- `if` for two branches, `when`/`unless` for one, `cond` for many.
- Never use `progn` in an `if` clause — use `cond`, `when`, or `unless`.
- Factor complex conditions into predicate functions.
- `case`/`ecase` for numbers, characters, and symbols only; prefer `ecase`/`etypecase` over `case`/`typecase`.
- Never use `ccase` or `ctypecase` in server processes.

### Identity, Equality and Comparisons

**Prefer `eql` over `eq`** — never use `eq` on numbers or characters; `eq` is for performance-critical pointer identity only.

| Type | Case-sensitive | Case-insensitive |
|------|---------------|-----------------|
| Numbers | `=` | — |
| Characters | `char=` | `char-equal` |
| Strings | `string=` | `string-equal` |
| Symbols / objects | `eql` | — |

- Use `zerop` / `plusp` / `minusp` rather than `(= x 0)`.
- Floats: never exact comparison — use a threshold. Use `eql` only when `0` / `0.0` / `-0.0` identity matters.
- `search` on strings: `:test` receives **characters**, so use `char=` / `char-equal`, not `string=` / `string-equal` (functionally correct but slower in many implementations).

### CLOS Slot Order

`:accessor` → `:initarg` → `:initform` → `:type` → `:documentation`

### Packages

- Use `:import-from` over `:use`
- Hierarchical names: `project.module.submodule`

## Project Structure

```
project-name/
├── project-name.asd
├── src/
│   ├── package.lisp
│   └── main.lisp
└── t/
    └── tests.lisp
```

## Conditions and Restarts

- Define custom conditions inheriting from `error` or `warning`
- Provide restarts with `restart-case` for recoverable errors
