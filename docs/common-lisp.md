## Common Lisp Development Environment

This file provides guidance to Claude Code (claude.ai/code) when working with Common Lisp code in this repository.

```lisp
(ql:quickload :project-name)
```

```shell
sbcl --load project-name.asd  # or: ros run -l project-name.asd
```

### `lisp-eval` wrapper

Use `lisp-eval` instead of raw `sbcl` for non-interactive evaluation. It suppresses the SBCL banner and Quicklisp loading noise.

```shell
lisp-eval :project-name '(project-name:main)'        # load system, then eval
lisp-eval '(format t "~a~%" (lisp-implementation-version))'  # eval without loading
```

Makefile must include `repl` and `test` targets.

### Preferred Libraries

- **Logging**: `log4cl` - set level via `ENV`; output JSON.
- **JSON**: `com.inoue.jzon` — use the default of hash tables with string keys.
- **Web Framework**: `ningle`
- **Web Server**: `clack`

### Optimization Declarations

Development (default):

```lisp
(declaim (optimize (safety 3) (debug 3) (speed 0)))
```

Production / executables:

```lisp
(declaim (optimize (speed 3) (safety 1) (debug 0)))
```

## Testing (FiveAM)

```lisp
(ql:quickload :project-name/tests)
(5am:run! 'project-name/tests:all-tests)
```

Single test suite:

```lisp
(5am:run! 'project-name/tests:suite-name)
```

From the shell (for CI / `make test`):

```shell
lisp-eval :project-name/tests '(unless (5am:run-all-tests) (uiop:quit 1))'
```

The `make test` target must emit concise output: a summary line and failure details only. Use a custom report runner to suppress FiveAM's verbose per-test output. Provide a `make test-verbose` target for full FiveAM output when debugging.

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
├── Makefile
├── project-name.asd
├── src/
│   ├── package.lisp
│   └── main.lisp
└── t/
    └── tests.lisp
```

## Common Pitfalls

### SBCL double-float stringification

`(princ-to-string 40.7d0)` → `"40.7d0"` — includes the `d0` suffix. When building URLs or external API strings, coerce to single-float first: `(float val 0.0)`.

### FASL cache staleness

ASDF uses file modification times. When debugging mysterious behavior after file moves or reverts, clear caches: `find ~/.cache/common-lisp/ -name "*.fasl" -delete`.

### `serapeum:keep` is NOT `remove-if-not`

`(keep ITEM SEQ)` keeps items matching ITEM via `eql` — it is not a predicate filter. `(serapeum:keep #'identity cmds)` silently returns NIL without error. Use `remove-if-not` or `(remove nil ...)` instead.

## Conditions and Restarts

- Inherit from `error`, `warning`, or `simple-error`; include descriptive slots.
- Use `handler-case` to catch and transform; use `handler-bind` when restarts must execute in the signaling frame (e.g., logging with full stack context).
- Provide restarts with `restart-case` for recoverable errors:

```lisp
(restart-case (process-item item)
  (skip-item () :report "Skip and continue" nil)
  (use-value (v) :report "Supply a replacement" v))
```

- Invoke restarts from handlers:

```lisp
(handler-bind ((parse-error (lambda (c)
                              (declare (ignore c))
                              (invoke-restart 'skip-item))))
  (process-all-items))
```

## Building Executables

```lisp
(sb-ext:save-lisp-and-die "project-name"
  :toplevel #'project-name:main
  :executable t
  :compression t)
```

## Docker

Use `clfoundation/sbcl:<version>-bookworm-slim` as the base image (native arm64 + amd64 support). Follow multi-stage build patterns from the top-level template.

## Web Projects

- Prefer JSON Rest APIs
- Add explicit liveness/readiness endpoints (`/health`, `/health/ready`) in API services

### Ningle Route Parameter Keys

- Path params (`:id` in `/feeds/:id`) → keyword-keyed alist: `((:id . "14"))`. Use `(cdr (assoc :id params))` — never `(assoc "id" params :test #'string=)` (SBCL uppercases symbol names; string form silently returns NIL).
- Query string params from `lack.request:request-query-parameters` use **string** keys.
