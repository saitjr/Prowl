import AppKit
import SwiftUI

struct WindowTabbingDisabler: NSViewRepresentable {
  func makeNSView(context: Context) -> WindowTabbingView {
    WindowTabbingView()
  }

  func updateNSView(_ nsView: WindowTabbingView, context: Context) {
    nsView.refreshWindowConfigurationIfNeeded()
  }
}

final class WindowTabbingView: NSView, NSWindowDelegate {
  private weak var configuredWindow: NSWindow?
  private var isSchedulingSanitization = false

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    refreshWindowConfigurationIfNeeded()
  }

  func refreshWindowConfigurationIfNeeded() {
    guard let window else { return }
    guard configuredWindow !== window else { return }
    configuredWindow = window

    if window.tabbingMode != .disallowed {
      window.tabbingMode = .disallowed
    }
    let mainIdentifier = NSUserInterfaceItemIdentifier("main")
    if window.identifier != mainIdentifier {
      window.identifier = mainIdentifier
    }
    window.isExcludedFromWindowsMenu = true
    if window.delegate !== self {
      window.delegate = self
    }
    scheduleSanitization()
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    return false
  }

  func windowDidResize(_ notification: Notification) {
    scheduleSanitization()
  }

  func windowDidChangeScreen(_ notification: Notification) {
    scheduleSanitization()
  }

  private func scheduleSanitization() {
    guard !isSchedulingSanitization else { return }
    isSchedulingSanitization = true
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }
      self.isSchedulingSanitization = false
      guard let window = self.window else { return }
      WindowFrameAutosaveSanitizer.sanitizeAttachedWindow(window)
    }
  }
}
