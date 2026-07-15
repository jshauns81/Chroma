---
description: Build Chroma and report errors/warnings
allowed-tools: Bash(xcodebuild:*)
---
## Build output
!`xcodebuild build -project Chroma.xcodeproj -scheme Chroma -destination 'generic/platform=iOS Simulator' -quiet 2>&1 | tail -100`

## Task
If the build succeeded, just confirm it briefly. If it failed, walk me through
what broke and *why* — teach me the concept behind the error before you fix it.
