import Foundation

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

  @discardableResult
  func importImages(at sourceURLs: [URL]) throws -> [WallpaperItem] {
    var imported: [WallpaperItem] = []
    let previousItems = items

    do {
      for sourceURL in sourceURLs {
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

  func setEnabled(_ isEnabled: Bool, for id: UUID) throws {
    guard let index = items.firstIndex(where: { $0.id == id }) else { return }
    let previousValue = items[index].isEnabled
    items[index].isEnabled = isEnabled
    do {
      try save()
    } catch {
      items[index].isEnabled = previousValue
      throw error
    }
  }

  func delete(itemID: UUID) throws {
    guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
    let item = items[index]
    let managedURL = fileURL(for: item)
    let stagedURL = rootDirectory.appendingPathComponent(".deleting-\(item.fileName)")
    let hadManagedFile = fileManager.fileExists(atPath: managedURL.path)

    if hadManagedFile {
      try fileManager.moveItem(at: managedURL, to: stagedURL)
    }
    items.remove(at: index)

    do {
      try save()
      if hadManagedFile {
        try? fileManager.removeItem(at: stagedURL)
      }
    } catch {
      items.insert(item, at: index)
      if hadManagedFile, fileManager.fileExists(atPath: stagedURL.path) {
        try? fileManager.moveItem(at: stagedURL, to: managedURL)
      }
      throw error
    }
  }

  private func save() throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(items).write(to: manifestURL, options: .atomic)
  }
}
