import AppKit
import Foundation

struct WallpaperSettings: Codable, Equatable {
  var rotationEnabled = true
  var intervalSeconds: TimeInterval = 30 * 60
  var order: WallpaperOrder = .shuffled
  var scaling: WallpaperScaling = .fill
  var displayTarget: DisplayTarget = .allDisplays
}

enum WallpaperScaling: String, Codable, CaseIterable, Identifiable {
  case fill
  case fit
  case stretch
  case center

  var id: Self { self }

  var title: String {
    switch self {
    case .fill: "Fill Screen"
    case .fit: "Fit to Screen"
    case .stretch: "Stretch"
    case .center: "Center"
    }
  }

  var imageScaling: NSImageScaling {
    switch self {
    case .fill, .fit: .scaleProportionallyUpOrDown
    case .stretch: .scaleAxesIndependently
    case .center: .scaleNone
    }
  }

  var allowsClipping: Bool {
    switch self {
    case .fill, .center: true
    case .fit, .stretch: false
    }
  }
}

enum DisplayTarget: String, Codable, CaseIterable, Identifiable {
  case allDisplays
  case mainDisplay

  var id: Self { self }

  var title: String {
    switch self {
    case .allDisplays: "All Displays"
    case .mainDisplay: "Main Display Only"
    }
  }
}

extension WallpaperOrder {
  var title: String {
    switch self {
    case .sequential: "Added Order"
    case .shuffled: "Shuffle"
    }
  }
}
