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
      // Search the whole library, so a last wallpaper that has since been
      // excluded still marks where the sequence continues.
      guard
        let lastID,
        let lastIndex = wallpapers.firstIndex(where: { $0.id == lastID })
      else {
        return enabled.first
      }
      let following = wallpapers[(lastIndex + 1)...] + wallpapers[...lastIndex]
      return following.first(where: \.isEnabled)
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
