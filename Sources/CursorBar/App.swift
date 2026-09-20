import AppKit
import SwiftUI

@main
enum CursorBarMain {
    static func main() {
        if CommandLine.arguments.contains("--status") {
            runStatusCommand()
            return
        }
        CursorBarApp.main()
    }

    private static func runStatusCommand() {
        let group = DispatchGroup()
        group.enter()
        Task {
            defer { group.leave() }
            do {
                let summary = try await CursorAPI.fetchUsageSummary()
                if summary.isUnlimitedPlan {
                    print("OK unlimited")
                    exit(0)
                }
                let used = Double(summary.includedUsedCents ?? 0)
                let pool = Double(summary.includedLimitCents ?? 0)
                let overage = pool > 0 ? max(used - pool, 0) : 0
                let onDemandUsed = Double(summary.resolvedOnDemand?.usedCents ?? 0)
                let overspend = overage + onDemandUsed
                let percent = min(summary.includedPercentUsed ?? 0, 100)
                if overspend > 0 {
                    print(String(
                        format: "OK %.0f%% (overspend $%.2f)",
                        percent,
                        overspend / 100.0
                    ))
                } else {
                    print(String(format: "OK %.0f%%", percent))
                }
                if let tokens = try? await CursorAPI.fetchPublicProfileTokens(
                    periodStart: summary.billingCycleStart.flatMap(FlexibleISO8601.date)
                ) {
                    print(
                        "TOKENS cycle=\(tokens.periodTokens) "
                        + "all=\(tokens.totalTokens) @\(tokens.handle)"
                    )
                }
                exit(0)
            } catch {
                fputs("ERROR: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
        }
        group.wait()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

struct CursorBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = UsageStore()
    @StateObject private var updater = UpdateChecker()
    @StateObject private var agents = AgentMonitor()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(store: store, updater: updater, agents: agents)
        } label: {
            MenuBarLabel(store: store, agents: agents)
        }
        .menuBarExtraStyle(.window)
    }
}
