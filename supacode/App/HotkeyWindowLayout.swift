import CoreGraphics
import Foundation

nonisolated struct HotkeyWindowScreenSnapshot: Equatable, Sendable {
  var frame: CGRect
  var visibleFrame: CGRect
  var isPrimary: Bool

  init(
    frame: CGRect,
    visibleFrame: CGRect,
    isPrimary: Bool = false
  ) {
    self.frame = frame
    self.visibleFrame = visibleFrame
    self.isPrimary = isPrimary
  }
}

nonisolated enum HotkeyWindowScreenSelector {
  static func targetScreenIndex(
    mouseLocation: CGPoint,
    screens: [HotkeyWindowScreenSnapshot],
    fallbackWindowFrame: CGRect?
  ) -> Int? {
    if let index = screens.firstIndex(where: { $0.frame.contains(mouseLocation) }) {
      return index
    }
    if let fallbackWindowFrame,
      let index = screens.firstIndex(where: { $0.frame.intersects(fallbackWindowFrame) })
    {
      return index
    }
    if let index = screens.firstIndex(where: \.isPrimary) {
      return index
    }
    return screens.indices.first
  }
}

nonisolated enum HotkeyWindowFrameCalculator {
  private static let minimumUsableFrameWidth: CGFloat = 320
  private static let minimumUsableFrameHeight: CGFloat = 240

  static func frame(
    in availableFrame: CGRect,
    retryingWith retryFrame: CGRect? = nil,
    settings: HotkeyWindowSettings
  ) -> CGRect {
    let normalized = settings.normalized
    let resolvedFrame = resolvedAvailableFrame(
      availableFrame,
      retryingWith: retryFrame,
      settings: normalized
    )
    let width = clampedDimension(
      preferred: resolvedFrame.width * normalized.widthRatio,
      minimum: normalized.minimumWidth,
      container: resolvedFrame.width
    )
    let height = clampedDimension(
      preferred: resolvedFrame.height * normalized.heightRatio,
      minimum: normalized.minimumHeight,
      container: resolvedFrame.height
    )
    let origin = CGPoint(
      x: resolvedFrame.midX - width / 2,
      y: resolvedFrame.minY
    )
    return CGRect(origin: origin, size: CGSize(width: width, height: height)).integral
  }

  private static func resolvedAvailableFrame(
    _ availableFrame: CGRect,
    retryingWith retryFrame: CGRect?,
    settings: HotkeyWindowSettings
  ) -> CGRect {
    if isUsable(frame: availableFrame) {
      return availableFrame
    }

    if let retryFrame, isUsable(frame: retryFrame) {
      return retryFrame
    }

    let origin = fallbackOrigin(primary: availableFrame, retry: retryFrame)
    return CGRect(
      origin: origin,
      size: CGSize(
        width: max(settings.minimumWidth, HotkeyWindowSettings.defaultMinimumWidth),
        height: max(settings.minimumHeight, HotkeyWindowSettings.defaultMinimumHeight)
      )
    )
  }

  private static func isUsable(frame: CGRect) -> Bool {
    guard
      frame.minX.isFinite,
      frame.minY.isFinite,
      frame.width.isFinite,
      frame.height.isFinite
    else {
      return false
    }

    return frame.width >= minimumUsableFrameWidth && frame.height >= minimumUsableFrameHeight
  }

  private static func fallbackOrigin(primary: CGRect, retry: CGRect?) -> CGPoint {
    if primary.minX.isFinite, primary.minY.isFinite {
      return CGPoint(x: primary.minX, y: primary.minY)
    }
    if let retry, retry.minX.isFinite, retry.minY.isFinite {
      return CGPoint(x: retry.minX, y: retry.minY)
    }
    return .zero
  }

  private static func clampedDimension(
    preferred: CGFloat,
    minimum: Double,
    container: CGFloat
  ) -> CGFloat {
    guard container.isFinite, container > 0 else {
      return CGFloat(minimum)
    }
    return min(max(preferred, CGFloat(minimum)), container)
  }
}

nonisolated enum HotkeyWindowDismissalPlanner {
  nonisolated enum RestoreOrder: Equatable, Sendable {
    case restoreThenHide
    case hideThenRestore
  }

  static func shouldDismissWhenActiveSpaceChanges() -> Bool {
    true
  }

  static func shouldDismissWhenWindowResigns() -> Bool {
    false
  }

  static func restoreOrder(
    snapshotFrame: CGRect?,
    currentFrame: CGRect
  ) -> RestoreOrder {
    guard let snapshotFrame else {
      return .restoreThenHide
    }
    return snapshotFrame.equalTo(currentFrame) ? .restoreThenHide : .hideThenRestore
  }
}
