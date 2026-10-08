import Core
import SwiftUI

extension TimerContentView {
    var notificationPermissionWarning: some View {
        Label {
            Text("timer.notification.error", bundle: localizationBundle)
        } icon: {
            Image(systemName: "bell.slash.fill")
        }
        .font(.caption)
        .foregroundStyle(.orange)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
