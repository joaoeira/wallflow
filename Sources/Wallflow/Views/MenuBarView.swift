import AppKit
import SwiftUI

struct MenuBarView: View {
  @ObservedObject var controller: AppController
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    if let current = controller.currentItem {
      Text("Current: \(current.displayName)")
    } else {
      Text("No wallpaper selected")
    }

    Button("Next Wallpaper", systemImage: "forward.fill") {
      controller.rotateNow()
    }
    .disabled(controller.enabledItemCount == 0)

    Toggle("Automatic Rotation", isOn: $controller.settings.rotationEnabled)

    Divider()

    Button("Open Wallflow", systemImage: "macwindow") {
      openWindow(id: "main")
      NSApp.activate(ignoringOtherApps: true)
    }

    Button("Show Photo Library", systemImage: "folder") {
      controller.revealLibrary()
    }

    Divider()

    Button("Quit Wallflow") {
      NSApplication.shared.terminate(nil)
    }
    .keyboardShortcut("q")
  }
}
