import AppKit
import Foundation

enum WallpaperSetter {
  static func apply(
    imageURL: URL,
    scaling: WallpaperScaling,
    target: DisplayTarget
  ) throws {
    let screens = screens(for: target)

    let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
      .imageScaling: NSNumber(value: scaling.imageScaling.rawValue),
      .allowClipping: NSNumber(value: scaling.allowsClipping),
      .fillColor: NSColor.black,
    ]

    for screen in screens {
      try NSWorkspace.shared.setDesktopImageURL(
        imageURL,
        for: screen,
        options: options
      )
    }
  }

  static func screens(for target: DisplayTarget) -> [NSScreen] {
    switch target {
    case .allDisplays:
      NSScreen.screens
    case .mainDisplay:
      NSScreen.main.map { [$0] } ?? []
    }
  }
}
