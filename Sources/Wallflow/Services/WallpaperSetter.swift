import AppKit
import Foundation

enum WallpaperSetter {
  static func apply(
    imageURL: URL,
    scaling: WallpaperScaling,
    target: DisplayTarget
  ) throws {
    let screens: [NSScreen]
    switch target {
    case .allDisplays:
      screens = NSScreen.screens
    case .mainDisplay:
      screens = NSScreen.main.map { [$0] } ?? []
    }

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
}
