#!/usr/bin/env sh
# PostToolUse hook: format touched JS, TS, JSON, and JSONC files with Biome.
set -eu

try() {
  command -v "$1" >/dev/null 2>&1
}

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
INPUT_JSON=$(mktemp "${TMPDIR:-/tmp}/codex-biome-hook.XXXXXX")
FILES=$(mktemp "${TMPDIR:-/tmp}/codex-biome-files.XXXXXX")
trap 'rm -f "$INPUT_JSON" "$FILES"' EXIT HUP INT TERM

cat >"$INPUT_JSON"

if try python3; then
  python3 - "$INPUT_JSON" "$ROOT" >"$FILES" <<'PY'
import json
import os
import re
import sys

input_json, root = sys.argv[1:3]
root = os.path.abspath(root)

try:
    with open(input_json, "r", encoding="utf-8") as handle:
        payload = json.load(handle)
except Exception:
    sys.exit(0)

tool_input = payload.get("tool_input") or {}
candidates = []
texts = []

def add_path(value):
    if isinstance(value, str) and value.strip():
        candidates.append(value.strip())

if isinstance(tool_input, dict):
    for key in ("file_path", "path"):
        add_path(tool_input.get(key))

    for key in ("file_paths", "paths"):
        value = tool_input.get(key)
        if isinstance(value, list):
            for item in value:
                add_path(item)

    for key in ("command", "patch", "input"):
        value = tool_input.get(key)
        if isinstance(value, str):
            texts.append(value)
elif isinstance(tool_input, str):
    texts.append(tool_input)

patch_path = re.compile(
    r"^\*\*\* (?:Add|Update|Delete) File: (.+)$"
    r"|^\*\*\* Move to: (.+)$",
    re.MULTILINE,
)
for text in texts:
    for match in patch_path.finditer(text):
        add_path(match.group(1) or match.group(2))

seen = set()
extensions = (
    ".js",
    ".mjs",
    ".cjs",
    ".jsx",
    ".ts",
    ".mts",
    ".cts",
    ".tsx",
    ".d.ts",
    ".json",
    ".jsonc",
)

for path in candidates:
    path = os.path.abspath(path if os.path.isabs(path) else os.path.join(root, path))
    if path in seen:
        continue
    seen.add(path)
    if not path.startswith(root + os.sep):
        continue
    if not os.path.isfile(path):
        continue
    if not path.endswith(extensions):
        continue
    sys.stdout.buffer.write(path.encode("utf-8") + b"\0")
PY
fi

if [ ! -s "$FILES" ]; then
  exit 0
fi

if try bunx; then
  xargs -0 bunx -p @biomejs/biome biome format --write -- <"$FILES"
elif try pnpm; then
  xargs -0 pnpm --package=@biomejs/biome dlx biome -- format --write -- <"$FILES"
elif try npx; then
  xargs -0 npx -y --package=@biomejs/biome biome format --write -- <"$FILES"
else
  echo "biome-formatter: skipped - install bun, pnpm, or Node.js/npm to enable." >&2
fi
