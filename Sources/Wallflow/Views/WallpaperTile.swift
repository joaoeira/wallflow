import AppKit
import SwiftUI

struct WallpaperTile: View {
  let item: WallpaperItem
  let imageURL: URL?
  let isCurrent: Bool
  let isSelected: Bool

  /// Thumbnails take the shape of the main display, so each reads as a
  /// preview of the desktop rather than an arbitrary crop.
  static let aspectRatio: CGFloat = {
    guard let frame = NSScreen.screens.first?.frame, frame.height > 0 else { return 16 / 10 }
    return frame.width / frame.height
  }()

  private let cornerRadius: CGFloat = 8

  var body: some View {
    VStack(spacing: 7) {
      thumbnail
        .padding(4)
        .overlay {
          if isSelected {
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
              .strokeBorder(Color.accentColor, lineWidth: 3)
          }
        }

      Text(item.displayName)
        .font(.callout)
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
        .padding(.horizontal, 6)
        .padding(.vertical, 1)
        .background {
          if isSelected {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
              .fill(Color.accentColor)
          }
        }
        .padding(.horizontal, 4)
    }
    .contentShape(Rectangle())
    .help(item.displayName)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityDescription)
    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
  }

  private var thumbnail: some View {
    WallpaperThumbnail(imageURL: imageURL)
      .aspectRatio(Self.aspectRatio, contentMode: .fit)
      .saturation(item.isEnabled ? 1 : 0)
      .opacity(item.isEnabled ? 1 : 0.7)
      .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
      .overlay {
        // A hairline edge keeps pale wallpapers from bleeding into the window.
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
      }
      .overlay(alignment: .bottomLeading) {
        HStack(spacing: 4) {
          if isCurrent {
            badge {
              Label("Current", systemImage: "checkmark.circle.fill")
                .padding(.horizontal, 7)
            }
          }
          if !item.isEnabled {
            badge {
              Image(systemName: "eye.slash")
                .frame(width: 22)
            }
            .help("Excluded from rotation")
          }
        }
        .padding(7)
      }
  }

  private func badge(@ViewBuilder content: () -> some View) -> some View {
    content()
      .font(.caption.weight(.semibold))
      .frame(height: 22)
      .background(.ultraThinMaterial, in: Capsule())
      .environment(\.colorScheme, .dark)
  }

  private var accessibilityDescription: String {
    var parts = [item.displayName]
    if isCurrent { parts.append("current wallpaper") }
    if !item.isEnabled { parts.append("excluded from rotation") }
    return parts.joined(separator: ", ")
  }
}

private struct WallpaperThumbnail: View {
  let imageURL: URL?

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
          Rectangle()
            .fill(.quaternary)
        }
      }
      .frame(width: geometry.size.width, height: geometry.size.height)
      .clipped()
    }
    .task(id: imageURL) {
      guard loadedImageURL != imageURL else { return }
      loadedImageURL = imageURL
      image = nil
      guard let imageURL else { return }
      image = await WallpaperThumbnailCache.shared.image(for: imageURL)
    }
  }
}
