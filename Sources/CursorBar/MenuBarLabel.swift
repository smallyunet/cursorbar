import AppKit
import SwiftUI

enum MenuBarText {
    static let fontSize = MenuChrome.menuBarFontSize
}

enum MenuBarQuotaIcon {
    static let size: CGFloat = 16

    /// Original single quota icon: a pale circle, white-tinted on a dark menu bar.
    static func usesWhiteTrack(isDark: Bool) -> Bool {
        isDark
    }

    static func trackColor(isDark: Bool) -> Color {
        usesWhiteTrack(isDark: isDark) ? Color.white.opacity(0.2) : Color.black.opacity(0.12)
    }

    static func fillColor(usedPercent: Double?) -> Color {
        guard let usedPercent else { return Color(nsColor: .secondaryLabelColor) }
        if usedPercent >= 90 { return .red }
        if usedPercent >= 70 { return .yellow }
        return .green
    }

    @MainActor
    static func image(remainingPercent: Double?, usedPercent: Double?, isDark: Bool) -> NSImage? {
        let content = MenuBarQuotaMark(
            remainingPercent: remainingPercent,
            usedPercent: usedPercent,
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
        HStack(spacing: 2) {
            if let image = iconImage {
                Image(nsImage: image)
                    .renderingMode(.original)
            }
            Text(store.menuBarLabel)
                .monospacedDigit()
        }
        .font(.system(size: MenuBarText.fontSize, weight: .medium).monospacedDigit())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var iconImage: NSImage? {
        MenuBarQuotaIcon.image(
            remainingPercent: store.quotaPercentRemaining,
            usedPercent: store.quotaPercentUsed,
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

private struct MenuBarQuotaMark: View {
    let remainingPercent: Double?
    let usedPercent: Double?
    let isDark: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(MenuBarQuotaIcon.trackColor(isDark: isDark))
            if let remainingPercent {
                PieSlice(fraction: remainingPercent / 100)
                    .fill(MenuBarQuotaIcon.fillColor(usedPercent: usedPercent).opacity(0.9))
            }
        }
        .frame(width: MenuBarQuotaIcon.size, height: MenuBarQuotaIcon.size)
    }
}

private struct PieSlice: Shape {
    var fraction: Double

    func path(in rect: CGRect) -> Path {
        let clamped = UsageRemaining.clamp(fraction)
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
