#!/usr/bin/env bash
# .claude/hooks/build-check.sh
# Fires after Claude edits a file. If it's Swift, does a build and
# feeds errors back to Claude so it can self-correct.

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Only care about Swift files
[[ "$file_path" == *.swift ]] || exit 0

cd "$CLAUDE_PROJECT_DIR" || exit 0

output=$(xcodebuild build \
  -project Chroma.xcodeproj \
  -scheme Chroma \
  -destination 'generic/platform=iOS Simulator' \
  -quiet 2>&1)

if echo "$output" | grep -q "BUILD FAILED"; then
  echo "$output" | grep -E "error:|warning:" | head -30 >&2
  exit 2   # exit 2 blocks + sends stderr back to Claude as feedback
fi

exit 0
