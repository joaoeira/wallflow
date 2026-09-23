import Foundation
import UniformTypeIdentifiers

final class WallpaperLibraryStore {
  private let fileManager: FileManager
  private let rootDirectory: URL
  private let imagesDirectory: URL
  private let manifestURL: URL

  private(set) var items: [WallpaperItem]

  init(
    rootDirectory: URL,
    fileManager: FileManager = .default
  ) throws {
    self.fileManager = fileManager
    self.rootDirectory = rootDirectory
    imagesDirectory = rootDirectory.appendingPathComponent("Images", isDirectory: true)
    manifestURL = rootDirectory.appendingPathComponent("Library.json")

    try fileManager.createDirectory(
      at: imagesDirectory,
      withIntermediateDirectories: true
    )

    if fileManager.fileExists(atPath: manifestURL.path) {
      let data = try Data(contentsOf: manifestURL)
      items = try JSONDecoder().decode([WallpaperItem].self, from: data)
    } else {
      items = []
    }
  }

  /// Copies the image files among `sourceURLs` into the library, skipping
  /// anything that isn't an image, such as folders or documents.
  @discardableResult
  func importImages(at sourceURLs: [URL]) throws -> [WallpaperItem] {
    var imported: [WallpaperItem] = []
    let previousItems = items

    do {
      for sourceURL in sourceURLs where Self.isImageFile(sourceURL) {
        let fileExtension = sourceURL.pathExtension.lowercased()
        let fileName = UUID().uuidString + (fileExtension.isEmpty ? "" : ".\(fileExtension)")
        let item = WallpaperItem(
          id: UUID(),
          fileName: fileName,
          displayName: sourceURL.deletingPathExtension().lastPathComponent,
          addedAt: Date(),
          isEnabled: true
        )
        try fileManager.copyItem(
          at: sourceURL,
          to: imagesDirectory.appendingPathComponent(fileName)
        )
        imported.append(item)
      }

      items.append(contentsOf: imported)
      try save()
      return imported
    } catch {
      items = previousItems
      for item in imported {
        try? fileManager.removeItem(at: fileURL(for: item))
      }
      throw error
    }
  }

  func fileURL(for item: WallpaperItem) -> URL {
    imagesDirectory.appendingPathComponent(item.fileName)
  }

  func setEnabled(_ isEnabled: Bool, for ids: Set<UUID>) throws {
    let previousItems = items
    for index in items.indices where ids.contains(items[index].id) {
      items[index].isEnabled = isEnabled
    }
    do {
      try save()
    } catch {
      items = previousItems
      throw error
    }
  }

  /// Removes the items and their managed copies. Files are staged aside until
  /// the manifest is saved, so a failed save leaves the library as it was.
  func delete(itemIDs ids: Set<UUID>) throws {
    let previousItems = items
    var stagedFiles: [(managedURL: URL, stagedURL: URL)] = []

    do {
      for item in items where ids.contains(item.id) {
        let managedURL = fileURL(for: item)
        guard fileManager.fileExists(atPath: managedURL.path) else { continue }
        let stagedURL = rootDirectory.appendingPathComponent(".deleting-\(item.fileName)")
        try fileManager.moveItem(at: managedURL, to: stagedURL)
        stagedFiles.append((managedURL, stagedURL))
      }
      items.removeAll { ids.contains($0.id) }
      try save()
    } catch {
      items = previousItems
      for file in stagedFiles {
        try? fileManager.moveItem(at: file.stagedURL, to: file.managedURL)
      }
      throw error
    }

    for file in stagedFiles {
      try? fileManager.removeItem(at: file.stagedURL)
    }
  }

  private static func isImageFile(_ url: URL) -> Bool {
    guard
      let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
    else {
      return false
    }
    return contentType.conforms(to: .image)
  }

  private func save() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(items).write(to: manifestURL, options: .atomic)
  }
}
