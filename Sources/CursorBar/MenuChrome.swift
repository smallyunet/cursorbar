import AppKit
import SwiftUI

enum MenuChrome {
    static let menuBarFontSize: CGFloat = 12
    static let rowFontSize: CGFloat = 13
    static let detailFontSize: CGFloat = 11
    static let progressHeight: CGFloat = 6
    static let menuWidth: CGFloat = 260
    static let stackSpacing: CGFloat = 6
    static let horizontalPadding: CGFloat = 14
    static let verticalPadding: CGFloat = 10
    static let progressFill = NSColor.secondaryLabelColor
    static let progressTrack = NSColor.separatorColor
}

struct MenuLabelRow: View {
    let title: String
    let value: String
    var deEmphasized = false
    var valueColor: Color?

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .font(.system(size: MenuChrome.rowFontSize, weight: .medium))
                .foregroundStyle(Color(nsColor: deEmphasized ? .secondaryLabelColor : .labelColor))
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: MenuChrome.rowFontSize, weight: .semibold).monospacedDigit())
                .foregroundStyle(valueColor ?? Color(nsColor: .secondaryLabelColor))
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

struct NeutralProgressBar: View {
    let progress: Double?
    let accessibilityLabel: String

    var body: some View {
        GeometryReader { geometry in
            let fraction = UsageRemaining.clamp(progress ?? 0)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(nsColor: MenuChrome.progressTrack))
                if fraction > 0 {
                    Capsule()
                        .fill(Color(nsColor: MenuChrome.progressFill))
                        .frame(width: geometry.size.width * fraction)
                }
            }
        }
        .frame(height: MenuChrome.progressHeight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(
            progress.map { "\(Int(($0 * 100).rounded())) percent remaining" } ?? "Unavailable"
        )
    }
}

struct MenuDetailText: View {
    let text: String
    var emphasized = false
    var lineLimit = 1

    var body: some View {
        Text(text)
            .font(.system(size: MenuChrome.detailFontSize))
            .foregroundStyle(Color(nsColor: emphasized ? .labelColor : .secondaryLabelColor))
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
    }
}
