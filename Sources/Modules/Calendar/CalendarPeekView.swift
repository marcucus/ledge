import Core
import SwiftUI

// MARK: — CalendarPeekView

/// Compact peek (hover) state: just the truncated title of the next event, or empty.
public struct CalendarPeekView: View {
    public var module: CalendarModule

    public init(module: CalendarModule) {
        self.module = module
    }

    public var body: some View {
        HStack(spacing: 8) {
            if let event = module.nextEvent {
                Image(systemName: "calendar")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(event.title ?? "")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
    }
}
