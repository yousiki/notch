#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="boringNotch.xcodeproj"
SCHEME="boringNotch"
CONFIGURATION="${CONFIGURATION:-Debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_PATH="$ROOT_DIR/$PROJECT_NAME"
DERIVED_DATA_PATH="$ROOT_DIR/.build/xcode-derived-data"
SOURCE_PACKAGES_PATH="$ROOT_DIR/.build/sourcepackages"

run_xcodebuild() {
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    -clonedSourcePackagesDirPath "$SOURCE_PACKAGES_PATH" \
    "$@"
}

run_swift_format_lint() {
  if ! xcrun --find swift-format >/dev/null 2>&1; then
    echo "swift-format not found; skipping format lint"
    return
  fi

  xcrun swift-format lint --recursive \
    "$ROOT_DIR/app/boringNotch" \
    "$ROOT_DIR/app/BoringNotchXPCHelper" \
    "$ROOT_DIR/app/boringNotchTests"
}

run_xcodebuild build
run_xcodebuild test
run_swift_format_lint
