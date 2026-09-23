import SwiftUI

struct LibraryView: View {
  @ObservedObject var controller: AppController
  let section: LibrarySection
  let searchText: String

  @State private var pendingDelete: WallpaperItem?
  @State private var isDropTargeted = false

  private var visibleItems: [WallpaperItem] {
    controller.items
      .filter { item in
        section.contains(item)
          && (searchText.isEmpty || item.displayName.localizedCaseInsensitiveContains(searchText))
      }
      .sorted { $0.addedAt > $1.addedAt }
  }

  var body: some View {
    content
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .overlay {
        if isDropTargeted {
          RoundedRectangle(cornerRadius: 12, style: .continuous)
            .strokeBorder(Color.accentColor, lineWidth: 3)
            .padding(6)
            .allowsHitTesting(false)
        }
      }
      .dropDestination(for: URL.self) { urls, _ in
        controller.importImages(at: urls)
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
            controller.delete([pendingDelete.id])
          }
          pendingDelete = nil
        }
        Button("Cancel", role: .cancel) {
          pendingDelete = nil
        }
      } message: {
        Text("This removes Wallflow’s copy. The original file is not affected.")
      }
  }

  @ViewBuilder
  private var content: some View {
    if controller.items.isEmpty {
      ContentUnavailableView {
        Label("Add Your Wallpapers", systemImage: "photo.badge.plus")
      } description: {
        Text(
          "Drag images here or choose them in Finder. Wallflow keeps its own copies, so your originals stay where they are."
        )
      } actions: {
        Button("Add Photos…") {
          controller.importImages(at: ImportPanel.chooseImages())
        }
      }
    } else if visibleItems.isEmpty, !searchText.isEmpty {
      ContentUnavailableView.search(text: searchText)
    } else if visibleItems.isEmpty {
      ContentUnavailableView(
        section == .excluded ? "No Excluded Photos" : "No Photos in Rotation",
        systemImage: section.systemImage,
        description: Text(
          section == .excluded
            ? "Photos you exclude stay in your library but won’t appear on the desktop."
            : "Include photos to add them to the rotation."
        )
      )
    } else {
      GeometryReader { geometry in
        ScrollView {
          LazyVGrid(
            columns: gridColumns(for: max(0, geometry.size.width - 48)),
            alignment: .leading,
            spacing: 16
          ) {
            ForEach(visibleItems) { item in
              WallpaperCard(
                item: item,
                imageURL: controller.imageURL(for: item),
                isCurrent: item.id == controller.currentItemID,
                onToggle: { controller.setEnabled($0, for: [item.id]) },
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
