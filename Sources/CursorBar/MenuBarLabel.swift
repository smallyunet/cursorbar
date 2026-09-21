import SwiftUI

enum MenuBarText {
    static let quotaSymbol = "chart.pie.fill"
    static let fontSize = MenuChrome.menuBarFontSize
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: MenuBarText.quotaSymbol)
                .imageScale(.small)
                .symbolRenderingMode(.monochrome)
            Text(store.menuBarLabel)
                .monospacedDigit()
        }
        .font(.system(size: MenuBarText.fontSize, weight: .medium).monospacedDigit())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
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
