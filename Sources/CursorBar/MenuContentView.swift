import AppKit
import SwiftUI

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var updater: UpdateChecker
    @ObservedObject var agents: AgentMonitor
    @State private var showSettings = false
    @AppStorage(MenuBarPrefs.showQuotaKey) private var showQuota = true
    @AppStorage(MenuBarPrefs.showDailyKey) private var showDaily = true
    @AppStorage(MenuBarPrefs.showOverspendKey) private var showOverspend = true
    @AppStorage(MenuBarPrefs.showAgentsKey) private var showAgents = true
    @AppStorage(MenuBarPrefs.iconStyleKey) private var iconStyle = MenuBarIconStyle.compact

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
            if showSettings {
                Divider()
                settingsSection
            }
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("CursorBar").font(.headline)
                Spacer()
                Text(store.planDisplayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Text(store.billingCycleText)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let days = store.daysUntilReset {
                Text("Resets in \(days) day\(days == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
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
        let hasMeters = store.includedPercentUsed != nil
            || store.cursorModelsPercentUsed != nil
            || store.otherModelsPercentUsed != nil

        if store.isUnlimitedPlan {
            Label("Unlimited usage plan", systemImage: "infinity")
                .font(.subheadline.weight(.medium))
        } else if hasMeters {
            VStack(alignment: .leading, spacing: 10) {
                if let percent = store.includedPercentUsed {
                    UsageMeterView(
                        title: "Included usage",
                        percent: percent,
                        color: store.includedStatusColor,
                        usedCents: store.includedUsedCreditsCents,
                        limitCents: store.includedLimitCreditsCents,
                        remainingCents: store.includedRemainingCreditsCents
                    )
                }
                if let percent = store.cursorModelsPercentUsed {
                    UsageMeterView(
                        title: "Cursor Models",
                        percent: percent,
                        color: store.cursorModelsStatusColor
                    )
                }
                if let percent = store.otherModelsPercentUsed {
                    UsageMeterView(
                        title: "Other Models",
                        percent: percent,
                        color: store.otherModelsStatusColor,
                        usedCents: store.otherModelsUsedCreditsCents,
                        limitCents: store.otherModelsLimitCreditsCents
                    )
                }
            }
        }

        if hasMeters, store.dailyUtilizationPercent != nil { Divider() }
        if let percent = store.dailyUtilizationPercent {
            UsageMeterView(
                title: "Daily utilization",
                percent: percent,
                color: store.dailyStatusColor,
                usedCents: store.todaySpendCents,
                limitCents: store.dailyBudgetCents,
                usedLabel: "Today",
                footnote: store.workingDaysInCycle.map {
                    "Daily budget = quota / \($0) working days"
                }
            )
        }
        if store.hasTokenTotals, hasMeters || store.dailyUtilizationPercent != nil {
            Divider()
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

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Show in menu bar").font(.caption.weight(.medium))
            Group {
                Toggle("Agents badge", isOn: $showAgents)
                Toggle("Quota", isOn: $showQuota)
                Toggle("Daily utilization", isOn: $showDaily)
                Toggle("Overspend amount", isOn: $showOverspend)
            }
            .toggleStyle(.checkbox)
            .font(.caption)
            Text("Icon style").font(.caption.weight(.medium)).padding(.top, 4)
            Picker("Icon style", selection: $iconStyle) {
                Text("Gauges").tag(MenuBarIconStyle.gauges)
                Text("Icon & percent").tag(MenuBarIconStyle.compact)
            }
            .pickerStyle(.segmented)
            .font(.caption)
            .labelsHidden()
            .accessibilityLabel("Menu bar icon style")
            .help("Gauges keep the filled pie and bar. Icon & percent uses a template symbol plus the percentage, like Codex Notch.")
        }
    }

    private var footer: some View {
        HStack {
            Text("Updated \(store.lastUpdatedText) · v\(UpdateChecker.currentVersion)")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
            Button { showSettings.toggle() } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Menu bar settings")
            .accessibilityLabel(showSettings ? "Hide menu bar settings" : "Show menu bar settings")

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

private struct UsageMeterView: View {
    let title: String
    let percent: Double
    let color: Color
    var usedCents: Int?
    var limitCents: Int?
    var remainingCents: Int?
    var usedLabel = "Used"
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .frame(width: 110, alignment: .leading)
                    .lineLimit(1)
                ProgressView(value: min(max(percent / 100, 0), 1))
                    .tint(color)
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
                    .accessibilityLabel(title)
                    .accessibilityValue("\(Int(percent.rounded())) percent used")
                Text("\(Int(percent.rounded()))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(color)
                    .frame(width: 30, alignment: .trailing)
            }
            if let detailText {
                Text(detailText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if let footnote {
                Text(footnote).font(.caption2).foregroundStyle(.secondary)
            }
        }
    }

    private var detailText: String? {
        guard let usedCents, let limitCents else { return nil }
        var value = "\(usedLabel) \(UsageStore.formatDollars(cents: usedCents))"
            + " / \(UsageStore.formatDollars(cents: limitCents))"
        if let remainingCents {
            value += " · \(UsageStore.formatDollars(cents: remainingCents)) left"
        }
        return value
    }
}
