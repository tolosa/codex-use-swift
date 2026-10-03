import Foundation

struct AccountResponse: Decodable {
    let account: Account?
    struct Account: Decodable {
        let type: String
        let email: String?
        let planType: String?
    }
}

struct RateLimitsResponse: Decodable {
    let rateLimits: RateLimitBucket
    let rateLimitsByLimitId: [String: RateLimitBucket]?

    var buckets: [RateLimitBucket] {
        if let values = rateLimitsByLimitId, !values.isEmpty {
            return values.sorted { lhs, rhs in
                if lhs.key == "codex" { return rhs.key != "codex" }
                if rhs.key == "codex" { return false }
                return lhs.key < rhs.key
            }.map { key, value in
                var bucket = value
                bucket.limitId = bucket.limitId ?? key
                return bucket
            }
        }
        return [rateLimits]
    }
}

struct RateLimitBucket: Decodable, Identifiable {
    var limitId: String?
    let limitName: String?
    let primary: UsageWindow?
    let secondary: UsageWindow?
    let planType: String?
    let credits: Credits?

    var id: String { limitId ?? "codex" }
    var title: String {
        if let limitName, !limitName.isEmpty { return limitName }
        return id == "codex" ? "Codex" : id.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct UsageWindow: Decodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: TimeInterval?

    var used: Double { min(100, max(0, usedPercent)) }
    var remaining: Double { 100 - used }
    var resetDate: Date? { resetsAt.map(Date.init(timeIntervalSince1970:)) }
    var title: String {
        guard let minutes = windowDurationMins else { return "Usage window" }
        if minutes == 10_080 { return "Weekly" }
        if minutes == 1_440 { return "Daily" }
        if minutes % 60 == 0 { return "\(minutes / 60)-hour window" }
        return "\(minutes)-minute window"
    }
}

struct Credits: Decodable {
    let hasCredits: Bool?
    let unlimited: Bool?
    let balance: String?
}

struct UsageSnapshot {
    let account: AccountResponse.Account
    let limits: RateLimitsResponse
    let fetchedAt: Date
}

enum UsageError: LocalizedError {
    case missingCLI, signedOut, unsupportedAccount, disconnected, timedOut, invalidResponse
    case server(String)

    var errorDescription: String? {
        switch self {
        case .missingCLI: "Codex couldn’t be found. Install the Codex CLI, or choose its executable in Settings."
        case .signedOut: "Sign in to Codex with your ChatGPT account, then refresh. You can run codex login in Terminal."
        case .unsupportedAccount: "Usage limits are available for a ChatGPT login. Your current Codex account uses another authentication method."
        case .disconnected: "The Codex connection closed. Try refreshing, or check that Codex runs in Terminal."
        case .timedOut: "Codex took too long to respond. Check your connection and try again."
        case .invalidResponse: "Codex returned an unreadable response. Try updating the Codex CLI."
        case .server(let message): message
        }
    }
}
