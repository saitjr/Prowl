import AppKit
import Foundation

@MainActor
final class HotkeyWindowManager {
  private struct MainWindowSnapshot {
    let frame: CGRect
    let level: NSWindow.Level
    let collectionBehavior: NSWindow.CollectionBehavior
    let animationBehavior: NSWindow.AnimationBehavior
  }

  static let shared = HotkeyWindowManager()

  private let logger = SupaLogger("HotkeyWindow")
  private let hotKeyMonitor = GlobalHotKeyMonitor()
  private var mainWindowProvider: @MainActor () -> NSWindow? = {
    NSApplication.shared.windows.first(where: { $0.identifier?.rawValue == "main" })
  }
  private var settings = HotkeyWindowSettings.default
  private var snapshot: MainWindowSnapshot?
  private var observedWindow: NSWindow?
  private var notificationObservers: [NSObjectProtocol] = []
  private var workspaceObserver: NSObjectProtocol?
  private var isTransitioningPresentation = false
  private var isPresentingHotkey = false

  private init() {
    observeActiveSpaceChanges()
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

    snapshot = MainWindowSnapshot(
      frame: snapshot?.frame ?? window.frame,
      level: window.level,
      collectionBehavior: window.collectionBehavior,
      animationBehavior: window.animationBehavior
    )
    observe(window: window)

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
    clearWindowObservation()
  }

  private func applyHotkeyPresentation(to window: NSWindow) {
    window.level = .floating
    window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
    window.animationBehavior = .utilityWindow
  }

  private func restoreMainWindowPresentation(on window: NSWindow) {
    if let snapshot {
      window.level = snapshot.level
      window.collectionBehavior = snapshot.collectionBehavior
      window.animationBehavior = snapshot.animationBehavior
      window.setFrame(snapshot.frame, display: false)
    } else {
      window.level = .normal
      window.collectionBehavior = [.managed]
      window.animationBehavior = .default
    }
  }

  private func layout(window: NSWindow) {
    guard let screen = targetScreen(fallbackWindowFrame: window.frame) else { return }
    let frame = HotkeyWindowFrameCalculator.frame(
      in: screen.visibleFrame,
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

  private func observe(window: NSWindow) {
    guard observedWindow !== window else { return }
    clearWindowObservation()
    observedWindow = window
    let center = NotificationCenter.default
    notificationObservers.append(
      center.addObserver(
        forName: NSWindow.didResignKeyNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        self?.handleWindowResign()
      })
    notificationObservers.append(
      center.addObserver(
        forName: NSWindow.didResignMainNotification,
        object: window,
        queue: .main
      ) { [weak self] _ in
        self?.handleWindowResign()
      })
  }

  private func clearWindowObservation() {
    let center = NotificationCenter.default
    notificationObservers.forEach(center.removeObserver)
    notificationObservers.removeAll()
    observedWindow = nil
  }

  private func handleWindowResign() {
    guard !isTransitioningPresentation else { return }
    if let window = observedWindow,
      !HotkeyWindowDismissalPlanner.shouldDismissWhenWindowResigns(
        hasAttachedSheet: window.attachedSheet != nil,
        hideOnApplicationDeactivate: settings.hideOnApplicationDeactivate
      )
    {
      return
    }
    dismissPanel()
  }

  private func observeActiveSpaceChanges() {
    workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification,
      object: NSWorkspace.shared,
      queue: .main
    ) { [weak self] _ in
      self?.handleActiveSpaceDidChange()
    }
  }

  private func handleActiveSpaceDidChange() {
    guard isPresentingHotkey else { return }
    guard HotkeyWindowDismissalPlanner.shouldDismissWhenActiveSpaceChanges() else { return }
    dismissPanel()
  }
}
