import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var updater: UpdateChecker
    @ObservedObject var agents: AgentMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            agentsSection
            Divider()
            if let errorMessage = store.errorMessage, store.summary == nil {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                usageSection
            }
            if updater.availableUpdate != nil || updater.statusMessage != nil {
                Divider()
                updateSection
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        HStack {
            Text("CursorBar").font(.headline)
            Spacer()
            Text(store.planDisplayName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Agents").font(.subheadline.weight(.medium))
                Spacer()
                Text("\(agents.totalRunning) running")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(agents.totalRunning > 0 ? .green : .secondary)
            }
            detailRow(title: "Local", value: "\(agents.localRunningCount)")
            detailRow(title: "Cloud", value: "\(agents.cloudRunningCount)")

            if !agents.agentsNeedingInput.isEmpty {
                Label("Needs input", systemImage: "exclamationmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.yellow)
                    .padding(.top, 2)
                ForEach(agents.agentsNeedingInput) { agent in
                    Button {
                        agent.openInCursor()
                    } label: {
                        HStack(alignment: .top, spacing: 6) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name).font(.caption).lineLimit(1)
                                Text(agent.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(agent.name) in Cursor. \(agent.reason)")
                }
            }
        }
    }

    @ViewBuilder
    private var usageSection: some View {
        if store.isUnlimitedPlan {
            Label("Unlimited usage plan", systemImage: "infinity")
                .font(.subheadline.weight(.medium))
            RemainingMeterView(
                title: "Until billing reset",
                valueText: store.billingResetValue(),
                progress: store.billingResetProgress(),
                accessibilityLabel: "Time remaining until billing reset",
                detail: store.billingResetDetail
            )
        } else {
            VStack(alignment: .leading, spacing: 8) {
                RemainingMeterView(
                    title: "Monthly remaining",
                    valueText: remainingValueText(store.includedPercentRemaining),
                    progress: store.includedRemainingProgress,
                    accessibilityLabel: "Monthly quota remaining",
                    detail: includedRemainingDetail
                )
                RemainingMeterView(
                    title: "Until billing reset",
                    valueText: store.billingResetValue(),
                    progress: store.billingResetProgress(),
                    accessibilityLabel: "Time remaining until billing reset",
                    detail: store.billingResetDetail
                )
            }
            if let percent = store.cursorModelsPercentRemaining {
                detailRow(title: "Cursor Models remaining", value: "\(Int(percent.rounded()))%")
            }
            if let percent = store.otherModelsPercentRemaining {
                detailRow(title: "Other Models remaining", value: "\(Int(percent.rounded()))%")
            }
        }
        if store.hasTokenTotals { tokensSection }
        if store.hasOverspend { overspendSection }
        if store.onDemandEnabled { onDemandSection }
        if let error = store.errorMessage {
            Label("Showing last successful data. \(error)", systemImage: "clock.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var includedRemainingDetail: String? {
        guard let remaining = store.includedRemainingCreditsCents,
              let limit = store.includedLimitCreditsCents
        else { return nil }
        return "\(UsageStore.formatDollars(cents: remaining)) left of \(UsageStore.formatDollars(cents: limit))"
    }

    private func remainingValueText(_ percent: Double?) -> String {
        guard let percent else { return "Unavailable" }
        return "\(Int(percent.rounded()))%"
    }

    private var tokensSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tokens").font(.subheadline.weight(.medium))
            if let count = store.periodTokenCount {
                detailRow(title: "This cycle", value: UsageStore.formatTokens(count))
            }
            if let count = store.lifetimeTokenCount {
                detailRow(title: "All time", value: UsageStore.formatTokens(count))
            }
            if let handle = store.profileHandle {
                Text("From cursor.com/@\(handle)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var overspendSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Overspend", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(UsageStore.formatDollars(cents: store.overspendCents))
                    .monospacedDigit()
                    .foregroundStyle(.red)
            }
            if store.includedOverageCents > 0 {
                detailRow(
                    title: "Over included",
                    value: UsageStore.formatDollars(cents: store.includedOverageCents),
                    valueColor: .red
                )
            }
            if store.onDemandUsedCents > 0 {
                detailRow(
                    title: "On-demand",
                    value: UsageStore.formatDollars(cents: store.onDemandUsedCents),
                    valueColor: .red
                )
            }
        }
    }

    private var onDemandSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !store.hasOverspend {
                HStack {
                    Text("On-demand spend").font(.subheadline.weight(.medium))
                    Spacer()
                    Text(onDemandSpendText).monospacedDigit()
                }
            }
            if let limit = store.onDemandLimitCents {
                detailRow(
                    title: store.hasOverspend ? "On-demand budget" : "On-demand limit",
                    value: UsageStore.formatDollars(cents: limit)
                )
            }
            if let remaining = store.onDemandRemainingCents {
                detailRow(
                    title: "On-demand remaining",
                    value: UsageStore.formatDollars(cents: remaining),
                    valueColor: remaining == 0 ? .red : .primary
                )
            }
        }
    }

    private var onDemandSpendText: String {
        let used = UsageStore.formatDollars(cents: store.onDemandUsedCents)
        guard let limit = store.onDemandLimitCents else { return used }
        return "\(used) / \(UsageStore.formatDollars(cents: limit))"
    }

    @ViewBuilder
    private var updateSection: some View {
        if let update = updater.availableUpdate {
            HStack {
                Text("Update available: v\(update.version)").font(.caption)
                Spacer()
                Button("View Release") { updater.openAvailableRelease() }
            }
        }
        if let message = updater.statusMessage {
            Text(message)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            Text("Updated \(store.lastUpdatedText) · v\(UpdateChecker.currentVersion)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                Task { await updater.checkForUpdates(announceResult: true) }
            } label: {
                Image(systemName: "arrow.down.circle")
            }
            .buttonStyle(.borderless)
            .help("Check for updates")
            .accessibilityLabel("Check for updates")
            .disabled(updater.isChecking)

            Button(store.isLoading ? "Refreshing…" : "Refresh") {
                Task { await store.refresh() }
            }
            .disabled(store.isLoading)
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
    }

    private func detailRow(
        title: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(valueColor)
        }
        .font(.caption)
    }
}

private struct RemainingMeterView: View {
    let title: String
    let valueText: String
    let progress: Double?
    let accessibilityLabel: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                Spacer()
                Text(valueText)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress ?? 0)
                .progressViewStyle(.linear)
                .tint(Color.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 6)
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(
                    progress.map { "\(Int(($0 * 100).rounded())) percent remaining" } ?? "Unavailable"
                )
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }
}
