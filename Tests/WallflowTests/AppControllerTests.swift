import XCTest

@testable import Wallflow

@MainActor
final class AppControllerTests: XCTestCase {
  func testImportingIntoEmptyLibraryShowsFirstPhotoAndStartsCountdown() throws {
    let app = try TestApp(testCase: self)
    let controller = app.launch()

    controller.importImages(at: [try app.makeImageFile(named: "Beach")])

    XCTAssertEqual(controller.currentItem?.displayName, "Beach")
    XCTAssertEqual(app.applier.shownFileNames, [controller.currentItem?.fileName])
    XCTAssertEqual(controller.nextChangeDate, app.now.addingTimeInterval(30 * 60))
  }

  func testChangingPresentationWhilePausedReappliesCurrentWallpaper() throws {
    let app = try TestApp(testCase: self)
    let controller = app.launch()
    controller.importImages(at: [try app.makeImageFile(named: "Beach")])
    controller.settings.rotationEnabled = false

    controller.settings.scaling = .fit
    controller.settings.displayTarget = .mainDisplay

    XCTAssertEqual(app.applier.applications.count, 3)
    XCTAssertEqual(app.applier.applications.last?.scaling, .fit)
    XCTAssertEqual(app.applier.applications.last?.target, .mainDisplay)
    XCTAssertEqual(controller.currentItem?.displayName, "Beach")
    XCTAssertNil(controller.nextChangeDate)
  }
}

@MainActor
private final class TestApp {
  let rootDirectory: URL
  let defaults: UserDefaults
  let applier = RecordingWallpaperApplier()
  var now = Date()

  init(testCase: XCTestCase) throws {
    let rootDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let suiteName = "WallflowTests.\(UUID().uuidString)"
    try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
    self.rootDirectory = rootDirectory
    defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    testCase.addTeardownBlock {
      try? FileManager.default.removeItem(at: rootDirectory)
      UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }
  }

  /// Creates a controller over this app's library and defaults, as a fresh
  /// launch of Wallflow would.
  func launch() -> AppController {
    let controller = AppController(
      libraryDirectoryURL: rootDirectory.appendingPathComponent("Library", isDirectory: true),
      defaults: defaults,
      wallpaperApplier: applier,
      now: { [unowned self] in now }
    )
    controller.start()
    return controller
  }

  func makeImageFile(named name: String) throws -> URL {
    let url = rootDirectory.appendingPathComponent("\(name).jpg")
    try Data("image bytes".utf8).write(to: url)
    return url
  }
}

@MainActor
private final class RecordingWallpaperApplier: WallpaperApplying {
  struct Application {
    let imageURL: URL
    let scaling: WallpaperScaling
    let target: DisplayTarget
  }

  private(set) var applications: [Application] = []

  var shownFileNames: [String?] {
    applications.map(\.imageURL.lastPathComponent)
  }

  func apply(
    imageURL: URL,
    previousImageURL: URL?,
    scaling: WallpaperScaling,
    target: DisplayTarget,
    animated: Bool
  ) throws {
    applications.append(Application(imageURL: imageURL, scaling: scaling, target: target))
  }
}
