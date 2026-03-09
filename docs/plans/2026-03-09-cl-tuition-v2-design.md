# cl-tuition v2 Minimal Migration

## Goal

Update `vendor/cl-tuition` submodule from v1.3.1+2 to v2.0.0 (post-fix `8f60e53`).
Migrate otenki to native v2 API without the compat layer.

## Migration Surface

The breaking changes that affect otenki are small:

### `src/app.lisp` (4 changes)

1. **Key message type**: `tui:key-msg` -> `tui:key-press-msg` (method specializer)
2. **Key accessor**: `tui:key-msg-key` -> `tui:key-event-code`
3. **Program creation**: `(tui:make-program model :alt-screen t)` -> `(tui:make-program model)`
4. **View return**: plain string -> `(tui:make-view <string> :alt-screen t)`

### Unchanged APIs (no migration needed)

- `tui:colored`, `tui:bold` -- styling
- `tui:render-border`, `tui:*border-rounded*` -- borders
- `tui:join-horizontal`, `tui:join-vertical`, `tui:place-vertical` -- layout
- `tui:batch`, `tui:tick`, `tui:quit-cmd` -- commands
- `tui:window-size-msg`, `tui:window-size-msg-width` -- window events
- `tui:defmessage`, `tui:update-message`, `tui:init`, `tui:view`, `tui:run` -- TEA core
- Color constants (`tui:*fg-red*`, etc.)

## Testing

- All 77 existing tests must pass (pure functions, no TUI dependency)
- Manual smoke test: launch TUI, verify key handling, refresh, quit

## Out of Scope (phase 2)

- Border gradients for weather cards
- `light-dark` for theme-aware colors
- Dynamic window title via `make-view :window-title`
- Compositing system
