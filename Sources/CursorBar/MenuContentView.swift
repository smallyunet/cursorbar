import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var updater: UpdateChecker
    @ObservedObject var agents: AgentMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: MenuChrome.stackSpacing) {
            usageSection
            if store.hasTokenTotals {
                Divider()
                tokensSection
            }
            if store.hasOverspend {
                Divider()
                overspendSection
            }
            if store.onDemandEnabled {
                Divider()
                onDemandSection
            }
            Divider()
            agentsSection
            if updater.availableUpdate != nil || updater.statusMessage != nil {
                Divider()
                updateSection
            }
            Divider()
            footer
        }
        .padding(.horizontal, MenuChrome.horizontalPadding)
        .padding(.vertical, MenuChrome.verticalPadding)
        .frame(width: MenuChrome.menuWidth)
    }

    @ViewBuilder
    private var usageSection: some View {
        MenuLabelRow(title: "Plan", value: store.planDisplayName)
        if let remaining = store.includedRemainingCreditsCents {
            MenuLabelRow(title: "Included credits remaining", value: UsageStore.formatDollars(cents: remaining))
        }
        if let remaining = store.otherModelsRemainingCreditsCents {
            MenuLabelRow(title: "Other Models credits remaining", value: UsageStore.formatDollars(cents: remaining))
        }
        if store.isUnlimitedPlan {
            MenuLabelRow(title: "Monthly remaining", value: "Unlimited")
        } else if let errorMessage = store.errorMessage, store.summary == nil {
            MenuLabelRow(title: "Monthly remaining", value: "Unavailable")
            MenuDetailText(text: errorMessage, emphasized: true, lineLimit: 3)
        } else {
            MenuLabelRow(
                title: "Monthly remaining",
                value: remainingValueText(store.includedPercentRemaining)
            )
            NeutralProgressBar(
                progress: store.includedRemainingProgress,
                accessibilityLabel: "Monthly quota remaining"
            )
        }
        MenuLabelRow(title: "Until billing reset", value: store.billingResetValue())
        NeutralProgressBar(
            progress: store.billingResetProgress(),
            accessibilityLabel: "Time remaining until billing reset"
        )
        if let detail = store.billingResetDetail {
            MenuDetailText(text: detail)
        }
        if !store.isUnlimitedPlan, let percent = store.cursorModelsPercentRemaining {
            MenuLabelRow(title: "Cursor Models remaining", value: "\(Int(percent.rounded()))%")
        }
        if !store.isUnlimitedPlan, let percent = store.otherModelsPercentRemaining {
            MenuLabelRow(title: "Other Models remaining", value: "\(Int(percent.rounded()))%")
        }
        if store.errorMessage != nil, store.summary != nil {
            MenuDetailText(text: "Refresh failed · Last updated: \(store.lastUpdatedText)", emphasized: true)
        }
    }

    private func remainingValueText(_ percent: Double?) -> String {
        guard let percent else { return "Unavailable" }
        return "\(Int(percent.rounded()))%"
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: MenuChrome.stackSpacing) {
            MenuLabelRow(
                title: "Agents",
                value: "\(agents.totalRunning) running"
            )
            MenuLabelRow(title: "Local", value: "\(agents.localRunningCount)")
            MenuLabelRow(title: "Cloud", value: "\(agents.cloudRunningCount)")

            if !agents.agentsNeedingInput.isEmpty {
                MenuLabelRow(title: "Needs input", value: "\(agents.needsInputCount)")
                ForEach(agents.agentsNeedingInput) { agent in
                    Button {
                        agent.openInCursor()
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(agent.name)
                                    .font(.system(size: MenuChrome.rowFontSize, weight: .medium))
                                    .foregroundStyle(Color(nsColor: .labelColor))
                                    .lineLimit(1)
                                Text(agent.reason)
                                    .font(.system(size: MenuChrome.detailFontSize))
                                    .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: MenuChrome.detailFontSize, weight: .medium))
                                .foregroundStyle(Color(nsColor: .secondaryLabelColor))
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open \(agent.name) in Cursor. \(agent.reason)")
                }
            }
        }
    }

    private var tokensSection: some View {
        VStack(alignment: .leading, spacing: MenuChrome.stackSpacing) {
            if let count = store.periodTokenCount {
                MenuLabelRow(title: "This cycle", value: UsageStore.formatTokens(count))
            }
            if let count = store.lifetimeTokenCount {
                MenuLabelRow(title: "All time", value: UsageStore.formatTokens(count))
            }
            if let handle = store.profileHandle {
                MenuDetailText(text: "From cursor.com/@\(handle)")
            }
        }
    }

    private var overspendSection: some View {
        VStack(alignment: .leading, spacing: MenuChrome.stackSpacing) {
            if let overspend = store.overspendCents, overspend > 0 {
                MenuLabelRow(
                    title: "Overspend",
                    value: UsageStore.formatDollars(cents: overspend),
                    valueColor: Color(nsColor: .systemRed)
                )
            }
            if let overage = store.includedOverageCents, overage > 0 {
                MenuLabelRow(
                    title: "Over included",
                    value: UsageStore.formatDollars(cents: overage),
                    valueColor: Color(nsColor: .systemRed)
                )
            }
            if let onDemand = store.onDemandUsedCents, onDemand > 0 {
                MenuLabelRow(
                    title: "On-demand",
                    value: UsageStore.formatDollars(cents: onDemand),
                    valueColor: Color(nsColor: .systemRed)
                )
            }
        }
    }

    private var onDemandSection: some View {
        VStack(alignment: .leading, spacing: MenuChrome.stackSpacing) {
            if !store.hasOverspend {
                MenuLabelRow(title: "On-demand spend", value: onDemandSpendText)
            }
            if let limit = store.onDemandLimitCents {
                MenuLabelRow(
                    title: store.hasOverspend ? "On-demand budget" : "On-demand limit",
                    value: UsageStore.formatDollars(cents: limit)
                )
            }
            if let remaining = store.onDemandRemainingCents {
                MenuLabelRow(
                    title: "On-demand remaining",
                    value: UsageStore.formatDollars(cents: remaining),
                    valueColor: remaining == 0 ? Color(nsColor: .systemRed) : nil
                )
            }
        }
    }

    private var onDemandSpendText: String {
        guard let usedCents = store.onDemandUsedCents else { return "Unavailable" }
        let used = UsageStore.formatDollars(cents: usedCents)
        guard let limit = store.onDemandLimitCents else { return used }
        return "\(used) / \(UsageStore.formatDollars(cents: limit))"
    }

    @ViewBuilder
    private var updateSection: some View {
        if let update = updater.availableUpdate {
            Button("View \(update.version) Release…") { updater.openAvailableRelease() }
                .buttonStyle(.plain)
                .font(.system(size: MenuChrome.rowFontSize))
        }
        if let message = updater.statusMessage {
            MenuDetailText(text: message, lineLimit: 3)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: MenuChrome.stackSpacing) {
            MenuDetailText(text: "Updated: \(store.lastUpdatedText)")
            MenuDetailText(text: "Version \(UpdateChecker.currentVersion)")
            Button("Check for Updates…") {
                Task { await updater.checkForUpdates(announceResult: true) }
            }
            .disabled(updater.isChecking)
            Button(store.isLoading ? "Refreshing…" : "Refresh Now") {
                Task { await store.refresh() }
            }
            .disabled(store.isLoading)
            Button("Quit CursorBar") { NSApplication.shared.terminate(nil) }
        }
        .buttonStyle(.plain)
        .font(.system(size: MenuChrome.rowFontSize))
        .foregroundStyle(Color(nsColor: .labelColor))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
