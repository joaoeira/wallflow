import AppKit
import QuickLook
import SwiftUI

struct LibraryView: View {
  @ObservedObject var controller: AppController
  let section: LibrarySection
  let searchText: String

  @State private var selection: Set<WallpaperItem.ID> = []
  /// The item a shift-click extends from and the arrow keys move from.
  @State private var selectionAnchor: WallpaperItem.ID?
  @State private var pendingDeletion: Set<WallpaperItem.ID> = []
  @State private var quickLookURL: URL?
  @State private var isDropTargeted = false
  @FocusState private var isGridFocused: Bool

  private let minimumTileWidth: CGFloat = 200
  private let maximumTileWidth: CGFloat = 320
  private let columnSpacing: CGFloat = 20
  private let margin: CGFloat = 20

  private var visibleItems: [WallpaperItem] {
    controller.items
      .filter { item in
        section.contains(item)
          && (searchText.isEmpty || item.displayName.localizedCaseInsensitiveContains(searchText))
      }
      .sorted { $0.addedAt > $1.addedAt }
  }

  private var selectedItems: [WallpaperItem] {
    visibleItems.filter { selection.contains($0.id) }
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
      .onChange(of: section) {
        selection = []
        selectionAnchor = nil
      }
      .confirmationDialog(
        deletionTitle,
        isPresented: Binding(
          get: { !pendingDeletion.isEmpty },
          set: { if !$0 { pendingDeletion = [] } }
        )
      ) {
        Button(pendingDeletion.count == 1 ? "Delete Photo" : "Delete Photos", role: .destructive) {
          controller.delete(pendingDeletion)
          selection.subtract(pendingDeletion)
          pendingDeletion = []
        }
        Button("Cancel", role: .cancel) {}
      } message: {
        Text(
          pendingDeletion.count == 1
            ? "This removes Wallflow’s copy. The original file is not affected."
            : "This removes Wallflow’s copies. The original files are not affected."
        )
      }
      .quickLookPreview($quickLookURL, in: selectedItems.compactMap(controller.imageURL(for:)))
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
        let columnCount = columnCount(for: geometry.size.width - margin * 2)
        ScrollViewReader { scrollProxy in
          ScrollView {
            grid(columnCount: columnCount)
          }
          .contentMargins(margin, for: .scrollContent)
          .focusable()
          .focused($isGridFocused)
          .focusEffectDisabled()
          .onMoveCommand { direction in
            moveSelection(direction, columnCount: columnCount, scrollProxy: scrollProxy)
          }
          .onDeleteCommand {
            pendingDeletion = Set(selectedItems.map(\.id))
          }
          .onKeyPress(.space) {
            toggleQuickLook()
            return .handled
          }
          .onCommand(#selector(NSResponder.selectAll(_:))) {
            selection = Set(visibleItems.map(\.id))
          }
        }
      }
    }
  }

  private func grid(columnCount: Int) -> some View {
    LazyVGrid(
      columns: Array(
        repeating: GridItem(
          .flexible(minimum: minimumTileWidth, maximum: maximumTileWidth),
          spacing: columnSpacing,
          alignment: .top
        ),
        count: columnCount
      ),
      alignment: .leading,
      spacing: 24
    ) {
      ForEach(visibleItems) { item in
        WallpaperTile(
          item: item,
          imageURL: controller.imageURL(for: item),
          isCurrent: item.id == controller.currentItemID,
          isSelected: selection.contains(item.id)
        )
        .id(item.id)
        .onTapGesture(count: 2) {
          controller.show(item)
        }
        .simultaneousGesture(
          TapGesture().onEnded {
            select(item, modifiers: NSEvent.modifierFlags)
          }
        )
        .contextMenu {
          contextMenu(for: item)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .topLeading)
    .background {
      // Clicking between tiles clears the selection, as in Finder.
      Color.clear
        .contentShape(Rectangle())
        .onTapGesture {
          selection = []
          isGridFocused = true
        }
    }
  }

  @ViewBuilder
  private func contextMenu(for item: WallpaperItem) -> some View {
    // Like Finder, a right-click inside the selection acts on all of it.
    let targets = selection.contains(item.id) ? selectedItems : [item]
    let ids = Set(targets.map(\.id))

    if targets.count == 1 {
      Button("Show on Desktop") {
        controller.show(item)
      }
      .disabled(!item.isEnabled)
    }

    if targets.allSatisfy(\.isEnabled) {
      Button("Exclude from Rotation") {
        controller.setEnabled(false, for: ids)
      }
    } else {
      Button("Include in Rotation") {
        controller.setEnabled(true, for: ids)
      }
    }

    Divider()

    Button("Quick Look") {
      if !selection.contains(item.id) {
        selection = [item.id]
        selectionAnchor = item.id
      }
      quickLookURL = controller.imageURL(for: item)
    }

    Button("Show in Finder") {
      controller.reveal(ids)
    }

    Divider()

    Button(targets.count == 1 ? "Delete…" : "Delete \(targets.count) Photos…", role: .destructive) {
      pendingDeletion = ids
    }
  }

  private var deletionTitle: String {
    if pendingDeletion.count == 1,
      let item = controller.items.first(where: { pendingDeletion.contains($0.id) })
    {
      return "Delete “\(item.displayName)”?"
    }
    return "Delete \(pendingDeletion.count) photos?"
  }

  private func select(_ item: WallpaperItem, modifiers: NSEvent.ModifierFlags) {
    isGridFocused = true

    if modifiers.contains(.command) {
      selection.formSymmetricDifference([item.id])
      selectionAnchor = item.id
    } else if modifiers.contains(.shift),
      let selectionAnchor,
      let anchorIndex = visibleItems.firstIndex(where: { $0.id == selectionAnchor }),
      let itemIndex = visibleItems.firstIndex(where: { $0.id == item.id })
    {
      let range = min(anchorIndex, itemIndex)...max(anchorIndex, itemIndex)
      selection = Set(visibleItems[range].map(\.id))
    } else {
      selection = [item.id]
      selectionAnchor = item.id
    }
  }

  private func moveSelection(
    _ direction: MoveCommandDirection,
    columnCount: Int,
    scrollProxy: ScrollViewProxy
  ) {
    let items = visibleItems
    guard !items.isEmpty else { return }

    let offset =
      switch direction {
      case .left: -1
      case .right: 1
      case .up: -columnCount
      case .down: columnCount
      @unknown default: 0
      }
    let targetIndex =
      selectionAnchor
      .flatMap { id in items.firstIndex { $0.id == id } }
      .map { min(max($0 + offset, 0), items.count - 1) }
      ?? 0
    let target = items[targetIndex]

    selection = [target.id]
    selectionAnchor = target.id
    scrollProxy.scrollTo(target.id)
    if quickLookURL != nil {
      quickLookURL = controller.imageURL(for: target)
    }
  }

  private func toggleQuickLook() {
    if quickLookURL != nil {
      quickLookURL = nil
    } else if let item = selectedItems.first(where: { $0.id == selectionAnchor })
      ?? selectedItems.first
    {
      quickLookURL = controller.imageURL(for: item)
    }
  }

  private func columnCount(for availableWidth: CGFloat) -> Int {
    let fittingCount = Int(
      (availableWidth + columnSpacing) / (minimumTileWidth + columnSpacing)
    )
    return max(1, min(visibleItems.count, fittingCount))
  }
}
