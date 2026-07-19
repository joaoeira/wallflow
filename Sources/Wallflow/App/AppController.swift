import AppKit
import Combine
import Foundation

@MainActor
final class AppController: ObservableObject {
  struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
  }

  @Published private(set) var items: [WallpaperItem] = []
  @Published var settings: WallpaperSettings {
    didSet {
      guard settings != oldValue else { return }
      persistSettings()
      guard hasStarted else { return }
      respondToSettingsChange(from: oldValue)
    }
  }
  @Published private(set) var currentItemID: UUID?
  @Published private(set) var nextChangeDate: Date?
  @Published private(set) var launchAtLoginEnabled = false
  @Published var presentedError: PresentedError?

  let libraryDirectoryURL: URL

  private let defaults: UserDefaults
  private var libraryStore: WallpaperLibraryStore?
  private var timer: Timer?
  private var hasStarted = false

  private static let settingsKey = "wallflow.settings"
  private static let currentItemKey = "wallflow.current-item"

  init(
    libraryDirectoryURL: URL? = nil,
    defaults: UserDefaults = .standard
  ) {
    self.defaults = defaults
    settings = Self.loadSettings(from: defaults)
    currentItemID = defaults.string(forKey: Self.currentItemKey).flatMap(UUID.init(uuidString:))
    launchAtLoginEnabled = LaunchAtLoginManager.isEnabled

    if let libraryDirectoryURL {
      self.libraryDirectoryURL = libraryDirectoryURL
    } else {
      let applicationSupport =
        FileManager.default.urls(
          for: .applicationSupportDirectory,
          in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
      self.libraryDirectoryURL =
        applicationSupport
        .appendingPathComponent("Wallflow", isDirectory: true)
    }

    do {
      let store = try WallpaperLibraryStore(rootDirectory: self.libraryDirectoryURL)
      libraryStore = store
      items = store.items
    } catch {
      presentedError = PresentedError(
        title: "Library Unavailable",
        message: error.localizedDescription
      )
    }
  }

  deinit {
    timer?.invalidate()
  }

  var enabledItemCount: Int {
    items.lazy.filter(\.isEnabled).count
  }

  var currentItem: WallpaperItem? {
    items.first { $0.id == currentItemID }
  }

  func start() {
    guard !hasStarted else { return }
    hasStarted = true

    if settings.rotationEnabled {
      if currentItem?.isEnabled != true, enabledItemCount > 0 {
        rotateNow()
      } else {
        scheduleNextChange()
      }
    }
  }

  func importImages(at urls: [URL]) {
    guard let libraryStore, !urls.isEmpty else { return }

    do {
      _ = try libraryStore.importImages(at: urls)
      refreshItems()
      if settings.rotationEnabled, currentItem == nil {
        rotateNow()
      } else if settings.rotationEnabled, timer == nil {
        scheduleNextChange()
      }
    } catch {
      present(error, title: "Couldn’t Add Photos")
    }
  }

  func setEnabled(_ isEnabled: Bool, for item: WallpaperItem) {
    guard let libraryStore else { return }

    do {
      try libraryStore.setEnabled(isEnabled, for: item.id)
      refreshItems()

      if !isEnabled, currentItemID == item.id {
        currentItemID = nil
        persistCurrentItem()
        if enabledItemCount > 0 {
          rotateNow()
        } else {
          invalidateSchedule()
        }
      } else if settings.rotationEnabled {
        scheduleNextChange()
      }
    } catch {
      present(error, title: "Couldn’t Update Photo")
    }
  }

  func delete(_ item: WallpaperItem) {
    guard let libraryStore else { return }

    do {
      let wasCurrent = currentItemID == item.id
      try libraryStore.delete(itemID: item.id)
      refreshItems()

      if wasCurrent {
        currentItemID = nil
        persistCurrentItem()
      }

      if wasCurrent, enabledItemCount > 0 {
        rotateNow()
      } else if settings.rotationEnabled {
        scheduleNextChange()
      }
    } catch {
      present(error, title: "Couldn’t Delete Photo")
    }
  }

  func rotateNow() {
    guard
      let libraryStore,
      let next = RotationPlanner.next(
        from: items,
        after: currentItemID,
        order: settings.order
      )
    else {
      invalidateSchedule()
      return
    }

    apply(item: next, from: libraryStore)
  }

  func show(_ item: WallpaperItem) {
    guard item.isEnabled, let libraryStore else { return }
    apply(item: item, from: libraryStore)
  }

  func reveal(_ item: WallpaperItem) {
    guard let libraryStore else { return }
    NSWorkspace.shared.activateFileViewerSelecting([libraryStore.fileURL(for: item)])
  }

  func revealLibrary() {
    NSWorkspace.shared.activateFileViewerSelecting([libraryDirectoryURL])
  }

  func setLaunchAtLogin(_ isEnabled: Bool) {
    do {
      try LaunchAtLoginManager.setEnabled(isEnabled)
      launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
    } catch {
      launchAtLoginEnabled = LaunchAtLoginManager.isEnabled
      present(error, title: "Couldn’t Change Login Setting")
    }
  }

  private func apply(item: WallpaperItem, from store: WallpaperLibraryStore) {
    do {
      try WallpaperSetter.apply(
        imageURL: store.fileURL(for: item),
        scaling: settings.scaling,
        target: settings.displayTarget
      )
      currentItemID = item.id
      persistCurrentItem()

      if settings.rotationEnabled {
        scheduleNextChange()
      } else {
        invalidateSchedule()
      }
    } catch {
      present(error, title: "Couldn’t Change Wallpaper")
      if settings.rotationEnabled {
        scheduleNextChange()
      }
    }
  }

  private func respondToSettingsChange(from oldSettings: WallpaperSettings) {
    if !settings.rotationEnabled {
      invalidateSchedule()
      return
    }

    if currentItem?.isEnabled != true, enabledItemCount > 0 {
      rotateNow()
      return
    }

    let presentationChanged =
      settings.scaling != oldSettings.scaling
      || settings.displayTarget != oldSettings.displayTarget

    if presentationChanged, let currentItem, let libraryStore {
      apply(item: currentItem, from: libraryStore)
    } else {
      scheduleNextChange()
    }
  }

  private func scheduleNextChange() {
    timer?.invalidate()

    guard settings.rotationEnabled, enabledItemCount > 0 else {
      nextChangeDate = nil
      timer = nil
      return
    }

    let interval = max(60, settings.intervalSeconds)
    let fireDate = Date().addingTimeInterval(interval)
    nextChangeDate = fireDate

    let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
      Task { @MainActor in
        self?.rotateNow()
      }
    }
    timer.tolerance = min(10, interval * 0.05)
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  private func invalidateSchedule() {
    timer?.invalidate()
    timer = nil
    nextChangeDate = nil
  }

  private func refreshItems() {
    items = libraryStore?.items ?? []
  }

  private func persistSettings() {
    do {
      defaults.set(try JSONEncoder().encode(settings), forKey: Self.settingsKey)
    } catch {
      present(error, title: "Couldn’t Save Settings")
    }
  }

  private func persistCurrentItem() {
    defaults.set(currentItemID?.uuidString, forKey: Self.currentItemKey)
  }

  private static func loadSettings(from defaults: UserDefaults) -> WallpaperSettings {
    guard
      let data = defaults.data(forKey: settingsKey),
      let decoded = try? JSONDecoder().decode(WallpaperSettings.self, from: data)
    else {
      return WallpaperSettings()
    }
    return decoded
  }

  private func present(_ error: Error, title: String) {
    presentedError = PresentedError(title: title, message: error.localizedDescription)
  }
}
