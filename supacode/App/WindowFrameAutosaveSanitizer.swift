import AppKit
import CoreGraphics
import Foundation

enum WindowFrameAutosaveSanitizer {
  private static let oversizedFrameMultiplier: CGFloat = 4

  struct StoredFrameDescriptor: Equatable {
    let windowFrame: CGRect
    let screenFrame: CGRect?
  }

  static func autosaveKey(_ name: String) -> String {
    "NSWindow Frame \(name)"
  }

  static func sanitizeStoredFrames(
    userDefaults: UserDefaults = .standard,
    screens: [CGRect] = NSScreen.screens.map(\.frame)
  ) {
    sanitizeStoredFrame(named: "main", userDefaults: userDefaults, screens: screens)
    sanitizeStoredFrame(named: "DiffWindow", userDefaults: userDefaults, screens: screens)
  }

  static func sanitizeStoredFrame(
    named name: String,
    userDefaults: UserDefaults = .standard,
    screens: [CGRect] = NSScreen.screens.map(\.frame)
  ) {
    let key = autosaveKey(name)
    guard
      let rawValue = userDefaults.string(forKey: key),
      let descriptor = parse(rawValue)
    else {
      return
    }

    guard isPlausible(frame: descriptor.windowFrame, storedScreenFrame: descriptor.screenFrame, screens: screens)
    else {
      userDefaults.removeObject(forKey: key)
      return
    }

    if name == "main",
      descriptor.windowFrame.width < HotkeyWindowSettings.defaultMinimumWidth
        || descriptor.windowFrame.height < HotkeyWindowSettings.defaultMinimumHeight
    {
      userDefaults.removeObject(forKey: key)
      return
    }
  }

  @MainActor
  static func sanitizeAttachedWindow(_ window: NSWindow, screens: [NSScreen] = NSScreen.screens) {
    if window.identifier?.rawValue == "main" {
      let minimumWidth = HotkeyWindowSettings.defaultMinimumWidth
      let minimumHeight = HotkeyWindowSettings.defaultMinimumHeight
      if window.minSize.width < minimumWidth || window.minSize.height < minimumHeight {
        window.minSize = CGSize(
          width: max(window.minSize.width, minimumWidth),
          height: max(window.minSize.height, minimumHeight)
        )
      }
      if window.frame.width < minimumWidth || window.frame.height < minimumHeight {
        let targetVisibleFrame = window.screen?.visibleFrame ?? screens.first?.visibleFrame ?? .null
        if !targetVisibleFrame.isNull {
          let width = min(max(minimumWidth, window.frame.width), targetVisibleFrame.width)
          let height = min(max(minimumHeight, window.frame.height), targetVisibleFrame.height)
          let correctedOrigin = CGPoint(
            x: targetVisibleFrame.midX - (width / 2),
            y: targetVisibleFrame.midY - (height / 2)
          )
          let correctedFrame = CGRect(origin: correctedOrigin, size: CGSize(width: width, height: height)).integral
          window.setFrame(correctedFrame, display: false, animate: false)
        }
      }
    }

    let screenFrames = screens.map(\.frame)
    let visibleFrames = screens.map(\.visibleFrame)
    guard
      let correctedFrame = sanitizedFrame(
        window.frame,
        minimumSize: window.minSize,
        screens: screenFrames,
        visibleFrames: visibleFrames
      )
    else {
      return
    }

    window.setFrame(correctedFrame, display: false, animate: false)
  }

  static func sanitizedFrame(
    _ frame: CGRect,
    minimumSize: CGSize,
    screens: [CGRect],
    visibleFrames: [CGRect]
  ) -> CGRect? {
    guard !isPlausible(frame: frame, storedScreenFrame: nil, screens: screens) else {
      return nil
    }
    guard let targetVisibleFrame = targetVisibleFrame(for: frame, screens: screens, visibleFrames: visibleFrames)
    else {
      return nil
    }

    let width = clampedDimension(
      frame.width,
      minimum: minimumSize.width,
      container: targetVisibleFrame.width
    )
    let height = clampedDimension(
      frame.height,
      minimum: minimumSize.height,
      container: targetVisibleFrame.height
    )
    let origin = CGPoint(
      x: targetVisibleFrame.midX - (width / 2),
      y: targetVisibleFrame.midY - (height / 2)
    )
    return CGRect(origin: origin, size: CGSize(width: width, height: height)).integral
  }

  static func parse(_ rawValue: String) -> StoredFrameDescriptor? {
    let parts = rawValue.split(whereSeparator: \.isWhitespace)
    guard parts.count >= 4 else { return nil }
    let values = parts.compactMap { Double($0) }
    guard values.count == parts.count else { return nil }

    let windowFrame = CGRect(
      x: values[0],
      y: values[1],
      width: values[2],
      height: values[3]
    )
    let screenFrame: CGRect? =
      if values.count >= 8 {
        CGRect(x: values[4], y: values[5], width: values[6], height: values[7])
      } else {
        nil
      }
    return StoredFrameDescriptor(windowFrame: windowFrame, screenFrame: screenFrame)
  }

  static func isPlausible(
    frame: CGRect,
    storedScreenFrame: CGRect?,
    screens: [CGRect]
  ) -> Bool {
    guard
      frame.minX.isFinite,
      frame.minY.isFinite,
      frame.width.isFinite,
      frame.height.isFinite,
      frame.width > 0,
      frame.height > 0
    else {
      return false
    }

    let maxCurrentWidth = screens.map(\.width).max() ?? 0
    let maxCurrentHeight = screens.map(\.height).max() ?? 0
    let referenceWidth = max(maxCurrentWidth, storedScreenFrame?.width ?? 0)
    let referenceHeight = max(maxCurrentHeight, storedScreenFrame?.height ?? 0)

    if referenceWidth > 0, frame.width > referenceWidth * oversizedFrameMultiplier {
      return false
    }
    if referenceHeight > 0, frame.height > referenceHeight * oversizedFrameMultiplier {
      return false
    }

    guard !screens.isEmpty else { return true }
    let unionFrame = screens.reduce(into: CGRect.null) { partialResult, screenFrame in
      partialResult = partialResult.union(screenFrame)
    }
    guard !unionFrame.isNull else { return true }

    let horizontalMargin = max(referenceWidth, unionFrame.width)
    let verticalMargin = max(referenceHeight, unionFrame.height)
    let allowedRegion = unionFrame.insetBy(dx: -horizontalMargin, dy: -verticalMargin)
    return allowedRegion.intersects(frame)
  }

  private static func targetVisibleFrame(
    for frame: CGRect,
    screens: [CGRect],
    visibleFrames: [CGRect]
  ) -> CGRect? {
    guard !visibleFrames.isEmpty else { return nil }
    let matchedIndex = screens.indices.first(where: { index in
      screens[index].intersects(frame) || screens[index].contains(frame.center)
    })
    if let matchedIndex {
      return visibleFrames[matchedIndex]
    }

    return visibleFrames.max { lhs, rhs in
      lhs.width * lhs.height < rhs.width * rhs.height
    }
  }

  private static func clampedDimension(
    _ value: CGFloat,
    minimum: CGFloat,
    container: CGFloat
  ) -> CGFloat {
    guard container.isFinite, container > 0 else { return max(value, minimum) }
    let effectiveMinimum = max(1, min(minimum > 0 ? minimum : 1, container))
    guard value.isFinite, value > 0 else { return effectiveMinimum }
    if value > container {
      return max(effectiveMinimum, container * 0.9)
    }
    return max(effectiveMinimum, value)
  }
}

private extension CGRect {
  var center: CGPoint {
    CGPoint(x: midX, y: midY)
  }
}
