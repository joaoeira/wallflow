import SwiftUI

enum LibrarySection: String, CaseIterable, Identifiable {
  case all
  case inRotation
  case excluded

  var id: Self { self }

  var title: String {
    switch self {
    case .all: "All Photos"
    case .inRotation: "In Rotation"
    case .excluded: "Excluded"
    }
  }

  var systemImage: String {
    switch self {
    case .all: "photo.on.rectangle"
    case .inRotation: "arrow.triangle.2.circlepath"
    case .excluded: "eye.slash"
    }
  }

  func contains(_ item: WallpaperItem) -> Bool {
    switch self {
    case .all: true
    case .inRotation: item.isEnabled
    case .excluded: !item.isEnabled
    }
  }
}

struct ContentView: View {
  @ObservedObject var controller: AppController
  @State private var section: LibrarySection? = .all
  @State private var searchText = ""

  var body: some View {
    NavigationSplitView {
      List(selection: $section) {
        Section("Library") {
          ForEach(LibrarySection.allCases) { section in
            Label(section.title, systemImage: section.systemImage)
              .badge(controller.items.filter(section.contains).count)
              .tag(section)
          }
        }
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
    } detail: {
      LibraryView(
        controller: controller,
        section: section ?? .all,
        searchText: searchText
      )
      .navigationTitle((section ?? .all).title)
      .navigationSubtitle(rotationSummary)
      .toolbar { toolbarContent }
    }
    .searchable(text: $searchText, placement: .toolbar, prompt: "Search")
    .alert(item: $controller.presentedError) { error in
      Alert(
        title: Text(error.title),
        message: Text(error.message),
        dismissButton: .default(Text("OK"))
      )
    }
  }

  @ToolbarContentBuilder
  private var toolbarContent: some ToolbarContent {
    ToolbarItemGroup {
      Button {
        controller.settings.rotationEnabled.toggle()
      } label: {
        if controller.settings.rotationEnabled {
          Label("Pause Rotation", systemImage: "pause.fill")
        } else {
          Label("Resume Rotation", systemImage: "play.fill")
        }
      }
      .help(controller.settings.rotationEnabled ? "Pause rotation" : "Resume rotation")

      Button {
        controller.rotateNow()
      } label: {
        Label("Next Wallpaper", systemImage: "forward.fill")
      }
      .help("Show the next wallpaper now")
      .disabled(controller.enabledItemCount == 0)
    }

    if #available(macOS 26.0, *) {
      ToolbarSpacer(.fixed)
    }

    ToolbarItem {
      Button {
        controller.importImages(at: ImportPanel.chooseImages())
      } label: {
        Label("Add Photos", systemImage: "plus")
      }
      .help("Add photos to the library")
    }
  }

  private var rotationSummary: String {
    guard !controller.items.isEmpty else { return "" }
    guard controller.enabledItemCount > 0 else { return "No photos in rotation" }
    guard controller.settings.rotationEnabled, let nextChangeDate = controller.nextChangeDate
    else { return "Rotation paused" }
    return "Next wallpaper \(Self.describe(nextChangeDate))"
  }

  /// "at 14:32", "tomorrow at 09:00", or "Friday at 09:00". A fixed time
  /// rather than a countdown, so the title bar isn't redrawn every second.
  private static func describe(_ date: Date) -> String {
    let time = date.formatted(date: .omitted, time: .shortened)
    if Calendar.current.isDateInToday(date) { return "at \(time)" }
    if Calendar.current.isDateInTomorrow(date) { return "tomorrow at \(time)" }
    return "\(date.formatted(.dateTime.weekday(.wide))) at \(time)"
  }
}
