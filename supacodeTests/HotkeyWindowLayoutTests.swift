import CoreGraphics
import Testing

@testable import supacode

struct HotkeyWindowLayoutTests {
  @Test func frameUsesRatiosAndBottomAlignment() {
    let availableFrame = CGRect(x: 100, y: 40, width: 1440, height: 900)
    let settings = HotkeyWindowSettings(
      isEnabled: true,
      hotkey: nil,
      widthRatio: 1,
      heightRatio: 2.0 / 3.0,
      hideOnApplicationDeactivate: true
    )

    let frame = HotkeyWindowFrameCalculator.frame(
      in: availableFrame,
      settings: settings
    )

    #expect(frame.origin.x == 100)
    #expect(frame.origin.y == 40)
    #expect(frame.width == 1440)
    #expect(frame.height == 600)
  }

  @Test func selectorPrefersScreenContainingMouse() {
    let screens = [
      HotkeyWindowScreenSnapshot(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 942),
        isPrimary: true
      ),
      HotkeyWindowScreenSnapshot(
        frame: CGRect(x: 1512, y: 0, width: 1728, height: 1117),
        visibleFrame: CGRect(x: 1512, y: 0, width: 1728, height: 1077)
      ),
    ]

    let index = HotkeyWindowScreenSelector.targetScreenIndex(
      mouseLocation: CGPoint(x: 2000, y: 400),
      screens: screens,
      fallbackWindowFrame: CGRect(x: 0, y: 0, width: 500, height: 500)
    )

    #expect(index == 1)
  }

  @Test func selectorFallsBackToWindowFrameThenPrimaryScreen() {
    let screens = [
      HotkeyWindowScreenSnapshot(
        frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
        visibleFrame: CGRect(x: 0, y: 0, width: 1512, height: 942),
        isPrimary: true
      ),
      HotkeyWindowScreenSnapshot(
        frame: CGRect(x: 1512, y: 0, width: 1728, height: 1117),
        visibleFrame: CGRect(x: 1512, y: 0, width: 1728, height: 1077)
      ),
    ]

    let fallbackIndex = HotkeyWindowScreenSelector.targetScreenIndex(
      mouseLocation: CGPoint(x: -1000, y: -1000),
      screens: screens,
      fallbackWindowFrame: CGRect(x: 1700, y: 100, width: 1000, height: 700)
    )
    #expect(fallbackIndex == 1)

    let primaryIndex = HotkeyWindowScreenSelector.targetScreenIndex(
      mouseLocation: CGPoint(x: -1000, y: -1000),
      screens: screens,
      fallbackWindowFrame: nil
    )
    #expect(primaryIndex == 0)
  }

  @Test func dismissalPlannerHidesBeforeRestoringAcrossDisplays() {
    let restoreOrder = HotkeyWindowDismissalPlanner.restoreOrder(
      snapshotFrame: CGRect(x: 0, y: 0, width: 1512, height: 982),
      currentFrame: CGRect(x: 1512, y: 0, width: 1728, height: 740)
    )

    #expect(restoreOrder == .hideThenRestore)
  }

  @Test func dismissalPlannerKeepsOriginalOrderWhenFrameIsUnchanged() {
    let frame = CGRect(x: 0, y: 0, width: 1512, height: 982)

    let restoreOrder = HotkeyWindowDismissalPlanner.restoreOrder(
      snapshotFrame: frame,
      currentFrame: frame
    )

    #expect(restoreOrder == .restoreThenHide)
  }

  @Test func dismissalPlannerKeepsHotkeyWindowVisibleWhileSheetIsAttached() {
    #expect(
      HotkeyWindowDismissalPlanner.shouldDismissWhenWindowResigns(
        hasAttachedSheet: true,
        hideOnApplicationDeactivate: true
      ) == false
    )
  }

  @Test func dismissalPlannerRespectsHideOnApplicationDeactivateSetting() {
    #expect(
      HotkeyWindowDismissalPlanner.shouldDismissWhenWindowResigns(
        hasAttachedSheet: false,
        hideOnApplicationDeactivate: true
      )
    )
    #expect(
      HotkeyWindowDismissalPlanner.shouldDismissWhenWindowResigns(
        hasAttachedSheet: false,
        hideOnApplicationDeactivate: false
      ) == false
    )
  }

  @Test func dismissalPlannerAlwaysDismissesWhenActiveSpaceChanges() {
    #expect(HotkeyWindowDismissalPlanner.shouldDismissWhenActiveSpaceChanges())
  }
}
