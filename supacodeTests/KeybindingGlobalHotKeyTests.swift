import Carbon
import Testing

@testable import supacode

struct KeybindingGlobalHotKeyTests {
  @Test func letterBindingsMapToCarbonDescriptor() {
    let descriptor = Keybinding(
      key: "k",
      modifiers: KeybindingModifiers(command: true, shift: true)
    ).globalHotKeyDescriptor

    #expect(descriptor?.keyCode == UInt32(kVK_ANSI_K))
    #expect(descriptor?.carbonModifiers == UInt32(cmdKey | shiftKey))
  }

  @Test func punctuationAndSpecialKeysMapToCarbonDescriptor() {
    let grave = Keybinding(
      key: "`",
      modifiers: KeybindingModifiers(command: true, control: true)
    ).globalHotKeyDescriptor
    #expect(grave?.keyCode == UInt32(kVK_ANSI_Grave))

    let leftArrow = Keybinding(
      key: "arrow_left",
      modifiers: KeybindingModifiers(option: true)
    ).globalHotKeyDescriptor
    #expect(leftArrow?.keyCode == UInt32(kVK_LeftArrow))
    #expect(leftArrow?.carbonModifiers == UInt32(optionKey))
  }

  @Test func numberTokensSupportLiteralAndPhysicalDigitForms() {
    let literal = Keybinding(
      key: "1",
      modifiers: KeybindingModifiers(command: true)
    ).globalHotKeyDescriptor
    let physical = Keybinding(
      key: "digit_1",
      modifiers: KeybindingModifiers(command: true)
    ).globalHotKeyDescriptor

    #expect(literal?.keyCode == UInt32(kVK_ANSI_1))
    #expect(physical?.keyCode == UInt32(kVK_ANSI_1))
  }

  @Test func spaceTokenProducesDescriptor() {
    let descriptor = Keybinding(
      key: "space",
      modifiers: KeybindingModifiers(command: true)
    ).globalHotKeyDescriptor

    #expect(descriptor?.keyCode == UInt32(kVK_Space))
    #expect(descriptor?.carbonModifiers == UInt32(cmdKey))
  }
}
