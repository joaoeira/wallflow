import SwiftUI

struct RotationStatusView: View {
  @ObservedObject var controller: AppController

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: statusIcon)
        .font(.title2)
        .foregroundStyle(statusColor)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text(statusTitle)
          .font(.headline)

        if let nextChangeDate = controller.nextChangeDate,
          controller.settings.rotationEnabled
        {
          TimelineView(.periodic(from: .now, by: 1)) { context in
            Text("Next change in \(remaining(until: nextChangeDate, now: context.date))")
              .font(.subheadline)
              .foregroundStyle(.secondary)
              .monospacedDigit()
          }
        } else {
          Text(statusSubtitle)
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      if controller.enabledItemCount > 0 {
        Button("Next Now") {
          controller.rotateNow()
        }
        .buttonStyle(.bordered)
      }

      Toggle("Rotation", isOn: $controller.settings.rotationEnabled)
        .labelsHidden()
        .toggleStyle(.switch)
        .help(controller.settings.rotationEnabled ? "Pause rotation" : "Resume rotation")
    }
    .padding(14)
    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .strokeBorder(Color.primary.opacity(0.08))
    }
  }

  private var statusTitle: String {
    if controller.enabledItemCount == 0 { return "No photos enabled" }
    return controller.settings.rotationEnabled ? "Rotation is running" : "Rotation is paused"
  }

  private var statusSubtitle: String {
    if controller.enabledItemCount == 0 {
      return "Enable a photo to resume the rotation."
    }
    return "Your current wallpaper will stay in place."
  }

  private var statusIcon: String {
    if controller.enabledItemCount == 0 { return "exclamationmark.triangle.fill" }
    return controller.settings.rotationEnabled ? "arrow.triangle.2.circlepath" : "pause.circle.fill"
  }

  private var statusColor: Color {
    if controller.enabledItemCount == 0 { return .orange }
    return controller.settings.rotationEnabled ? .green : .secondary
  }

  private func remaining(until date: Date, now: Date) -> String {
    let total = max(0, Int(date.timeIntervalSince(now)))
    let hours = total / 3_600
    let minutes = (total % 3_600) / 60
    let seconds = total % 60

    if hours > 0 { return "\(hours)h \(minutes)m" }
    if minutes > 0 { return "\(minutes)m \(seconds)s" }
    return "\(seconds)s"
  }
}
