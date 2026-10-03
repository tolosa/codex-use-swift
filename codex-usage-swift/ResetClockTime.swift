import Foundation

struct ResetClockTime {
    static let resetCount = 5
    static let resetInterval: TimeInterval = 5 * 60 * 60

    let firstReset: Date
    let hourTurns: Double
    let minuteTurns: Double

    init(resetDate: Date, now: Date, calendar: Calendar = .current) {
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
        let stepsToNoon = (noon.timeIntervalSince(resetDate) / Self.resetInterval).rounded()
        firstReset = resetDate.addingTimeInterval(stepsToNoon * Self.resetInterval)

        // Five five-hour sectors form a 25-hour dial, anchored near today's local noon.
        let elapsed = now.timeIntervalSince(firstReset) / Self.resetInterval
        let cycle = Double(Self.resetCount)
        hourTurns = (elapsed - floor(elapsed / cycle) * cycle) / cycle
        minuteTurns = elapsed - floor(elapsed)
    }
}
