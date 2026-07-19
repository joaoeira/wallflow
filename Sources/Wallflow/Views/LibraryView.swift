import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
  private enum Filter: String, CaseIterable, Identifiable {
    case all
    case enabled
    case disabled

    var id: Self { self }

    var title: String {
      rawValue.capitalized
    }
  }

  @ObservedObject var controller: AppController
  @State private var searchText = ""
  @State private var filter: Filter = .all
  @State private var pendingDelete: WallpaperItem?
  @State private var isDropTargeted = false

  private var visibleItems: [WallpaperItem] {
    controller.items
      .filter { item in
        let matchesFilter =
          switch filter {
          case .all: true
          case .enabled: item.isEnabled
          case .disabled: !item.isEnabled
          }
        let matchesSearch =
          searchText.isEmpty
          || item.displayName.localizedCaseInsensitiveContains(searchText)
        return matchesFilter && matchesSearch
      }
      .sorted { $0.addedAt > $1.addedAt }
  }

  var body: some View {
    VStack(spacing: 0) {
      header
      Divider()

      if controller.items.isEmpty {
        ContentUnavailableView {
          Label("Build Your Rotation", systemImage: "photo.badge.plus")
        } description: {
          Text(
            "Add a few favorite images. Wallflow keeps managed copies so the rotation stays reliable."
          )
        } actions: {
          Button("Add Photos…", action: chooseImages)
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else if visibleItems.isEmpty {
        ContentUnavailableView.search(text: searchText)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        GeometryReader { geometry in
          ScrollView {
            RotationStatusView(controller: controller)
              .padding(.bottom, 16)

            LazyVGrid(
              columns: gridColumns(for: max(0, geometry.size.width - 48)),
              alignment: .leading,
              spacing: 16
            ) {
              ForEach(visibleItems) { item in
                WallpaperCard(
                  item: item,
                  imageURL: imageURL(for: item),
                  isCurrent: item.id == controller.currentItemID,
                  onToggle: { controller.setEnabled($0, for: item) },
                  onShow: { controller.show(item) },
                  onReveal: { controller.reveal(item) },
                  onDelete: { pendingDelete = item }
                )
                .frame(maxWidth: .infinity)
              }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
          }
          .contentMargins(24, for: .scrollContent)
        }
      }
    }
    .background(isDropTargeted ? Color.accentColor.opacity(0.08) : Color.clear)
    .dropDestination(for: URL.self) { urls, _ in
      controller.importImages(at: urls.filter { $0.isFileURL })
      return true
    } isTargeted: { targeted in
      isDropTargeted = targeted
    }
    .confirmationDialog(
      "Delete “\(pendingDelete?.displayName ?? "this photo")”?",
      isPresented: Binding(
        get: { pendingDelete != nil },
        set: { if !$0 { pendingDelete = nil } }
      )
    ) {
      Button("Delete Photo", role: .destructive) {
        if let pendingDelete {
          controller.delete(pendingDelete)
        }
        pendingDelete = nil
      }
      Button("Cancel", role: .cancel) {
        pendingDelete = nil
      }
    } message: {
      Text("This removes Wallflow’s managed copy. The original file is not affected.")
    }
  }

  private var header: some View {
    VStack(spacing: 14) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 3) {
          Text("Wallpaper Library")
            .font(.largeTitle.weight(.semibold))
          Text("\(controller.enabledItemCount) of \(controller.items.count) photos enabled")
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button(action: chooseImages) {
          Label("Add Photos", systemImage: "plus")
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut("o", modifiers: [.command])
      }

      HStack(spacing: 12) {
        TextField("Search photos", text: $searchText)
          .textFieldStyle(.roundedBorder)
          .frame(maxWidth: 320)

        Picker("Filter", selection: $filter) {
          ForEach(Filter.allCases) { filter in
            Text(filter.title).tag(filter)
          }
        }
        .labelsHidden()
        .pickerStyle(.segmented)
        .frame(width: 240)

        Spacer()
      }
    }
    .padding(24)
  }

  private func chooseImages() {
    let panel = NSOpenPanel()
    panel.title = "Add Photos to Wallflow"
    panel.prompt = "Add Photos"
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true

    if panel.runModal() == .OK {
      controller.importImages(at: panel.urls)
    }
  }

  private func imageURL(for item: WallpaperItem) -> URL {
    controller.libraryDirectoryURL
      .appendingPathComponent("Images", isDirectory: true)
      .appendingPathComponent(item.fileName)
  }

  private func gridColumns(for availableWidth: CGFloat) -> [GridItem] {
    let minimumCardWidth: CGFloat = 220
    let maximumCardWidth: CGFloat = 300
    let spacing: CGFloat = 16
    let fittingColumnCount = max(
      1,
      Int((availableWidth + spacing) / (minimumCardWidth + spacing))
    )
    let columnCount = min(visibleItems.count, fittingColumnCount)

    return Array(
      repeating: GridItem(
        .flexible(minimum: minimumCardWidth, maximum: maximumCardWidth),
        spacing: spacing,
        alignment: .top
      ),
      count: columnCount
    )
  }
}
