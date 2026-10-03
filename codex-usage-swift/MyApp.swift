import SwiftUI

@main
struct CodexUsageApp: App {
    @State private var store = UsageStore()

    var body: some Scene {
        Window("Codex Usage", id: "usage") {
            ContentView()
                .environment(store)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.stop()
                }
        }
        .defaultSize(width: 660, height: 620)
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
