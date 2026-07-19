import AppKit
import CoreGraphics
import Foundation

@MainActor
final class WallpaperTransitionCoordinator {
  private final class ActiveTransition {
    let id = UUID()
    let windows: [NSWindow]
    let startedAt: TimeInterval
    var timer: Timer?

    init(windows: [NSWindow], startedAt: TimeInterval) {
      self.windows = windows
      self.startedAt = startedAt
    }
  }

  private var activeTransition: ActiveTransition?
  private var animationSuppressedUntil = Date.distantPast

  private let fadeDuration: TimeInterval = 0.65

  func apply(
    imageURL: URL,
    previousImageURL: URL?,
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

    guard
      mayAnimate,
      let previousImageURL,
      previousImageURL != imageURL,
      let previousImage = NSImage(contentsOf: previousImageURL)
    else {
      try WallpaperSetter.apply(imageURL: imageURL, scaling: scaling, target: target)
      return
    }

    let windows = WallpaperSetter.screens(for: target).map { screen in
      makeOverlayWindow(for: screen, image: previousImage, scaling: scaling)
    }
    let transition = ActiveTransition(
      windows: windows,
      startedAt: ProcessInfo.processInfo.systemUptime
    )
    activeTransition = transition
    animationSuppressedUntil = now.addingTimeInterval(fadeDuration)
    for window in windows {
      window.orderFrontRegardless()
    }

    do {
      try WallpaperSetter.apply(imageURL: imageURL, scaling: scaling, target: target)
    } catch {
      tearDown(transition)
      throw error
    }

    let transitionID = transition.id
    let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
      MainActor.assumeIsolated {
        self?.advanceTransition(id: transitionID, timer: timer)
      }
    }
    timer.tolerance = 1.0 / 240.0
    transition.timer = timer
    RunLoop.main.add(timer, forMode: .common)
  }

  private func makeOverlayWindow(
    for screen: NSScreen,
    image: NSImage,
    scaling: WallpaperScaling
  ) -> NSWindow {
    let window = NSWindow(
      contentRect: screen.frame,
      styleMask: [.borderless],
      backing: .buffered,
      defer: true,
      screen: screen
    )
    window.contentView = WallpaperOverlayView(
      frame: NSRect(origin: .zero, size: screen.frame.size),
      image: image,
      scaling: scaling
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

  private func tearDownActiveTransition() {
    guard let activeTransition else { return }
    tearDown(activeTransition)
  }

  private func advanceTransition(id: UUID, timer: Timer) {
    guard let transition = activeTransition, transition.id == id else {
      timer.invalidate()
      return
    }

    let elapsed = ProcessInfo.processInfo.systemUptime - transition.startedAt
    let progress = min(1, max(0, elapsed / fadeDuration))
    let easedProgress = progress * progress * (3 - 2 * progress)
    for window in transition.windows {
      window.alphaValue = 1 - easedProgress
    }

    if progress >= 1 {
      tearDown(transition)
    }
  }

  private func tearDown(_ transition: ActiveTransition) {
    transition.timer?.invalidate()
    transition.timer = nil
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

private final class WallpaperOverlayView: NSView {
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
      in: destinationRect,
      from: NSRect(origin: .zero, size: image.size),
      operation: .sourceOver,
      fraction: 1,
      respectFlipped: true,
      hints: [.interpolation: NSImageInterpolation.high]
    )
  }

  private var destinationRect: NSRect {
    switch scaling {
    case .stretch:
      return bounds
    case .center:
      return centeredRect(size: image.size)
    case .fill, .fit:
      let horizontalScale = bounds.width / image.size.width
      let verticalScale = bounds.height / image.size.height
      let scale =
        scaling == .fill
        ? max(horizontalScale, verticalScale)
        : min(horizontalScale, verticalScale)
      return centeredRect(
        size: NSSize(width: image.size.width * scale, height: image.size.height * scale)
      )
    }
  }

  private func centeredRect(size: NSSize) -> NSRect {
    NSRect(
      x: bounds.midX - size.width / 2,
      y: bounds.midY - size.height / 2,
      width: size.width,
      height: size.height
    )
  }
}
