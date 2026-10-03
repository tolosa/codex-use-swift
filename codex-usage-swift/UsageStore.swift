import SwiftUI

@MainActor @Observable
final class UsageStore {
    var snapshot: UsageSnapshot?
    var isRefreshing = false
    var errorMessage: String?
    var customPath: String {
        didSet {
            guard !isPreview else { return }
            UserDefaults.standard.set(customPath, forKey: "codexExecutablePath")
        }
    }
    private let isPreview: Bool
    private var refreshTask: Task<Void, Never>?
    private var client: CodexClient?

    init(isPreview: Bool = false) {
        self.isPreview = isPreview
        customPath = isPreview ? "" : UserDefaults.standard.string(forKey: "codexExecutablePath") ?? ""
    }

    var menuLabel: String {
        guard errorMessage == nil, let window = snapshot?.limits.buckets.first?.primary else { return "Codex" }
        return "\(Int(window.remaining.rounded()))%"
    }

    func start() {
        guard !isPreview, refreshTask == nil else { return }
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                do { try await Task.sleep(for: .seconds(60)) } catch { return }
            }
        }
    }

    func refresh() async {
        guard !isPreview, !isRefreshing else { return }
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
