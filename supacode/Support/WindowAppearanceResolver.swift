import AppKit
import SwiftUI

enum WindowAppearanceResolver {
  static func appearance(for colorScheme: ColorScheme?) -> NSAppearance? {
    switch colorScheme {
    case .none:
      nil
    case .some(let scheme):
      switch scheme {
      case .light:
        NSAppearance(named: .aqua)
      case .dark:
        NSAppearance(named: .darkAqua)
      @unknown default:
        nil
      }
    }
  }
}
