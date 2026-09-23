import AppKit
import SwiftUI

enum MenuBarText {
    static let fontSize = MenuChrome.menuBarFontSize
}

enum MenuBarQuotaIcon {
    static let width: CGFloat = 38
    static let height: CGFloat = 16
    static let cornerRadius: CGFloat = 4

    /// Original quota pill: white label on a dark menu bar, dark label on a light one.
    static func usesWhiteLabel(isDark: Bool) -> Bool {
        isDark
    }

    static func labelColor(isDark: Bool) -> Color {
        usesWhiteLabel(isDark: isDark) ? .white : .black
    }

    static func trackColor(isDark: Bool) -> Color {
        isDark ? Color.white.opacity(0.2) : Color.black.opacity(0.12)
    }

    static func fillColor(usedPercent: Double?) -> Color {
        guard let usedPercent else { return Color(nsColor: .secondaryLabelColor) }
        if usedPercent >= 90 { return .red }
        if usedPercent >= 70 { return .yellow }
        return .green
    }

    @MainActor
    static func image(remainingPercent: Double?, usedPercent: Double?, title: String, isDark: Bool) -> NSImage? {
        let content = MenuBarQuotaPill(
            remainingPercent: remainingPercent,
            usedPercent: usedPercent,
            title: title,
            isDark: isDark
        )
        let renderer = ImageRenderer(content: content)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @StateObject private var chrome = MenuBarChromeMonitor()

    var body: some View {
        if let image = renderedImage {
            Image(nsImage: image)
                .renderingMode(.original)
                .accessibilityLabel(accessibilitySummary)
        } else {
            Text(store.menuBarLabel)
                .font(.system(size: MenuBarText.fontSize, weight: .medium).monospacedDigit())
                .monospacedDigit()
                .accessibilityLabel(accessibilitySummary)
        }
    }

    private var renderedImage: NSImage? {
        MenuBarQuotaIcon.image(
            remainingPercent: store.quotaPercentRemaining,
            usedPercent: store.quotaPercentUsed,
            title: store.menuBarLabel,
            isDark: chrome.isDark
        )
    }

    private var accessibilitySummary: String {
        if store.isUnlimitedPlan {
            return "CursorBar, unlimited usage remaining"
        }
        if let remaining = store.quotaPercentRemaining {
            return "CursorBar, \(Int(remaining.rounded())) percent monthly quota remaining"
        }
        if store.summary == nil {
            return store.isLoading ? "CursorBar, loading usage" : "CursorBar, usage unavailable"
        }
        return "CursorBar, monthly remaining unavailable"
    }
}

private struct MenuBarQuotaPill: View {
    let remainingPercent: Double?
    let usedPercent: Double?
    let title: String
    let isDark: Bool

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: MenuBarQuotaIcon.cornerRadius)
                        .fill(MenuBarQuotaIcon.trackColor(isDark: isDark))
                    if let remainingPercent {
                        RoundedRectangle(cornerRadius: MenuBarQuotaIcon.cornerRadius)
                            .fill(MenuBarQuotaIcon.fillColor(usedPercent: usedPercent).opacity(0.85))
                            .frame(
                                width: max(
                                    geometry.size.width * UsageRemaining.clamp(remainingPercent / 100),
                                    remainingPercent > 0 ? 4 : 0
                                )
                            )
                    }
                }
            }
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(MenuBarQuotaIcon.labelColor(isDark: isDark))
                .shadow(
                    color: isDark ? .black.opacity(0.4) : .white.opacity(0.4),
                    radius: 0.5
                )
        }
        .frame(width: MenuBarQuotaIcon.width, height: MenuBarQuotaIcon.height)
        .clipShape(RoundedRectangle(cornerRadius: MenuBarQuotaIcon.cornerRadius))
    }
}
