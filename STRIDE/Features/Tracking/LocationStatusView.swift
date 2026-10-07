import SwiftUI

/// Permission message + GPS indicator + the action that fixes the problem.
struct LocationStatusView: View {
    let authorization: LocationAuthorization
    let gpsStatus: GPSStatus
    var onRequestAuthorization: () -> Void = {}

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(gpsStatus.label, systemImage: "location.fill")
                .foregroundStyle(color)
                .font(.headline)

            if let message = authorization.message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if authorization.canRequest {
                Button("Allow Location", action: onRequestAuthorization)
                    .buttonStyle(.borderedProminent)
            } else if authorization.canOpenSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var color: Color {
        switch gpsStatus {
        case .good: .green
        case .acquiring, .weak: .orange
        case .lost, .unavailable: .red
        }
    }
}
