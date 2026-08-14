# Peony — design brief

## What it is

A tiny Mac app that lives in the menu bar. Click a flower icon, a small card
appears with today's flower, a quote, a compliment, and one small thing to
learn. Click away, it closes. That's the whole interaction — no onboarding,
no settings, no account.

## Who sees it

A small team of coworkers. The person building it wants to hand it to
teammates and have them actually want to install it and keep it — not
because they were told to, but because opening it feels good. That's the
one metric that matters: does someone choose to click it again tomorrow.

## The feeling to design for

Warm, not corporate. A small gift someone left you, not a dashboard widget
or a notification. Think of the best paper daily-calendar-tear-off you've
ever seen on someone's desk — a little ritual, over in ten seconds, and you
come back the next day out of genuine curiosity, not habit-loop design.

Avoid: generic "wellness app" pastel gradients, motivational-poster clichés,
anything that reads as HR-mandated positivity.

## What's on the card today (content is fixed, presentation is fully open)

1. **Today's flower** — a name (e.g. "Chrysanthemum") and one short sentence
   connecting something true about the flower to something worth feeling
   (e.g. "Blooms latest in the year, when most things have already given
   up."). A different flower every day, same for the whole team.
2. **A quote** — text plus author.
3. **A compliment** — one sentence, written to be specific and earned, not
   generic flattery.
4. **One thing to learn** — a short title and a few sentences. Alternates
   between a technical nugget and a piece of world trivia depending on the
   day of the week.

All four are already written and rotate automatically by date — that part is
done. What's open is entirely how it looks and feels.

## Questions worth answering

- **Does the flower get a visual, or stay text-only?** An illustrated icon
  per flower (30 of them) is a real option, but also real production cost.
  Is there a lighter-weight way to make the flower feel present — color,
  shape, a single evolving accent — without needing 30 custom illustrations?
- **Layout and hierarchy.** Right now all four elements get roughly equal
  visual weight, stacked with plain dividers. Should the flower lead
  visually, with the rest supporting it? Or should the four feel like a
  small deck the eye moves through evenly?
- **Typography and color** — light and dark mode both, since this sits in a
  system menu bar and needs to feel native, not like a web page dropped in.
- **Motion**, if any — how it appears and disappears. Should be quick;
  nothing that makes someone wait to read.
- **The icon itself** — currently a plain 🌸 emoji in the menu bar. Worth
  a real icon, or is the emoji already right (native, recognizable, zero
  production cost)?

## Constraints

- Native macOS (SwiftUI), not a web view — needs to feel like it belongs in
  the menu bar, not like a browser tab.
- Popover, roughly 320–380px wide. Whatever height the content needs.
- No images or assets that require a network fetch — the app has no network
  access and should stay that way.
- Whatever gets proposed needs to be buildable without Xcode (Swift +
  SF Symbols + SwiftUI native drawing only — no asset catalogs that need
  Xcode's editor, no custom fonts that require licensing/embedding work).

## What "done" looks like

A short description of the visual direction (mood, palette, type, layout),
concrete enough that it could be handed to an engineer and built without
further design decisions needed — not a full mockup, but not vague either.
