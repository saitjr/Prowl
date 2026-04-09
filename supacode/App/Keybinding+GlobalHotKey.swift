import Carbon
import Foundation

nonisolated struct GlobalHotKeyDescriptor: Equatable, Sendable {
  let keyCode: UInt32
  let carbonModifiers: UInt32
}

extension KeybindingModifiers {
  var carbonModifiers: UInt32 {
    var modifiers: UInt32 = 0
    if command {
      modifiers |= UInt32(cmdKey)
    }
    if shift {
      modifiers |= UInt32(shiftKey)
    }
    if option {
      modifiers |= UInt32(optionKey)
    }
    if control {
      modifiers |= UInt32(controlKey)
    }
    return modifiers
  }
}

extension Keybinding {
  var globalHotKeyDescriptor: GlobalHotKeyDescriptor? {
    guard let keyCode = globalHotKeyKeyCode else { return nil }
    return GlobalHotKeyDescriptor(
      keyCode: UInt32(keyCode),
      carbonModifiers: modifiers.carbonModifiers
    )
  }

  private var globalHotKeyKeyCode: UInt16? {
    switch key {
    case "space":
      return UInt16(kVK_Space)
    case "return":
      return UInt16(kVK_Return)
    case "arrow_up":
      return UInt16(kVK_UpArrow)
    case "arrow_down":
      return UInt16(kVK_DownArrow)
    case "arrow_left":
      return UInt16(kVK_LeftArrow)
    case "arrow_right":
      return UInt16(kVK_RightArrow)
    case "`":
      return UInt16(kVK_ANSI_Grave)
    case "-":
      return UInt16(kVK_ANSI_Minus)
    case "=":
      return UInt16(kVK_ANSI_Equal)
    case "[":
      return UInt16(kVK_ANSI_LeftBracket)
    case "]":
      return UInt16(kVK_ANSI_RightBracket)
    case "\\":
      return UInt16(kVK_ANSI_Backslash)
    case ";":
      return UInt16(kVK_ANSI_Semicolon)
    case "'":
      return UInt16(kVK_ANSI_Quote)
    case ",":
      return UInt16(kVK_ANSI_Comma)
    case ".":
      return UInt16(kVK_ANSI_Period)
    case "/":
      return UInt16(kVK_ANSI_Slash)
    case "0", "digit_0":
      return UInt16(kVK_ANSI_0)
    case "1", "digit_1":
      return UInt16(kVK_ANSI_1)
    case "2", "digit_2":
      return UInt16(kVK_ANSI_2)
    case "3", "digit_3":
      return UInt16(kVK_ANSI_3)
    case "4", "digit_4":
      return UInt16(kVK_ANSI_4)
    case "5", "digit_5":
      return UInt16(kVK_ANSI_5)
    case "6", "digit_6":
      return UInt16(kVK_ANSI_6)
    case "7", "digit_7":
      return UInt16(kVK_ANSI_7)
    case "8", "digit_8":
      return UInt16(kVK_ANSI_8)
    case "9", "digit_9":
      return UInt16(kVK_ANSI_9)
    default:
      guard key.count == 1, let scalar = key.unicodeScalars.first else { return nil }
      switch scalar {
      case "a": return UInt16(kVK_ANSI_A)
      case "b": return UInt16(kVK_ANSI_B)
      case "c": return UInt16(kVK_ANSI_C)
      case "d": return UInt16(kVK_ANSI_D)
      case "e": return UInt16(kVK_ANSI_E)
      case "f": return UInt16(kVK_ANSI_F)
      case "g": return UInt16(kVK_ANSI_G)
      case "h": return UInt16(kVK_ANSI_H)
      case "i": return UInt16(kVK_ANSI_I)
      case "j": return UInt16(kVK_ANSI_J)
      case "k": return UInt16(kVK_ANSI_K)
      case "l": return UInt16(kVK_ANSI_L)
      case "m": return UInt16(kVK_ANSI_M)
      case "n": return UInt16(kVK_ANSI_N)
      case "o": return UInt16(kVK_ANSI_O)
      case "p": return UInt16(kVK_ANSI_P)
      case "q": return UInt16(kVK_ANSI_Q)
      case "r": return UInt16(kVK_ANSI_R)
      case "s": return UInt16(kVK_ANSI_S)
      case "t": return UInt16(kVK_ANSI_T)
      case "u": return UInt16(kVK_ANSI_U)
      case "v": return UInt16(kVK_ANSI_V)
      case "w": return UInt16(kVK_ANSI_W)
      case "x": return UInt16(kVK_ANSI_X)
      case "y": return UInt16(kVK_ANSI_Y)
      case "z": return UInt16(kVK_ANSI_Z)
      default:
        return nil
      }
    }
  }
}
