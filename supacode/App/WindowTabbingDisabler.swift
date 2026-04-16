import AppKit
import SwiftUI

struct WindowTabbingDisabler: NSViewRepresentable {
  func makeNSView(context: Context) -> WindowTabbingView {
    WindowTabbingView()
  }

  func updateNSView(_ nsView: WindowTabbingView, context: Context) {
    nsView.disallowTabbing()
  }
}

final class WindowTabbingView: NSView, NSWindowDelegate {
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    disallowTabbing()
  }

  func disallowTabbing() {
    guard let window else { return }
    window.tabbingMode = .disallowed
    window.identifier = NSUserInterfaceItemIdentifier("main")
    WindowFrameAutosaveSanitizer.sanitizeAttachedWindow(window)
    if window.delegate !== self {
      window.delegate = self
    }
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    sender.orderOut(nil)
    return false
  }

  func windowDidResize(_ notification: Notification) {
    guard let window else { return }
    WindowFrameAutosaveSanitizer.sanitizeAttachedWindow(window)
  }

  func windowDidChangeScreen(_ notification: Notification) {
    guard let window else { return }
    WindowFrameAutosaveSanitizer.sanitizeAttachedWindow(window)
  }
}
