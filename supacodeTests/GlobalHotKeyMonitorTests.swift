import AppKit
import Carbon
import Foundation
import Testing

@testable import supacode

@MainActor
struct GlobalHotKeyMonitorTests {
  @Test func retriesRegistrationAfterLaunchWhenInitialAttemptFails() async {
    let registrar = TestGlobalHotKeyRegistrar(registerStatuses: [-1, noErr])
    let monitor = GlobalHotKeyMonitor(
      notificationCenter: registrar.notificationCenter,
      registrar: registrar.makeRegistrar()
    )

    monitor.register(binding: Self.binding) {}
    #expect(registrar.installCallCount == 1)
    #expect(registrar.registerCallCount == 1)

    registrar.notificationCenter.post(name: NSApplication.didFinishLaunchingNotification, object: nil)
    await Task.yield()

    #expect(registrar.installCallCount == 1)
    #expect(registrar.registerCallCount == 2)
  }

  @Test func retriesAgainWhenAppBecomesActiveAndLaunchRetryStillFails() async {
    let registrar = TestGlobalHotKeyRegistrar(registerStatuses: [-1, -2, noErr])
    let monitor = GlobalHotKeyMonitor(
      notificationCenter: registrar.notificationCenter,
      registrar: registrar.makeRegistrar()
    )

    monitor.register(binding: Self.binding) {}
    registrar.notificationCenter.post(name: NSApplication.didFinishLaunchingNotification, object: nil)
    await Task.yield()
    registrar.notificationCenter.post(name: NSApplication.didBecomeActiveNotification, object: nil)
    await Task.yield()

    #expect(registrar.installCallCount == 1)
    #expect(registrar.registerCallCount == 3)
  }

  @Test func doesNotRetryWhenRegistrationAlreadySucceeded() async {
    let registrar = TestGlobalHotKeyRegistrar(registerStatuses: [noErr])
    let monitor = GlobalHotKeyMonitor(
      notificationCenter: registrar.notificationCenter,
      registrar: registrar.makeRegistrar()
    )

    monitor.register(binding: Self.binding) {}
    registrar.notificationCenter.post(name: NSApplication.didFinishLaunchingNotification, object: nil)
    await Task.yield()
    registrar.notificationCenter.post(name: NSApplication.didBecomeActiveNotification, object: nil)
    await Task.yield()

    #expect(registrar.installCallCount == 1)
    #expect(registrar.registerCallCount == 1)
  }

  private static let binding = Keybinding(
    key: "space",
    modifiers: KeybindingModifiers(shift: true)
  )
}

@MainActor
private final class TestGlobalHotKeyRegistrar {
  let notificationCenter = NotificationCenter()

  var installCallCount = 0
  var removeHandlerCallCount = 0
  var registerCallCount = 0
  var unregisterCallCount = 0
  var registerStatuses: [OSStatus]

  init(registerStatuses: [OSStatus]) {
    self.registerStatuses = registerStatuses
  }

  func makeRegistrar() -> GlobalHotKeyRegistrar {
    GlobalHotKeyRegistrar(
      installEventHandler: { _, _, eventHandlerRef in
        self.installCallCount += 1
        eventHandlerRef = Self.makeEventHandlerRef()
        return noErr
      },
      removeEventHandler: { _ in
        self.removeHandlerCallCount += 1
      },
      registerHotKey: { _, _, hotKeyRef in
        self.registerCallCount += 1
        let status = self.registerStatuses.isEmpty ? noErr : self.registerStatuses.removeFirst()
        if status == noErr {
          hotKeyRef = Self.makeEventHotKeyRef()
        }
        return status
      },
      unregisterHotKey: { _ in
        self.unregisterCallCount += 1
      }
    )
  }

  private static func makeEventHandlerRef() -> EventHandlerRef {
    unsafeBitCast(UnsafeMutableRawPointer(bitPattern: 0x1)!, to: EventHandlerRef.self)
  }

  private static func makeEventHotKeyRef() -> EventHotKeyRef {
    unsafeBitCast(UnsafeMutableRawPointer(bitPattern: 0x2)!, to: EventHotKeyRef.self)
  }
}
