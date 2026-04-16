import CoreGraphics
import Foundation
import Testing

@testable import supacode

struct WindowFrameAutosaveSanitizerTests {
  @Test func sanitizeStoredFramesRemovesImplausibleMainWindowFrame() {
    let defaults = makeDefaults()
    defer { tearDown(defaults) }

    defaults.set(
      "0 0 100286 1130 0 0 1800 1130 ",
      forKey: WindowFrameAutosaveSanitizer.autosaveKey("main")
    )

    WindowFrameAutosaveSanitizer.sanitizeStoredFrames(
      userDefaults: defaults,
      screens: [CGRect(x: 0, y: 0, width: 1800, height: 1130)]
    )

    #expect(defaults.string(forKey: WindowFrameAutosaveSanitizer.autosaveKey("main")) == nil)
  }

  @Test func sanitizeStoredFramesKeepsPlausibleMainWindowFrame() {
    let defaults = makeDefaults()
    defer { tearDown(defaults) }

    let key = WindowFrameAutosaveSanitizer.autosaveKey("main")
    let storedFrame = "120 80 1440 900 0 0 1800 1130 "
    defaults.set(storedFrame, forKey: key)

    WindowFrameAutosaveSanitizer.sanitizeStoredFrames(
      userDefaults: defaults,
      screens: [CGRect(x: 0, y: 0, width: 1800, height: 1130)]
    )

    #expect(defaults.string(forKey: key) == storedFrame)
  }

  @Test func sanitizedFrameRecentersOversizedWindowWithinVisibleFrame() {
    let correctedFrame = WindowFrameAutosaveSanitizer.sanitizedFrame(
      CGRect(x: 0, y: 0, width: 100286, height: 1130),
      minimumSize: CGSize(width: 750, height: 500),
      screens: [CGRect(x: 0, y: 0, width: 1800, height: 1130)],
      visibleFrames: [CGRect(x: 0, y: 0, width: 1800, height: 1130)]
    )

    #expect(correctedFrame == CGRect(x: 90, y: 0, width: 1620, height: 1130))
  }

  private func makeDefaults() -> UserDefaults {
    let suiteName = "WindowFrameAutosaveSanitizerTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
      Issue.record("Unable to create isolated UserDefaults suite")
      fatalError("Unable to create isolated UserDefaults suite")
    }
    defaults.set(suiteName, forKey: "test-suite-name")
    return defaults
  }

  private func tearDown(_ defaults: UserDefaults) {
    guard let suiteName = defaults.string(forKey: "test-suite-name") else { return }
    defaults.removePersistentDomain(forName: suiteName)
  }
}
