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

  func testEditingOtherPhotosKeepsTheCountdown() throws {
    let app = try TestApp(testCase: self)
    let controller = app.launch()
    controller.importImages(at: [
      try app.makeImageFile(named: "Beach"), try app.makeImageFile(named: "Forest"),
    ])
    let countdown = try XCTUnwrap(controller.nextChangeDate)
    let other = try XCTUnwrap(controller.items.first { $0.id != controller.currentItemID })
    app.now += 10 * 60

    controller.setEnabled(false, for: other)
    controller.setEnabled(true, for: other)
    controller.delete(other)

    XCTAssertEqual(controller.nextChangeDate, countdown)
    XCTAssertEqual(app.applier.applications.count, 1)
  }

  func testEnablingAPhotoWhenNoneWereEnabledShowsItImmediately() throws {
    let app = try TestApp(testCase: self)
    let controller = app.launch()
    controller.importImages(at: [try app.makeImageFile(named: "Beach")])
    let beach = try XCTUnwrap(controller.currentItem)
    controller.setEnabled(false, for: beach)
    XCTAssertNil(controller.nextChangeDate)

    controller.setEnabled(true, for: beach)

    XCTAssertEqual(controller.currentItemID, beach.id)
    XCTAssertEqual(app.applier.applications.count, 2)
    XCTAssertEqual(controller.nextChangeDate, app.now.addingTimeInterval(30 * 60))
  }

  func testRelaunchingResumesTheSavedCountdown() throws {
    let app = try TestApp(testCase: self)
    let first = app.launch()
    first.importImages(at: [
      try app.makeImageFile(named: "Beach"), try app.makeImageFile(named: "Forest"),
    ])
    let countdown = try XCTUnwrap(first.nextChangeDate)
    app.now += 20 * 60

    let relaunched = app.launch()

    XCTAssertEqual(relaunched.nextChangeDate, countdown)
    XCTAssertEqual(relaunched.currentItemID, first.currentItemID)
    XCTAssertEqual(app.applier.applications.count, 1)
  }

  func testRelaunchingAfterTheSavedCountdownRotatesImmediately() throws {
    let app = try TestApp(testCase: self)
    let first = app.launch()
    first.importImages(at: [
      try app.makeImageFile(named: "Beach"), try app.makeImageFile(named: "Forest"),
    ])
    app.now += 45 * 60

    let relaunched = app.launch()

    XCTAssertNotEqual(relaunched.currentItemID, first.currentItemID)
    XCTAssertEqual(app.applier.applications.count, 2)
    XCTAssertEqual(relaunched.nextChangeDate, app.now.addingTimeInterval(30 * 60))
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
