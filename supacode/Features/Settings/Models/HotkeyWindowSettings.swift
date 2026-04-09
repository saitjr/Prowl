import Foundation

nonisolated struct HotkeyWindowSettings: Codable, Equatable, Sendable {
  static let widthRatioRange = 0.3 ... 1.0
  static let heightRatioRange = 0.25 ... 1.0

  var isEnabled: Bool
  var hotkey: Keybinding?
  var widthRatio: Double
  var heightRatio: Double

  static let `default` = HotkeyWindowSettings(
    isEnabled: false,
    hotkey: Keybinding(
      key: "`",
      modifiers: KeybindingModifiers(command: true, control: true)
    ),
    widthRatio: 1,
    heightRatio: 2.0 / 3.0
  )

  init(
    isEnabled: Bool,
    hotkey: Keybinding?,
    widthRatio: Double,
    heightRatio: Double
  ) {
    self.isEnabled = isEnabled
    self.hotkey = hotkey
    self.widthRatio = widthRatio
    self.heightRatio = heightRatio
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? Self.default.isEnabled
    hotkey = try container.decodeIfPresent(Keybinding.self, forKey: .hotkey) ?? Self.default.hotkey
    widthRatio = try container.decodeIfPresent(Double.self, forKey: .widthRatio) ?? Self.default.widthRatio
    heightRatio = try container.decodeIfPresent(Double.self, forKey: .heightRatio) ?? Self.default.heightRatio
    self = normalized
  }

  var normalized: Self {
    var copy = self
    copy.widthRatio = widthRatio.clamped(to: Self.widthRatioRange)
    copy.heightRatio = heightRatio.clamped(to: Self.heightRatioRange)
    return copy
  }
}

private extension Double {
  nonisolated func clamped(to range: ClosedRange<Double>) -> Double {
    min(max(self, range.lowerBound), range.upperBound)
  }
}
