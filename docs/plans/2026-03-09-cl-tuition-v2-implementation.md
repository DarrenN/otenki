# cl-tuition v2 Minimal Migration — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Update cl-tuition submodule to v2.0.0 and migrate otenki to native v2 API.

**Architecture:** Four small edits in `src/app.lisp` (key-msg rename, key accessor rename, declarative view, program creation). No test changes — the 77 existing tests cover pure functions that don't touch the TUI layer.

**Tech Stack:** Common Lisp, SBCL, cl-tuition v2, FiveAM

---

### Task 1: Update cl-tuition submodule to v2

**Files:**
- Modify: `vendor/cl-tuition` (submodule pointer)

**Step 1: Update the submodule to latest origin/master (post v2.0.0 with batch fix)**

```bash
cd vendor/cl-tuition
git checkout origin/master
cd ../..
```

**Step 2: Verify the submodule is on the expected commit**

Run: `cd vendor/cl-tuition && git log --oneline -1`
Expected: `8f60e53 Merge pull request #17 from atgreen/fix/batch-keep-bug`

**Step 3: Clear FASL cache to avoid stale compiled files**

```bash
find ~/.cache/common-lisp/ -name "*.fasl" -delete
```

**Step 4: Verify tuition v2 loads**

Run: `lisp-eval :tuition '(format t "tuition ~A~%" (asdf:component-version (asdf:find-system :tuition)))'`
Expected: `tuition 2.0.0`

**Step 5: Commit**

```bash
git add vendor/cl-tuition
git commit -m "chore: update cl-tuition submodule to v2.0.0"
```

---

### Task 2: Migrate key-msg to key-press-msg

**Files:**
- Modify: `src/app.lisp:166-175`

**Step 1: Update the key input handler**

Change the method specializer and accessor. In `src/app.lisp`, replace:

```lisp
(defmethod tui:update-message ((model otenki-model) (msg tui:key-msg))
  "q — quit; r — force refresh; everything else is ignored."
  (let ((key (tui:key-msg-key msg)))
```

With:

```lisp
(defmethod tui:update-message ((model otenki-model) (msg tui:key-press-msg))
  "q — quit; r — force refresh; everything else is ignored."
  (let ((key (tui:key-event-code msg)))
```

The body (`cond` with `char=` checks) stays identical — `key-event-code` returns characters and keyword symbols just like `key-msg-key` did.

**Step 2: Run tests to verify nothing broke**

Run: `make test`
Expected: `TOTAL: 77 passed, 0 failed`

**Step 3: Commit**

```bash
git add src/app.lisp
git commit -m "refactor: migrate key-msg to key-press-msg for cl-tuition v2"
```

---

### Task 3: Migrate to declarative view

**Files:**
- Modify: `src/app.lisp:185-206`

**Step 1: Wrap view return in make-view**

In `src/app.lisp`, change the `tui:view` method from:

```lisp
(defmethod tui:view ((model otenki-model))
  "Delegate rendering to the pure view layer."
  (render-app (otenki-model-cards            model)
              (otenki-model-units            model)
              (otenki-model-terminal-width   model)
              (otenki-model-last-updated     model)
              (otenki-model-next-refresh-time model)
              (get-universal-time)
              (otenki-model-loading-p        model)
              (otenki-model-error-message    model)
              (length (otenki-model-locations model))))
```

To:

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

**Step 2: Remove :alt-screen from make-program**

In `src/app.lisp`, change:

```lisp
         (program (tui:make-program model :alt-screen t)))
```

To:

```lisp
         (program (tui:make-program model)))
```

**Step 3: Run tests**

Run: `make test`
Expected: `TOTAL: 77 passed, 0 failed`

**Step 4: Commit**

```bash
git add src/app.lisp
git commit -m "refactor: migrate to declarative view for cl-tuition v2"
```

---

### Task 4: Also update openweathermap submodule (docs-only change)

**Files:**
- Modify: `vendor/openweathermap` (submodule pointer)

**Step 1: Update the submodule**

```bash
cd vendor/openweathermap
git checkout origin/main
cd ../..
```

**Step 2: Verify**

Run: `cd vendor/openweathermap && git log --oneline -1`
Expected: `e95b302 docs: update AGENTS.md to reflect jzon refactor`

**Step 3: Run full test suite**

Run: `make test`
Expected: `TOTAL: 77 passed, 0 failed`

**Step 4: Commit**

```bash
git add vendor/openweathermap
git commit -m "chore: update openweathermap submodule (docs-only)"
```

---

### Task 5: Manual smoke test

**Step 1: Launch the TUI**

```bash
make run
```

Or if no `make run` target:
```bash
lisp-eval :otenki '(otenki.main:main)'
```

**Step 2: Verify**

- [ ] TUI launches in alt-screen
- [ ] Weather cards render correctly
- [ ] Press `r` — triggers refresh
- [ ] Press `q` — exits cleanly
- [ ] Terminal restored to normal after exit
