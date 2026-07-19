# Wallflow

Wallflow is a small, native macOS utility for curating and automatically rotating a personal wallpaper library. It is built with SwiftUI and AppKit, has no third-party dependencies, and keeps running from the menu bar when its main window is closed.

## Features

- Import multiple images with the file picker or by dragging them into the library.
- Keep reliable managed copies in `~/Library/Application Support/Wallflow`.
- Enable or exclude individual images without deleting them.
- Delete managed copies without touching the original source files.
- Double-click an enabled thumbnail to show it immediately and restart the rotation interval.
- Rotate sequentially or in shuffled order without immediate repeats.
- Choose intervals from one minute to one day.
- Select fill, fit, stretch, or center presentation.
- Apply wallpapers to every display or only the main display.
- Fade smoothly between wallpapers using a desktop-level transition overlay.
- Change to the next wallpaper from the menu bar or with Command-].
- Hide the menu-bar item while leaving Wallflow running and accessible from the Dock.
- Start Wallflow automatically at login.

## Run the app

Wallflow requires macOS 14 or later. Build a signed local app bundle with:

```sh
make app
open ./dist/Wallflow.app
```

The package script builds a universal Apple Silicon and Intel release executable, creates the `.app` bundle and icon set, validates its `Info.plist`, and applies an ad-hoc code signature. For everyday use, move `Wallflow.app` into `/Applications`; this also gives the launch-at-login setting a stable application location.

## Development

```sh
swift build
swift test
```

The domain behavior is tested at two public seams: rotation planning and the managed image library. Wallpaper application uses macOS’s `NSWorkspace` desktop-image API, while `SMAppService` manages launch at login.

Rotation occurs while Wallflow is running. Closing the main window leaves the menu-bar app running; choosing **Quit Wallflow** stops the timer.
