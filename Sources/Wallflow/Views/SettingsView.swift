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
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Settings")
            .font(.largeTitle.weight(.semibold))
          Text("Control the timing, order, and presentation of your rotation.")
            .foregroundStyle(.secondary)
        }

        GroupBox {
          VStack(spacing: 14) {
            settingsRow("Automatic rotation") {
              Toggle("Automatic rotation", isOn: $controller.settings.rotationEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
            }

            Divider()

            settingsRow("Change wallpaper") {
              Picker("Change wallpaper", selection: $controller.settings.intervalSeconds) {
                ForEach(Self.intervals) { interval in
                  Text(interval.title).tag(interval.seconds)
                }
              }
              .labelsHidden()
              .frame(width: 180)
            }
            .disabled(!controller.settings.rotationEnabled)

            Divider()

            settingsRow("Order") {
              Picker("Order", selection: $controller.settings.order) {
                ForEach(WallpaperOrder.allCases) { order in
                  Text(order.title).tag(order)
                }
              }
              .labelsHidden()
              .pickerStyle(.segmented)
              .frame(width: 220)
            }
          }
          .padding(6)
        } label: {
          Label("Rotation", systemImage: "arrow.triangle.2.circlepath")
            .font(.headline)
        }

        GroupBox {
          VStack(spacing: 14) {
            settingsRow("Image sizing") {
              Picker("Image sizing", selection: $controller.settings.scaling) {
                ForEach(WallpaperScaling.allCases) { scaling in
                  Text(scaling.title).tag(scaling)
                }
              }
              .labelsHidden()
              .frame(width: 180)
            }

            Divider()

            settingsRow("Apply to") {
              Picker("Apply to", selection: $controller.settings.displayTarget) {
                ForEach(DisplayTarget.allCases) { target in
                  Text(target.title).tag(target)
                }
              }
              .labelsHidden()
              .frame(width: 180)
            }

            Divider()

            settingsRow("Smooth transitions") {
              Toggle("Smooth transitions", isOn: $controller.settings.smoothTransitions)
                .labelsHidden()
                .toggleStyle(.switch)
            }
          }
          .padding(6)
        } label: {
          Label("Presentation", systemImage: "display")
            .font(.headline)
        }

        GroupBox {
          VStack(spacing: 14) {
            settingsRow("Show menu-bar icon") {
              Toggle("Show menu-bar icon", isOn: $controller.settings.showsMenuBarIcon)
                .labelsHidden()
                .toggleStyle(.switch)
            }

            Divider()

            settingsRow("Open Wallflow at login") {
              Toggle(
                "Open Wallflow at login",
                isOn: Binding(
                  get: { controller.launchAtLoginEnabled },
                  set: { controller.setLaunchAtLogin($0) }
                )
              )
              .labelsHidden()
              .toggleStyle(.switch)
            }

            Divider()

            settingsRow("Managed photo library") {
              Button("Show in Finder") {
                controller.revealLibrary()
              }
            }
          }
          .padding(6)
        } label: {
          Label("App", systemImage: "macwindow")
            .font(.headline)
        }

        Text(
          "Wallflow keeps rotating after its windows close. Reopen it from the menu bar when visible, or from the Dock. Rotation stops when the app quits."
        )
        .font(.footnote)
        .foregroundStyle(.secondary)
      }
      .padding(24)
      .frame(maxWidth: 680)
      .frame(maxWidth: .infinity)
    }
  }

  private func settingsRow<Content: View>(
    _ title: String,
    @ViewBuilder content: () -> Content
  ) -> some View {
    HStack {
      Text(title)
      Spacer()
      content()
    }
  }
}
