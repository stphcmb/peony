import AppKit

FontRegistration.registerBundledFonts()

let app = NSApplication.shared
// main.swift's top-level code runs on the main thread before the run loop
// starts, but the compiler can't infer that automatically — this makes it
// explicit rather than fighting the type checker with unsafe casts.
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory) // menu bar only, no Dock icon, no app switcher entry
app.run()
