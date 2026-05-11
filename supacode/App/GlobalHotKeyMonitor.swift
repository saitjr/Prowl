import AppKit
import Carbon
import Foundation

private enum GlobalHotKeyMonitorConstants {
  static let signature = OSType(0x5052574C)  // PRWL
}

struct GlobalHotKeyRegistrar {
  var installEventHandler: (
    EventHandlerUPP,
    UnsafeMutableRawPointer?,
    inout EventHandlerRef?
  ) -> OSStatus
  var removeEventHandler: (EventHandlerRef) -> Void
  var registerHotKey: (
    GlobalHotKeyDescriptor,
    EventHotKeyID,
    inout EventHotKeyRef?
  ) -> OSStatus
  var unregisterHotKey: (EventHotKeyRef) -> Void

  static let live = GlobalHotKeyRegistrar(
    installEventHandler: { eventHandler, userData, eventHandlerRef in
      var eventType = GlobalHotKeyMonitor.eventType
      return InstallEventHandler(
        GetApplicationEventTarget(),
        eventHandler,
        1,
        &eventType,
        userData,
        &eventHandlerRef
      )
    },
    removeEventHandler: { eventHandlerRef in
      RemoveEventHandler(eventHandlerRef)
    },
    registerHotKey: { descriptor, hotKeyID, hotKeyRef in
      RegisterEventHotKey(
        descriptor.keyCode,
        descriptor.carbonModifiers,
        hotKeyID,
        GetApplicationEventTarget(),
        0,
        &hotKeyRef
      )
    },
    unregisterHotKey: { hotKeyRef in
      UnregisterEventHotKey(hotKeyRef)
    }
  )
}

@MainActor
final class GlobalHotKeyMonitor {
  typealias Handler = @MainActor () -> Void

  static let eventType = EventTypeSpec(
    eventClass: OSType(kEventClassKeyboard),
    eventKind: UInt32(kEventHotKeyPressed)
  )
  private static let eventHandler: EventHandlerUPP = { _, event, userData in
    guard let userData else { return noErr }
    let monitor = Unmanaged<GlobalHotKeyMonitor>.fromOpaque(userData).takeUnretainedValue()
    return monitor.handleCarbonEvent(event)
  }

  private let logger = SupaLogger("HotkeyWindow")
  private let notificationCenter: NotificationCenter
  private let registrar: GlobalHotKeyRegistrar
  private var eventHandlerRef: EventHandlerRef?
  private var hotKeyRef: EventHotKeyRef?
  private var handler: Handler?
  private var binding: Keybinding?
  private var didFinishLaunchingObserver: NSObjectProtocol?
  private var didBecomeActiveObserver: NSObjectProtocol?

  init(
    notificationCenter: NotificationCenter = .default,
    registrar: GlobalHotKeyRegistrar = .live
  ) {
    self.notificationCenter = notificationCenter
    self.registrar = registrar
    configureRecoveryObservers()
  }

  func register(
    binding: Keybinding?,
    handler: @escaping Handler
  ) {
    self.handler = handler
    self.binding = binding
    unregisterHotKey()

    guard binding?.globalHotKeyDescriptor != nil else {
      return
    }

    attemptRegistration(source: "register")
  }

  func unregister() {
    unregisterHotKey()
    if let eventHandlerRef {
      registrar.removeEventHandler(eventHandlerRef)
      self.eventHandlerRef = nil
    }
    binding = nil
    handler = nil
  }

  private func configureRecoveryObservers() {
    didFinishLaunchingObserver = notificationCenter.addObserver(
      forName: NSApplication.didFinishLaunchingNotification,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.retryRegistrationIfNeeded(source: "didFinishLaunching")
      }
    }
    didBecomeActiveObserver = notificationCenter.addObserver(
      forName: NSApplication.didBecomeActiveNotification,
      object: nil,
      queue: nil
    ) { [weak self] _ in
      MainActor.assumeIsolated {
        self?.retryRegistrationIfNeeded(source: "didBecomeActive")
      }
    }
  }

  private func retryRegistrationIfNeeded(source: String) {
    guard hotKeyRef == nil, binding?.globalHotKeyDescriptor != nil else { return }
    attemptRegistration(source: source)
  }

  private func attemptRegistration(source: String) {
    guard let descriptor = binding?.globalHotKeyDescriptor else { return }
    guard installEventHandlerIfNeeded(source: source) else { return }

    let hotKeyID = EventHotKeyID(signature: GlobalHotKeyMonitorConstants.signature, id: 1)
    var hotKeyRef: EventHotKeyRef?
    let status = registrar.registerHotKey(descriptor, hotKeyID, &hotKeyRef)

    guard status == noErr, let hotKeyRef else {
      logger.warning("Failed to register global hotkey status=\(status) source=\(source)")
      return
    }

    self.hotKeyRef = hotKeyRef
  }

  private func installEventHandlerIfNeeded(source: String) -> Bool {
    guard eventHandlerRef == nil else { return true }

    let pointer = Unmanaged.passUnretained(self).toOpaque()
    var eventHandlerRef: EventHandlerRef?
    let status = registrar.installEventHandler(
      Self.eventHandler,
      pointer,
      &eventHandlerRef
    )

    guard status == noErr, let eventHandlerRef else {
      logger.warning("Failed to install global hotkey handler status=\(status) source=\(source)")
      return false
    }

    self.eventHandlerRef = eventHandlerRef
    return true
  }

  private func unregisterHotKey() {
    if let hotKeyRef {
      registrar.unregisterHotKey(hotKeyRef)
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
