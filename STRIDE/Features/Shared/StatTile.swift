import SwiftUI

/// A value with its caption, e.g. `5.20` over `Distance (km)`. Read by VoiceOver as a single
/// element with the spoken value ("5.2 kilometers"), not the visual text.
struct StatTile: View {
    let title: LocalizedStringResource
    /// Unit shown in the caption, e.g. `km`; `nil` when the value carries no unit.
    var unit: String?
    let value: String
    let spokenValue: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.title2.monospacedDigit().weight(.bold))
            Text(verbatim: caption).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(spokenValue)
    }

    private var caption: String {
        let name = String(localized: title)
        return unit.map { "\(name) (\($0))" } ?? name
    }
}

/// Lays children out in a row, or in a column at accessibility text sizes where a row would clip.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat = 24
    @ViewBuilder let content: Content
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: spacing))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout { content }
    }
}

/// Progress toward the run goal: a bar plus the numbers, and a clear message once it is reached.
struct GoalProgressCard: View {
    let goal: RunGoal
    let distance: Double
    let elapsed: TimeInterval
    let unit: DistanceUnit

    var body: some View {
        let progress = goal.progress(distance: distance, elapsed: elapsed)
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    heading(progress)
                    Spacer()
                    numbers
                }
                VStack(alignment: .leading, spacing: 4) {
                    heading(progress)
                    numbers
                }
            }
            ProgressView(value: progress.fraction)
                .tint(BrandPalette.accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brandCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Goal"))
        .accessibilityValue(spokenValue(progress))
        .accessibilityIdentifier("goalProgress")
    }

    @ViewBuilder
    private func heading(_ progress: RunGoal.Progress) -> some View {
        if progress.isReached {
            Label("Goal reached", systemImage: "checkmark.circle.fill").font(.headline)
        } else {
            Label("Goal", systemImage: "flag.checkered").font(.headline)
        }
    }

    private var numbers: some View {
        Text(goal.progressText(distance: distance, elapsed: elapsed, unit: unit))
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
    }

    private func spokenValue(_ progress: RunGoal.Progress) -> String {
        let percent = Int((progress.fraction * 100).rounded(.down))
        let target: String = switch goal {
        case .distance(let meters): SpokenFormat.distance(meters, unit: unit)
        case .time(let seconds): SpokenFormat.duration(seconds)
        }
        let done = String(localized: "\(percent) percent of \(target)")
        return progress.isReached ? String(localized: "Goal reached") + ", " + done : done
    }
}
