import SwiftUI

@main
struct WallflowApp: App {
  @StateObject private var controller = AppController()

  var body: some Scene {
    Window("Wallflow", id: "main") {
      ContentView(controller: controller)
        .frame(minWidth: 860, minHeight: 560)
        .onAppear {
          controller.start()
        }
    }
    .defaultSize(width: 1_040, height: 700)
    .commands {
      CommandMenu("Wallpaper") {
        Button("Next Wallpaper") {
          controller.rotateNow()
        }
        .keyboardShortcut("]", modifiers: [.command])
        .disabled(controller.enabledItemCount == 0)

        Toggle("Rotation Enabled", isOn: $controller.settings.rotationEnabled)
      }
    }

    MenuBarExtra {
      MenuBarView(controller: controller)
    } label: {
      Label(
        "Wallflow",
        systemImage: controller.settings.rotationEnabled
          ? "photo.stack.fill"
          : "pause.circle.fill"
      )
    }

    Settings {
      SettingsView(controller: controller)
        .frame(width: 560, height: 540)
    }
  }
}
