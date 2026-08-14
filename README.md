# Peony

A menu bar app that gives you a new flower, a quote, a compliment, and one
small thing to sit with — every day. Click the icon, read for ten seconds,
get on with your day.

The card isn't a rectangle. It's cut in the shape of the day's bloom —
petals around a soft centre, like a sticker someone left on your desk. A
different flower every day, thirty in rotation, each with its own petal
shape and colour.

## Install

```bash
git clone https://github.com/stphcmb/peony.git
cd peony
./install.sh
```

That builds the app, copies it to `/Applications`, and sets it to start next
time you log in. No Xcode, no Apple Developer account, no App Store.

The icon lives in your menu bar — a small five-petal outline. Click it
whenever you want today's flower.

To remove it:

```bash
./uninstall.sh
```

### Just want to try it without cloning?

Grab `Peony.zip` from this repo's [Releases](../../releases) page, unzip,
drag `Peony.app` to Applications, then **right-click → Open** the first
time (macOS warns because it isn't signed with a paid Apple Developer
account — that's expected, and only happens once).

## How it decides what to show you

Everything is picked from today's date, not randomly — so it's the same for
everyone on the team on any given day. That's on purpose: it gives you
something to compare notes on ("did you see today's flower") instead of
everyone getting a different private feed.

The fourth block — the prompt — alternates by day of the week between two
pools, each mixing three kinds of invitation: a question worth sitting with,
a specific act of kindness, or a nudge toward rest.

## Adding your own content

Everything text-based lives in one file:
`Sources/PositiveVibeOnlyApp/Resources/content.json` — `quotes`,
`compliments`, `prompts`, `flowers`. Add an entry to any list, then rebuild:

```bash
./scripts/build-app.sh   # rebuilds dist/Peony.app
./install.sh             # reinstalls it and restarts the login item
```

Adding a new flower's *shape* (not just its name and meaning) means adding a
row to the `BloomCatalog` table in `Sources/PositiveVibeOnlyCore/Bloom.swift`
— petal count, width, length, offset, tip style, and two colours. Any
flower name in `content.json` without a matching row falls back to Daisy's
shape rather than crashing.

## A few things worth knowing

**Your name.** Read from your macOS account automatically. No setup.

**Nothing is stored, ever, except a version number.** No history, no record
of what you were shown, no analytics. The one exception: once a day, the app
checks GitHub for the latest release tag, so it can show a small "Update
available" link if you're behind — that check and its timestamp are the only
things saved locally (`UserDefaults`), and the only network call the app
makes. Miss it entirely and nothing breaks; it just won't nudge you.

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
create`, same as any release.

## If something looks wrong

```bash
launchctl list | grep peony   # is the login item registered?
open -a Peony                 # launch it by hand
```

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
