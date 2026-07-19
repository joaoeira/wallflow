import XCTest

@testable import Wallflow

final class WallpaperSettingsTests: XCTestCase {
  func testPreviouslySavedSettingsAdoptNewVisualDefaults() throws {
    let savedSettings = Data(
      #"{"rotationEnabled":false,"intervalSeconds":900,"order":"sequential","scaling":"fit","displayTarget":"mainDisplay"}"#
        .utf8
    )

    let settings = try JSONDecoder().decode(WallpaperSettings.self, from: savedSettings)

    XCTAssertFalse(settings.rotationEnabled)
    XCTAssertEqual(settings.intervalSeconds, 900)
    XCTAssertEqual(settings.order, .sequential)
    XCTAssertEqual(settings.scaling, .fit)
    XCTAssertEqual(settings.displayTarget, .mainDisplay)
    XCTAssertTrue(settings.smoothTransitions)
    XCTAssertTrue(settings.showsMenuBarIcon)
  }
}
