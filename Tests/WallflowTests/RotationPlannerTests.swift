import XCTest

@testable import Wallflow

final class RotationPlannerTests: XCTestCase {
  func testSequentialRotationAdvancesAndWraps() {
    let first = WallpaperItem.fixture(name: "First")
    let second = WallpaperItem.fixture(name: "Second")
    let third = WallpaperItem.fixture(name: "Third")
    let wallpapers = [first, second, third]

    let afterFirst = RotationPlanner.next(
      from: wallpapers,
      after: first.id,
      order: .sequential
    )
    let afterThird = RotationPlanner.next(
      from: wallpapers,
      after: third.id,
      order: .sequential
    )

    XCTAssertEqual(afterFirst?.id, second.id)
    XCTAssertEqual(afterThird?.id, first.id)
  }

  func testShuffleDoesNotImmediatelyRepeatWhenAnotherWallpaperIsEnabled() {
    let first = WallpaperItem.fixture(name: "First")
    let second = WallpaperItem.fixture(name: "Second")

    let next = RotationPlanner.next(
      from: [first, second],
      after: first.id,
      order: .shuffled,
      randomIndex: { _ in 0 }
    )

    XCTAssertEqual(next?.id, second.id)
  }
}

extension WallpaperItem {
  fileprivate static func fixture(name: String, isEnabled: Bool = true) -> WallpaperItem {
    WallpaperItem(
      id: UUID(),
      fileName: "\(name).jpg",
      displayName: name,
      addedAt: Date(timeIntervalSince1970: 1_700_000_000),
      isEnabled: isEnabled
    )
  }
}
