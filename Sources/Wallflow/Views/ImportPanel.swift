import AppKit
import UniformTypeIdentifiers

@MainActor
enum ImportPanel {
  /// Asks for image files to add to the library; empty if cancelled.
  static func chooseImages() -> [URL] {
    let panel = NSOpenPanel()
    panel.title = "Add Photos to Wallflow"
    panel.prompt = "Add Photos"
    panel.allowedContentTypes = [.image]
    panel.allowsMultipleSelection = true
    panel.canChooseDirectories = false
    panel.canChooseFiles = true
    return panel.runModal() == .OK ? panel.urls : []
  }
}
