# Hotkey Window Implementation Plan

**Goal:** Add an iTerm2-style dedicated hotkey panel to Prowl that can quickly show or hide a separate hotkey terminal window on the current active display, while keeping the hotkey shortcut and size rules configurable from a dedicated Settings section.

**Point-Free / TCA note:** Per repo guidance, this kind of feature should ideally be planned with pointfree/TCA skills first. That skill is not available in the current session, so implementation follows the existing local architecture patterns already used in `AppFeature`, `SettingsFeature`, and AppKit-backed window managers.

## Requirement Understanding

The original request started as "reuse the current app window", but repeated testing against macOS Spaces showed that reusing the main window is not stable enough. The revised requirement follows the same model used by iTerm2's dedicated hotkey window:

- A shortcut should toggle the current app quickly.
- Showing the app should happen on the user's current active display/context.
- It should avoid the current behavior where macOS jumps to whichever Prowl window/Space already exists, because that reorders context and feels disruptive in multi-display workflows.
- The stable way to achieve that is to use a dedicated hotkey panel instead of reusing the main app window.
- The shown window should be laid out by ratio, not fixed pixels, because different displays have different sizes.
- The size/position behavior should be configurable in Settings.
- Settings should expose a dedicated Hotkey Window section, not bury this feature inside unrelated settings.

## Existing Behavior Analysis

### Current main-window activation

- `SupacodeAppDelegate.showMainWindow(from:)` and `SupacodeApp.bringMainWindowToFront()` both use:
  - `NSApplication.activate(ignoringOtherApps: true)`
  - `window.makeKeyAndOrderFront(nil)`
- This always reuses the existing main window as-is.
- If that window lives on another display or another Space, macOS can pull focus there, which is the disruption described in the requirement.
- Multiple rounds of experimentation confirmed that even aggressive hide/orderOut/Space-observer logic is not enough to make this path reliable across Space transitions.

### Existing settings and shortcut infrastructure

- Global app settings already flow through `GlobalSettings` -> `SettingsFeature.State` -> `@Shared(.settingsFile)`.
- User-configurable app shortcuts already exist via:
  - `AppShortcuts`
  - `KeybindingSchemaDocument`
  - `KeybindingUserOverrideStore`
  - `ShortcutsSettingsView`
- There is currently no dedicated global hotkey registration layer.
- Existing shortcuts are app/menu-oriented; they are not enough by themselves for hotkey-window-style toggling from outside the app.

### Existing window management shape

- Main window is a single `Window("Prowl", id: "main")`.
- Settings already uses an AppKit manager class (`SettingsWindowManager`) instead of forcing all window behavior through TCA state.
- Ghostty surface views support attachment changes, which makes a separate AppKit hotkey panel feasible as long as the panel owns the visible surface attachment while it is shown.
- That makes a separate AppKit hotkey-window manager a good fit for the new behavior.

## Technical Plan

### 1. Use a dedicated panel instead of the main window

Introduce a dedicated manager responsible for:

- registering/unregistering the hotkey
- toggling visibility
- computing the target frame on the active display
- creating and destroying a dedicated `NSPanel`
- showing that panel on the current Space without reusing the main window's old screen/Space placement

This keeps `AppFeature` focused on state and keeps AppKit window behavior in one place.

### 2. Decide "active display" by explicit strategy

To avoid pulling the user to the wrong display:

- when showing from hidden/inactive state, use the screen containing the current mouse location as the target display
- fall back to the current key/main window screen if needed
- fall back again to `NSScreen.main` / first screen

This is an approximation of "current active display" that does not require Accessibility permission and is good enough for the first implementation.

### 3. Layout by ratio instead of fixed size

Add a pure layout model for the hotkey window:

- width ratio: `0...1`
- height ratio: `0...1`
- horizontal anchor: start with centered width
- vertical anchor: start with bottom-aligned

Initial supported behavior matches the request:

- width can be `1.0` for full screen width
- height can be `2/3`
- vertical alignment is bottom

Window frame should be recomputed every time the hotkey window is shown, based on the target screen's visible frame.

### 4. Dedicated settings section

Add a new Settings section:

- label: `Hotkey Window`
- contains:
  - enable toggle
  - hotkey recorder
  - width ratio
  - height ratio
  - bottom alignment description/preview text

The hotkey recorder should be editable directly in this section instead of forcing users to jump to the global Shortcuts page.

### 5. Reuse keybinding model, add global registration adapter

Use the existing `Keybinding` data model for persistence, then add a small adapter that can:

- convert `Keybinding` to Carbon hotkey registration data
- map modifier flags to Carbon modifiers
- map stored key tokens to key codes

This avoids inventing a second shortcut format.

### 6. Keep the first version narrow

In scope for this implementation:

- toggle a dedicated hotkey panel
- move/layout it on the target display before showing
- auto-hide it when the panel loses focus
- dedicated Settings section
- tests for pure logic and persistence

Out of scope for this first pass:

- a second hotkey profile or multiple panel presets
- per-display saved presets
- arbitrary docking/alignment presets beyond the current bottom-aligned ratio layout
- Accessibility-driven detection of the true frontmost foreign app window frame

## Implementation Steps

1. Add new hotkey-window settings data to `GlobalSettings` and `SettingsFeature`.
2. Add pure models/utilities for:
   - hotkey window configuration
   - screen selection
   - ratio-based frame calculation
3. Add a global hotkey registration manager based on Carbon.
4. Add an AppKit hotkey-window manager that creates a dedicated hotkey panel using the calculated frame.
5. Wire the manager into `supacodeApp.swift`.
6. Add a dedicated `Hotkey Window` settings section and view.
7. Ensure Ghostty surface hosting can reattach cleanly between the main window and the hotkey panel.
8. Add tests for settings persistence, shortcut mapping, and frame calculation.
9. Run build/tests/lint and then commit only the relevant changes.

## Progress

- [x] Requirement clarified and current code paths inspected.
- [x] Existing settings, shortcut, and window activation architecture analyzed.
- [x] Plan document created under `docs/`.
- [x] Hotkey-window settings model implemented.
- [x] Global hotkey registration implemented.
- [x] Active-display layout logic implemented.
- [x] Dedicated Hotkey Window settings UI implemented.
- [x] Dedicated hotkey panel implementation in progress on a clean branch from `main`.
- [x] Tests added.
- [ ] Tests passing.
- [x] `make build-app` completed.
- [ ] Changes committed.

### Validation Status

- `git diff --check` passes.
- `swift build --product prowl` completed successfully as part of `make build-app`.
- `mise trust` has been completed for this repository.
- direct `swiftlint --fix --quiet && swiftlint lint --quiet --config .swiftlint.yml` passes.
- On the fresh `feature/hotkey-panel` branch, `make build-app` and `make lint` both pass with the dedicated panel implementation wired in.
- The panel implementation also adds explicit Ghostty surface reattachment support so the visible terminal surface can migrate between the main window and the hotkey panel cleanly.
- After the first runtime test on the dedicated panel branch, a crash on re-show was traced to a missing `GhosttyShortcutManager` SwiftUI environment in the panel content tree. The panel root now mirrors the main window's environment injection for `ghosttyShortcuts`, `resolvedKeybindings`, and terminal surface opacity, and `make build-app` / `make lint` still pass after that fix.
- The panel content now reuses the full `ContentView` instead of rendering only `WorktreeDetailView`, so the hotkey panel keeps the same sidebar and `Add Repo` affordances as the main window.
- A later runtime issue showed that rebuilding the panel on every toggle and letting hidden windows unconditionally reattach `GhosttySurfaceView` instances caused panel lag and stale/blank terminal content after switching Spaces. The hotkey panel is now reused across show/hide cycles, and surface reattachment is restricted so only the currently visible window can take ownership from another host.
- Hotkey recording and global registration now support the `space` key explicitly, so shortcuts such as `Shift+Space` can be recorded and registered. The unsupported-key message in Hotkey Window settings was also rewritten to be more specific and less abrupt.

## Risks / Watchpoints

- Carbon global hotkey registration needs stable key-token -> keyCode mapping.
- Panel activation on top of an already-visible main window still depends on AppKit focus timing, so manual verification across multiple Spaces remains necessary.
- The app currently has no reusable shortcut recorder component; some extraction from `ShortcutsSettingsView` may be needed to avoid duplicating logic.
