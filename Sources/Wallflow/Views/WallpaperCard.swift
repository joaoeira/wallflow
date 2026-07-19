import AppKit
import SwiftUI

struct WallpaperCard: View {
  let item: WallpaperItem
  let imageURL: URL
  let isCurrent: Bool
  let onToggle: (Bool) -> Void
  let onShow: () -> Void
  let onReveal: () -> Void
  let onDelete: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      thumbnail
        .frame(maxWidth: .infinity)
        .frame(height: 152)
        .contentShape(Rectangle())
        .onTapGesture(count: 2, perform: onShow)
        .help(
          item.isEnabled
            ? "Double-click to show this wallpaper now"
            : "Enable this wallpaper before showing it"
        )

      HStack(spacing: 10) {
        VStack(alignment: .leading, spacing: 3) {
          Text(item.displayName)
            .font(.headline)
            .lineLimit(1)
          Text(item.isEnabled ? "In rotation" : "Excluded")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer(minLength: 4)

        Toggle(
          "Include \(item.displayName)",
          isOn: Binding(get: { item.isEnabled }, set: onToggle)
        )
        .labelsHidden()
        .toggleStyle(.switch)

        Menu {
          Button("Show Now", systemImage: "desktopcomputer", action: onShow)
            .disabled(!item.isEnabled)
          Button("Show in Finder", systemImage: "folder", action: onReveal)
          Divider()
          Button("Delete…", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
          Image(systemName: "ellipsis.circle")
            .font(.title3)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
      }
      .padding(12)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(nsColor: .controlBackgroundColor))
    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .strokeBorder(
          isCurrent ? Color.accentColor : Color.primary.opacity(0.09),
          lineWidth: isCurrent ? 2 : 1
        )
    }
    .opacity(item.isEnabled ? 1 : 0.66)
    .contextMenu {
      Button("Show Now", action: onShow)
        .disabled(!item.isEnabled)
      Button("Show in Finder", action: onReveal)
      Divider()
      Button("Delete…", role: .destructive, action: onDelete)
    }
  }

  private var thumbnail: some View {
    ZStack {
      Rectangle()
        .fill(Color.secondary.opacity(0.12))

      WallpaperThumbnail(imageURL: imageURL)
    }
    .clipped()
    .overlay(alignment: .topLeading) {
      if isCurrent {
        Label("Current", systemImage: "checkmark.circle.fill")
          .font(.caption.weight(.semibold))
          .padding(.horizontal, 9)
          .padding(.vertical, 5)
          .background(.ultraThickMaterial, in: Capsule())
          .padding(.leading, 12)
          .padding(.top, 16)
      }
    }
  }
}

private struct WallpaperThumbnail: View {
  let imageURL: URL

  @State private var image: NSImage?
  @State private var loadedImageURL: URL?

  var body: some View {
    GeometryReader { geometry in
      Group {
        if let image {
          Image(nsImage: image)
            .resizable()
            .scaledToFill()
        } else {
          Image(systemName: "photo")
            .font(.system(size: 32))
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
    .task(id: imageURL) {
      guard loadedImageURL != imageURL else { return }
      loadedImageURL = imageURL
      image = nil
      image = await WallpaperThumbnailCache.shared.image(for: imageURL)
    }
  }
}
