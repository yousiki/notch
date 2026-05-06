# Notch Core+Extensions Refactor — Handoff (Phase A complete, mechanical)

**Handoff date:** 2026-05-06
**Branch:** `refactor/core-extensions` (12 commits ahead of `main`)
**Working directory:** `/Users/yousiki/Documents/notch`
**Workspace:** `Notch.xcworkspace`

## What this is

A large refactor turning the forked `boringNotch` macOS app into a minimal core (host app + `NotchKit.framework`) plus dynamic `.notchext` plug-in bundles loaded at runtime. All current features (Music, Shelf, Calendar, Battery, HUD, Webcam, Live Activities, Tips) will eventually ship as built-in extensions.

**Authoritative documents:**
- Spec: `docs/superpowers/specs/2026-05-05-notch-core-extensions-design.md`
- Plan: `docs/superpowers/plans/2026-05-05-notch-core-extensions.md`

The plan is structured in three phases. **Phase A is mechanically complete; A18 manual verification is pending. Phase B and C have not started.**

## Branch state

Twelve commits on `refactor/core-extensions`, in order:

```
7aea959 Move boringNotch.xcodeproj under Core/, add workspace
e83a9cb Move host source under Core/Host/ via git mv (no content changes)
5ba1156 Add NotchKit framework target with @rpath install name
dc709ce Fix repo-root paths in pbxproj after Core/ move; clean up stray script
e69e177 Define NotchKit public API: NotchExtension, NotchHost, contributions, settings/permissions/logger/services
c537489 Implement host's NotchHost adapters and ExtensionLoader
953429e Disable library validation; add Embed Plug-ins build phase
ed792ae Add TipsExtension.xcodeproj scaffold (no source yet)
b0d9241 TipsExtension principal class + move TipStore.swift
7ae36d2 Boot ExtensionHost from boringNotchApp.applicationDidFinishLaunching
4fa649d CI lint: forbid NotchKit embedding inside .notchext bundles
91d24bf Untrack .claude/settings.json and ignore workspace state
```

## Verified end state of Phase A

Verified via `xcodebuild` — final state:

- `xcodebuild -workspace Notch.xcworkspace -scheme boringNotch ... build` → **BUILD SUCCEEDED**
- `boringNotch.app/Contents/Frameworks/` contains `NotchKit.framework` (alongside Lottie, MediaRemoteAdapter, Sparkle)
- `boringNotch.app/Contents/PlugIns/` contains `TipsExtension.notchext`
- `scripts/check_no_notchkit_embed.sh "$APP"` → `OK: no extension embeds NotchKit.framework`
- `NSPrincipalClass = "TipsExtension.TipsExtension"` in the embedded bundle's Info.plist
- Hardened Runtime enabled; `com.apple.security.cs.disable-library-validation = true` in entitlements

**What's NOT verified yet** (this is what the next session needs to do first):
- Has `Bundle.load()` + `principalClass` instantiation actually worked at runtime?
- Is there exactly one `NotchKit.framework` in the dyld image graph (no duplication)?
- Does the user-installed extension path (`~/Library/Application Support/Notch/Extensions/`) load?

## Repo / build layout (current state)

```
Notch.xcworkspace/                            # workspace
├── Core/
│   ├── Notch.xcodeproj/                      # host project (was boringNotch.xcodeproj)
│   ├── Host/                                 # host source (was boringNotch/...)
│   │   ├── boringNotchApp.swift              # @main, AppDelegate
│   │   ├── BoringViewCoordinator.swift       # global coordinator (still uses SneakContentType enum — Phase B replaces)
│   │   ├── ContentView.swift                 # main view (still hard-codes feature views — Phase B replaces with registry iteration)
│   │   ├── ExtensionHost.swift               # NEW: NotchHost impl, contribution registry
│   │   ├── ExtensionLoader.swift             # NEW: scans + dlopens .notchext bundles
│   │   ├── ObjCExceptionCatcher.{h,m}        # NEW: best-effort NSException trap during activate
│   │   ├── Notch-Bridging-Header.h           # NEW
│   │   ├── Logger/HostLogger.swift           # NEW: NotchLogger backing
│   │   ├── Settings/HostSettingsStore.swift  # NEW: NotchSettingsStore backing
│   │   ├── Permissions/HostPermissionsAPI.swift # NEW: NotchPermissionsAPI backing
│   │   ├── Components/                       # ⚠️ contains feature subtrees due to A2 over-move (see below)
│   │   ├── MediaControllers/, Providers/, Metal/, Onboarding/, Managers/, Models/, Helpers/, Observers/, Settings/
│   │   └── (everything else from old boringNotch/)
│   └── NotchKit/                             # NEW framework
│       ├── Resources/Info.plist
│       └── Sources/
│           ├── NotchExtension.swift          # principal-class @objc protocol
│           ├── NotchHost.swift               # host API @objc protocol
│           ├── NotchSlotLifecycle.swift
│           ├── Contributions/                # 11 contribution types (Tab, HomeFragment, ClosedChin, SneakPeek, ExpandedItem, HUD, SettingsPane, MenuItem, Onboarding, KeyboardShortcut, PermissionRequest)
│           ├── Settings/NotchSettingsStore.swift
│           ├── Permissions/{NotchPermissionKind,NotchPermissionsAPI}.swift
│           ├── Logger/NotchLogger.swift
│           ├── Observation/NotchObservation.swift
│           ├── Services/{NotchNotchStateHost,NotchScreenHost,NotchCoordinatorHost}.swift
│           └── Version/NotchKitVersion.swift
├── Extensions/
│   └── Tips/
│       ├── TipsExtension.xcodeproj
│       ├── Resources/Info.plist
│       └── Sources/
│           ├── TipsExtension.swift           # NEW: principal class, registers a tab contribution
│           └── TipStore.swift                # ⚠️ moved here but excluded from Compile Sources (depends on host-only AppIcon)
├── BoringNotchXPCHelper/                     # unchanged at repo root
├── mediaremote-adapter/                      # unchanged at repo root
├── Configuration/                            # unchanged
├── updater/                                  # unchanged
├── scripts/check_no_notchkit_embed.sh        # NEW: CI lint
└── docs/superpowers/{specs,plans,handoffs}/
```

## Critical deviations from the plan (read before proceeding)

### Deviation 1 — A2 over-moved feature files

**Plan said:** move only host-bound files from `boringNotch/...` to `Core/Host/...`; leave feature files at `boringNotch/components/<Feature>/` etc. for Phase C migration.

**What happened:** the implementer moved *everything* under `boringNotch/` into `Core/Host/`. The end-state of the refactor is unchanged (Phase C still ends with feature files in `Extensions/<Feature>/`), but the intermediate source paths shifted.

**Implication for Phase C tasks:** every `git mv boringNotch/<path>` in the plan needs translation to `git mv Core/Host/<corresponding-path>`. Specifically:

| Plan's source path | Actual current path |
|---|---|
| `boringNotch/components/<Feature>/...` | `Core/Host/Components/<Feature>/...` (Calendar, Live activities, Music, Shelf, Tips, Webcam) |
| `boringNotch/MediaControllers/...` | `Core/Host/MediaControllers/...` |
| `boringNotch/Providers/CalendarServiceProviding.swift` | `Core/Host/Providers/CalendarServiceProviding.swift` |
| `boringNotch/managers/MusicManager.swift` etc. | `Core/Host/Managers/MusicManager.swift` etc. (all 6 feature managers: Battery, Brightness, Calendar, Music, Volume, Webcam) |
| `boringNotch/observers/MediaKeyInterceptor.swift` | `Core/Host/Observers/MediaKeyInterceptor.swift` |
| `boringNotch/helpers/{MediaChecker,AppleScriptHelper}.swift` | `Core/Host/Helpers/{MediaChecker,AppleScriptHelper}.swift` |
| `boringNotch/components/Onboarding/MusicControllerSelectionView.swift` | `Core/Host/Onboarding/MusicControllerSelectionView.swift` |
| `boringNotch/components/Settings/MusicSlotConfigurationView.swift` | `Core/Host/Settings/MusicSlotConfigurationView.swift` |
| `boringNotch/models/{CalendarModel,EventModel,MusicControlButton,PlaybackState,BatteryStatusViewModel}.swift` | `Core/Host/Models/{...}.swift` |
| `boringNotch/metal/visualizer.metal` | `Core/Host/Metal/visualizer.metal` |
| `boringNotch/extensions/{URL+SecurityScoped,NSItemProvider+LoadHelpers}.swift` | `Core/Host/Extensions/{...}.swift` |

**The original plan document was not updated** to reflect this. When dispatching Phase C tasks, the controller must mention this translation explicitly.

### Deviation 2 — `TipStore.swift` not yet in TipsExtension Compile Sources

`Extensions/Tips/Sources/TipStore.swift` exists as a file reference in `TipsExtension.xcodeproj` but is **not** in the target's Compile Sources phase. It calls `AppIcon(for:)` (defined in `Core/Host/Helpers/AppIcons.swift`), which lives only in the host module. Adding it caused `cannot find 'AppIcon' in scope`.

**Phase C resolution options:**
- Provide an `AppIconService` via `NotchHost.service(of: "app-icons")` — recommended
- Move `AppIcons.swift` into `NotchKit` as a public utility — alternative
- Inline the icon name directly in TipStore.swift — minimal-edit fallback

The Phase C plan tasks for TipsExtension don't currently address this. When migrating Tips fully (it has no dedicated Phase C task; it was the Phase A pilot), the implementer must pick one of the above and document the choice.

### Deviation 3 — Cross-project dependency uses run-script + target dependency, not PBXContainerItemProxy

The plan said "add `TipsExtension` as a target dependency of the host". The Ruby `xcodeproj` gem doesn't expose cross-project `PBXContainerItemProxy` cleanly. Implementer used:

1. **Cross-project target dependency** (added via gem) — guarantees TipsExtension builds before boringNotch in the workspace.
2. **"Build Built-in Extensions" run-script phase** on boringNotch — verifies `TipsExtension.notchext` is present in `BUILT_PRODUCTS_DIR`. (Earlier version of this script invoked nested xcodebuild but caused DB locking; current version is a presence check only.)
3. **Embed Plug-ins phase** references `BUILT_PRODUCTS_DIR/TipsExtension.notchext` with `CodeSignOnCopy`.
4. **`ENABLE_USER_SCRIPT_SANDBOXING = NO`** set on boringNotch target so the run-script can read `$BUILT_PRODUCTS_DIR`.

**Implication for Phase C:** every new extension (Music, Shelf, Calendar, Battery, HUD, Webcam, LiveActivities) follows the same pattern. Replicate the wiring from `commit ed792ae` (the Tips scaffold).

### Deviation 4 — Sandbox + plug-in loading

The host has `com.apple.security.app-sandbox = true` *and* now also `com.apple.security.cs.disable-library-validation = true`. These can co-exist, but the App Sandbox restricts file-system access. The user-installed extension directory `~/Library/Application Support/Notch/Extensions/` is **not** in the host's sandbox container — it's in the user's home Application Support, which sandboxed apps can't read by default.

If A18 step 5 (third-party extension load) fails with a sandbox error, the host needs a sandbox extension to read that directory. Options:
- Use a security-scoped bookmark stored in user defaults that the user grants on first run
- Drop the user-extensions directory inside the host's sandbox container (e.g., `~/Library/Containers/com.theboredteam.boringNotch/Data/Library/Application Support/Notch/Extensions/`)
- Disable App Sandbox

**This was flagged as a concern but not addressed in Phase A.** Phase A only tested the built-in (`Contents/PlugIns/`) path. Treat user-installed loading as a known unknown.

## Tooling notes

- **Ruby `xcodeproj` gem** is installed at `--user-install` scope. All pbxproj manipulation in Phase A used it. Pattern:
  ```ruby
  require 'xcodeproj'
  project = Xcodeproj::Project.open('Core/Notch.xcodeproj')
  target = project.targets.find { |t| t.name == 'boringNotch' }
  # ... mutate ...
  project.save
  ```
  The gem is not always reliable for cross-project references; for those, prefer run-script + target dependency (see Deviation 3).
- **Source tree convention:** when adding files via the gem, use `source_tree = 'SOURCE_ROOT'` and an explicit path relative to the .xcodeproj's parent (e.g., `Host/foo.swift` from `Core/Notch.xcodeproj`, or `Sources/foo.swift` from `Extensions/Tips/TipsExtension.xcodeproj`). Do **not** use the gem's default `source_tree = '<group>'` — earlier task surfaced that it resolves incorrectly.
- **Xcodebuild flags for non-signing local builds:** `CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`.
- **SourceKit stale-index errors** ("No such module 'NotchKit'", "No such module 'Defaults'", "Cannot find type 'NotchHost'") have appeared after every gem-driven pbxproj edit. They are **not** real compile errors — `xcodebuild` is consistently green. Clear with `pkill -9 sourcekit-lsp` then restart Xcode. The Xcode-resident agent should expect these and ignore them; trust `xcodebuild` output.

## Pending work

### Immediate next step: A18 — runtime verification

The user is moving to a Claude Code session inside Xcode for this. The Xcode-resident agent should:

1. **Restart SourceKit** (`pkill -9 sourcekit-lsp`), confirm the IDE shows no remaining false-positive module errors. If diagnostics persist after restart, treat the actual build as authoritative.
2. **Build & run** the `boringNotch` scheme. Expected: app launches normally; existing notch UI works as before (no feature has actually moved to its extension yet — Phase C does that).
3. **Verify in lldb (Debug → Pause):**
   ```
   (lldb) image list NotchKit
   ```
   Must show **exactly one** entry (path under `boringNotch.app/Contents/Frameworks/NotchKit.framework/...`). Two entries means TipsExtension is loading its own copy of NotchKit — investigate target's `OTHER_LDFLAGS` and runpath.
   ```
   (lldb) po (id)[ExtensionHost shared].tabs
   ```
   Must show one `NotchTabContribution` with identifier `"com.theboredteam.notch.tips.tab"`. Empty array means the bundle didn't load or principalClass instantiation failed; check the Xcode console for `ExtensionLoader` failure messages.
4. **Tips tab will NOT appear in the UI yet.** That's expected — Phase A only proves the loader works. Phase B switches `ContentView` from hard-coded enum-based rendering to registry-iteration, which makes the Tips tab visible.
5. **(Optional) third-party load test:** copy the embedded `TipsExtension.notchext` to `~/Library/Application Support/Notch/Extensions/`, ad-hoc re-sign with `codesign --force --sign -`, relaunch. `[ExtensionHost shared].tabs` should now have **two** entries. If the load fails with a sandbox error, that's Deviation 4 manifesting — flag it but don't block on it.

### After A18 passes: Phase B (B1-B7)

Goal: the Tips tab actually shows up in the notch because `ContentView` now reads from the registry. Plan tasks B1-B7 are detailed in `docs/superpowers/plans/2026-05-05-notch-core-extensions.md`. Highlights:

- **B1:** Implement `NotchStateServiceAdapter`, `ScreenServiceAdapter`, `CoordinatorServiceAdapter` in `Core/Host/Services/` — concrete `NSObject` classes that wrap `BoringViewModel` / `BoringViewCoordinator` and expose them via the `@objc` host-service protocols defined in NotchKit.
- **B2 (host edit, non-verbatim):** Replace `BoringViewCoordinator`'s `SneakContentType` enum (lines 13-21) with `String`-keyed dispatch. `toggleSneakPeek(type: SneakContentType, …)` → `toggleSneakPeek(kind: String, …)`. Same for `toggleExpandingView`. Update all callers in `Core/Host/...`. Add `currentTabIdentifier: String` published property; make `currentView: NotchViews` a thin wrapper that derives from it.
- **B3:** In `ExtensionHost.start()`, register the service factories (`registerService(kind: "notch-state") { … }` etc.) so `host.service(of: "notch-state")` returns a working adapter when extensions ask.
- **B4 (host edit, non-verbatim):** Replace `ContentView`'s hard-coded `MusicVisualizer` / `BoringBattery` / `DownloadView` / `OpenNotchHUD` / `InlineHUD` / `LiveActivityModifier` / `WebcamView` / `NotchHomeView` / `ShelfView` / `BoringCalendar` references with iteration over `ExtensionHost.shared.<slot>`. Helper view added at file bottom: `ContributionViewControllerHost: NSViewControllerRepresentable`.
- **B5:** Replace `NotchHomeView.mainContent`'s body with iteration over `ExtensionHost.shared.homeFragments`. The composing struct stays at `Core/Host/Notch/NotchHomeView.swift`. Per-feature subviews (`MusicPlayerView`, `CalendarView`, `CameraPreviewView`) stay in the file as dead code until Phase C migrates them.
- **B6:** Settings `extensions` case body iterates `ExtensionHost.shared.settingsPanes`. Status bar menu appends `ExtensionHost.shared.menuBarItems` after built-ins.
- **B7:** Manual verification — Tips tab visible in notch UI.

### Then: Phase C (C1-C8) — feature migrations

In order of risk (least-risky first):
1. **C1 Webcam** (single manager, single view, fragment to home)
2. **C2 Battery** (live activity + sneak-peek + expanded-item kinds)
3. **C3 Calendar** (tab + EventKit permission flow — exercises permissions API end-to-end)
4. **C4 LiveActivities** (download + marquee + modifier; mostly view-only)
5. **C5 HUD** (volume + brightness + media-key interceptor; exercises XPC accessibility helper)
6. **C6 Shelf** (largest single feature; sustained state, multiple services, AirDrop)
7. **C7 Music** (last; multiple controllers, NotchHomeView fragment, onboarding step, keyboard shortcut)
8. **C8 cleanup** — verify no Swift remains in `Core/Host/Components/<Feature>/` etc.

For each Phase C task: copy the TipsExtension scaffold pattern (xcodeproj, Info.plist, principal class, run-script + target-dependency wiring), then `git mv` the feature's source files from their current `Core/Host/<paths>` (per Deviation 1) to `Extensions/<Feature>/Sources/...`. Apply minimal edits per the plan's per-task tables.

The recurring code pattern in each extension's principal class:
```swift
@objc(<Feature>Extension)
public final class <Feature>Extension: NSObject, NotchExtension {
    @objc public static func make() -> NotchExtension { <Feature>Extension() }
    @objc public var identifier: String { "com.theboredteam.notch.<feature>" }
    @objc public var displayName: String { "<Feature>" }
    @objc public func activate(host: NotchHost) {
        host.register(...)  // tab / fragment / closed-chin / sneak-peek / expanded-item / etc.
        // Optionally: host.permissions.request(...) for permissions
    }
}
```

UI views inside an extension that need notch-state observe via:
```swift
private final class NotchStateBridge: ObservableObject {
    @Published var notchState: NotchOpenState = .closed
    private var token: NotchObservation?
    init(host: NotchHost) {
        guard let svc = host.service(of: "notch-state") as? NotchNotchStateHost else { return }
        notchState = svc.notchState
        token = svc.observeNotchState { [weak self] s in
            DispatchQueue.main.async { self?.notchState = s }
        }
    }
}
```
This pattern recurs in every extension; consider creating `Extensions/_Shared/NotchStateBridge.swift` on the first migration that needs it (the plan suggests Webcam in C1) and reusing.

## Constraints carried forward

- **Preserve-by-copy.** Files that survive the refactor move via `git mv`; edits are minimal (imports, access modifiers, `@objc` annotations, deletions, replacing direct `Defaults`/`NotificationCenter` cross-feature references with `host.service(of:)` calls). No re-typing of file contents.
- **No drive-by refactors, renames, formatting changes.**
- **Big-bang single PR.** All three phases land together. Internal commits are sequenced by phase so risk surfaces early in review.
- **XPC-readiness:** all `NotchKit` API types crossing the bundle boundary use `@convention(block)` for closures and stick to Foundation/`@objc`-bridgeable types. v2 may move extensions to XPC for crash isolation; v1 design must not foreclose that path.
- **Don't commit `.claude/`** — already in `.gitignore`.
- **Don't commit Ruby helper scripts** — delete them after use.

## When in doubt

- Read `docs/superpowers/specs/2026-05-05-notch-core-extensions-design.md` for design intent and risk acceptance.
- Read `docs/superpowers/plans/2026-05-05-notch-core-extensions.md` for per-task details (apply Deviation 1's path translation when reading Phase C tasks).
- Trust `xcodebuild` over SourceKit/IDE diagnostics.
- Use the `superpowers:subagent-driven-development` skill to dispatch one subagent per task, with two-stage review (spec compliance, then code quality) per task. Phase A skipped code-quality review for tasks A1/A2 (file-rename only); Phase B/C tasks have real code and should run both reviews.
- Use `superpowers:executing-plans` if subagent-driven gets too noisy.
- If anything is genuinely ambiguous, ask the user before continuing.
