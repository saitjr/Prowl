import AppKit
import SwiftUI
import Testing

@testable import supacode

struct WindowAppearanceResolverTests {
  @Test func nilUsesSystemAppearance() {
    #expect(WindowAppearanceResolver.appearance(for: nil) == nil)
  }

  @Test func lightMapsToAqua() {
    #expect(WindowAppearanceResolver.appearance(for: .light)?.name == .aqua)
  }

  @Test func darkMapsToDarkAqua() {
    #expect(WindowAppearanceResolver.appearance(for: .dark)?.name == .darkAqua)
  }
}
