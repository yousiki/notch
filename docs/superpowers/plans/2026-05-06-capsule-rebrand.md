# Capsule Rebrand Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebrand the entire codebase from upstream `boringNotch` (TheBoredTeam) to `Capsule` (yousiki) — replacing every brand identifier, bundle ID, file path, type name, and external link, while preserving GPL-3.0 compliance and acknowledging the upstream project.

**Architecture:** Rename in dependency-safe order: copy/text changes first (README, comments) → bundle identity (plist/pbxproj) → Swift identifiers → file/dir renames (`git mv`) → framework rename (`NotchKit → CapsuleKit`) → project & workspace rename → assets and CI. Each phase produces a green-build, atomic commit. The rename of the SDK module (`NotchKit → CapsuleKit`) is fenced into its own phase because it ripples through every `import` site.

**Tech Stack:** Swift 5.x, Xcode 16, SwiftUI, AppKit, Sparkle, GPL-3.0, GitHub Actions, Crowdin.

**Naming policy** (read this first — it answers "should I rename type X?"):

| Pattern | Action | Example |
|---|---|---|
| `boring*` / `Boring*` / `BoringNotch*` | **Rename → `Capsule*`** | `BoringViewModel` → `CapsuleViewModel` |
| `TheBoredTeam`, `theboringteam`, `theboring.name` | **Rename / replace** | bundle ID, asset name, README links |
| `NotchKit` (the framework) | **Rename → `CapsuleKit`** | module name, folder, scheme |
| `Notch*` types **inside `NotchKit`** (SDK API surface: `NotchHost`, `NotchExtension`, contribution types, `NotchKitVersion`, `NotchLogger`, `NotchSettingsStore`, `NotchObservation`, `NotchSlotLifecycle`, `NotchPermissions*`) | **Rename → `Capsule*`** | `NotchHost` → `CapsuleHost` |
| `Notch*` types in **domain code** that describe the macOS notch hardware itself (`NotchShape`, `NotchHomeView`, `NotchSpaceManager`, `NotchStateServiceAdapter`, `OpenNotchHUD`) | **KEEP** — they describe the hardware feature, not the brand | `NotchShape` stays |
| `Notch.xcodeproj`, `Notch.xcworkspace`, `Notch-Bridging-Header.h` | **Rename → `Capsule.*`** | project identity |
| `boringNotch` directory in `crowdin.yml` source path | **Fix to actual path** (it's already wrong; it's `Core/Host/`) | path correction |

**Concrete identifier targets:**

- App Bundle ID: `theboringteam.boringnotch` → `moe.siki.Capsule`
- XPC Helper Bundle ID: `theboringteam.boringnotch.BoringNotchXPCHelper` → `moe.siki.Capsule.XPCHelper`
- Framework Bundle ID: `com.theboredteam.NotchKit` → `moe.siki.CapsuleKit`
- App display name: `TheBoringNotch` → `Capsule`
- Sparkle feed: `https://TheBoredTeam.github.io/boring.notch/appcast.xml` → `https://yousiki.github.io/Capsule/appcast.xml`
- Repo URL: `https://github.com/TheBoredTeam/boring.notch` → `https://github.com/yousiki/Capsule`
- DMG name: `boringNotch.dmg` → `Capsule.dmg`

**Out of scope** (deferred to follow-up branches):
- AppIcon replacement (`Core/Host/Assets.xcassets/AppIcon.appiconset/`) — keeping upstream icon for now per user choice.
- `MacroVisionKit` SPM dep — keep referencing `https://github.com/TheBoredTeam/MacroVisionKit` upstream per user choice.
- Setting up `https://yousiki.github.io/Capsule/appcast.xml` actually serving content (infrastructure, not code).
- Setting up `yousiki/homebrew-capsule` tap.

**Prerequisites:**
- The parallel session on `refactor/core-extensions` must be merged (or rebased onto a clean base) before this work begins. Conflicts in `Core/Notch.xcodeproj/project.pbxproj` and `Core/Host/Localizable.xcstrings` are otherwise inevitable.
- Confirm `siki.moe` is yours (it is — user confirmed).
- New empty repo created at `https://github.com/yousiki/Capsule` (or planned for first push).

---

## Task 1: Branch off and capture rebrand baseline

**Files:**
- Create: `docs/rebrand/INVENTORY.md` (audit log; deleted before final merge)
- Branch: `rebrand/capsule`

- [ ] **Step 1: Verify clean working tree on the merged base**

```bash
git status
git log --oneline -5
```

Expected: clean tree, on `main` (or whichever branch contains the merged `refactor/core-extensions` work).

- [ ] **Step 2: Create rebrand branch**

```bash
git checkout -b rebrand/capsule
```

- [ ] **Step 3: Capture pre-rename baseline counts** (sanity for later verification)

```bash
mkdir -p docs/rebrand
{
  echo "# Rebrand baseline — captured $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
  echo "## Boring/boring occurrences"
  grep -rE "[Bb]oring" --include="*.swift" --include="*.plist" --include="*.entitlements" --include="*.pbxproj" --include="*.xcstrings" --include="*.md" --include="*.yml" --include="*.sh" --include="*.json" --include="*.h" . 2>/dev/null | wc -l
  echo
  echo "## TheBoredTeam occurrences"
  grep -rE "TheBoredTeam|theboringteam|theboring" --include="*.swift" --include="*.plist" --include="*.entitlements" --include="*.pbxproj" --include="*.xcstrings" --include="*.md" --include="*.yml" --include="*.sh" --include="*.json" . 2>/dev/null | wc -l
  echo
  echo "## NotchKit occurrences"
  grep -rE "NotchKit" --include="*.swift" --include="*.pbxproj" --include="*.plist" --include="*.sh" . 2>/dev/null | wc -l
} > docs/rebrand/INVENTORY.md
cat docs/rebrand/INVENTORY.md
```

Expected: counts roughly: Boring ~600+, TheBoredTeam ~30+, NotchKit ~40+. Exact numbers don't matter — used as a "did we miss anything" check later.

- [ ] **Step 4: Commit the baseline**

```bash
git add docs/rebrand/INVENTORY.md
git commit -m "rebrand: capture pre-rename baseline counts"
```

---

## Task 2: Rewrite README with fork attribution (GPL-3.0 §5(a) compliance)

**Files:**
- Modify: `README.md` (full rewrite)
- Modify: `LICENSE` (append your copyright; do NOT replace GPL-3.0 text)
- Modify: `SECURITY.md`

- [ ] **Step 1: Replace `README.md`**

Write `README.md` with this content (adjust acknowledgments as needed):

```markdown
<h1 align="center">
  <br>
  Capsule
  <br>
</h1>

<p align="center">
  <em>A programmable, extensible notch-space framework for macOS.</em>
</p>

<p align="center">
  <a href="https://github.com/yousiki/Capsule/actions/workflows/cicd.yml">
    <img src="https://github.com/yousiki/Capsule/actions/workflows/cicd.yml/badge.svg" alt="Build & Test" />
  </a>
</p>

> **Capsule is a fork of [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch)**, originally created by Alexander5015 and the Boring Team.
> This fork was started on 2026-05-06 and has diverged substantially: an extension-based architecture, new APIs, different scope. Capsule is **not** a drop-in replacement for boring.notch and is maintained independently.
> Both projects are licensed under GPL-3.0; modifications are tracked in the git history of this repository.

## Status

Capsule is in active development. Things will break. APIs are unstable.

## System Requirements

- macOS 14 Sonoma or later
- Apple Silicon or Intel Mac
- Xcode 16 or later (to build from source)

## Building from Source

```bash
git clone https://github.com/yousiki/Capsule.git
cd Capsule
open Capsule.xcworkspace
```

Build and run the `Capsule` scheme.

## Architecture

Capsule consists of:

- **Capsule.app** — the host application that owns the notch UI and lifecycle.
- **CapsuleKit.framework** — the public extension SDK. Third-party `.capsule` extensions link against this framework to contribute UI and behavior.
- **CapsuleXPCHelper** — privileged helper for system-level integrations (volume, brightness, etc.).
- **First-party extensions** — `Extensions/` contains shipped extensions (Tips, Battery, Music, etc.).

## Extensions

Capsule's extension system is the core differentiator from upstream. See [`Core/CapsuleKit/Sources/`](Core/CapsuleKit/Sources/) for the public API.

## License

Capsule is licensed under [GPL-3.0](LICENSE). It is a derivative work of [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch), which is also GPL-3.0.

## Acknowledgments

- **[TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch)** — the upstream project Capsule was forked from. Original architecture, UI design, and many of the features still present in Capsule originate from boring.notch. Thank you to Alexander5015 and the Boring Team.
- **[MediaRemoteAdapter](https://github.com/ungive/mediaremote-adapter)** — open-source bridge enabling Now Playing access on macOS 15.4+.
- **[NotchDrop](https://github.com/Lakr233/NotchDrop)** — original inspiration for the Shelf/file-drop feature.
- **[MacroVisionKit](https://github.com/TheBoredTeam/MacroVisionKit)** — fullscreen-detection helper, dependency maintained by TheBoredTeam.

For a full list of third-party licenses see [`THIRD_PARTY_LICENSES`](THIRD_PARTY_LICENSES).
```

- [ ] **Step 2: Append your copyright to `LICENSE`** (do NOT modify existing GPL-3.0 text)

The GPL-3.0 license text itself must remain byte-identical. Add a header above it with the project's combined copyright. Open `LICENSE`, prepend these lines (before "GNU GENERAL PUBLIC LICENSE"):

```
Capsule
Copyright (C) 2026 yousiki

Derived from boring.notch
Copyright (C) 2024 The Boring Team

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.

================================================================================

```

- [ ] **Step 3: Update `SECURITY.md`**

Replace any `https://github.com/TheBoredTeam/boring.notch/security/advisories/new` with `https://github.com/yousiki/Capsule/security/advisories/new`.

```bash
sed -i '' 's|TheBoredTeam/boring.notch|yousiki/Capsule|g' SECURITY.md
```

- [ ] **Step 4: Verify**

```bash
grep -E "TheBoredTeam|boring\.notch" README.md SECURITY.md
```

Expected: only matches inside attribution paragraphs in README (the "fork of" line and the Acknowledgments). No matches in SECURITY.md.

- [ ] **Step 5: Commit**

```bash
git add README.md LICENSE SECURITY.md
git commit -m "rebrand: rewrite README, attribute upstream, prepend Capsule copyright to LICENSE"
```

---

## Task 3: Bulk-rename Swift file header comments and CONTRIBUTING / issue templates

**Files:**
- Modify: every `*.swift` containing `//  boringNotch` header comment
- Modify: `CONTRIBUTING.md`, `.github/PULL_REQUEST.md`, `.github/ISSUE_TEMPLATE/1-bug-report-form.yml`, `.github/ISSUE_TEMPLATE/1-feature-request-form.yml`

- [ ] **Step 1: Replace boilerplate Swift header comments**

Every Swift file in this repo has a stock header like:

```swift
//
//  SomeView.swift
//  boringNotch
//
//  Created by ... on ....
//
```

Bulk replace `//  boringNotch` → `//  Capsule`:

```bash
grep -rl "^//  boringNotch$" --include="*.swift" --include="*.h" . | \
  xargs sed -i '' 's|^//  boringNotch$|//  Capsule|'
```

- [ ] **Step 2: Verify header sweep**

```bash
grep -rE "^//\s+boringNotch$" --include="*.swift" --include="*.h" .
```

Expected: zero output.

```bash
grep -rE "^//  Capsule$" --include="*.swift" --include="*.h" . | wc -l
```

Expected: ~80+ files updated.

- [ ] **Step 3: Update GitHub templates and CONTRIBUTING**

```bash
sed -i '' \
  -e 's|TheBoredTeam/boring\.notch|yousiki/Capsule|g' \
  -e 's|Boring Notch|Capsule|g' \
  -e 's|boring\.notch|Capsule|g' \
  -e 's|boringNotch|Capsule|g' \
  CONTRIBUTING.md \
  .github/PULL_REQUEST.md \
  .github/ISSUE_TEMPLATE/1-bug-report-form.yml \
  .github/ISSUE_TEMPLATE/1-feature-request-form.yml
```

- [ ] **Step 4: Verify**

```bash
grep -rE "TheBoredTeam|boringNotch|Boring Notch|boring\.notch" CONTRIBUTING.md .github/
```

Expected: zero output.

- [ ] **Step 5: Commit**

```bash
git add -u
git commit -m "rebrand: replace boringNotch boilerplate in Swift headers and GitHub templates"
```

---

## Task 4: Update bundle identifiers, display names, and product names in `project.pbxproj`

**Files:**
- Modify: `Core/Notch.xcodeproj/project.pbxproj` (10 lines)

- [ ] **Step 1: Apply pbxproj substitutions**

```bash
sed -i '' \
  -e 's|PRODUCT_BUNDLE_IDENTIFIER = theboringteam\.boringnotch\.BoringNotchXPCHelper;|PRODUCT_BUNDLE_IDENTIFIER = moe.siki.Capsule.XPCHelper;|g' \
  -e 's|PRODUCT_BUNDLE_IDENTIFIER = theboringteam\.boringnotch;|PRODUCT_BUNDLE_IDENTIFIER = moe.siki.Capsule;|g' \
  -e 's|PRODUCT_BUNDLE_IDENTIFIER = com\.theboredteam\.NotchKit;|PRODUCT_BUNDLE_IDENTIFIER = moe.siki.CapsuleKit;|g' \
  -e 's|INFOPLIST_KEY_CFBundleDisplayName = TheBoringNotch;|INFOPLIST_KEY_CFBundleDisplayName = Capsule;|g' \
  -e 's|INFOPLIST_KEY_CFBundleDisplayName = BoringNotchXPCHelper;|INFOPLIST_KEY_CFBundleDisplayName = CapsuleXPCHelper;|g' \
  Core/Notch.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Verify**

```bash
grep -E "PRODUCT_BUNDLE_IDENTIFIER|INFOPLIST_KEY_CFBundleDisplayName" Core/Notch.xcodeproj/project.pbxproj
```

Expected output:

```
INFOPLIST_KEY_CFBundleDisplayName = CapsuleXPCHelper;
PRODUCT_BUNDLE_IDENTIFIER = moe.siki.Capsule.XPCHelper;
INFOPLIST_KEY_CFBundleDisplayName = Capsule;
PRODUCT_BUNDLE_IDENTIFIER = moe.siki.Capsule;
PRODUCT_BUNDLE_IDENTIFIER = moe.siki.CapsuleKit;
PRODUCT_BUNDLE_IDENTIFIER = moe.siki.CapsuleKit;
```

(Order/repetition may vary; ensure no `theboringteam`/`TheBoring*` left.)

- [ ] **Step 3: Build to confirm pbxproj is still valid**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED` (the scheme is still called `boringNotch` until Task 14 — that's fine).

- [ ] **Step 4: Commit**

```bash
git add Core/Notch.xcodeproj/project.pbxproj
git commit -m "rebrand: bundle IDs to moe.siki.Capsule, display names to Capsule"
```

---

## Task 5: Update `Info.plist`, entitlements, and XPC mach-service name

**Files:**
- Modify: `Core/Host/Info.plist` (Sparkle feed URL)
- Modify: `Core/NotchKit/Resources/Info.plist` (CFBundleIdentifier — only if hardcoded)
- Modify: `Core/Host/boringNotch.entitlements` (mach-lookup global-name)
- Modify: `BoringNotchXPCHelper/BoringNotchXPCHelper.entitlements` (if any global-name mention)

- [ ] **Step 1: Update Sparkle feed URL**

```bash
sed -i '' 's|https://TheBoredTeam\.github\.io/boring\.notch/appcast\.xml|https://yousiki.github.io/Capsule/appcast.xml|g' Core/Host/Info.plist
```

- [ ] **Step 2: Update NotchKit framework Info.plist**

```bash
sed -i '' \
  -e 's|com\.theboredteam\.NotchKit|moe.siki.CapsuleKit|g' \
  Core/NotchKit/Resources/Info.plist
```

(`CFBundleName` if literal `NotchKit` will be handled when the folder is renamed in Task 14; if it's `$(PRODUCT_NAME)` it'll auto-update. Inspect first.)

- [ ] **Step 3: Update mach-service global-name in entitlements**

The XPC mach service name is a contract between the entitlements file and the Swift connection code. Update both atomically.

```bash
sed -i '' 's|theboringteam\.boringnotch\.BoringNotchXPCHelper|moe.siki.Capsule.XPCHelper|g' Core/Host/boringNotch.entitlements
sed -i '' 's|theboringteam\.boringnotch\.BoringNotchXPCHelper|moe.siki.Capsule.XPCHelper|g' BoringNotchXPCHelper/BoringNotchXPCHelper.entitlements 2>/dev/null || true
```

(Note: file rename to `Capsule.entitlements` happens in Task 11.)

- [ ] **Step 4: Update mach-service name in Swift code**

```bash
sed -i '' 's|theboringteam\.boringnotch\.BoringNotchXPCHelper|moe.siki.Capsule.XPCHelper|g' \
  Core/Host/XPCHelperClient/XPCHelperClient.swift \
  BoringNotchXPCHelper/main.swift
```

Then verify the literal is consistent:

```bash
grep -rE "moe\.siki\.Capsule\.XPCHelper" Core/Host/ BoringNotchXPCHelper/ Core/Host/boringNotch.entitlements
```

Expected: appears in entitlements file + `XPCHelperClient.swift` + `main.swift`.

- [ ] **Step 5: Update `theboringteam.boringnotch` container/applicationscripts paths in Swift**

`Core/Host/Helpers/ApplicationRelauncher.swift` (or similar) contains uninstall paths:

```bash
grep -nE "theboringteam\.boringnotch" Core/Host/ -r --include="*.swift"
```

For each match, replace `theboringteam.boringnotch` → `moe.siki.Capsule`:

```bash
grep -rl "theboringteam\.boringnotch" --include="*.swift" Core/Host/ | \
  xargs sed -i '' 's|theboringteam\.boringnotch|moe.siki.Capsule|g'
```

- [ ] **Step 6: Verify**

```bash
grep -rE "theboringteam|TheBoredTeam" --include="*.swift" --include="*.plist" --include="*.entitlements" .
```

Expected: zero output (all instances now use new bundle ID prefix).

- [ ] **Step 7: Build and commit**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
git add -u
git commit -m "rebrand: update Sparkle feed, XPC mach service, and container paths to moe.siki.Capsule"
```

---

## Task 6: Replace hardcoded URLs and brand strings in Swift code

**Files:**
- Modify: `Core/Host/Notch/BoringExtrasMenu.swift` (2 GitHub URLs)
- Modify: `Core/Host/boringNotchApp.swift` (`MenuBarExtra("boring.notch", ...)` and `AppIcon(for: "theboringteam.boringNotch")`)
- Modify: `Core/Host/Components/WhatsNewView.swift` (`Text("Boring Notch")`)
- Modify: any other Swift literal containing "Boring Notch", "boring.notch"

- [ ] **Step 1: Replace upstream GitHub URLs**

```bash
grep -rl "https://github\.com/TheBoredTeam/boring\.notch" --include="*.swift" . | \
  xargs sed -i '' 's|https://github\.com/TheBoredTeam/boring\.notch|https://github.com/yousiki/Capsule|g'
```

- [ ] **Step 2: Replace MenuBarExtra title and AppIcon name**

```bash
grep -rl 'MenuBarExtra("boring\.notch"' --include="*.swift" . | \
  xargs sed -i '' 's|MenuBarExtra("boring\.notch"|MenuBarExtra("Capsule"|g'

grep -rl 'AppIcon(for: "theboringteam\.boringNotch")' --include="*.swift" . | \
  xargs sed -i '' 's|AppIcon(for: "theboringteam\.boringNotch")|AppIcon(for: "moe.siki.Capsule")|g'
```

- [ ] **Step 3: Replace `Text("Boring Notch")` and similar UI strings**

```bash
grep -rn '"Boring Notch"' --include="*.swift" .
```

For each match (likely `Components/WhatsNewView.swift:?`), inspect the context and decide:
- If it's a literal app name to display: change to `"Capsule"`
- If it's part of a larger sentence: rewrite the sentence

```bash
grep -rl '"Boring Notch"' --include="*.swift" . | \
  xargs sed -i '' 's|"Boring Notch"|"Capsule"|g'
```

- [ ] **Step 4: Replace `Image("theboringteam")` and the imageset reference**

The asset name is `theboringteam` (from `Core/Host/Assets.xcassets/theboringteam.imageset/`). The image is upstream's brand mark — **delete the imageset entirely** rather than rebrand it (see Task 13). For now, find the call site and remove or replace:

```bash
grep -rn 'Image("theboringteam")' --include="*.swift" .
```

Decision: The image appears in the about/credits area. Replace with `Image(systemName: "macwindow.on.rectangle")` or remove the credit row entirely. Edit the file by hand — sed substitution changes meaning here.

- [ ] **Step 5: Verify no upstream brand strings remain in Swift code**

```bash
grep -rE "TheBoredTeam|theboringteam|theboring\.name|boring\.notch" --include="*.swift" .
```

Expected: zero output. (`Boring*` type names still exist — those are renamed in Task 7.)

- [ ] **Step 6: Build and commit**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
git add -u
git commit -m "rebrand: replace hardcoded github URLs, menu titles, and Boring Notch strings"
```

---

## Task 7: Rename `Boring*` Swift types and all callers

**Files:** all `*.swift` files matching `grep -rl "Boring" --include="*.swift" .`

Type rename map (apply in this exact order — longest first to avoid prefix collisions):

| Old | New |
|---|---|
| `BoringNotchSkyLightWindow` | `CapsuleSkyLightWindow` |
| `BoringNotchXPCHelperProtocol` | `CapsuleXPCHelperProtocol` |
| `BoringNotchXPCHelper` | `CapsuleXPCHelper` |
| `BoringNotchWindow` | `CapsuleWindow` |
| `BoringViewCoordinator` | `CapsuleViewCoordinator` |
| `BoringViewModel` | `CapsuleViewModel` |
| `BoringExtrasMenu` | `CapsuleExtrasMenu` |
| `BoringLargeButtons` | `CapsuleLargeButtons` |
| `BoringCalendar` | `CapsuleCalendar` |
| `BoringBattery` | `CapsuleBattery` |
| `BoringHeader` | `CapsuleHeader` |

- [ ] **Step 1: Apply rename map (longest-first)**

```bash
SWIFT_FILES=$(find . -name "*.swift" -not -path "./.git/*" -not -path "*/.build/*" -not -path "*/build/*")

for pair in \
  "BoringNotchSkyLightWindow:CapsuleSkyLightWindow" \
  "BoringNotchXPCHelperProtocol:CapsuleXPCHelperProtocol" \
  "BoringNotchXPCHelper:CapsuleXPCHelper" \
  "BoringNotchWindow:CapsuleWindow" \
  "BoringViewCoordinator:CapsuleViewCoordinator" \
  "BoringViewModel:CapsuleViewModel" \
  "BoringExtrasMenu:CapsuleExtrasMenu" \
  "BoringLargeButtons:CapsuleLargeButtons" \
  "BoringCalendar:CapsuleCalendar" \
  "BoringBattery:CapsuleBattery" \
  "BoringHeader:CapsuleHeader"; do
  OLD="${pair%%:*}"; NEW="${pair##*:}"
  echo "$OLD → $NEW"
  echo "$SWIFT_FILES" | xargs grep -l "\b${OLD}\b" 2>/dev/null | xargs sed -i '' "s/\\b${OLD}\\b/${NEW}/g"
done
```

- [ ] **Step 2: Verify zero `Boring*` identifiers remain in Swift**

```bash
grep -rE "\bBoring[A-Z]" --include="*.swift" .
```

Expected: zero output.

```bash
grep -rE "\bboring[A-Za-z]" --include="*.swift" .
```

Expected: only matches inside file names (e.g., `boringNotchApp.swift`), not in code. (Files renamed in Task 10.)

- [ ] **Step 3: Build**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. If anything fails, the rename map is incomplete — grep the error message, find the missed type, add to the map and re-run.

- [ ] **Step 4: Commit**

```bash
git add -u
git commit -m "rebrand: rename Boring* Swift types to Capsule*"
```

---

## Task 8: Replace `"Boring Notch"` and `"boring.notch"` in `Localizable.xcstrings`

**Files:**
- Modify: `Core/Host/Localizable.xcstrings` (74 hits across 28 translation entries)

- [ ] **Step 1: Replace localized strings**

The `xcstrings` file is JSON. Two distinct entries appear: `"Boring Notch"` (display name, ~16 translations) and `"boring.notch"` (technical/menu strings, ~12 translations). Both are user-facing.

```bash
sed -i '' \
  -e 's|"Boring Notch"|"Capsule"|g' \
  -e 's|"boring\.notch"|"Capsule"|g' \
  Core/Host/Localizable.xcstrings
```

- [ ] **Step 2: Validate JSON is still well-formed**

```bash
python3 -c "import json; json.load(open('Core/Host/Localizable.xcstrings'))"
```

Expected: no output (success).

- [ ] **Step 3: Verify**

```bash
grep -E "(Boring Notch|boring\.notch)" Core/Host/Localizable.xcstrings
```

Expected: zero output.

- [ ] **Step 4: Fix `crowdin.yml` source path**

The path `/boringNotch/Localizable.xcstrings` doesn't even match the actual location (`Core/Host/Localizable.xcstrings`):

```yaml
files:
  - source: /Core/Host/Localizable.xcstrings
    translation: /Core/Host/Localizable.xcstrings
    multilingual: 1
```

Apply:

```bash
cat > crowdin.yml <<'EOF'
files:
  - source: /Core/Host/Localizable.xcstrings
    translation: /Core/Host/Localizable.xcstrings
    multilingual: 1
EOF
```

- [ ] **Step 5: Build (catches localization-key mismatches if any code uses LocalizedStringKey lookup) and commit**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
git add Core/Host/Localizable.xcstrings crowdin.yml
git commit -m "rebrand: replace localized brand strings; fix crowdin source path"
```

---

## Task 9: Rename `Boring*` Swift files (file/folder renames, pbxproj sync)

**Files:**

Source rename map:

| Old path | New path |
|---|---|
| `Core/Host/boringNotchApp.swift` | `Core/Host/CapsuleApp.swift` |
| `Core/Host/BoringViewCoordinator.swift` | `Core/Host/CapsuleViewCoordinator.swift` |
| `Core/Host/Models/BoringViewModel.swift` | `Core/Host/Models/CapsuleViewModel.swift` |
| `Core/Host/Notch/BoringExtrasMenu.swift` | `Core/Host/Notch/CapsuleExtrasMenu.swift` |
| `Core/Host/Notch/BoringHeader.swift` | `Core/Host/Notch/CapsuleHeader.swift` |
| `Core/Host/Notch/BoringNotchSkyLightWindow.swift` | `Core/Host/Notch/CapsuleSkyLightWindow.swift` |
| `Core/Host/Notch/BoringNotchWindow.swift` | `Core/Host/Notch/CapsuleWindow.swift` |
| `Core/Host/Components/Calendar/BoringCalendar.swift` | `Core/Host/Components/Calendar/CapsuleCalendar.swift` |
| `Core/Host/Components/Live activities/BoringBattery.swift` | `Core/Host/Components/Live activities/CapsuleBattery.swift` |
| `Core/Host/XPCHelperClient/BoringNotchXPCHelperProtocol.swift` | `Core/Host/XPCHelperClient/CapsuleXPCHelperProtocol.swift` |

- [ ] **Step 1: `git mv` all renames**

```bash
git mv Core/Host/boringNotchApp.swift Core/Host/CapsuleApp.swift
git mv Core/Host/BoringViewCoordinator.swift Core/Host/CapsuleViewCoordinator.swift
git mv Core/Host/Models/BoringViewModel.swift Core/Host/Models/CapsuleViewModel.swift
git mv Core/Host/Notch/BoringExtrasMenu.swift Core/Host/Notch/CapsuleExtrasMenu.swift
git mv Core/Host/Notch/BoringHeader.swift Core/Host/Notch/CapsuleHeader.swift
git mv Core/Host/Notch/BoringNotchSkyLightWindow.swift Core/Host/Notch/CapsuleSkyLightWindow.swift
git mv Core/Host/Notch/BoringNotchWindow.swift Core/Host/Notch/CapsuleWindow.swift
git mv "Core/Host/Components/Calendar/BoringCalendar.swift" "Core/Host/Components/Calendar/CapsuleCalendar.swift"
git mv "Core/Host/Components/Live activities/BoringBattery.swift" "Core/Host/Components/Live activities/CapsuleBattery.swift"
git mv Core/Host/XPCHelperClient/BoringNotchXPCHelperProtocol.swift Core/Host/XPCHelperClient/CapsuleXPCHelperProtocol.swift
```

- [ ] **Step 2: Update `project.pbxproj` `path = ` and file-reference name attributes**

```bash
sed -i '' \
  -e 's|boringNotchApp\.swift|CapsuleApp.swift|g' \
  -e 's|BoringViewCoordinator\.swift|CapsuleViewCoordinator.swift|g' \
  -e 's|BoringViewModel\.swift|CapsuleViewModel.swift|g' \
  -e 's|BoringExtrasMenu\.swift|CapsuleExtrasMenu.swift|g' \
  -e 's|BoringHeader\.swift|CapsuleHeader.swift|g' \
  -e 's|BoringNotchSkyLightWindow\.swift|CapsuleSkyLightWindow.swift|g' \
  -e 's|BoringNotchWindow\.swift|CapsuleWindow.swift|g' \
  -e 's|BoringCalendar\.swift|CapsuleCalendar.swift|g' \
  -e 's|BoringBattery\.swift|CapsuleBattery.swift|g' \
  -e 's|BoringNotchXPCHelperProtocol\.swift|CapsuleXPCHelperProtocol.swift|g' \
  Core/Notch.xcodeproj/project.pbxproj
```

- [ ] **Step 3: Build** (this validates pbxproj path refs match actual filenames)

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

If "file not found" — open `Core/Notch.xcodeproj/project.pbxproj` in a text editor, search for the missing file's old name; the sed missed a line.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "rebrand: rename Boring*.swift source files to Capsule*.swift"
```

---

## Task 10: Rename entitlements file and audio resource

**Files:**
- Rename: `Core/Host/boringNotch.entitlements` → `Core/Host/Capsule.entitlements`
- Rename: `Core/Host/boring.m4a` → `Core/Host/capsule.m4a` (or keep — see step 1)

- [ ] **Step 1: Rename entitlements file**

```bash
git mv Core/Host/boringNotch.entitlements Core/Host/Capsule.entitlements
sed -i '' 's|Core/Host/boringNotch\.entitlements|Core/Host/Capsule.entitlements|g' Core/Notch.xcodeproj/project.pbxproj
sed -i '' 's|boringNotch\.entitlements|Capsule.entitlements|g' Core/Notch.xcodeproj/project.pbxproj
```

- [ ] **Step 2: Rename `boring.m4a` audio resource**

This is the notification chime. Inspect Swift code for the asset name first:

```bash
grep -rn "boring\.m4a\|\"boring\"" --include="*.swift" Core/Host/
```

If the code references the bare name `"boring"` (without extension), rename file but update Swift reference too:

```bash
git mv Core/Host/boring.m4a Core/Host/capsule.m4a
sed -i '' 's|"boring\.m4a"|"capsule.m4a"|g' Core/Host/**/*.swift 2>/dev/null
sed -i '' 's|boring\.m4a|capsule.m4a|g' Core/Notch.xcodeproj/project.pbxproj

# If the bare name "boring" is used as the resource lookup key:
grep -rn '"boring"' --include="*.swift" Core/Host/ | grep -i "Bundle\|NSSound\|asset"
# Decide based on context whether to also rename "boring" → "capsule"
```

- [ ] **Step 3: Build and commit**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
git add -A
git commit -m "rebrand: rename entitlements and audio resource files"
```

---

## Task 11: Rename `BoringNotchXPCHelper/` directory

**Files:**
- Rename: `BoringNotchXPCHelper/` → `CapsuleXPCHelper/`
- Rename inside: `BoringNotchXPCHelper.swift` → `CapsuleXPCHelper.swift`, `BoringNotchXPCHelperProtocol.swift` → `CapsuleXPCHelperProtocol.swift`, `BoringNotchXPCHelper.entitlements` → `CapsuleXPCHelper.entitlements`

- [ ] **Step 1: Rename directory and its files**

```bash
git mv BoringNotchXPCHelper CapsuleXPCHelper
git mv CapsuleXPCHelper/BoringNotchXPCHelper.swift CapsuleXPCHelper/CapsuleXPCHelper.swift
git mv CapsuleXPCHelper/BoringNotchXPCHelper.entitlements CapsuleXPCHelper/CapsuleXPCHelper.entitlements
# protocol file may have been already renamed in Task 9 — check first
[ -f CapsuleXPCHelper/BoringNotchXPCHelperProtocol.swift ] && \
  git mv CapsuleXPCHelper/BoringNotchXPCHelperProtocol.swift CapsuleXPCHelper/CapsuleXPCHelperProtocol.swift
```

- [ ] **Step 2: Update `project.pbxproj`** — folder path + scheme target name + product name

```bash
sed -i '' \
  -e 's|BoringNotchXPCHelper/BoringNotchXPCHelper\.swift|CapsuleXPCHelper/CapsuleXPCHelper.swift|g' \
  -e 's|BoringNotchXPCHelper/BoringNotchXPCHelperProtocol\.swift|CapsuleXPCHelper/CapsuleXPCHelperProtocol.swift|g' \
  -e 's|BoringNotchXPCHelper/BoringNotchXPCHelper\.entitlements|CapsuleXPCHelper/CapsuleXPCHelper.entitlements|g' \
  -e 's|BoringNotchXPCHelper/main\.swift|CapsuleXPCHelper/main.swift|g' \
  -e 's|path = BoringNotchXPCHelper|path = CapsuleXPCHelper|g' \
  -e 's|name = BoringNotchXPCHelper|name = CapsuleXPCHelper|g' \
  -e 's|BoringNotchXPCHelper\.swift|CapsuleXPCHelper.swift|g' \
  -e 's|BoringNotchXPCHelper\.entitlements|CapsuleXPCHelper.entitlements|g' \
  -e 's|BoringNotchXPCHelperProtocol\.swift|CapsuleXPCHelperProtocol.swift|g' \
  -e 's|"BoringNotchXPCHelper"|"CapsuleXPCHelper"|g' \
  -e 's|BoringNotchXPCHelper\.xpc|CapsuleXPCHelper.xpc|g' \
  Core/Notch.xcodeproj/project.pbxproj
```

- [ ] **Step 3: Verify no `BoringNotch*` paths remain in pbxproj**

```bash
grep -E "BoringNotch" Core/Notch.xcodeproj/project.pbxproj
```

Expected: zero output.

- [ ] **Step 4: Rename xcscheme**

```bash
SCHEME_DIR="Core/Notch.xcodeproj/xcshareddata/xcschemes"
[ -f "$SCHEME_DIR/BoringNotchXPCHelper.xcscheme" ] && \
  git mv "$SCHEME_DIR/BoringNotchXPCHelper.xcscheme" "$SCHEME_DIR/CapsuleXPCHelper.xcscheme"

# Update scheme management plist
sed -i '' 's|BoringNotchXPCHelper\.xcscheme|CapsuleXPCHelper.xcscheme|g' \
  Core/Notch.xcodeproj/xcuserdata/*.xcuserdatad/xcschemes/xcschememanagement.plist
```

- [ ] **Step 5: Build and commit**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme boringNotch -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
git add -A
git commit -m "rebrand: rename BoringNotchXPCHelper directory and target to CapsuleXPCHelper"
```

---

## Task 12: Rename main app scheme `boringNotch` → `Capsule`

**Files:**
- Rename: `Core/Notch.xcodeproj/xcshareddata/xcschemes/boringNotch.xcscheme` → `Capsule.xcscheme`
- Modify: `xcschememanagement.plist`
- Modify: `project.pbxproj` (target name)

- [ ] **Step 1: Rename scheme file**

```bash
git mv Core/Notch.xcodeproj/xcshareddata/xcschemes/boringNotch.xcscheme \
       Core/Notch.xcodeproj/xcshareddata/xcschemes/Capsule.xcscheme
```

- [ ] **Step 2: Update scheme management plist**

```bash
sed -i '' 's|boringNotch\.xcscheme|Capsule.xcscheme|g' \
  Core/Notch.xcodeproj/xcuserdata/*.xcuserdatad/xcschemes/xcschememanagement.plist
```

- [ ] **Step 3: Update target name in `project.pbxproj`**

The target name appears in many places: `name = boringNotch;`, `productName = boringNotch;`, `BuildableName = "boringNotch.app"`, `BlueprintName = "boringNotch"`.

```bash
sed -i '' \
  -e 's|name = boringNotch;|name = Capsule;|g' \
  -e 's|productName = boringNotch;|productName = Capsule;|g' \
  -e 's|"boringNotch\.app"|"Capsule.app"|g' \
  -e 's|/\* boringNotch \*/|/* Capsule */|g' \
  Core/Notch.xcodeproj/project.pbxproj
```

Then update the `Capsule.xcscheme` itself (which still references `boringNotch.app` and `BlueprintName = "boringNotch"`):

```bash
sed -i '' \
  -e 's|BlueprintName = "boringNotch"|BlueprintName = "Capsule"|g' \
  -e 's|BuildableName = "boringNotch\.app"|BuildableName = "Capsule.app"|g' \
  Core/Notch.xcodeproj/xcshareddata/xcschemes/Capsule.xcscheme
```

- [ ] **Step 4: Build with the new scheme name**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme Capsule -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`. The built product is `Capsule.app`.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "rebrand: rename boringNotch scheme/target to Capsule, build product is Capsule.app"
```

---

## Task 13: Replace upstream brand assets

**Files:**
- Delete: `Core/Host/Assets.xcassets/theboringteam.imageset/`
- Delete: `Core/Host/Assets.xcassets/logo2.imageset/BoringNotch icon.png` (and rename imageset)

- [ ] **Step 1: Delete `theboringteam` imageset**

The image inside is upstream's "TheBoringTeam" brand mark — not licensed under GPL-3.0 (trademark/brand). Removing is safest. Step 6 of Task 6 already removed code references.

```bash
git rm -r Core/Host/Assets.xcassets/theboringteam.imageset
```

Update `project.pbxproj` if there's an explicit reference (asset catalogs are typically referenced as folders, no per-file refs needed):

```bash
grep -nE "theboringteam" Core/Notch.xcodeproj/project.pbxproj
```

Expected: zero output (imagesets aren't usually individually listed in pbxproj).

- [ ] **Step 2: Rename `logo2` imageset and image**

```bash
git mv "Core/Host/Assets.xcassets/logo2.imageset/BoringNotch icon.png" "Core/Host/Assets.xcassets/logo2.imageset/logo.png"
sed -i '' 's|"BoringNotch icon\.png"|"logo.png"|g' Core/Host/Assets.xcassets/logo2.imageset/Contents.json
```

(Imageset folder name `logo2` is generic — leave or rename to `logo` if you prefer.)

- [ ] **Step 3: Build and verify no missing-asset warnings**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme Capsule -configuration Debug -destination 'platform=macOS' build 2>&1 | grep -iE "warning|error" | head -10
```

Expected: no "asset not found" / "image not found" warnings.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "rebrand: remove upstream theboringteam brand asset, rename logo2 contents"
```

---

## Task 14: Rename `NotchKit` framework to `CapsuleKit`

**Files:**
- Rename: `Core/NotchKit/` → `Core/CapsuleKit/`
- Modify: `Core/Notch.xcodeproj/project.pbxproj` (PRODUCT_NAME, paths, target name)
- Rename: `Core/Notch.xcodeproj/xcshareddata/xcschemes/NotchKit.xcscheme` → `CapsuleKit.xcscheme`
- Modify: every `import NotchKit` in `Core/Host/`, `Extensions/`, `CapsuleXPCHelper/`
- Rename Swift types in `Core/CapsuleKit/Sources/`:
  - `NotchHost` → `CapsuleHost`
  - `NotchExtension` → `CapsuleExtension`
  - `NotchKitVersion` → `CapsuleKitVersion`
  - `NotchLogger` → `CapsuleLogger`
  - `NotchSettingsStore` → `CapsuleSettingsStore`
  - `NotchObservation` → `CapsuleObservation`
  - `NotchSlotLifecycle` → `CapsuleSlotLifecycle`
  - `NotchPermissionsAPI` → `CapsulePermissionsAPI`
  - `NotchPermissionKind` → `CapsulePermissionKind`
  - `NotchPermissionRequest` → `CapsulePermissionRequest`
  - `NotchTabContribution` → `CapsuleTabContribution`
  - `NotchHUDContribution` → `CapsuleHUDContribution`
  - `NotchSneakPeekContribution` → `CapsuleSneakPeekContribution`
  - `NotchExpandedItemContribution` → `CapsuleExpandedItemContribution`
  - `NotchClosedChinContribution` → `CapsuleClosedChinContribution`
  - `NotchHomeFragmentContribution` → `CapsuleHomeFragmentContribution`
  - `NotchKeyboardShortcutContribution` → `CapsuleKeyboardShortcutContribution`
  - `NotchMenuItemContribution` → `CapsuleMenuItemContribution`
  - `NotchOnboardingContribution` → `CapsuleOnboardingContribution`
  - `NotchSettingsPaneContribution` → `CapsuleSettingsPaneContribution`
  - `NotchCoordinatorHost` → `CapsuleCoordinatorHost`
  - `NotchNotchStateHost` → `CapsuleNotchStateHost` (keeps the second `Notch*` since that describes domain)
  - `NotchScreenHost` → `CapsuleScreenHost`

This is the largest single task. Subagent-friendly. Do NOT split across commits — the codebase doesn't compile mid-rename.

- [ ] **Step 1: Rename folder**

```bash
git mv Core/NotchKit Core/CapsuleKit
git mv Core/NotchKitTests Core/CapsuleKitTests 2>/dev/null || true
```

- [ ] **Step 2: Rename SDK type files inside (where filename = type name)**

```bash
git mv Core/CapsuleKit/Sources/NotchHost.swift Core/CapsuleKit/Sources/CapsuleHost.swift
git mv Core/CapsuleKit/Sources/NotchExtension.swift Core/CapsuleKit/Sources/CapsuleExtension.swift
git mv Core/CapsuleKit/Sources/NotchSlotLifecycle.swift Core/CapsuleKit/Sources/CapsuleSlotLifecycle.swift
git mv Core/CapsuleKit/Sources/Logger/NotchLogger.swift Core/CapsuleKit/Sources/Logger/CapsuleLogger.swift
git mv Core/CapsuleKit/Sources/Settings/NotchSettingsStore.swift Core/CapsuleKit/Sources/Settings/CapsuleSettingsStore.swift
git mv Core/CapsuleKit/Sources/Observation/NotchObservation.swift Core/CapsuleKit/Sources/Observation/CapsuleObservation.swift
git mv Core/CapsuleKit/Sources/Permissions/NotchPermissionsAPI.swift Core/CapsuleKit/Sources/Permissions/CapsulePermissionsAPI.swift
git mv Core/CapsuleKit/Sources/Permissions/NotchPermissionKind.swift Core/CapsuleKit/Sources/Permissions/CapsulePermissionKind.swift
git mv Core/CapsuleKit/Sources/Version/NotchKitVersion.swift Core/CapsuleKit/Sources/Version/CapsuleKitVersion.swift
git mv Core/CapsuleKit/Sources/Services/NotchCoordinatorHost.swift Core/CapsuleKit/Sources/Services/CapsuleCoordinatorHost.swift
git mv Core/CapsuleKit/Sources/Services/NotchNotchStateHost.swift Core/CapsuleKit/Sources/Services/CapsuleNotchStateHost.swift
git mv Core/CapsuleKit/Sources/Services/NotchScreenHost.swift Core/CapsuleKit/Sources/Services/CapsuleScreenHost.swift
# Contributions
for f in NotchTabContribution NotchHUDContribution NotchSneakPeekContribution NotchExpandedItemContribution \
         NotchClosedChinContribution NotchHomeFragmentContribution NotchKeyboardShortcutContribution \
         NotchMenuItemContribution NotchOnboardingContribution NotchSettingsPaneContribution NotchPermissionRequest; do
  NEW=$(echo "$f" | sed 's|^Notch|Capsule|')
  [ -f "Core/CapsuleKit/Sources/Contributions/${f}.swift" ] && \
    git mv "Core/CapsuleKit/Sources/Contributions/${f}.swift" "Core/CapsuleKit/Sources/Contributions/${NEW}.swift"
done
```

- [ ] **Step 3: Apply type rename across all Swift code (longest-first)**

```bash
ALL_SWIFT=$(find . -name "*.swift" -not -path "./.git/*" -not -path "*/.build/*" -not -path "*/build/*")

for pair in \
  "NotchKeyboardShortcutContribution:CapsuleKeyboardShortcutContribution" \
  "NotchHomeFragmentContribution:CapsuleHomeFragmentContribution" \
  "NotchExpandedItemContribution:CapsuleExpandedItemContribution" \
  "NotchSettingsPaneContribution:CapsuleSettingsPaneContribution" \
  "NotchClosedChinContribution:CapsuleClosedChinContribution" \
  "NotchOnboardingContribution:CapsuleOnboardingContribution" \
  "NotchMenuItemContribution:CapsuleMenuItemContribution" \
  "NotchSneakPeekContribution:CapsuleSneakPeekContribution" \
  "NotchHUDContribution:CapsuleHUDContribution" \
  "NotchTabContribution:CapsuleTabContribution" \
  "NotchPermissionRequest:CapsulePermissionRequest" \
  "NotchPermissionsAPI:CapsulePermissionsAPI" \
  "NotchPermissionKind:CapsulePermissionKind" \
  "NotchCoordinatorHost:CapsuleCoordinatorHost" \
  "NotchNotchStateHost:CapsuleNotchStateHost" \
  "NotchSettingsStore:CapsuleSettingsStore" \
  "NotchSlotLifecycle:CapsuleSlotLifecycle" \
  "NotchScreenHost:CapsuleScreenHost" \
  "NotchObservation:CapsuleObservation" \
  "NotchKitVersion:CapsuleKitVersion" \
  "NotchExtension:CapsuleExtension" \
  "NotchLogger:CapsuleLogger" \
  "NotchHost:CapsuleHost"; do
  OLD="${pair%%:*}"; NEW="${pair##*:}"
  echo "$OLD → $NEW"
  echo "$ALL_SWIFT" | xargs grep -l "\\b${OLD}\\b" 2>/dev/null | xargs sed -i '' "s/\\b${OLD}\\b/${NEW}/g"
done
```

- [ ] **Step 4: Replace `import NotchKit` → `import CapsuleKit`**

```bash
echo "$ALL_SWIFT" | xargs grep -l "^import NotchKit$" 2>/dev/null | \
  xargs sed -i '' 's|^import NotchKit$|import CapsuleKit|'
```

- [ ] **Step 5: Update `project.pbxproj` for module rename**

```bash
sed -i '' \
  -e 's|PRODUCT_NAME = NotchKit;|PRODUCT_NAME = CapsuleKit;|g' \
  -e 's|path = NotchKit;|path = CapsuleKit;|g' \
  -e 's|path = "NotchKit";|path = "CapsuleKit";|g' \
  -e 's|name = NotchKit;|name = CapsuleKit;|g' \
  -e 's|/\* NotchKit \*/|/* CapsuleKit */|g' \
  -e 's|"NotchKit\.framework"|"CapsuleKit.framework"|g' \
  -e 's|NotchKit\.framework|CapsuleKit.framework|g' \
  -e 's|NotchKit\.xcscheme|CapsuleKit.xcscheme|g' \
  -e 's|productName = NotchKit;|productName = CapsuleKit;|g' \
  -e 's|Core/NotchKit|Core/CapsuleKit|g' \
  Core/Notch.xcodeproj/project.pbxproj
```

- [ ] **Step 6: Rename xcscheme**

```bash
git mv Core/Notch.xcodeproj/xcshareddata/xcschemes/NotchKit.xcscheme \
       Core/Notch.xcodeproj/xcshareddata/xcschemes/CapsuleKit.xcscheme
sed -i '' \
  -e 's|BlueprintName = "NotchKit"|BlueprintName = "CapsuleKit"|g' \
  -e 's|BuildableName = "NotchKit\.framework"|BuildableName = "CapsuleKit.framework"|g' \
  Core/Notch.xcodeproj/xcshareddata/xcschemes/CapsuleKit.xcscheme
sed -i '' 's|NotchKit\.xcscheme|CapsuleKit.xcscheme|g' \
  Core/Notch.xcodeproj/xcuserdata/*.xcuserdatad/xcschemes/xcschememanagement.plist
```

- [ ] **Step 7: Update enforcement script**

```bash
sed -i '' \
  -e 's|notchkit|capsulekit|g' \
  -e 's|NotchKit|CapsuleKit|g' \
  scripts/check_no_notchkit_embed.sh
git mv scripts/check_no_notchkit_embed.sh scripts/check_no_capsulekit_embed.sh
```

Update the `.github/workflows/*.yml` calls to this script (Task 16 covers workflows broadly, but if the script name is referenced, fix here):

```bash
grep -rn "check_no_notchkit_embed" .github/ scripts/ Core/Notch.xcodeproj/project.pbxproj
# Replace any matches
sed -i '' 's|check_no_notchkit_embed|check_no_capsulekit_embed|g' \
  .github/workflows/*.yml \
  Core/Notch.xcodeproj/project.pbxproj 2>/dev/null
```

- [ ] **Step 8: Build CapsuleKit, then full app**

```bash
xcodebuild -workspace Notch.xcworkspace -scheme CapsuleKit -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -10
xcodebuild -workspace Notch.xcworkspace -scheme Capsule -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: both `BUILD SUCCEEDED`.

- [ ] **Step 9: Verify no `NotchKit` symbols leaked**

```bash
grep -rE "\\bNotchKit\\b|import NotchKit" --include="*.swift" --include="*.pbxproj" --include="*.sh" --include="*.yml" .
```

Expected: zero output.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "rebrand: rename NotchKit framework and SDK API surface to CapsuleKit"
```

---

## Task 15: Rename Xcode project and workspace

**Files:**
- Rename: `Core/Notch.xcodeproj` → `Core/Capsule.xcodeproj`
- Rename: `Notch.xcworkspace` → `Capsule.xcworkspace`
- Rename: `Core/Host/Notch-Bridging-Header.h` → `Core/Host/Capsule-Bridging-Header.h`
- Modify: `Capsule.xcworkspace/contents.xcworkspacedata`

- [ ] **Step 1: Rename xcodeproj folder**

```bash
git mv Core/Notch.xcodeproj Core/Capsule.xcodeproj
```

- [ ] **Step 2: Rename xcworkspace**

```bash
git mv Notch.xcworkspace Capsule.xcworkspace
```

- [ ] **Step 3: Update workspace contents reference**

```bash
sed -i '' 's|Core/Notch\.xcodeproj|Core/Capsule.xcodeproj|g' \
  Capsule.xcworkspace/contents.xcworkspacedata
```

Verify:

```bash
cat Capsule.xcworkspace/contents.xcworkspacedata
```

Expected: contains `<FileRef location="group:Core/Capsule.xcodeproj"></FileRef>`.

- [ ] **Step 4: Rename bridging header**

```bash
git mv Core/Host/Notch-Bridging-Header.h Core/Host/Capsule-Bridging-Header.h
sed -i '' 's|Notch-Bridging-Header\.h|Capsule-Bridging-Header.h|g' \
  Core/Capsule.xcodeproj/project.pbxproj
```

- [ ] **Step 5: Build using the new workspace name**

```bash
xcodebuild -workspace Capsule.xcworkspace -scheme Capsule -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: `BUILD SUCCEEDED`.

- [ ] **Step 6: Update README to reference the new workspace**

(Already done in Task 2 — verify):

```bash
grep "Capsule.xcworkspace" README.md
```

Expected: at least one match.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "rebrand: rename Notch.xcodeproj→Capsule.xcodeproj and workspace, rename bridging header"
```

---

## Task 16: Update CI workflows and DMG packaging

**Files:**
- Modify: `.github/workflows/cicd.yml`, `build_reusable.yml`, `release.yml`
- Modify: `Configuration/dmg/create_dmg.sh`

- [ ] **Step 1: Replace upstream URLs and product names in workflows**

```bash
sed -i '' \
  -e 's|TheBoredTeam/boring\.notch|yousiki/Capsule|g' \
  -e 's|TheBoredTeam/homebrew-boring-notch|yousiki/homebrew-capsule|g' \
  -e 's|boring-notch/boring-notch|capsule/capsule|g' \
  -e 's|boringNotch\.dmg|Capsule.dmg|g' \
  -e 's|boringNotch\.app|Capsule.app|g' \
  -e 's|scheme: boringNotch|scheme: Capsule|g' \
  -e 's|"boringNotch"|"Capsule"|g' \
  -e 's|workspace: Notch\.xcworkspace|workspace: Capsule.xcworkspace|g' \
  -e 's|Notch\.xcworkspace|Capsule.xcworkspace|g' \
  .github/workflows/cicd.yml \
  .github/workflows/build_reusable.yml \
  .github/workflows/release.yml
```

- [ ] **Step 2: Update DMG script**

```bash
sed -i '' \
  -e 's|boringNotch|Capsule|g' \
  -e 's|Boring Notch|Capsule|g' \
  Configuration/dmg/create_dmg.sh
```

- [ ] **Step 3: Verify**

```bash
grep -rnE "TheBoredTeam|boringNotch|boring\.notch|Boring Notch" .github/ Configuration/
```

Expected: zero output.

- [ ] **Step 4: Smoke-test workflow YAML validity** (using `act` if available, otherwise just lint)

```bash
# minimal sanity: yaml parses
python3 -c "import yaml; [yaml.safe_load(open(f)) for f in ['.github/workflows/cicd.yml', '.github/workflows/build_reusable.yml', '.github/workflows/release.yml']]"
```

Expected: no exceptions.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "rebrand: update GitHub workflows and DMG script for Capsule"
```

---

## Task 17: Update internal docs and superpowers references

**Files:**
- Modify: `docs/superpowers/handoffs/*.md` and `docs/superpowers/specs/*.md` and `docs/superpowers/plans/*.md` — only the file references that point to renamed paths. Don't rewrite history-style notes.

- [ ] **Step 1: Inventory remaining boring/Notch references in docs**

```bash
grep -rnE "TheBoredTeam|boringNotch|boring\.notch|Boring Notch" docs/ 2>/dev/null
grep -rnE "Core/NotchKit/|Core/Notch\.xcodeproj|Notch\.xcworkspace|Notch-Bridging" docs/ 2>/dev/null
```

- [ ] **Step 2: For each match, decide**

- **Plans/specs documenting completed history**: **leave** — they describe past work and the file paths at that time. Adding a footnote is OK.
- **Active plans/handoffs referencing current paths**: update the path so they remain runnable.
- **Bibliography sections naming `boring.notch`**: update if it's an attribution line, leave if quoting.

Edit each file by hand. Do NOT bulk-sed `docs/` — meaning is contextual.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "rebrand: update internal docs to reference Capsule paths"
```

---

## Task 18: Final verification sweep and cleanup

**Files:**
- Modify: `docs/rebrand/INVENTORY.md` (mark completion)

- [ ] **Step 1: Re-run the baseline counts and compare**

```bash
echo "## Post-rename counts ($(date -u +%Y-%m-%dT%H:%M:%SZ))"
echo "Boring/boring:"
grep -rE "[Bb]oring" --include="*.swift" --include="*.plist" --include="*.entitlements" --include="*.pbxproj" --include="*.xcstrings" --include="*.md" --include="*.yml" --include="*.sh" --include="*.json" --include="*.h" . 2>/dev/null | grep -vE "^\./docs/|^\./README\.md:|^\./LICENSE:|^\./CONTRIBUTING\.md:|^\./SECURITY\.md:" | wc -l
echo "TheBoredTeam:"
grep -rE "TheBoredTeam|theboringteam|theboring" --include="*.swift" --include="*.plist" --include="*.entitlements" --include="*.pbxproj" --include="*.xcstrings" --include="*.md" --include="*.yml" --include="*.sh" --include="*.json" . 2>/dev/null | grep -vE "^\./docs/|^\./README\.md:|^\./LICENSE:" | wc -l
echo "NotchKit (in code/build, not docs):"
grep -rE "NotchKit" --include="*.swift" --include="*.pbxproj" --include="*.plist" --include="*.sh" . 2>/dev/null | wc -l
```

Expected:
- **Boring/boring (excluding attribution docs):** 0
- **TheBoredTeam (excluding attribution docs):** 0
- **NotchKit:** 0

If any nonzero, find them and fix:

```bash
grep -rE "[Bb]oring" --include="*.swift" --include="*.plist" --include="*.entitlements" --include="*.pbxproj" --include="*.xcstrings" --include="*.yml" --include="*.sh" --include="*.json" --include="*.h" . 2>/dev/null
```

- [ ] **Step 2: Full clean build of all schemes**

```bash
xcodebuild -workspace Capsule.xcworkspace -scheme Capsule -configuration Debug -destination 'platform=macOS' clean build 2>&1 | tail -20
xcodebuild -workspace Capsule.xcworkspace -scheme CapsuleKit -configuration Debug -destination 'platform=macOS' clean build 2>&1 | tail -10
xcodebuild -workspace Capsule.xcworkspace -scheme CapsuleXPCHelper -configuration Debug -destination 'platform=macOS' clean build 2>&1 | tail -10
```

Expected: all `BUILD SUCCEEDED`.

- [ ] **Step 3: Archive build (release configuration)**

```bash
xcodebuild -workspace Capsule.xcworkspace -scheme Capsule -configuration Release -destination 'platform=macOS' -archivePath /tmp/Capsule.xcarchive archive 2>&1 | tail -20
```

Expected: archive succeeds. Inspect:

```bash
ls /tmp/Capsule.xcarchive/Products/Applications/
```

Expected: `Capsule.app` (not `boringNotch.app`).

- [ ] **Step 4: Inspect built bundle identifiers**

```bash
plutil -p /tmp/Capsule.xcarchive/Products/Applications/Capsule.app/Contents/Info.plist | grep -E "CFBundleIdentifier|CFBundleName|CFBundleDisplayName|SUFeedURL"
```

Expected:
```
"CFBundleIdentifier" => "moe.siki.Capsule"
"CFBundleName" => "Capsule"
"CFBundleDisplayName" => "Capsule"
"SUFeedURL" => "https://yousiki.github.io/Capsule/appcast.xml"
```

- [ ] **Step 5: Manual smoke test**

Open the archived app. Verify:
- Launch succeeds
- Menu bar icon appears
- Notch UI renders
- Settings open and show "Capsule" branding
- Sparkle update check **does NOT** hit `TheBoredTeam.github.io`. Run with Network Link Conditioner or check Console for outgoing requests.

(Document any issues; do not commit fixes here — they go in follow-up commits.)

- [ ] **Step 6: Delete inventory log**

```bash
git rm -r docs/rebrand
git commit -m "rebrand: remove rebrand inventory after completion"
```

- [ ] **Step 7: Push**

```bash
git push -u origin rebrand/capsule
```

(Then open a PR titled "Rebrand: boringNotch → Capsule (yousiki)".)

---

## Self-Review

**Spec coverage check:**

| Spec item | Task | ✓ |
|---|---|---|
| Replace all `boring`/`boringNotch` identifiers | T6, T7, T9 | ✓ |
| Replace `TheBoredTeam`/`theboringteam` | T4, T5, T6 | ✓ |
| `NotchKit` → `CapsuleKit` | T14 | ✓ |
| `Notch.xcodeproj` → `Capsule.xcodeproj`, workspace, bridging header | T15 | ✓ |
| Bundle ID `moe.siki.Capsule` family | T4, T5 | ✓ |
| Sparkle feed URL → yousiki.github.io | T5 | ✓ |
| GitHub URLs / DMG / homebrew tap | T6 (code), T16 (CI) | ✓ |
| Localized strings | T8 | ✓ |
| README rewrite + GPL §5(a) attribution | T2 | ✓ |
| LICENSE — keep GPL-3.0, prepend own copyright | T2 | ✓ |
| Crowdin path fix | T8 | ✓ |
| Remove upstream brand assets (theboringteam imageset) | T13 | ✓ |
| Keep AppIcon as-is (deferred) | (out of scope, noted) | ✓ |
| Keep `MacroVisionKit` upstream reference | (no change needed) | ✓ |
| Keep `Notch*` types describing the hardware feature | (naming policy table) | ✓ |
| Final QA + archive verification | T18 | ✓ |

**Placeholder scan:** No "TBD", "implement later", or "similar to Task N" — every step has the exact command or substitution. Two judgment-call steps (Task 6 Step 4 — replacing `Image("theboringteam")`; Task 17 Step 2 — selectively editing docs) explicitly call out that they require human judgment rather than blind sed.

**Type consistency:** New names used in later tasks all defined in the rename map at top. Spot-checks: `CapsuleHost` (T14) matches its file rename `NotchHost.swift → CapsuleHost.swift` (T14 Step 2). `CapsuleXPCHelper` consistent across T7, T11. `Capsule.app` build product matches T12 + T18 verification.

**Risk callouts:**
1. **T11 directory rename + scheme `boringNotch` rename in T12** — the `boringNotch` scheme is renamed *after* directory ops. Build between T11 and T12 still uses the `boringNotch` scheme name, which is fine because the scheme hasn't been renamed yet.
2. **T14 is the largest task** — non-atomic mid-state doesn't compile. Subagent must complete all 10 steps before commit. If a subagent times out mid-task, drop the worktree and restart fresh from T13's commit.
3. **T15 workspace rename** breaks Xcode's saved user state. After this commit, anyone with the project open in Xcode must reopen `Capsule.xcworkspace`.
4. **`xcuserdata/yousiki.xcuserdatad/`** paths in shell commands are user-specific. If executed by an agent under a different user (or in CI), substitute the actual username or use a glob: `xcuserdata/*.xcuserdatad/`.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-06-capsule-rebrand.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration. Best for this plan because Tasks 7, 8, 14, 16 are bulk text operations that benefit from fresh context.

**2. Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints. Slower but avoids subagent dispatch overhead.

**Which approach?**
