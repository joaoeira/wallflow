import AppKit
import Foundation
import ImageIO

actor WallpaperThumbnailCache {
  static let shared = WallpaperThumbnailCache()

  private let cache: NSCache<NSURL, NSImage>
  private let maximumPixelSize = 640

  private init() {
    cache = NSCache<NSURL, NSImage>()
    cache.countLimit = 200
    cache.totalCostLimit = 64 * 1_024 * 1_024
  }

  func image(for url: URL) -> NSImage? {
    let key = url as NSURL
    if let cached = cache.object(forKey: key) {
      return cached
    }

    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
          kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
      )
    else {
      return nil
    }

    let image = NSImage(
      cgImage: thumbnail,
      size: NSSize(width: thumbnail.width, height: thumbnail.height)
    )
    cache.setObject(image, forKey: key, cost: thumbnail.bytesPerRow * thumbnail.height)
    return image
  }
}
