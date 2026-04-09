import Foundation
import SwiftUI
import Testing

@testable import supacode

struct SplitViewTests {
  @Test func updatedSplitUsesDragTranslationForHorizontalDivider() {
    let result = SplitView<EmptyView, EmptyView>.updatedSplit(
      direction: .horizontal,
      currentSplit: 0.5,
      translation: CGSize(width: 120, height: 0),
      context: .init(
        size: CGSize(width: 400, height: 300),
        minSize: 10,
        resizeIncrements: CGSize(width: 1, height: 1)
      )
    )

    #expect(result == 0.8)
  }

  @Test func updatedSplitClampsVerticalDividerToMinimumSize() {
    let result = SplitView<EmptyView, EmptyView>.updatedSplit(
      direction: .vertical,
      currentSplit: 0.5,
      translation: CGSize(width: 0, height: -500),
      context: .init(
        size: CGSize(width: 400, height: 300),
        minSize: 10,
        resizeIncrements: CGSize(width: 1, height: 1)
      )
    )

    #expect(result == (10.0 / 300.0))
  }

  @Test func updatedSplitSnapsToResizeIncrement() {
    let result = SplitView<EmptyView, EmptyView>.updatedSplit(
      direction: .horizontal,
      currentSplit: 0.5,
      translation: CGSize(width: 13, height: 0),
      context: .init(
        size: CGSize(width: 400, height: 300),
        minSize: 10,
        resizeIncrements: CGSize(width: 8, height: 1)
      )
    )

    #expect(result == (208.0 / 400.0))
  }
}
