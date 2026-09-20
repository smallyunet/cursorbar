import AppKit
import SwiftUI

enum MenuBarIconStyle: String, CaseIterable {
    case gauges
    case compact
}

enum MenuBarPrefs {
    static let showQuotaKey = "menuBarShowQuota"
    static let showDailyKey = "menuBarShowDaily"
    static let showOverspendKey = "menuBarShowOverspend"
    static let showAgentsKey = "menuBarShowAgents"
    static let iconStyleKey = "menuBarIconStyle"
}

enum MenuBarCompactText {
    static let quotaSymbol = "chart.pie.fill"
    static let dailySymbol = "chart.bar.fill"
    static let fontSize: CGFloat = 12

    static func percentTitle(percent: Double?, isUnlimited: Bool = false) -> String {
        if isUnlimited { return "∞" }
        guard let percent else { return "—" }
        return "\(Int(percent.rounded()))%"
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var agents: AgentMonitor
    @AppStorage(MenuBarPrefs.showQuotaKey) private var showQuota = true
    @AppStorage(MenuBarPrefs.showDailyKey) private var showDaily = true
    @AppStorage(MenuBarPrefs.showOverspendKey) private var showOverspend = true
    @AppStorage(MenuBarPrefs.showAgentsKey) private var showAgents = true
    @AppStorage(MenuBarPrefs.iconStyleKey) private var iconStyle = MenuBarIconStyle.compact
    @StateObject private var chrome = MenuBarChromeMonitor()

    var body: some View {
        if store.summary == nil {
            Text(store.menuBarLabel)
                .monospacedDigit()
                .accessibilityLabel(accessibilitySummary)
        } else if !hasVisibleContent {
            Image(systemName: "chart.bar.fill")
                .accessibilityLabel(accessibilitySummary)
        } else if iconStyle == .compact {
            compactContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(accessibilitySummary)
        } else if let image = renderedImage {
            Image(nsImage: image)
                .accessibilityLabel(accessibilitySummary)
        } else {
            Text(store.menuBarLabel)
                .monospacedDigit()
                .accessibilityLabel(accessibilitySummary)
        }
    }

    private var hasVisibleContent: Bool {
        showAgents || showQuota || showDaily || (showOverspend && store.hasOverspend)
    }

    private var accessibilitySummary: String {
        var parts = ["CursorBar"]
        if showAgents {
            parts.append("\(agents.totalRunning) agents running")
            if agents.needsInputCount > 0 {
                parts.append("\(agents.needsInputCount) need input")
            }
        }
        if showQuota {
            if store.isUnlimitedPlan {
                parts.append("unlimited usage")
            } else if let quota = store.quotaPercentUsed {
                parts.append("\(Int(quota.rounded())) percent quota used")
            }
        }
        if showDaily, let daily = store.dailyUtilizationPercent {
            parts.append("\(Int(daily.rounded())) percent daily utilization")
        }
        if showOverspend, store.hasOverspend {
            parts.append("\(UsageStore.formatDollars(cents: store.overspendCents)) overspend")
        }
        return parts.joined(separator: ", ")
    }

    private var compactContent: some View {
        HStack(spacing: 8) {
            if showAgents {
                MenuBarAgentBadge(
                    totalRunning: agents.totalRunning,
                    needsInputCount: agents.needsInputCount
                )
            }
            if showQuota {
                MenuBarCompactMetric(
                    systemImage: MenuBarCompactText.quotaSymbol,
                    title: MenuBarCompactText.percentTitle(
                        percent: store.quotaPercentUsed,
                        isUnlimited: store.isUnlimitedPlan
                    )
                )
            }
            if showDaily {
                MenuBarCompactMetric(
                    systemImage: MenuBarCompactText.dailySymbol,
                    title: MenuBarCompactText.percentTitle(percent: store.dailyUtilizationPercent)
                )
            }
            if showOverspend, store.hasOverspend {
                Text(UsageStore.formatDollarsCompact(cents: store.overspendCents))
                    .font(.system(size: MenuBarCompactText.fontSize, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
    }

    private var renderedImage: NSImage? {
        let isDark = chrome.isDark
        let content = HStack(spacing: 8) {
            if showAgents {
                MenuBarAgentBadge(
                    totalRunning: agents.totalRunning,
                    needsInputCount: agents.needsInputCount
                )
            }
            if showQuota {
                MenuBarRingGauge(
                    percent: store.quotaPercentUsed,
                    isUnlimited: store.isUnlimitedPlan,
                    fillColor: store.statusColor,
                    isDark: isDark
                )
            }
            if showDaily {
                MenuBarBarGauge(
                    percent: store.dailyUtilizationPercent,
                    fillColor: store.dailyStatusColor,
                    isDark: isDark
                )
            }
            if showOverspend, store.hasOverspend {
                Text(UsageStore.formatDollarsCompact(cents: store.overspendCents))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 1)

        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}

private struct MenuBarCompactMetric: View {
    let systemImage: String
    let title: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.system(size: MenuBarCompactText.fontSize, weight: .medium))
                .imageScale(.small)
                .symbolRenderingMode(.monochrome)
            Text(title)
                .font(.system(size: MenuBarCompactText.fontSize, weight: .medium, design: .default))
                .monospacedDigit()
        }
    }
}

private struct MenuBarAgentBadge: View {
    let totalRunning: Int
    let needsInputCount: Int

    private var fillColor: Color {
        if needsInputCount > 0 { return .yellow }
        return totalRunning > 0 ? .green : .red
    }

    private var text: String {
        AgentMonitorFormatting.compactCount(needsInputCount > 0 ? needsInputCount : totalRunning)
    }

    var body: some View {
        ZStack {
            Circle().fill(fillColor.opacity(0.9))
            Text(text)
                .font(.system(size: text.count > 1 ? 9 : 10, weight: .bold, design: .monospaced))
                .foregroundStyle(needsInputCount > 0 ? .black : .white)
                .fixedSize()
        }
        .frame(width: 16, height: 16)
    }
}

private struct PieSlice: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return Path() }
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(-90 + 360 * clamped),
            clockwise: false
        )
        path.closeSubpath()
        return path
    }
}

private struct MenuBarRingGauge: View {
    let percent: Double?
    let isUnlimited: Bool
    let fillColor: Color
    let isDark: Bool

    var body: some View {
        ZStack {
            Circle().fill(isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.12))
            if let percent {
                PieSlice(fraction: percent / 100).fill(fillColor.opacity(0.9))
            }
            if isUnlimited {
                Text("∞")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isDark ? .white : .black)
            }
        }
        .frame(width: 16, height: 16)
    }
}

private struct MenuBarBarGauge: View {
    let percent: Double?
    let fillColor: Color
    let isDark: Bool

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.12))
                    if let percent {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fillColor.opacity(0.85))
                            .frame(
                                width: max(
                                    geometry.size.width * min(percent / 100, 1),
                                    percent > 0 ? 4 : 0
                                )
                            )
                    }
                }
            }
            Text(percent.map { "\(Int($0.rounded()))%" } ?? "–")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(isDark ? .white : .black)
                .shadow(
                    color: isDark ? .black.opacity(0.4) : .white.opacity(0.4),
                    radius: 0.5
                )
        }
        .frame(width: 38, height: 16)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
