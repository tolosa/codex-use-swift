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

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: -3 * 60 * 60)!
        let noon = calendar.date(from: DateComponents(year: 2026, month: 10, day: 3, hour: 12))!
        let reset = noon.addingTimeInterval(60 * 60)
        let atReset = ResetClockTime(resetDate: reset, now: reset, calendar: calendar)
        precondition(atReset.firstReset == reset)
        precondition(atReset.hourTurns == 0 && atReset.minuteTurns == 0)
        let halfway = ResetClockTime(resetDate: reset, now: reset.addingTimeInterval(2.5 * 3600), calendar: calendar)
        precondition(abs(halfway.hourTurns - 0.1) < 0.000001 && halfway.minuteTurns == 0.5)
        let next = ResetClockTime(resetDate: reset.addingTimeInterval(5 * 3600), now: reset.addingTimeInterval(5 * 3600), calendar: calendar)
        precondition(next.firstReset == reset && next.hourTurns == 0.2 && next.minuteTurns == 0)
        let before = ResetClockTime(resetDate: reset, now: reset.addingTimeInterval(-2.5 * 3600), calendar: calendar)
        precondition(before.hourTurns == 0.9 && before.minuteTurns == 0.5)
        let tomorrow = ResetClockTime(resetDate: reset, now: reset.addingTimeInterval(25 * 3600), calendar: calendar)
        precondition(tomorrow.firstReset == reset.addingTimeInterval(25 * 3600))
        precondition(tomorrow.hourTurns == 0 && tomorrow.minuteTurns == 0)
        let lateReset = ResetClockTime(resetDate: noon.addingTimeInterval(4 * 3600), now: noon, calendar: calendar)
        precondition(lateReset.firstReset == noon.addingTimeInterval(-3600))
        print("PASS: reset clock noon anchor, five-hour rollover, fractional hands, pre-anchor wrapping, and next-day anchor")

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
