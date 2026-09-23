import Foundation

struct WallpaperItem: Codable, Hashable, Identifiable {
  let id: UUID
  let fileName: String
  let displayName: String
  let addedAt: Date
  var isEnabled: Bool

  private enum CodingKeys: String, CodingKey {
    case id
    case fileName
    case displayName
    case addedAt
    case isEnabled
  }
}

extension WallpaperItem {
  /// Only the identity and the managed file are essential. Everything else
  /// falls back to a default so that fields added in later versions don't
  /// stop an existing library from loading.
  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(UUID.self, forKey: .id)
    fileName = try container.decode(String.self, forKey: .fileName)
    displayName =
      try container.decodeIfPresent(String.self, forKey: .displayName)
      ?? URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
    addedAt = try container.decodeIfPresent(Date.self, forKey: .addedAt) ?? .distantPast
    isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
  }
}

enum WallpaperOrder: String, Codable, CaseIterable, Identifiable {
  case sequential
  case shuffled

  var id: Self { self }
}
