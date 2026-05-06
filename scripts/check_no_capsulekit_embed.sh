#!/usr/bin/env bash
# Verifies that no .capsule bundle embeds CapsuleKit.framework. Extensions
# must link against the host-embedded copy via @rpath; embedding leads to
# two separate type identities at runtime.
set -euo pipefail

APP_PATH="${1:?Usage: $0 <path-to-Capsule.app>}"

if [ ! -d "$APP_PATH/Contents/PlugIns" ]; then
    echo "No PlugIns directory; nothing to check."
    exit 0
fi

failures=0
for ext in "$APP_PATH/Contents/PlugIns"/*.capsule; do
    if [ ! -d "$ext" ]; then continue; fi  # skip if glob didn't match anything
    if [ -d "$ext/Contents/Frameworks/CapsuleKit.framework" ]; then
        echo "ERROR: $ext embeds CapsuleKit.framework — extensions must NOT embed CapsuleKit."
        failures=$((failures + 1))
    fi
done

if [ "$failures" -gt 0 ]; then
    exit 1
fi
echo "OK: no extension embeds CapsuleKit.framework"
