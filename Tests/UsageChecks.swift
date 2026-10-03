import Foundation

@main
struct UsageChecks {
    @MainActor static func main() async throws {
        let fixture = #"{"rateLimits":{"primary":{"usedPercent":25,"windowDurationMins":300,"resetsAt":1791057600},"secondary":null},"rateLimitsByLimitId":{"other":{"limitName":"Other models","primary":null,"secondary":null},"codex":{"primary":{"usedPercent":125,"windowDurationMins":10080,"resetsAt":null},"secondary":null}}}"#
        let limits = try JSONDecoder().decode(RateLimitsResponse.self, from: Data(fixture.utf8))
        precondition(limits.buckets.map(\.id) == ["codex", "other"])
        precondition(limits.buckets[0].primary?.remaining == 0)
        precondition(limits.buckets[0].primary?.title == "Weekly")
        precondition(limits.buckets[0].primary?.resetDate == nil)
        precondition(limits.rateLimits.primary?.remaining == 75)
        precondition(limits.rateLimits.primary?.title == "5-hour window")
        let fallback = #"{"rateLimits":{"primary":null,"secondary":null},"rateLimitsByLimitId":{}}"#
        let empty = try JSONDecoder().decode(RateLimitsResponse.self, from: Data(fallback.utf8))
        precondition(empty.buckets.count == 1)
        let signedOut = try JSONDecoder().decode(AccountResponse.self, from: Data(#"{"account":null}"#.utf8))
        precondition(signedOut.account == nil)
        do {
            _ = try CodexClient.executable(customPath: "/nonexistent/codex")
            fatalError("Expected missing executable error")
        } catch UsageError.missingCLI { }
        print("PASS: usage decoding, bucket ordering, percentage bounds, missing windows, signed-out account, missing executable")

        if CommandLine.arguments.contains("--live") {
            let snapshot = try await CodexClient().fetch(customPath: "")
            precondition(!snapshot.limits.buckets.isEmpty)
            print("PASS: live Codex initialize → account/read → account/rateLimits/read")
            print("Received \(snapshot.limits.buckets.count) usage buckets; account details omitted.")
        }
        if let index = CommandLine.arguments.firstIndex(of: "--fake"), CommandLine.arguments.count > index + 1 {
            let path = CommandLine.arguments[index + 1]
            let snapshot = try await CodexClient().fetch(customPath: path)
            precondition(snapshot.limits.buckets.first?.primary?.remaining == 63)
            print("PASS: fragmented JSONL transport, ignored notifications, complete handshake")
        }
    }
}
