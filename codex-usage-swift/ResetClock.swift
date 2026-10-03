import SwiftUI

struct ResetClock: View {
    let resetDate: Date?

    // Number of small tick marks between neighboring reset markers.
    private let minuteTicksPerReset = 5
    private let size: CGFloat = 108
    private let ink = Color(white: 0.10)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let time = resetDate.map { ResetClockTime(resetDate: $0, now: context.date) }
            face(time: time)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Five-hour reset clock")
                .accessibilityValue(description(time: time))
                .help(description(time: time))
        }
        .frame(width: size, height: size)
    }

    private func face(time: ResetClockTime?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.clear)
                .glassEffect(.clear, in: .rect(cornerRadius: 24))
            Circle().fill(.white).padding(8)
            ticks
            ForEach(0..<ResetClockTime.resetCount, id: \.self) { index in
                let angle = Double(index) * 2 * .pi / Double(ResetClockTime.resetCount)
                Text("\(index + 1)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ink)
                    .offset(x: sin(angle) * 28, y: -cos(angle) * 28)
            }
            if let time {
                hand(length: 23, width: 4.5, turns: time.hourTurns)
                hand(length: 35, width: 3, turns: time.minuteTurns)
                Circle().fill(ink).frame(width: 7, height: 7)
                Circle().fill(.white).frame(width: 2, height: 2)
            } else {
                Text("—").font(.caption).foregroundStyle(ink.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
    }

    private var ticks: some View {
        let ticksPerReset = minuteTicksPerReset + 1
        let count = ResetClockTime.resetCount * ticksPerReset
        return ZStack {
            ForEach(0..<count, id: \.self) { index in
                let isReset = index.isMultiple(of: ticksPerReset)
                Capsule()
                    .fill(ink.opacity(isReset ? 0.85 : 0.35))
                    .frame(width: isReset ? 1.6 : 1, height: isReset ? 5 : 3)
                    .offset(y: -40)
                    .rotationEffect(.degrees(Double(index) * 360 / Double(count)))
            }
        }
    }

    private func hand(length: CGFloat, width: CGFloat, turns: Double) -> some View {
        ClockHand()
            .fill(ink)
            .frame(width: width, height: length + 5)
            .offset(y: -(length - 5) / 2)
            .rotationEffect(.degrees(turns * 360))
            .shadow(color: .black.opacity(0.2), radius: 1, y: 1)
    }

    private func description(time: ResetClockTime?) -> String {
        guard let time else { return "Reset time unavailable" }
        let first = time.firstReset.formatted(date: .omitted, time: .shortened)
        return "Reset 1: \(first), nearest noon. Each number marks five hours; the long hand completes one turn per reset."
    }
}

private struct ClockHand: Shape {
    func path(in rect: CGRect) -> Path {
        let tipRadius = rect.width / 2
        let baseRadius = tipRadius * 0.65
        let tip = CGPoint(x: rect.midX, y: rect.minY + tipRadius)
        let base = CGPoint(x: rect.midX, y: rect.maxY - baseRadius)

        return Path { path in
            path.addArc(center: tip, radius: tipRadius, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
            path.addLine(to: CGPoint(x: base.x + baseRadius, y: base.y))
            path.addArc(center: base, radius: baseRadius, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: false)
            path.closeSubpath()
        }
    }
}
