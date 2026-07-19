import XCTest

@testable import Wallflow

final class WallpaperLibraryStoreTests: XCTestCase {
  func testImportedImageIsCopiedAndSurvivesLibraryReload() throws {
    let fileManager = FileManager.default
    let testRoot = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceURL = testRoot.appendingPathComponent("Source.jpg")
    try fileManager.createDirectory(
      at: testRoot,
      withIntermediateDirectories: true
    )
    try Data("image bytes".utf8).write(to: sourceURL)
    defer { try? fileManager.removeItem(at: testRoot) }

    let library = try WallpaperLibraryStore(
      rootDirectory: testRoot.appendingPathComponent("Library"))
    let imported = try library.importImages(at: [sourceURL])

    XCTAssertEqual(imported.map(\.displayName), ["Source"])
    XCTAssertTrue(fileManager.fileExists(atPath: library.fileURL(for: imported[0]).path))
    XCTAssertTrue(fileManager.fileExists(atPath: sourceURL.path))

    let reloaded = try WallpaperLibraryStore(
      rootDirectory: testRoot.appendingPathComponent("Library"))
    XCTAssertEqual(reloaded.items, imported)
  }

  func testEnabledStatePersistsAcrossReload() throws {
    let fileManager = FileManager.default
    let testRoot = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceURL = testRoot.appendingPathComponent("Source.png")
    try fileManager.createDirectory(at: testRoot, withIntermediateDirectories: true)
    try Data("image bytes".utf8).write(to: sourceURL)
    defer { try? fileManager.removeItem(at: testRoot) }

    let libraryURL = testRoot.appendingPathComponent("Library")
    let library = try WallpaperLibraryStore(rootDirectory: libraryURL)
    let item = try XCTUnwrap(library.importImages(at: [sourceURL]).first)

    try library.setEnabled(false, for: item.id)

    let reloaded = try WallpaperLibraryStore(rootDirectory: libraryURL)
    XCTAssertEqual(reloaded.items.first?.isEnabled, false)
  }

  func testDeleteRemovesManagedImageAndManifestEntry() throws {
    let fileManager = FileManager.default
    let testRoot = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let sourceURL = testRoot.appendingPathComponent("Source.heic")
    try fileManager.createDirectory(at: testRoot, withIntermediateDirectories: true)
    try Data("image bytes".utf8).write(to: sourceURL)
    defer { try? fileManager.removeItem(at: testRoot) }

    let libraryURL = testRoot.appendingPathComponent("Library")
    let library = try WallpaperLibraryStore(rootDirectory: libraryURL)
    let item = try XCTUnwrap(library.importImages(at: [sourceURL]).first)
    let managedURL = library.fileURL(for: item)

    try library.delete(itemID: item.id)

    XCTAssertFalse(fileManager.fileExists(atPath: managedURL.path))
    XCTAssertTrue(library.items.isEmpty)
    XCTAssertTrue(try WallpaperLibraryStore(rootDirectory: libraryURL).items.isEmpty)
  }
}
