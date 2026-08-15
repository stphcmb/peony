import Foundation

/// Pure state machine behind the break-reminder feature: no I/O, no timers
/// — the app calls `tick` every 30s with the system-wide idle time, and this
/// only tracks accumulated active time and whether a break is due.
public struct BreakClock: Equatable, Sendable {
    public enum Event: Equatable, Sendable {
        case breakDue
    }

    public private(set) var activeSeconds: TimeInterval = 0
    private var due = false
    private var snoozeRemaining: TimeInterval?

    /// 50 minutes of active time earns a break.
    private static let breakThreshold: TimeInterval = 3000
    /// 5 minutes away from the keyboard counts as a real break already taken.
    private static let idleResetThreshold: TimeInterval = 300

    public init() {}

    /// Called once per tick with the system's current idle time and the
    /// elapsed interval since the last tick. Returns `.breakDue` on the tick
    /// that crosses the threshold (from active accumulation or from a
    /// snooze elapsing) — never on any tick after that, until the state
    /// clears via `acknowledge()`, a fresh `snooze(for:)`, or an idle reset.
    @discardableResult
    public mutating func tick(idleSeconds: TimeInterval, interval: TimeInterval) -> Event? {
        // Walking away is a real break, whatever state we were in — clears a
        // pending due state and a running snooze alike.
        if idleSeconds >= Self.idleResetThreshold {
            reset()
            return nil
        }

        if let remaining = snoozeRemaining {
            let next = remaining - interval
            guard next <= 0 else {
                snoozeRemaining = next
                return nil
            }
            snoozeRemaining = nil
            due = true
            return .breakDue
        }

        // Already due and not snoozed: holding, waiting on acknowledge().
        if due { return nil }

        activeSeconds += interval
        guard activeSeconds >= Self.breakThreshold else { return nil }
        due = true
        return .breakDue
    }

    /// "Took it ✓" — back to counting from zero.
    public mutating func acknowledge() {
        reset()
    }

    /// "5 more minutes" (or Esc's longer snooze): suppress re-firing until
    /// `seconds` of ticks have elapsed.
    public mutating func snooze(for seconds: TimeInterval) {
        due = false
        snoozeRemaining = seconds
    }

    private mutating func reset() {
        activeSeconds = 0
        due = false
        snoozeRemaining = nil
    }
}
