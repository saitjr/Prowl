import AppKit
import Foundation

@MainActor
final class HotkeyWindowManager {
  private struct NotificationObserver {
    let center: NotificationCenter
    let token: NSObjectProtocol
  }

  private struct MainWindowSnapshot {
    let frame: CGRect
    let level: NSWindow.Level
    let collectionBehavior: NSWindow.CollectionBehavior
    let animationBehavior: NSWindow.AnimationBehavior
    let minSize: CGSize
  }

  private static let fallbackMainWindowMinimumSize = CGSize(
    width: HotkeyWindowSettings.defaultMinimumWidth,
    height: HotkeyWindowSettings.defaultMinimumHeight
  )

  static let shared = HotkeyWindowManager()

  private let workspaceNotificationCenter: NotificationCenter
  private let logger = SupaLogger("HotkeyWindow")
  private let hotKeyMonitor = GlobalHotKeyMonitor()
  private var mainWindowProvider: @MainActor () -> NSWindow? = {
    NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" })
  }
  private var settings = HotkeyWindowSettings.default
  private var snapshot: MainWindowSnapshot?
  private var notificationObservers: [NotificationObserver] = []
  private var isTransitioningPresentation = false
  private var isPresentingHotkey = false

  private init(
    workspaceNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter
  ) {
    self.workspaceNotificationCenter = workspaceNotificationCenter
  }

  func configure(
    mainWindowProvider: @escaping @MainActor () -> NSWindow?,
    settings: HotkeyWindowSettings
  ) {
    self.mainWindowProvider = mainWindowProvider
    update(settings: settings)
  }

  func update(settings: HotkeyWindowSettings) {
    self.settings = settings.normalized
    let binding = self.settings.isEnabled ? self.settings.hotkey : nil
    hotKeyMonitor.register(binding: binding) { [weak self] in
      self?.toggle()
    }
    if !self.settings.isEnabled {
      dismissPanel()
      return
    }
    if isPresentingHotkey, let window = mainWindowProvider() {
      layout(window: window)
    }
  }

  func toggle() {
    if isPresentingHotkey || isTransitioningPresentation {
      dismissPanel()
      return
    }
    showPanel()
  }

  func hideIfVisible() {
    guard isPresentingHotkey || isTransitioningPresentation else { return }
    dismissPanel()
  }

  private func showPanel() {
    guard let window = mainWindowProvider() else {
      logger.warning("Unable to resolve main window for hotkey presentation")
      return
    }
    normalizeMainWindowBeforeHotkeyPresentation(window)

    snapshot = MainWindowSnapshot(
      // Always capture the current non-hotkey frame so restoration does not
      // drift to a stale, previously persisted size.
      frame: clampedMainWindowFrame(window.frame, minimumSize: minimumMainWindowSize(for: window)),
      level: window.level,
      collectionBehavior: window.collectionBehavior,
      animationBehavior: window.animationBehavior,
      minSize: window.minSize
    )
    observePresentationLifecycle()

    isTransitioningPresentation = true
    isPresentingHotkey = true
    applyHotkeyPresentation(to: window)
    layout(window: window)
    window.orderFrontRegardless()
    DispatchQueue.main.async { [weak self, weak window] in
      guard let self, let window else { return }
      NSApplication.shared.activate(ignoringOtherApps: true)
      window.makeKeyAndOrderFront(nil)
      self.isTransitioningPresentation = false
    }
  }

  private func dismissPanel() {
    isTransitioningPresentation = false
    guard isPresentingHotkey else { return }
    isPresentingHotkey = false
    guard let window = mainWindowProvider() else {
      clearWindowObservation()
      snapshot = nil
      return
    }
    switch HotkeyWindowDismissalPlanner.restoreOrder(
      snapshotFrame: snapshot?.frame,
      currentFrame: window.frame
    ) {
    case .restoreThenHide:
      restoreMainWindowPresentation(on: window)
      window.orderOut(nil)
    case .hideThenRestore:
      // Hide first so AppKit does not briefly redraw the restored main-window frame
      // on another display while dismissing the hotkey presentation.
      window.orderOut(nil)
      restoreMainWindowPresentation(on: window)
    }
    snapshot = nil
    clearWindowObservation()
  }

  private func applyHotkeyPresentation(to window: NSWindow) {
    window.level = .floating
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    window.animationBehavior = .utilityWindow
  }

  private func restoreMainWindowPresentation(on window: NSWindow) {
    if let snapshot {
      let minimumSize = minimumMainWindowSize(
        fromSnapshot: snapshot.minSize,
        currentWindowMinimumSize: window.minSize
      )
      let restoredFrame = clampedMainWindowFrame(snapshot.frame, minimumSize: minimumSize)
      window.level = snapshot.level
      window.collectionBehavior = snapshot.collectionBehavior
      window.animationBehavior = snapshot.animationBehavior
      window.minSize = minimumSize
      window.setFrame(restoredFrame, display: false)
    } else {
      window.level = .normal
      window.collectionBehavior = [.managed]
      window.animationBehavior = .default
      window.minSize = minimumMainWindowSize(for: window)
    }
  }

  private func minimumMainWindowSize(for window: NSWindow) -> CGSize {
    minimumMainWindowSize(
      fromSnapshot: window.minSize,
      currentWindowMinimumSize: window.minSize
    )
  }

  private func minimumMainWindowSize(
    fromSnapshot snapshotMinimumSize: CGSize,
    currentWindowMinimumSize: CGSize
  ) -> CGSize {
    CGSize(
      width: max(
        Self.fallbackMainWindowMinimumSize.width,
        snapshotMinimumSize.width,
        currentWindowMinimumSize.width
      ),
      height: max(
        Self.fallbackMainWindowMinimumSize.height,
        snapshotMinimumSize.height,
        currentWindowMinimumSize.height
      )
    )
  }

  private func clampedMainWindowFrame(_ frame: CGRect, minimumSize: CGSize) -> CGRect {
    var clamped = frame
    clamped.size.width = max(minimumSize.width, frame.size.width)
    clamped.size.height = max(minimumSize.height, frame.size.height)
    return clamped.integral
  }

  private func normalizeMainWindowBeforeHotkeyPresentation(_ window: NSWindow) {
    // A previous crash while hotkey mode is active can leave the window in a
    // floating + tiny state for the next launch. Normalize before snapshotting
    // so we never persist/restore the transient hotkey geometry as main state.
    if window.level != .normal {
      window.level = .normal
    }
    if window.collectionBehavior.contains(.fullScreenAuxiliary) || window.collectionBehavior.contains(.moveToActiveSpace)
    {
      window.collectionBehavior = [.managed]
    }
    if window.animationBehavior != .default {
      window.animationBehavior = .default
    }

    let minimumSize = minimumMainWindowSize(for: window)
    window.minSize = minimumSize
    let clampedFrame = clampedMainWindowFrame(window.frame, minimumSize: minimumSize)
    if clampedFrame != window.frame {
      window.setFrame(clampedFrame, display: false, animate: false)
    }
  }

  private func layout(window: NSWindow) {
    guard let screen = targetScreen(fallbackWindowFrame: window.frame) else { return }
    let minimumWidth = min(settings.minimumWidth, screen.frame.width)
    let minimumHeight = min(settings.minimumHeight, screen.frame.height)
    window.minSize = CGSize(width: minimumWidth, height: minimumHeight)
    let frame = HotkeyWindowFrameCalculator.frame(
      in: screen.visibleFrame,
      retryingWith: screen.frame,
      settings: settings
    )
    window.setFrame(frame, display: true, animate: false)
  }

  private func targetScreen(fallbackWindowFrame: CGRect?) -> NSScreen? {
    let screens = NSScreen.screens
    let snapshots = screens.enumerated().map { index, screen in
      HotkeyWindowScreenSnapshot(
        frame: screen.frame,
        visibleFrame: screen.visibleFrame,
        isPrimary: index == 0
      )
    }
    let mainWindowFrame = mainWindowProvider()?.frame
    guard let targetIndex = HotkeyWindowScreenSelector.targetScreenIndex(
      mouseLocation: NSEvent.mouseLocation,
      screens: snapshots,
      fallbackWindowFrame: fallbackWindowFrame ?? mainWindowFrame
    ) else {
      return nil
    }
    return screens[targetIndex]
  }

  private func observePresentationLifecycle() {
    guard notificationObservers.isEmpty else { return }
    notificationObservers.append(
      NotificationObserver(
        center: workspaceNotificationCenter,
        token: workspaceNotificationCenter.addObserver(
          forName: NSWorkspace.activeSpaceDidChangeNotification,
          object: nil,
          queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated {
            self?.handleActiveSpaceDidChange()
          }
        }
      )
    )
  }

  private func clearWindowObservation() {
    notificationObservers.forEach { observer in
      observer.center.removeObserver(observer.token)
    }
    notificationObservers.removeAll()
  }

  private func handleActiveSpaceDidChange() {
    guard !isTransitioningPresentation else { return }
    guard HotkeyWindowDismissalPlanner.shouldDismissWhenActiveSpaceChanges() else { return }
    dismissPanel()
  }
}
