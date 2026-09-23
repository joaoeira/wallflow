import SwiftUI

@main
struct WallflowApp: App {
  @StateObject private var controller: AppController

  init() {
    let controller = AppController.forCurrentLaunch()
    _controller = StateObject(wrappedValue: controller)
    // Rotation runs from launch, whether or not the main window is ever shown
    // (for example after a login launch or a restored, closed window).
    Task {
      controller.start()
    }
  }

  var body: some Scene {
    Window("Wallflow", id: "main") {
      ContentView(controller: controller)
        .frame(minWidth: 860, minHeight: 560)
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

    MenuBarExtra(isInserted: menuBarIconBinding) {
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

  private var menuBarIconBinding: Binding<Bool> {
    Binding(
      get: { controller.settings.showsMenuBarIcon },
      set: { isVisible in
        guard controller.settings.showsMenuBarIcon != isVisible else { return }
        controller.settings.showsMenuBarIcon = isVisible
      }
    )
  }
}
