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
  static func frame(
    in availableFrame: CGRect,
    settings: HotkeyWindowSettings
  ) -> CGRect {
    let normalized = settings.normalized
    let width = availableFrame.width * normalized.widthRatio
    let height = availableFrame.height * normalized.heightRatio
    let origin = CGPoint(
      x: availableFrame.midX - width / 2,
      y: availableFrame.minY
    )
    return CGRect(origin: origin, size: CGSize(width: width, height: height)).integral
  }
}

nonisolated enum HotkeyWindowDismissalPlanner {
  nonisolated enum RestoreOrder: Equatable, Sendable {
    case restoreThenHide
    case hideThenRestore
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
