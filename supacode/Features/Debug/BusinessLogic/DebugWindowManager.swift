import AppKit
import ComposableArchitecture
import SwiftUI

#if DEBUG

  /// Manages the singleton Debug Window. Lifecycle mirrors
  /// `SettingsWindowManager`: cache the `NSWindow`, deminiaturise +
  /// front it on subsequent shows, never release on close so opening
  /// is cheap. Configured once during app bootstrap with the root
  /// store so the window can mirror the user's appearance setting.
  @MainActor
  final class DebugWindowManager {
    static let shared = DebugWindowManager()

    private var window: NSWindow?
    private var store: StoreOf<AppFeature>?

    private init() {}

    private func applyWindowConfiguration(_ window: NSWindow, colorScheme: ColorScheme?) {
      let resolvedAppearance = WindowAppearanceResolver.appearance(for: colorScheme)
      if window.appearance?.name != resolvedAppearance?.name {
        window.appearance = resolvedAppearance
      }
    }

    func configure(store: StoreOf<AppFeature>) {
      self.store = store
    }

    func updateAppearance(colorScheme: ColorScheme?) {
      guard let window else { return }
      applyWindowConfiguration(window, colorScheme: colorScheme)
    }

    func show() {
      if let existing = window {
        if let store {
          applyWindowConfiguration(existing, colorScheme: store.settings.appearanceMode.colorScheme)
        }
        if existing.isMiniaturized {
          existing.deminiaturize(nil)
        }
        existing.makeKeyAndOrderFront(nil)
        return
      }

      guard let store else { return }
      let host = NSHostingController(rootView: DebugView(store: store))
      let new = NSWindow(contentViewController: host)
      new.title = "Prowl Debug"
      new.identifier = NSUserInterfaceItemIdentifier("debug")
      new.styleMask = [.titled, .closable, .miniaturizable, .resizable]
      new.tabbingMode = .disallowed
      new.toolbarStyle = .unified
      new.toolbar = NSToolbar(identifier: "DebugToolbar")
      if #unavailable(macOS 15.0) {
        new.toolbar?.showsBaselineSeparator = false
      }
      new.isReleasedWhenClosed = false
      new.setContentSize(NSSize(width: 800, height: 600))
      new.minSize = NSSize(width: 700, height: 500)
      applyWindowConfiguration(new, colorScheme: store.settings.appearanceMode.colorScheme)
      new.center()
      new.makeKeyAndOrderFront(nil)
      window = new
    }
  }

#endif
