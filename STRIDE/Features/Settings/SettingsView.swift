import SwiftUI

/// Units, goal and appearance. Each group is an opaque card on the brand gradient, so its text
/// keeps the system's contrast in light and dark mode (see docs/DESIGN.md).
struct SettingsView: View {
    @Bindable var settings: AppSettings
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    unitsCard
                    goalCard
                    appearanceCard
                    aboutCard
                }
                .padding()
            }
            .navigationTitle("Settings")
            .brandScreen()
        }
    }

    private var unitsCard: some View {
        card("Units", footnote: "Distances and paces are shown in this unit. Your saved runs are not changed.") {
            choice("Units", selection: $settings.distanceUnit, options: DistanceUnit.allCases) { Text($0.name) }
        }
    }

    private var goalCard: some View {
        card("Run goal", footnote: "The progress shows on the Tracking screen during a run.") {
            choice("Goal", selection: $settings.goalKind, options: AppSettings.GoalKind.allCases) { Text($0.name) }

            switch settings.goalKind {
            case .none:
                EmptyView()
            case .distance:
                Stepper(
                    onIncrement: { settings.stepDistanceGoal(by: 1) },
                    onDecrement: { settings.stepDistanceGoal(by: -1) }
                ) {
                    Text(DistanceFormat.goal(settings.goalDistance, unit: settings.distanceUnit))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                .accessibilityLabel("Goal distance")
                .accessibilityValue(SpokenFormat.distance(settings.goalDistance, unit: settings.distanceUnit))
                .accessibilityIdentifier("goalDistanceStepper")
            case .time:
                Stepper(
                    onIncrement: { settings.stepTimeGoal(by: 1) },
                    onDecrement: { settings.stepTimeGoal(by: -1) }
                ) {
                    Text(DurationFormat.goal(settings.goalTime))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
                .accessibilityLabel("Goal time")
                .accessibilityValue(SpokenFormat.duration(settings.goalTime))
                .accessibilityIdentifier("goalTimeStepper")
            }
        }
    }

    private var appearanceCard: some View {
        card("Appearance", footnote: "System follows the light or dark mode of your iPhone.") {
            choice("Appearance", selection: $settings.appearance, options: AppSettings.Appearance.allCases) { Text($0.name) }
        }
    }

    private var aboutCard: some View {
        card("About", footnote: "STRIDE has no account and sends your runs nowhere.") {
            Link("Privacy policy", destination: AppLinks.privacyPolicy)
                .accessibilityIdentifier("privacyPolicyLink")
            Link("Support", destination: AppLinks.support)
                .accessibilityIdentifier("supportLink")
        }
    }

    /// A segmented control, or a menu at accessibility text sizes where segments would truncate.
    @ViewBuilder
    private func choice<Value: Hashable & Identifiable>(
        _ title: LocalizedStringKey,
        selection: Binding<Value>,
        options: [Value],
        @ViewBuilder label: @escaping (Value) -> some View
    ) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            Picker(title, selection: selection) {
                ForEach(options) { label($0).tag($0) }
            }
            .pickerStyle(.menu)
        } else {
            Picker(title, selection: selection) {
                ForEach(options) { label($0).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }

    private func card<Content: View>(
        _ title: LocalizedStringKey,
        footnote: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            content()
            Text(footnote).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .brandCard()
    }
}
