# Maintenance

This fork is maintained with local verification first. Keep product behavior stable when making cleanup changes, and prefer small commits that are easy to review.

## Local Commands

Build the macOS app:

```bash
xcodebuild \
  -project boringNotch.xcodeproj \
  -scheme boringNotch \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath .build/xcode-derived-data \
  -clonedSourcePackagesDirPath .build/sourcepackages \
  build
```

Run the unit tests:

```bash
xcodebuild \
  -project boringNotch.xcodeproj \
  -scheme boringNotch \
  -configuration Debug \
  -destination "platform=macOS" \
  -derivedDataPath .build/xcode-derived-data \
  -clonedSourcePackagesDirPath .build/sourcepackages \
  test
```

Lint Swift formatting when `swift-format` is available:

```bash
xcrun swift-format lint --recursive app/boringNotch app/BoringNotchXPCHelper app/boringNotchTests
```

Run the full local maintenance check:

```bash
./support/scripts/check.sh
```

Build and launch-check the app:

```bash
./support/scripts/build_and_run.sh --verify
```

## Codex Sandbox Note

Xcode and SwiftPM may write into user cache directories such as `~/Library/Caches` or `~/.cache` while resolving packages and compiling. In Codex, those writes can require broader filesystem permission even when project-local `.build/xcode-derived-data` and `.build/sourcepackages` paths are configured.
