---
description: Run the ThemeKit test suite and summarize results
allowed-tools: Bash(swift:*)
argument-hint: [optional test name/pattern]
---
## Test output
!`swift test --package-path ThemeKit $([ -n "$ARGUMENTS" ] && echo "--filter $ARGUMENTS") 2>&1 | tail -150`

## Task
Summarize what passed and failed for: $ARGUMENTS (if empty, the full suite ran).
For any failure, explain what the test was checking and the likely cause —
don't just patch it silently.

Note: all logic and tests live in the ThemeKit package (`swift test`), so this
is the real suite. The app-target ChromaTests/ChromaUITests are Xcode stubs.
