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
                let overspend: Double?
                if let used = summary.includedUsedCents,
                   let pool = summary.includedLimitCents,
                   let onDemandUsed = summary.resolvedOnDemand?.used {
                    overspend = Double(max(used - pool, 0) + onDemandUsed)
                } else {
                    overspend = nil
                }
                let percent = UsageRemaining.percent(fromUsed: summary.includedPercentUsed) ?? 0
                if let overspend, overspend > 0 {
                    print(String(
                        format: "OK %.0f%% remaining (overspend $%.2f)",
                        percent,
                        overspend / 100.0
                    ))
                } else {
                    print(String(format: "OK %.0f%% remaining", percent))
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
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
