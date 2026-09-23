import AppKit
import CoreGraphics
import Foundation
import ImageIO
import QuartzCore

@MainActor
protocol WallpaperApplying: AnyObject {
  func apply(
    imageURL: URL,
    scaling: WallpaperScaling,
    target: DisplayTarget,
    animated: Bool
  ) throws
}

@MainActor
final class WallpaperTransitionCoordinator: WallpaperApplying {
  private final class ActiveTransition {
    let id = UUID()
    let windows: [NSWindow]
    var teardownTimer: Timer?

    init(windows: [NSWindow]) {
      self.windows = windows
    }
  }

  private var activeTransition: ActiveTransition?
  private var animationSuppressedUntil = Date.distantPast

  private let fadeDuration: TimeInterval = 0.65
  // The system applies the desktop image asynchronously, some time after
  // setDesktopImageURL returns. The overlay stays up this long after the fade
  // so the swap underneath finishes before the desktop becomes visible again.
  private let settleDuration: TimeInterval = 0.6

  func apply(
    imageURL: URL,
    scaling: WallpaperScaling,
    target: DisplayTarget,
    animated: Bool
  ) throws {
    let now = Date()
    let supersededTransition = activeTransition != nil
    tearDownActiveTransition()

    let mayAnimate =
      animated
      && !supersededTransition
      && now >= animationSuppressedUntil

    if animated, !mayAnimate {
      animationSuppressedUntil = now.addingTimeInterval(fadeDuration)
    }

    let windows =
      mayAnimate
      ? makeOverlayWindows(incomingImageURL: imageURL, scaling: scaling, target: target)
      : []
    guard !windows.isEmpty else {
      try WallpaperSetter.apply(imageURL: imageURL, scaling: scaling, target: target)
      return
    }

    let transition = ActiveTransition(windows: windows)
    activeTransition = transition
    animationSuppressedUntil = now.addingTimeInterval(fadeDuration)
    for window in windows {
      window.orderFrontRegardless()
      window.displayIfNeeded()
    }
    // Layer-backed content otherwise commits at the end of the runloop turn,
    // after setDesktopImageURL below — letting the system's swap flash through
    // before the overlay's first frame reaches the screen.
    CATransaction.flush()

    do {
      try WallpaperSetter.apply(imageURL: imageURL, scaling: scaling, target: target)
    } catch {
      tearDown(transition)
      throw error
    }

    let transitionID = transition.id
    NSAnimationContext.runAnimationGroup { context in
      context.duration = fadeDuration
      context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
      for window in windows {
        (window.contentView as? WallpaperCrossfadeView)?
          .incomingView.animator().alphaValue = 1
      }
    } completionHandler: { [weak self] in
      MainActor.assumeIsolated {
        self?.scheduleTeardown(id: transitionID)
      }
    }
  }

  /// Builds an overlay for each target screen that needs one, fading from
  /// whatever that screen shows now, which need not be Wallflow's last
  /// wallpaper. Screens already showing the image, or showing something that
  /// can't be loaded, get no overlay and simply switch.
  private func makeOverlayWindows(
    incomingImageURL: URL,
    scaling: WallpaperScaling,
    target: DisplayTarget
  ) -> [NSWindow] {
    var sources: [URL: TransitionImageSource?] = [:]
    func source(at url: URL) -> TransitionImageSource? {
      if let loaded = sources[url] { return loaded }
      let source = TransitionImageSource(url: url)
      sources[url] = source
      return source
    }

    guard let incomingSource = source(at: incomingImageURL) else { return [] }

    return WallpaperSetter.screens(for: target).compactMap { screen in
      let outgoingScaling =
        NSWorkspace.shared.desktopImageOptions(for: screen)
        .flatMap(WallpaperScaling.init(desktopImageOptions:)) ?? scaling
      guard
        let outgoingImageURL = NSWorkspace.shared.desktopImageURL(for: screen),
        outgoingImageURL.standardizedFileURL.path != incomingImageURL.standardizedFileURL.path,
        let outgoingImage = source(at: outgoingImageURL)?
          .image(for: screen, scaling: outgoingScaling),
        let incomingImage = incomingSource.image(for: screen, scaling: scaling)
      else { return nil }

      return makeOverlayWindow(
        for: screen,
        outgoing: (outgoingImage, outgoingScaling),
        incoming: (incomingImage, scaling)
      )
    }
  }

  private func makeOverlayWindow(
    for screen: NSScreen,
    outgoing: (image: NSImage, scaling: WallpaperScaling),
    incoming: (image: NSImage, scaling: WallpaperScaling)
  ) -> NSWindow {
    // screen.frame is in global coordinates; the screen-relative initializer
    // variant would double-offset the window on secondary displays.
    let window = NSWindow(
      contentRect: screen.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: true
    )
    window.contentView = WallpaperCrossfadeView(
      frame: NSRect(origin: .zero, size: screen.frame.size),
      outgoing: outgoing,
      incoming: incoming
    )
    window.level = NSWindow.Level(
      rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1
    )
    window.collectionBehavior = [.moveToActiveSpace, .stationary, .ignoresCycle, .transient]
    window.backgroundColor = .black
    window.isOpaque = true
    window.hasShadow = false
    window.ignoresMouseEvents = true
    window.animationBehavior = .none
    window.isReleasedWhenClosed = false
    return window
  }

  private func scheduleTeardown(id: UUID) {
    guard let transition = activeTransition, transition.id == id else { return }

    let timer = Timer(timeInterval: settleDuration, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        guard
          let self,
          let transition = self.activeTransition,
          transition.id == id
        else { return }
        self.tearDown(transition)
      }
    }
    timer.tolerance = 0.1
    transition.teardownTimer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func tearDownActiveTransition() {
    guard let activeTransition else { return }
    tearDown(activeTransition)
  }

  private func tearDown(_ transition: ActiveTransition) {
    transition.teardownTimer?.invalidate()
    transition.teardownTimer = nil
    for window in transition.windows {
      window.alphaValue = 0
      window.orderOut(nil)
      window.contentView = nil
      window.close()
    }
    if activeTransition === transition {
      activeTransition = nil
    }
  }
}

private final class WallpaperCrossfadeView: NSView {
  let incomingView: WallpaperImageView

  init(
    frame: NSRect,
    outgoing: (image: NSImage, scaling: WallpaperScaling),
    incoming: (image: NSImage, scaling: WallpaperScaling)
  ) {
    let contentBounds = NSRect(origin: .zero, size: frame.size)
    let outgoingView = WallpaperImageView(
      frame: contentBounds, image: outgoing.image, scaling: outgoing.scaling
    )
    let incomingView = WallpaperImageView(
      frame: contentBounds, image: incoming.image, scaling: incoming.scaling
    )
    self.incomingView = incomingView
    super.init(frame: frame)
    wantsLayer = true
    addSubview(outgoingView)
    addSubview(incomingView)
    incomingView.alphaValue = 0
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }
}

private final class WallpaperImageView: NSView {
  private let image: NSImage
  private let scaling: WallpaperScaling

  init(frame: NSRect, image: NSImage, scaling: WallpaperScaling) {
    self.image = image
    self.scaling = scaling
    super.init(frame: frame)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func draw(_ dirtyRect: NSRect) {
    NSColor.black.setFill()
    bounds.fill()

    guard image.size.width > 0, image.size.height > 0 else { return }
    image.draw(
      in: scaling.destinationRect(forImageOfSize: image.size, in: bounds),
      from: NSRect(origin: .zero, size: image.size),
      operation: .sourceOver,
      fraction: 1,
      respectFlipped: true,
      hints: [.interpolation: NSImageInterpolation.high]
    )
  }

}

/// A wallpaper file, decoded no larger than a given screen will draw it.
/// Wallpapers are often several times the display's resolution, and a
/// full-size decode on the main thread stalls the start of the fade.
@MainActor
private final class TransitionImageSource {
  private let source: CGImageSource
  /// The upright size NSImage would report: pixels at the file's resolution.
  private let pointSize: NSSize
  private var decodedImages: [Int: NSImage] = [:]

  init?(url: URL) {
    guard
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
      let pixelWidth = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.doubleValue,
      let pixelHeight = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.doubleValue,
      pixelWidth > 0, pixelHeight > 0
    else { return nil }

    func dotsPerInch(_ key: CFString) -> Double {
      let value = (properties[key] as? NSNumber)?.doubleValue ?? 72
      return value > 0 ? value : 72
    }
    let width = pixelWidth * 72 / dotsPerInch(kCGImagePropertyDPIWidth)
    let height = pixelHeight * 72 / dotsPerInch(kCGImagePropertyDPIHeight)
    // EXIF orientations 5 through 8 turn the image a quarter turn.
    let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
    let isQuarterTurned = (5...8).contains(orientation)

    self.source = source
    pointSize =
      isQuarterTurned
      ? NSSize(width: height, height: width)
      : NSSize(width: width, height: height)
  }

  func image(for screen: NSScreen, scaling: WallpaperScaling) -> NSImage? {
    let drawnSize = scaling.destinationRect(
      forImageOfSize: pointSize,
      in: NSRect(origin: .zero, size: screen.frame.size)
    ).size
    let maxPixelSize = Int(
      (max(drawnSize.width, drawnSize.height) * screen.backingScaleFactor).rounded(.up)
    )
    if let decoded = decodedImages[maxPixelSize] { return decoded }

    guard
      let thumbnail = CGImageSourceCreateThumbnailAtIndex(
        source,
        0,
        [
          kCGImageSourceCreateThumbnailFromImageAlways: true,
          kCGImageSourceCreateThumbnailWithTransform: true,
          kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
          kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
      )
    else { return nil }

    let image = NSImage(cgImage: thumbnail, size: pointSize)
    decodedImages[maxPixelSize] = image
    return image
  }
}

extension WallpaperScaling {
  /// Where the desktop draws an image of `imageSize` within `bounds`.
  fileprivate func destinationRect(forImageOfSize imageSize: NSSize, in bounds: NSRect) -> NSRect {
    func centered(_ size: NSSize) -> NSRect {
      NSRect(
        x: bounds.midX - size.width / 2,
        y: bounds.midY - size.height / 2,
        width: size.width,
        height: size.height
      )
    }

    switch self {
    case .stretch:
      return bounds
    case .center:
      return centered(imageSize)
    case .fill, .fit:
      let horizontalScale = bounds.width / imageSize.width
      let verticalScale = bounds.height / imageSize.height
      let scale =
        self == .fill
        ? max(horizontalScale, verticalScale)
        : min(horizontalScale, verticalScale)
      return centered(NSSize(width: imageSize.width * scale, height: imageSize.height * scale))
    }
  }
}
