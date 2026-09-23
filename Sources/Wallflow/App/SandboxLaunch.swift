import Foundation

extension AppController {
  /// Launching with `-WallflowSandbox <directory>` keeps the library in that
  /// directory and settings in a separate defaults domain, and never touches
  /// the desktop, so the interface can be developed and screenshotted without
  /// disturbing the real library or wallpaper.
  static func forCurrentLaunch() -> AppController {
    guard let sandboxPath = UserDefaults.standard.string(forKey: "WallflowSandbox") else {
      return AppController()
    }
    return AppController(
      libraryDirectoryURL: URL(fileURLWithPath: sandboxPath, isDirectory: true),
      defaults: UserDefaults(suiteName: "com.joaoeira.wallflow.sandbox") ?? .standard,
      wallpaperApplier: InertWallpaperApplier()
    )
  }
}

private final class InertWallpaperApplier: WallpaperApplying {
  func apply(
    imageURL: URL,
    scaling: WallpaperScaling,
    target: DisplayTarget,
    animated: Bool
  ) throws {}
}
