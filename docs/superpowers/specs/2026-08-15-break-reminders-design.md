# Break Reminders — design spec

Approved in chat 2026-08-15. Peony watches how long you've actually been at the
laptop and blooms a break card — water, eyes, stretch, tea, toilet, breathe —
when you've earned one.

## Sensing: BreakClock (Core, pure) + ActivityMonitor (app)

**BreakClock** is a pure state machine in `PositiveVibeOnlyCore`, tested in
CoreTests. No I/O, no timers — the app feeds it ticks.

```swift
public struct BreakClock {
    public enum Event { case breakDue }
    public private(set) var activeSeconds: TimeInterval
    // mutating tick(idleSeconds:interval:) -> Event?
    // mutating acknowledge()   // "Took it ✓": back to counting from 0
    // mutating snooze(for:)    // suppress re-fire for N seconds
}
```

Rules:
- Tick cadence: the app calls `tick` every 30s with the system-wide idle time
  (`CGEventSource.secondsSinceLastEventType(.combinedSessionState,
  eventType:)` with the any-input event type, `CGEventType(rawValue: ~0)`).
  No accessibility or screen-recording permission — this API is free.
- `idleSeconds >= 300` (5 min away) → a real break happened: `activeSeconds`
  resets to 0, any pending due/snooze state clears. This also runs while a
  break card is up — walking away auto-acknowledges it (the app dismisses the
  card on the next tick).
- Otherwise `activeSeconds += interval`. Crossing `3000` (50 min) emits
  `.breakDue` exactly once; the clock then holds (no re-fire) until
  acknowledge, snooze expiry, or idle reset.
- `snooze(for: 300)` — the "5 more minutes" button. After it elapses, next
  tick re-emits `.breakDue` (if no idle reset happened meanwhile).
- Esc on the card = `snooze(for: 600)`, repeatable — dismissal without
  punishment, but the card comes back while the streak continues.
- Sleep/wake needs no special handling: after wake, idle is huge → reset.
  Constants hardcoded (50 min / 5 min / 5 min / 10 min) — no settings until
  the rhythm proves wrong.

## Break card (app)

Same bloom + arch card + entrance animation as the greeting card; the body's
centerpiece is the nudge, not a quote:

- Header band: today's flower, unchanged.
- Body: nudge `title` in Fraunces ~22 semibold (where the quote goes today),
  nudge `body` in Karla below it.
- Two capsule buttons, side by side, tinted with the flower colour:
  **Took it ✓** (acknowledge → dismiss) and **5 more minutes** (snooze →
  dismiss). Karla, quiet styling — soft pressure, not an alarm.
- Toast: break-flavored gift-note pool (~6 lines, GiftNotes pattern —
  "Hey beauty, the work will wait 🌸", "Bloom break, right now 🌷" …).
- Persistence: outside clicks never dismiss it (the pin-mode monitor path);
  Esc = snooze(600) as above. The ↺/pin controls are hidden on a break card;
  × acts as Esc.

## Wiring (AppDelegate)

- `ActivityMonitor`: 30s `Timer` (tolerance 5, same pattern as hourlyTimer)
  reads idle, ticks BreakClock, and on `.breakDue` shows the break card —
  drawing a random `careNudge` (one-off draw, like Surprise Me) and the
  hour's flower.
- Suppression: while a break card is visible, and for 10 min after one fires,
  the hourly ambient bloom skips — never two popups in a minute.
- A user-opened greeting (icon click, Surprise Me) replaces a visible break
  card; the clock keeps counting.
- Menu: "Break Reminders" toggle after "Bloom Every Hour", default ON
  (`UserDefaults` key `BreakReminders`, registered like `HourlyBloom`).
  Off = monitor stops ticking.

## Content

`content.json` gains a pool; `Content` decodes it with `decodeIfPresent`
defaulting to `[]` so older files keep working (memberwise init gets a
defaulted parameter — existing test callers unchanged):

```json
"careNudges": [
  { "kind": "eyes", "title": "Eyes off the screen", "body": "Look at something six meters away for twenty seconds." },
  { "kind": "water", "title": "Water break", "body": "A full glass, not a sip." }
]
```

~15 entries across kinds: water, eyes, stretch, move, tea, toilet, breathe,
posture. Warm, specific, imperative; no guilt language.

## Testing

CoreTests (pure BreakClock): accumulates across ticks; resets on 5-min idle;
fires exactly once at threshold; holds without re-fire; snooze expiry
re-fires; idle during due state clears it; toggle-off is the app's job (no
ticks), not the clock's. Content: decodes with and without `careNudges`.
UI verified by hand (temporarily lower the threshold to 2 min).

## Out of scope (explicitly)

AI-generated nudges, energy check-ins / health diary, configurable
intervals, calendar awareness — all parked pending the AI-native
conversation (see project memory).
