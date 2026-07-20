import AppKit
import CoreGraphics
import Foundation
import QuartzCore

@MainActor
final class WallpaperTransitionCoordinator {
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
      let previousImage = NSImage(contentsOf: previousImageURL),
      let newImage = NSImage(contentsOf: imageURL)
    else {
      try WallpaperSetter.apply(imageURL: imageURL, scaling: scaling, target: target)
      return
    }

    let windows = WallpaperSetter.screens(for: target).map { screen in
      makeOverlayWindow(
        for: screen,
        outgoingImage: previousImage,
        incomingImage: newImage,
        scaling: scaling
      )
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

  private func makeOverlayWindow(
    for screen: NSScreen,
    outgoingImage: NSImage,
    incomingImage: NSImage,
    scaling: WallpaperScaling
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
      outgoingImage: outgoingImage,
      incomingImage: incomingImage,
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
    outgoingImage: NSImage,
    incomingImage: NSImage,
    scaling: WallpaperScaling
  ) {
    let contentBounds = NSRect(origin: .zero, size: frame.size)
    let outgoing = WallpaperImageView(
      frame: contentBounds, image: outgoingImage, scaling: scaling
    )
    let incoming = WallpaperImageView(
      frame: contentBounds, image: incomingImage, scaling: scaling
    )
    incomingView = incoming
    super.init(frame: frame)
    wantsLayer = true
    addSubview(outgoing)
    addSubview(incoming)
    incoming.alphaValue = 0
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
