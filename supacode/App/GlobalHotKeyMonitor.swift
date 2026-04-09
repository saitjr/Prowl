import Carbon
import Foundation

private enum GlobalHotKeyMonitorConstants {
  static let signature = OSType(0x5052574C)  // PRWL
}

@MainActor
final class GlobalHotKeyMonitor {
  typealias Handler = @MainActor () -> Void

  private static let eventType = EventTypeSpec(
    eventClass: OSType(kEventClassKeyboard),
    eventKind: UInt32(kEventHotKeyPressed)
  )
  private static let eventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else { return noErr }
    let monitor = Unmanaged<GlobalHotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
    return monitor.handleCarbonEvent(event)
  }

  private let logger = SupaLogger("HotkeyWindow")
  private var eventHandlerRef: EventHandlerRef?
  private var hotKeyRef: EventHotKeyRef?
  private var handler: Handler?

  func register(
    binding: Keybinding?,
    handler: @escaping Handler
  ) {
    self.handler = handler
    unregisterHotKey()

    guard let descriptor = binding?.globalHotKeyDescriptor else {
      return
    }

    installEventHandlerIfNeeded()

    let hotKeyID = EventHotKeyID(signature: GlobalHotKeyMonitorConstants.signature, id: 1)
    let status = RegisterEventHotKey(
      descriptor.keyCode,
      descriptor.carbonModifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )

    if status != noErr {
      logger.warning("Failed to register global hotkey status=\(status)")
    }
  }

  func unregister() {
    unregisterHotKey()
    if let eventHandlerRef {
      RemoveEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }
    handler = nil
  }

  private func installEventHandlerIfNeeded() {
    guard eventHandlerRef == nil else { return }

    let pointer = Unmanaged.passUnretained(self).toOpaque()
    var eventType = Self.eventType
    let status = InstallEventHandler(
      GetApplicationEventTarget(),
      Self.eventHandler,
      1,
      &eventType,
      pointer,
      &eventHandlerRef
    )
    if status != noErr {
      logger.warning("Failed to install global hotkey handler status=\(status)")
    }
  }

  private func unregisterHotKey() {
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
  }

  nonisolated private func handleCarbonEvent(_ event: EventRef?) -> OSStatus {
    guard let event else { return noErr }
    let signature = OSType(0x5052574C)

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
      event,
      EventParamName(kEventParamDirectObject),
      EventParamType(typeEventHotKeyID),
      nil,
      MemoryLayout<EventHotKeyID>.size,
      nil,
      &hotKeyID
    )

    guard status == noErr, hotKeyID.signature == signature else {
      return noErr
    }

    Task { @MainActor in
      self.handler?()
    }

    return noErr
  }
}
