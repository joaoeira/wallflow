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

  func testImportSkipsFilesThatAreNotImages() throws {
    let fileManager = FileManager.default
    let testRoot = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let imageURL = testRoot.appendingPathComponent("Source.jpg")
    let documentURL = testRoot.appendingPathComponent("Notes.txt")
    let folderURL = testRoot.appendingPathComponent("Folder", isDirectory: true)
    try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
    try Data("image bytes".utf8).write(to: imageURL)
    try Data("notes".utf8).write(to: documentURL)
    try Data("image bytes".utf8).write(to: folderURL.appendingPathComponent("Nested.jpg"))
    defer { try? fileManager.removeItem(at: testRoot) }

    let libraryURL = testRoot.appendingPathComponent("Library")
    let library = try WallpaperLibraryStore(rootDirectory: libraryURL)
    let imported = try library.importImages(at: [imageURL, documentURL, folderURL])

    XCTAssertEqual(imported.map(\.displayName), ["Source"])
    XCTAssertEqual(library.items, imported)
    XCTAssertEqual(
      try fileManager.contentsOfDirectory(atPath: libraryURL.appendingPathComponent("Images").path),
      [imported[0].fileName]
    )
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

  func testManifestEntriesMissingOptionalFieldsStillLoad() throws {
    let fileManager = FileManager.default
    let libraryURL = fileManager.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: libraryURL, withIntermediateDirectories: true)
    defer { try? fileManager.removeItem(at: libraryURL) }
    let id = UUID()
    try Data(
      #"[{"id":"\#(id.uuidString)","fileName":"Beach.jpg","futureField":1}]"#.utf8
    ).write(to: libraryURL.appendingPathComponent("Library.json"))

    let library = try WallpaperLibraryStore(rootDirectory: libraryURL)

    XCTAssertEqual(library.items.map(\.id), [id])
    XCTAssertEqual(library.items.first?.displayName, "Beach")
    XCTAssertEqual(library.items.first?.isEnabled, true)
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
