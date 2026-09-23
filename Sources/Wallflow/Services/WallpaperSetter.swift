import AppKit
import Foundation

enum WallpaperSetter {
  static func apply(
    imageURL: URL,
    scaling: WallpaperScaling,
    target: DisplayTarget
  ) throws {
    for screen in screens(for: target) {
      try NSWorkspace.shared.setDesktopImageURL(
        imageURL,
        for: screen,
        options: scaling.desktopImageOptions
      )
    }
  }

  static func screens(for target: DisplayTarget) -> [NSScreen] {
    switch target {
    case .allDisplays:
      NSScreen.screens
    case .mainDisplay:
      // NSScreen.main is the screen holding the key window; the first screen
      // is the one with the menu bar, which is what "main display" means here.
      NSScreen.screens.first.map { [$0] } ?? []
    }
  }
}
