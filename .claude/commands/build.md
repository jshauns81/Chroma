---
description: Build the Chroma app (headless macOS) and report errors/warnings
allowed-tools: Bash(xcodebuild:*)
---
## Build output
!`xcodebuild build -project Chroma/Chroma.xcodeproj -scheme Chroma -destination 'platform=macOS,arch=arm64' -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO -quiet 2>&1 | tail -100`

## Task
If the build succeeded, just confirm it briefly. If it failed, walk me through
what broke and *why* — teach me the concept behind the error before you fix it.
