import Foundation

enum RotationPlanner {
  static func next(
    from wallpapers: [WallpaperItem],
    after lastID: UUID?,
    order: WallpaperOrder,
    randomIndex: (Int) -> Int = { upperBound in
      Int.random(in: 0..<upperBound)
    }
  ) -> WallpaperItem? {
    let enabled = wallpapers.filter(\.isEnabled)
    guard !enabled.isEmpty else { return nil }

    switch order {
    case .sequential:
      guard
        let lastID,
        let currentIndex = enabled.firstIndex(where: { $0.id == lastID })
      else {
        return enabled.first
      }
      return enabled[(currentIndex + 1) % enabled.count]
    case .shuffled:
      let candidates: [WallpaperItem]
      if enabled.count > 1, let lastID {
        candidates = enabled.filter { $0.id != lastID }
      } else {
        candidates = enabled
      }
      return candidates[randomIndex(candidates.count)]
    }
  }
}
