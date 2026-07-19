import Foundation

struct WallpaperItem: Codable, Hashable, Identifiable {
  let id: UUID
  let fileName: String
  let displayName: String
  let addedAt: Date
  var isEnabled: Bool
}

enum WallpaperOrder: String, Codable, CaseIterable, Identifiable {
  case sequential
  case shuffled

  var id: Self { self }
}
