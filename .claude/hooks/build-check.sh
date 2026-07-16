#!/usr/bin/env bash
# .claude/hooks/build-check.sh
# Fires after Claude edits a Swift file and reports compile errors back so it
# can self-correct. Routes to the right builder for this repo's two halves:
#   • ThemeKit/*  -> `swift build`  (fast SPM incremental build — the common case)
#   • Chroma/*    -> headless macOS `xcodebuild` (signing off, for speed)
# Non-Swift edits are ignored. exit 2 = block the edit AND send stderr back to
# Claude as feedback.

input=$(cat)
file_path=$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')

# Only Swift source edits trigger a build.
[[ "$file_path" == *.swift ]] || exit 0

root="${CLAUDE_PROJECT_DIR:-$(pwd)}"

if [[ "$file_path" == *"/ThemeKit/"* ]]; then
  output=$(swift build --package-path "$root/ThemeKit" 2>&1)
  status=$?
else
  # App target — a real macOS build. Skip code signing; we only want to know
  # whether it compiles, not to produce a runnable, signed bundle.
  output=$(xcodebuild build \
    -project "$root/Chroma/Chroma.xcodeproj" \
    -scheme Chroma \
    -destination 'platform=macOS' \
    -derivedDataPath "$root/DerivedData" \
    CODE_SIGNING_ALLOWED=NO \
    -quiet 2>&1)
  status=$?
fi

if [[ $status -ne 0 ]]; then
  echo "$output" | grep -E "error:|warning:" | head -30 >&2
  exit 2
fi

exit 0
