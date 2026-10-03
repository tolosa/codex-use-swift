import Foundation

/// A short-lived, read-only account client. Credentials stay inside the Codex process.
@MainActor
final class CodexClient {
    private var process: Process?
    private var input: FileHandle?
    private var output: FileHandle?
    private var buffer = Data()
    private var nextID = 0
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var timeouts: [Int: Task<Void, Never>] = [:]

    static func executable(customPath: String) throws -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = customPath.isEmpty ? [
            "/opt/homebrew/bin/codex", "/usr/local/bin/codex",
            "\(home)/.local/bin/codex", "\(home)/.cargo/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex"
        ] + (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/codex" } : [customPath]
        guard let path = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            throw UsageError.missingCLI
        }
        return URL(fileURLWithPath: path)
    }

    func fetch(customPath: String) async throws -> UsageSnapshot {
        defer { stop() }
        try start(executable: Self.executable(customPath: customPath))
        _ = try await request("initialize", params: ["clientInfo": [
            "name": "codex_usage_macos", "title": "Codex Usage", "version": "1.0.0"
        ]])
        try send(["method": "initialized", "params": [:]])
        let accountData = try await request("account/read", params: ["refreshToken": false])
        let response = try JSONDecoder().decode(AccountResponse.self, from: accountData)
        guard let account = response.account else { throw UsageError.signedOut }
        guard account.type == "chatgpt" || account.type == "chatgptAuthTokens" else {
            throw UsageError.unsupportedAccount
        }
        let limitsData = try await request("account/rateLimits/read")
        let limits = try JSONDecoder().decode(RateLimitsResponse.self, from: limitsData)
        return UsageSnapshot(account: account, limits: limits, fetchedAt: .now)
    }

    private func start(executable: URL) throws {
        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()
        process.executableURL = executable
        process.arguments = ["app-server", "--listen", "stdio://"]
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:" + (environment["PATH"] ?? "")
        process.environment = environment
        process.standardInput = stdin
        process.standardOutput = stdout
        // Never persist server diagnostics, which may contain account information.
        process.standardError = FileHandle.nullDevice
        input = stdin.fileHandleForWriting
        output = stdout.fileHandleForReading
        self.process = process
        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            Task { @MainActor [weak self] in
                guard let self else { return }
                if data.isEmpty { self.failPending(UsageError.disconnected) }
                else { self.receive(data) }
            }
        }
        try process.run()
    }

    private func request(_ method: String, params: [String: Any] = [:]) async throws -> Data {
        try Task.checkCancellation()
        nextID += 1
        let id = nextID
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            timeouts[id] = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                self?.finish(id, result: .failure(UsageError.timedOut))
            }
            do { try send(["id": id, "method": method, "params": params]) }
            catch { finish(id, result: .failure(error)) }
        }
    }

    private func send(_ message: [String: Any]) throws {
        guard let input, process?.isRunning == true else { throw UsageError.disconnected }
        var data = try JSONSerialization.data(withJSONObject: message)
        data.append(0x0A)
        try input.write(contentsOf: data)
    }

    private func receive(_ data: Data) {
        buffer.append(data)
        guard buffer.count < 4_000_000 else {
            failPending(UsageError.invalidResponse)
            return
        }
        while let newline = buffer.firstIndex(of: 0x0A) {
            let line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let id = object["id"] as? Int else { continue }
            if let error = object["error"] as? [String: Any] {
                finish(id, result: .failure(UsageError.server(error["message"] as? String ?? "Codex couldn’t fetch usage.")))
            } else if let result = object["result"],
                      let data = try? JSONSerialization.data(withJSONObject: result) {
                finish(id, result: .success(data))
            } else {
                finish(id, result: .failure(UsageError.invalidResponse))
            }
        }
    }

    private func finish(_ id: Int, result: Result<Data, Error>) {
        timeouts.removeValue(forKey: id)?.cancel()
        pending.removeValue(forKey: id)?.resume(with: result)
    }

    private func failPending(_ error: Error) {
        for id in Array(pending.keys) { finish(id, result: .failure(error)) }
    }

    func stop() {
        output?.readabilityHandler = nil
        try? input?.close()
        if let process, process.isRunning {
            process.terminate()
            // Don't allow a stuck helper to outlive the application indefinitely.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            }
        }
        try? output?.close()
        input = nil
        output = nil
        process = nil
        failPending(UsageError.disconnected)
        buffer.removeAll()
    }
}
