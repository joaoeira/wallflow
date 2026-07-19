import AppKit
import Foundation

struct WallpaperSettings: Codable, Equatable {
  var rotationEnabled = true
  var intervalSeconds: TimeInterval = 30 * 60
  var order: WallpaperOrder = .shuffled
  var scaling: WallpaperScaling = .fill
  var displayTarget: DisplayTarget = .allDisplays
  var smoothTransitions = true
  var showsMenuBarIcon = true

  private enum CodingKeys: String, CodingKey {
    case rotationEnabled
    case intervalSeconds
    case order
    case scaling
    case displayTarget
    case smoothTransitions
    case showsMenuBarIcon
  }

  init(
    rotationEnabled: Bool = true,
    intervalSeconds: TimeInterval = 30 * 60,
    order: WallpaperOrder = .shuffled,
    scaling: WallpaperScaling = .fill,
    displayTarget: DisplayTarget = .allDisplays,
    smoothTransitions: Bool = true,
    showsMenuBarIcon: Bool = true
  ) {
    self.rotationEnabled = rotationEnabled
    self.intervalSeconds = intervalSeconds
    self.order = order
    self.scaling = scaling
    self.displayTarget = displayTarget
    self.smoothTransitions = smoothTransitions
    self.showsMenuBarIcon = showsMenuBarIcon
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    rotationEnabled = try container.decodeIfPresent(Bool.self, forKey: .rotationEnabled) ?? true
    intervalSeconds =
      try container.decodeIfPresent(TimeInterval.self, forKey: .intervalSeconds) ?? 30 * 60
    order = try container.decodeIfPresent(WallpaperOrder.self, forKey: .order) ?? .shuffled
    scaling = try container.decodeIfPresent(WallpaperScaling.self, forKey: .scaling) ?? .fill
    displayTarget =
      try container.decodeIfPresent(DisplayTarget.self, forKey: .displayTarget) ?? .allDisplays
    smoothTransitions = try container.decodeIfPresent(Bool.self, forKey: .smoothTransitions) ?? true
    showsMenuBarIcon = try container.decodeIfPresent(Bool.self, forKey: .showsMenuBarIcon) ?? true
  }
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
