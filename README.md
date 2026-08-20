# Peony

A menu bar app that gives you a new flower every hour and one short thing
to read with it — a quote, a compliment, or something to sit with. Click
the icon, read for ten seconds, get on with your day — or let it bloom on
its own when the hour turns.

The card isn't a rectangle. It's cut in the shape of the hour's bloom —
petals around a soft centre, like a sticker someone left on your desk. A
different flower every hour, thirty in rotation, each with its own petal
shape and colour.

## Install

```bash
git clone https://github.com/stphcmb/peony.git
cd peony
./install.sh
```

That builds the app, copies it to `/Applications`, and sets it to start next
time you log in. No Xcode, no Apple Developer account, no App Store.

The icon lives in your menu bar — a small pink bloom. Click it whenever
you want this hour's flower; it opens somewhere different on screen each
time. When the hour turns, the card also blooms on its own, lingers about
twenty seconds, and fades — pin it to keep it, or turn that off entirely.
Right-click for the menu: **Surprise Me** (a one-off random draw),
**Bloom Every Hour** (the auto-appearance, on by default),
**Start at Login** (on by default, toggle it off any time) and **Quit**.
On the card itself, ↺ draws another surprise, 📌 pins it so it stays up
while you click around other apps (click again to unpin — the choice is
remembered), × closes it, and you can drag it anywhere on screen. Flower
names come with their Vietnamese name alongside.

To remove it:

```bash
./uninstall.sh
```

### Installing from the zip (no cloning)

1. Download `Peony.zip` from the [latest release](../../releases/latest).
2. Double-click the zip to unpack it, then drag `Peony.app` into your
   **Applications** folder.
3. Open it. The first launch is where macOS may push back — see below.
4. Look for the small pink bloom in your menu bar. That's it.

### Installing with Homebrew

```bash
brew install --cask stphcmb/peony/peony
```

Homebrew keeps macOS's quarantine flag on, so the first launch still needs
the one-time "Open Anyway" step below. To skip that entirely, install with:

```bash
brew install --cask --no-quarantine stphcmb/peony/peony
```

Whichever route you take, the app starts at login from its first launch
onwards — it registers itself, so it shows up in System Settings > General >
Login Items. The `./install.sh` route additionally skips the security
warning entirely.

### "Apple could not verify this app" — how to open it anyway

Peony isn't signed with a paid Apple Developer account (it's a small
internal tool, not an App Store product), so the first time you open it
macOS shows a warning. Nothing is wrong with the app — this happens to
every app distributed outside the App Store without a paid signature.
You only have to get past it once.

**macOS 15 (Sequoia) and later:**

1. Double-click `Peony.app` — macOS blocks it. Click **Done**.
2. Open **System Settings → Privacy & Security**, scroll down to the
   Security section.
3. You'll see *"Peony" was blocked to protect your Mac* — click
   **Open Anyway**.
4. Confirm in the dialog (it may ask for your password or Touch ID).

**macOS 13–14 (Ventura / Sonoma):**

1. **Right-click** (or Control-click) `Peony.app` and choose **Open**.
2. In the warning dialog, click **Open**.

**Still blocked, or it says the app "is damaged"?** Clear the quarantine
flag from Terminal and open it again:

```bash
xattr -dr com.apple.quarantine /Applications/Peony.app
```

(That's exactly what `install.sh` does for you — which is why the clone
route never hits any of this.)

## How it decides what to show you

Everything is picked from the date and hour, not randomly — so it's the
same for everyone on the team in any given hour. That's on purpose: it
gives you something to compare notes on ("did you see the three o'clock
flower") instead of everyone getting a different private feed. (Surprise Me
is the escape hatch: a random draw that doesn't touch the hourly pick.)

**One text per card.** The card used to stack all three — a quote, a
compliment, and a prompt — and inside a 380pt disc that's more reading than
a ten-second card can carry. Which one you get also rotates hourly, so you
still see all three over a day without any single card being a wall.

The prompt pool alternates by day of the week between two sets, each mixing
three kinds of invitation: a question worth sitting with, a specific act of
kindness, or a nudge toward rest.

## Adding your own content

Everything text-based lives in one file:
`Sources/PositiveVibeOnlyApp/Resources/content.json` — `quotes`,
`compliments`, `prompts`, `flowers` — currently 100 quotes, 30
encouragements, 24 prompts, and 30 flowers (each with a `nameVi`
Vietnamese name). Add an entry to any list, then rebuild:

```bash
./scripts/build-app.sh   # rebuilds dist/Peony.app
./install.sh             # reinstalls it to /Applications and relaunches
```

Adding a new flower's *shape* (not just its name and meaning) means adding a
row to the `BloomCatalog` table in `Sources/PositiveVibeOnlyCore/Bloom.swift`
— petal count, width, length, offset, tip style, and two colours. Any
flower name in `content.json` without a matching row falls back to Daisy's
shape rather than crashing.

## A few things worth knowing

**Your name.** Read from your macOS account automatically. No setup.

**Nothing is stored, ever, except a version number.** No history, no record
of what you were shown, no analytics. The only things saved locally
(`UserDefaults`) are your preferences — card size, 📌 pin, Bloom Every Hour,
Break Reminders — plus the version it last saw and when it last looked.

**It keeps itself up to date.** A few times a day Peony asks GitHub what the
newest release is. If you're behind, it downloads it and swaps itself over
while the card is closed, so the newest version is simply there next time you
look — no dialog, no zip, nothing to click. Those checks and downloads are the
only network calls the app makes; offline, it quietly skips them and nothing
breaks. Prefer to decide yourself? Right-click 🌸 → **Update Automatically**
turns it off, and **Check for Updates…** stays there for when you want it.

**Unsigned, on purpose.** This isn't in the Mac App Store and isn't signed
with a paid Apple Developer account — that costs money and review time for
an internal team tool. `install.sh` clears the quarantine flag automatically;
the zip-download path needs one right-click → Open instead.

**Fonts.** Fraunces and Karla, both open-source (SIL Open Font License,
see `licenses/`), bundled directly and registered at launch — no system
font install, no licensing cost.

**What it needs.** macOS 13 or later, and a network connection once a day
for the update check (fails silently offline). No accounts, no permissions
to grant.

**Shipping a new release.** Bump `VERSION` at the top of
`scripts/build-app.sh` to match the git tag you're about to push — that's
what the update check compares against. Build, zip, tag, `gh release
create`, same as any release. Then update the Homebrew tap
([stphcmb/homebrew-peony](https://github.com/stphcmb/homebrew-peony)):
set `version` and `sha256` in `Casks/peony.rb` to the new release
(`shasum -a 256 Peony.zip` for the hash) and push.

## If something looks wrong

```bash
open -a Peony                 # launch it by hand
```

Not starting at login? Check System Settings > General > Login Items, or
right-click 🌸 and look at **Start at Login**.

## Rebuilding from source

```bash
swift run CoreTests             # runs the logic checks (day → greeting rules)
./scripts/build-app.sh          # builds dist/Peony.app
```

No XCTest here — Command Line Tools alone doesn't ship it, and pulling in
full Xcode just to run tests would defeat the point. `CoreTests` is a plain
executable that asserts and reports pass/fail; see its comment at the top of
`Sources/CoreTests/main.swift` for why.

## Design

The visual design — the die-cut bloom shape, the type system, the colour
rules — was designed and approved in a companion Claude Design project.
`DESIGN_BRIEF.md` in this repo is the brief that kicked that process off;
the approved geometry and colour values are implemented directly in
`Sources/PositiveVibeOnlyCore/Bloom.swift`.
