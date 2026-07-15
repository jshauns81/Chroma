---
description: Build and run Chroma in the iOS Simulator
allowed-tools: Bash(xcodebuild:*), Bash(xcrun:*)
argument-hint: [simulator name, e.g. "iPhone 17"]
---
Build and run Chroma in the iOS Simulator (device: $ARGUMENTS, or the
currently booted simulator if none is given).

Steps:
1. Boot the simulator if it isn't already running.
2. Build the app for the simulator destination.
3. Locate the built .app bundle and the target's bundle identifier.
4. Install with `xcrun simctl install` and launch with `xcrun simctl launch`.
5. If any step fails, tell me which one and why before attempting a fix.
