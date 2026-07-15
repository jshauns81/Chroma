---
description: Run the Chroma test suite and summarize results
allowed-tools: Bash(xcodebuild:*)
argument-hint: [optional test name/pattern]
---
## Test output
!`xcodebuild test -project Chroma.xcodeproj -scheme Chroma -destination 'platform=iOS Simulator,name=iPhone 17' 2>&1 | tail -150`

## Task
Summarize what passed and failed for: $ARGUMENTS (if empty, the full suite ran).
For any failure, explain what the test was checking and the likely cause —
don't just patch it silently.
