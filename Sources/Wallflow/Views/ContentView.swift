import SwiftUI

struct ContentView: View {
  enum Destination: String, CaseIterable, Identifiable {
    case library
    case settings

    var id: Self { self }

    var title: String {
      switch self {
      case .library: "Library"
      case .settings: "Settings"
      }
    }

    var systemImage: String {
      switch self {
      case .library: "photo.on.rectangle.angled"
      case .settings: "gearshape"
      }
    }
  }

  @ObservedObject var controller: AppController
  @State private var selection: Destination? = .library

  var body: some View {
    NavigationSplitView {
      List(selection: $selection) {
        Section {
          ForEach(Destination.allCases) { destination in
            Label(destination.title, systemImage: destination.systemImage)
              .tag(destination)
          }
        }

        Section("Rotation") {
          LabeledContent("Enabled") {
            Text("\(controller.enabledItemCount)")
              .monospacedDigit()
          }
          LabeledContent("Status") {
            Text(sidebarStatus)
              .foregroundStyle(sidebarStatusColor)
          }
        }
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 210)
      .safeAreaInset(edge: .top) {
        HStack(spacing: 10) {
          Image(systemName: "photo.stack.fill")
            .font(.title2)
            .foregroundStyle(.blue)
          Text("Wallflow")
            .font(.headline)
          Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
      }
    } detail: {
      switch selection ?? .library {
      case .library:
        LibraryView(controller: controller)
      case .settings:
        SettingsView(controller: controller)
      }
    }
    .alert(item: $controller.presentedError) { error in
      Alert(
        title: Text(error.title),
        message: Text(error.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  private var sidebarStatus: String {
    if controller.enabledItemCount == 0 { return "Waiting" }
    return controller.settings.rotationEnabled ? "Running" : "Paused"
  }

  private var sidebarStatusColor: Color {
    if controller.enabledItemCount == 0 { return .orange }
    return controller.settings.rotationEnabled ? .green : .secondary
  }
}
