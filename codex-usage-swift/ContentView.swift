import SwiftUI

private let mint = Color(red: 0.34, green: 0.88, blue: 0.73)

struct ContentView: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                if let snapshot = store.snapshot {
                    if let error = store.errorMessage {
                        notice(title: "Showing the last reading", message: error, symbol: "wifi.exclamationmark")
                    }
                    ForEach(snapshot.limits.buckets) { bucket in
                        bucketView(bucket)
                    }
                    footer(snapshot)
                } else if store.isRefreshing {
                    VStack(spacing: 16) {
                        ProgressView().controlSize(.large)
                        Text("Checking your usage…").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    ContentUnavailableView {
                        Label("Let’s connect Codex", systemImage: "terminal")
                    } description: {
                        Text(store.errorMessage ?? "Your current usage will appear here once Codex is connected.")
                            .frame(maxWidth: 360)
                    } actions: {
                        Button("Try again", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                            .buttonStyle(.glassProminent)
                        SettingsLink { Text("Connection settings") }
                            .buttonStyle(.glass)
                    }
                    .frame(minHeight: 280)
                }
            }
            .padding(32)
        }
        .background {
            ZStack {
                Color(red: 0.055, green: 0.075, blue: 0.09)
                Ellipse().fill(mint.opacity(0.14)).frame(width: 520, height: 360)
                    .blur(radius: 95).offset(x: -240, y: -180)
                Ellipse().fill(Color.blue.opacity(0.12)).frame(width: 400, height: 320)
                    .blur(radius: 90).offset(x: 290, y: 190)
            }
            .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
        .frame(minWidth: 580, minHeight: 460)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                SettingsLink { Image(systemName: "gearshape") }.help("Connection settings")
                Button("Refresh usage", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
                    .keyboardShortcut("r", modifiers: .command)
                    .help("Refresh usage (⌘R)")
            }
        }
        .task { store.start() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            ResetClock(resetDate: clockResetDate)
            VStack(alignment: .leading, spacing: 9) {
                Text("CODEX / USAGE").font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(2.5).foregroundStyle(mint)
                Text("Room to build.").font(.system(size: 34, weight: .semibold, design: .rounded))
                Text("Your limits, at a glance.").font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer()
            if let snapshot = store.snapshot {
                Label(snapshot.account.planType?.capitalized ?? "ChatGPT", systemImage: "sparkle")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 14).padding(.vertical, 9)
                    .glassEffect(.regular.tint(mint.opacity(0.12)), in: .capsule)
            }
        }
    }

    private var clockResetDate: Date? {
        store.snapshot?.limits.buckets
            .flatMap { [$0.primary, $0.secondary].compactMap { $0 } }
            .first { $0.windowDurationMins == 300 && $0.resetDate != nil }?
            .resetDate
    }

    private func bucketView(_ bucket: RateLimitBucket) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassEffectContainer(spacing: 20) {
                HStack(alignment: .top, spacing: 18) {
                    if let primary = bucket.primary { UsageCard(window: primary, symbol: "bolt") }
                    if let secondary = bucket.secondary { UsageCard(window: secondary, symbol: "calendar") }
                    if bucket.primary == nil && bucket.secondary == nil {
                        Text("No usage windows reported for this account.")
                            .foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(32)
                    }
                }
            }
        }
    }

    private func footer(_ snapshot: UsageSnapshot) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Label(store.errorMessage == nil ? "Connected to Codex" : "Connection interrupted",
                      systemImage: store.errorMessage == nil ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(store.errorMessage == nil ? mint : .orange)
                if let email = snapshot.account.email {
                    Text(email).foregroundStyle(.secondary).textSelection(.enabled)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                if store.isRefreshing {
                    Text("Refreshing…")
                } else {
                    TimelineView(.periodic(from: .now, by: 15)) { _ in
                        Text("Updated \(snapshot.fetchedAt, style: .relative) ago")
                    }
                }
                Text("Refreshes every minute").foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
    }

    private func notice(title: String, message: String, symbol: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).fontWeight(.semibold)
                Text(message).foregroundStyle(.secondary)
            }
        } icon: { Image(systemName: symbol).foregroundStyle(.orange) }
        .font(.caption).padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.08), in: .rect(cornerRadius: 14))
    }
}

private struct UsageCard: View {
    let window: UsageWindow
    let symbol: String
    private var color: Color { window.remaining <= 10 ? .orange : mint }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(window.title, systemImage: symbol)
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(window.remaining, format: .number.precision(.fractionLength(0)))
                    .font(.system(size: 62, weight: .light, design: .rounded))
                    .contentTransition(.numericText())
                Text("%").font(.system(size: 24, weight: .light)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 10) {
                GeometryReader { geometry in
                    Capsule().fill(.white.opacity(0.08))
                        .overlay(alignment: .leading) {
                            Capsule().fill(color.gradient)
                                .frame(width: geometry.size.width * window.remaining / 100)
                        }
                }
                .frame(height: 6)
                Text("\(Int(window.used.rounded()))% used").font(.caption).foregroundStyle(.secondary)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                resetDetails(now: context.date)
            }
        }
        .padding(24).frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(window.title), \(Int(window.remaining)) percent remaining, \(Int(window.used)) percent used")
    }

    private func resetDetails(now: Date) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let reset = window.resetDate {
                Text(reset > now ? "Resets in \(countdown(to: reset, from: now))" : "Reset due · refresh to check")
                    .foregroundStyle(color)
                Text(reset, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .foregroundStyle(.tertiary)
            } else {
                Text("Reset time unavailable").foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 11))
    }

    private func countdown(to reset: Date, from now: Date) -> String {
        let minutes = max(1, Int(ceil(reset.timeIntervalSince(now) / 60)))
        if minutes >= 1440 { return "\(minutes / 1440)d \((minutes % 1440) / 60)h" }
        if minutes >= 60 { return "\(minutes / 60)h \(minutes % 60)m" }
        return "\(minutes)m"
    }

}

struct MenuUsageView: View {
    @Environment(UsageStore.self) private var store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Label("Codex Usage", systemImage: "terminal").font(.headline)
                Spacer()
                Button("Refresh", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                    .labelStyle(.iconOnly).buttonStyle(.glass).disabled(store.isRefreshing)
            }
            if let snapshot = store.snapshot {
                ForEach(snapshot.limits.buckets) { bucket in
                    Text(bucket.title).font(.caption).foregroundStyle(.secondary)
                    if let window = bucket.primary { row(window) }
                    if let window = bucket.secondary { row(window) }
                }
            } else {
                Text(store.isRefreshing ? "Checking usage…" : "Connect Codex to see your usage.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            if store.errorMessage != nil {
                Label("Usage unavailable · open for details", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Button("Open dashboard") {
                    openWindow(id: "usage")
                    NSApplication.shared.activate(ignoringOtherApps: true)
                }.buttonStyle(.glass)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }.buttonStyle(.plain).foregroundStyle(.secondary)
            }
        }
        .padding(20).frame(width: 320)
        .task { store.start() }
    }

    private func row(_ window: UsageWindow) -> some View {
        VStack(spacing: 7) {
            HStack {
                Text(window.title)
                Spacer()
                Text("\(Int(window.remaining.rounded()))% left").monospacedDigit().fontWeight(.medium)
            }.font(.callout)
            ProgressView(value: window.remaining, total: 100).tint(window.remaining <= 10 ? .orange : mint)
        }
    }
}

struct ConnectionSettings: View {
    @Environment(UsageStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Form {
            Section("Codex connection") {
                Text("Uses your existing Codex ChatGPT login. Sign in with codex login in Terminal if needed.")
                    .foregroundStyle(.secondary)
                TextField("Executable path", text: $store.customPath, prompt: Text("Automatic detection"))
                HStack {
                    Button("Choose executable…") {
                        let panel = NSOpenPanel()
                        panel.canChooseDirectories = false
                        panel.canChooseFiles = true
                        panel.allowsMultipleSelection = false
                        panel.message = "Choose the Codex command-line executable"
                        if panel.runModal() == .OK, let url = panel.url { store.customPath = url.path }
                    }
                    Button("Use automatic detection") { store.customPath = "" }
                }
                Button("Reconnect", systemImage: "arrow.clockwise") { Task { await store.refresh() } }
                    .disabled(store.isRefreshing)
            }
            Section {
                Text("Usage refreshes every 60 seconds. Credentials are managed by Codex and are never read or stored by this app.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped).padding().frame(width: 500, height: 330)
    }
}
