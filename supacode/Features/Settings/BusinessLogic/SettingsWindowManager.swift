import AppKit
import ComposableArchitecture
import SwiftUI

@MainActor
final class SettingsWindowManager {
  static let shared = SettingsWindowManager()

  private var settingsWindow: NSWindow?
  private var store: StoreOf<AppFeature>?
  private var ghosttyShortcuts: GhosttyShortcutManager?
  private var commandKeyObserver: CommandKeyObserver?

  private init() {}

  private func applyWindowConfiguration(_ window: NSWindow, colorScheme: ColorScheme?) {
    window.tabbingMode = .disallowed
    window.level = .normal
    let resolvedAppearance = WindowAppearanceResolver.appearance(for: colorScheme)
    if window.appearance?.name != resolvedAppearance?.name {
      window.appearance = resolvedAppearance
    }
  }

  func configure(
    store: StoreOf<AppFeature>,
    ghosttyShortcuts: GhosttyShortcutManager,
    commandKeyObserver: CommandKeyObserver
  ) {
    self.store = store
    self.ghosttyShortcuts = ghosttyShortcuts
    self.commandKeyObserver = commandKeyObserver
  }

  func updateAppearance(colorScheme: ColorScheme?) {
    guard let settingsWindow else { return }
    applyWindowConfiguration(settingsWindow, colorScheme: colorScheme)
  }

  func show() {
    if let existingWindow = settingsWindow {
      if let store {
        applyWindowConfiguration(existingWindow, colorScheme: store.settings.appearanceMode.colorScheme)
      }
      if existingWindow.isMiniaturized {
        existingWindow.deminiaturize(nil)
      }
      existingWindow.makeKeyAndOrderFront(nil)
      return
    }

    guard let store, let ghosttyShortcuts, let commandKeyObserver else {
      return
    }
    let settingsView = SettingsView(store: store)
      .environment(ghosttyShortcuts)
      .environment(commandKeyObserver)
    let hostingController = NSHostingController(rootView: settingsView)

    let window = NSWindow(contentViewController: hostingController)
    window.title = ""
    window.titleVisibility = .hidden
    window.identifier = NSUserInterfaceItemIdentifier("settings")
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
    window.titlebarAppearsTransparent = true
    window.toolbarStyle = .unified
    window.toolbar = NSToolbar(identifier: "SettingsToolbar")
    if #unavailable(macOS 15.0) {
      window.toolbar?.showsBaselineSeparator = false
    }
    window.isReleasedWhenClosed = false
    window.setContentSize(NSSize(width: 800, height: 600))
    window.minSize = NSSize(width: 750, height: 500)
    applyWindowConfiguration(window, colorScheme: store.settings.appearanceMode.colorScheme)

    window.center()
    window.makeKeyAndOrderFront(nil)

    settingsWindow = window
  }
}
