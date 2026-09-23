import SwiftUI

struct SettingsView: View {
  private struct IntervalChoice: Identifiable {
    let seconds: TimeInterval
    let title: String
    var id: TimeInterval { seconds }
  }

  private static let intervals: [IntervalChoice] = [
    .init(seconds: 60, title: "Every Minute"),
    .init(seconds: 5 * 60, title: "Every 5 Minutes"),
    .init(seconds: 15 * 60, title: "Every 15 Minutes"),
    .init(seconds: 30 * 60, title: "Every 30 Minutes"),
    .init(seconds: 60 * 60, title: "Every Hour"),
    .init(seconds: 3 * 60 * 60, title: "Every 3 Hours"),
    .init(seconds: 6 * 60 * 60, title: "Every 6 Hours"),
    .init(seconds: 12 * 60 * 60, title: "Every 12 Hours"),
    .init(seconds: 24 * 60 * 60, title: "Every Day"),
  ]

  @ObservedObject var controller: AppController

  var body: some View {
    Form {
      Section("Rotation") {
        Toggle("Change wallpaper automatically", isOn: $controller.settings.rotationEnabled)

        Picker("Interval", selection: $controller.settings.intervalSeconds) {
          ForEach(intervalChoices) { interval in
            Text(interval.title).tag(interval.seconds)
          }
        }
        .disabled(!controller.settings.rotationEnabled)

        Picker("Order", selection: $controller.settings.order) {
          ForEach(WallpaperOrder.allCases) { order in
            Text(order.title).tag(order)
          }
        }
      }

      Section("Appearance") {
        Picker("Image sizing", selection: $controller.settings.scaling) {
          ForEach(WallpaperScaling.allCases) { scaling in
            Text(scaling.title).tag(scaling)
          }
        }

        Picker("Show on", selection: $controller.settings.displayTarget) {
          ForEach(DisplayTarget.allCases) { target in
            Text(target.title).tag(target)
          }
        }

        Toggle("Fade between wallpapers", isOn: $controller.settings.smoothTransitions)
      }

      Section {
        Toggle("Show in menu bar", isOn: $controller.settings.showsMenuBarIcon)

        Toggle(
          "Open at login",
          isOn: Binding(
            get: { controller.launchAtLoginState != .disabled },
            set: { controller.setLaunchAtLogin($0) }
          )
        )

        if controller.launchAtLoginState == .needsApproval {
          LabeledContent {
            Button("Open Login Items…") {
              controller.openLoginItemsSettings()
            }
          } label: {
            Text("Wallflow is switched off in Login Items, so it won’t open at login.")
              .foregroundStyle(.secondary)
          }
        }

        LabeledContent("Photo library") {
          Button("Show in Finder") {
            controller.revealLibrary()
          }
        }
      } header: {
        Text("General")
      } footer: {
        Text("Wallflow keeps changing your wallpaper while its window is closed, and stops when you quit.")
          .foregroundStyle(.secondary)
      }
    }
    .formStyle(.grouped)
  }

  /// The preset intervals, plus the saved one if it isn't a preset (from an
  /// older version or edited defaults), so the picker never shows blank.
  private var intervalChoices: [IntervalChoice] {
    let seconds = controller.settings.intervalSeconds
    guard !Self.intervals.contains(where: { $0.seconds == seconds }) else {
      return Self.intervals
    }

    let formatter = DateComponentsFormatter()
    formatter.allowedUnits = [.day, .hour, .minute, .second]
    formatter.unitsStyle = .full
    let custom = IntervalChoice(
      seconds: seconds,
      title: "Every \(formatter.string(from: seconds) ?? "\(Int(seconds)) seconds")"
    )
    return (Self.intervals + [custom]).sorted { $0.seconds < $1.seconds }
  }
}
