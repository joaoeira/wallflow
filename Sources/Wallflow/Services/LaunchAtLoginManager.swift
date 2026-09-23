import ServiceManagement

enum LaunchAtLoginManager {
  enum State {
    case disabled
    case enabled
    /// Registered, but switched off in System Settings › General › Login Items.
    case needsApproval
  }

  static var state: State {
    switch SMAppService.mainApp.status {
    case .enabled: .enabled
    case .requiresApproval: .needsApproval
    default: .disabled
    }
  }

  static func setEnabled(_ isEnabled: Bool) throws {
    if isEnabled {
      try SMAppService.mainApp.register()
    } else {
      try SMAppService.mainApp.unregister()
    }
  }

  static func openLoginItemsSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
