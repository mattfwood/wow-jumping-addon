#!/bin/sh
# PostToolUse hook: lint a Lua file right after Claude edits it.
# Exit code 2 sends luacheck's output back to Claude so it fixes the problem
# in the same session. Anything else exits 0 so edits are never blocked.

input=$(cat)

# Pull tool_input.file_path out of the hook JSON without needing jq.
file=$(printf '%s' "$input" | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

case "$file" in
  *.lua) ;;
  *) exit 0 ;;
esac

[ -f "$file" ] || exit 0

if ! command -v luacheck >/dev/null 2>&1; then
  echo "luacheck isn't installed, so this edit wasn't linted. Install it with: brew install luacheck" >&2
  exit 0
fi

# Run from the repo root so luacheck picks up .luacheckrc.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if ! output=$(luacheck --no-color --formatter plain "$file" 2>&1); then
  echo "luacheck found problems in $file:" >&2
  echo "$output" >&2
  exit 2
fi
exit 0
