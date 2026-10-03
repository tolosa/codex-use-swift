import SwiftUI

@MainActor @Observable
final class UsageStore {
    var snapshot: UsageSnapshot?
    var isRefreshing = false
    var errorMessage: String?
    var customPath: String {
        didSet { UserDefaults.standard.set(customPath, forKey: "codexExecutablePath") }
    }
    private var refreshTask: Task<Void, Never>?
    private var client: CodexClient?

    init() {
        customPath = UserDefaults.standard.string(forKey: "codexExecutablePath") ?? ""
    }

    var menuLabel: String {
        guard errorMessage == nil, let window = snapshot?.limits.buckets.first?.primary else { return "Codex" }
        return "\(Int(window.remaining.rounded()))%"
    }

    func start() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let client = CodexClient()
        self.client = client
        do {
            snapshot = try await client.fetch(customPath: customPath.trimmingCharacters(in: .whitespacesAndNewlines))
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        self.client = nil
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        client?.stop()
    }
}
