import SwiftUI

@main
struct CodexUsageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var store = UsageStore()

    var body: some Scene {
        Window("Codex Usage", id: "usage") {
            ContentView()
                .environment(store)
                .onAppear {
                    appDelegate.store = store
                }
        }
        .defaultSize(width: 660, height: 280)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Refresh Usage") { Task { await store.refresh() } }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(store.isRefreshing)
            }
        }

        MenuBarExtra {
            MenuUsageView().environment(store)
        } label: {
            Label(store.menuLabel, systemImage: "terminal")
        }
        .menuBarExtraStyle(.window)

        Settings {
            ConnectionSettings().environment(store)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var store: UsageStore?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
    }
}
