import SwiftUI

/// Permission message + GPS indicator + the action that fixes the problem.
struct LocationStatusView: View {
    let authorization: LocationAuthorization
    let gpsStatus: GPSStatus
    var onRequestAuthorization: () -> Void = {}

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Only the icon carries the status color: orange text would not be readable on white.
            Label {
                Text(gpsStatus.label)
            } icon: {
                Image(systemName: "location.fill").foregroundStyle(color)
            }
            .font(.headline)

            if let message = authorization.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if authorization.canRequest {
                Button("Allow Location", action: onRequestAuthorization)
                    .buttonStyle(.brandFilled)
            } else if authorization.canOpenSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.brandFilled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brandCard()
    }

    private var color: Color {
        switch gpsStatus {
        case .good: .green
        case .acquiring, .weak: .orange
        case .lost, .unavailable: .red
        }
    }
}
