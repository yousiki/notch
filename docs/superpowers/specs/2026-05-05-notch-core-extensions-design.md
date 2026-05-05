# Notch — Core + Extension System Refactor

**Date:** 2026-05-05
**Status:** Design approved, implementation plan pending
**Scope:** Refactor the forked Boring Notch app into a minimal core + dynamic-bundle extension system. v1.

---

## 1. Goal

Split the current monolithic `boringNotch` app target into:

- A minimal **core** (host app + `NotchKit.framework`) that owns app lifecycle, the notch window/screen plumbing, and an extension API.
- A set of **extensions** — dynamic `.notchext` bundles loaded at runtime — that implement every user-visible feature (Music, Shelf, Calendar, Battery, HUD, Webcam, Live Activities, Tips).

Built-in features ship as extensions inside the host bundle. Third parties can ship extensions independently by dropping a `.notchext` into a known user directory.

## 2. Design constraints (must-honor rules)

These constraints override stylistic preferences and apply to every step of implementation.

### 2.1 Preserve-by-copy, edit minimally

- Every file that survives the refactor moves via `git mv` (preferred, to preserve history) or `cp`. **No re-typing, no Read+rewrite of file contents.**
- Edits to a moved file are limited to the smallest diff that makes it compile in its new location:
  - import changes
  - access-level changes (`internal` → `public` / `open`) on types `NotchKit` must construct
  - `@objc` annotations on types that cross the API boundary
  - removal of code that no longer belongs there (e.g. references to features that have moved to other extensions)
  - replacing direct `Defaults`/`NotificationCenter` cross-feature references with `host.settings`/`host.permissions`/contribution-registration calls
- **No drive-by refactors, renames, formatting changes, or "while I'm here" cleanups.** Behavior preservation > stylistic improvement.
- New code is written only when there is no existing code to repurpose: `NotchKit` API protocols, the extension loader, slot-registration glue, the host's plugin-mount points, and per-extension principal-class entry files (~50 lines each).
- The implementation plan must, for each file, explicitly state: **source path → destination path**, and **the exact list of line-level edits required** post-copy. Any plan step that says "rewrite" or "reimplement" must be justified; the default is `git mv` + minimal edits.
- During implementation, agents must verify post-move file contents match pre-move file contents except for the listed edits (e.g. `git diff --stat` of the move + edit shows only the intended hunks).

### 2.2 XPC-readiness

v1 ships in-process. v2 may move to per-extension XPC for crash isolation. To keep that upgrade tractable:

- All non-view types crossing the `NotchKit` API are `Codable` *and* either Foundation-`@objc` types or `NSSecureCoding`-conforming.
- No shared mutable globals between core and extensions; all communication goes through the explicit `NotchHost` API.
- View contributions return `NSViewController` instances (not raw `NSView` references) so a v2 swap to `NSRemoteView`-hosted controllers is a smaller surgery.
- Results that need to round-trip from the host back to the extension are delivered via completion handlers, not synchronous returns of complex Swift values.

### 2.3 Big-bang scope, single landing

The refactor lands as one coherent change. There is no transitional in-process-legacy-fallback path and no per-feature staged migration.

## 3. Architecture

### 3.1 Repo / build layout

```
Notch.xcworkspace
├── Core/Notch.xcodeproj
│   ├── Notch (host app target)              → boringNotch.app
│   ├── NotchKit (framework target)          → NotchKit.framework
│   └── BoringNotchXPCHelper                 (preserved, unchanged)
├── Extensions/
│   ├── Music/MusicExtension.xcodeproj             → MusicExtension.notchext
│   ├── Shelf/ShelfExtension.xcodeproj             → ShelfExtension.notchext
│   ├── Calendar/CalendarExtension.xcodeproj       → CalendarExtension.notchext
│   ├── Battery/BatteryExtension.xcodeproj         → BatteryExtension.notchext
│   ├── HUD/HUDExtension.xcodeproj                 → HUDExtension.notchext
│   ├── Webcam/WebcamExtension.xcodeproj           → WebcamExtension.notchext
│   ├── LiveActivities/LiveActivitiesExtension.xcodeproj → LiveActivitiesExtension.notchext
│   └── Tips/TipsExtension.xcodeproj               → TipsExtension.notchext
└── mediaremote-adapter/                     (preserved, unchanged)
```

`NotchKit.framework` is embedded in the host and linked weakly by every extension bundle. Each extension project depends on the workspace's `NotchKit` product. Each `.xcodeproj` is independent enough that an extension could later be lifted to its own repo.

### 3.2 Process & loading model

- Single process. All extensions load in-process at app launch.
- Extension is a `.notchext` bundle whose `Info.plist` declares `NSPrincipalClass` conforming to the `@objc` `NotchExtension` protocol from `NotchKit`.
- Loader scans, in order:
  1. `Notch.app/Contents/PlugIns/*.notchext` (built-ins)
  2. `~/Library/Application Support/Notch/Extensions/*.notchext` (user-installed)
- No signature gating in v1. Risk documented in §8.
- Built-in extensions ship via the host's "Copy Files (PlugIns)" build phase, fed from each extension project's product.

### 3.3 Boot sequence

1. `boringNotchApp.init()` constructs `SPUStandardUpdaterController` (unchanged).
2. `AppDelegate.applicationDidFinishLaunching` runs the existing screen / window / lock / drag-detector / onboarding-window setup *first* (preserved verbatim).
3. After the first window is created, `ExtensionHost.shared.start()` is called.
4. `ExtensionLoader` scans the two directories. For each bundle: `Bundle.load()` → instantiate `NSPrincipalClass` → call `activate(host:)`.
5. Inside `activate`, the extension calls `host.register(...)` for every slot/pane/menu/shortcut/permission it contributes. Registrations land in the contribution registry keyed by slot.
6. `ExtensionHost` posts `notchExtensionsDidLoad`. `ContentView` / `SettingsView` / `StatusBarMenu` re-render to pick up contributions.
7. Per-slot lifecycle policy: `.preInstantiated` view controllers are built immediately on first slot use; `.onDemand` are built only when their slot becomes visible.

## 4. `NotchKit` API surface

All new code (nothing existing to copy). Lives in `Core/Notch.xcodeproj` framework target `NotchKit`.

### 4.1 Extension protocol

```swift
@objc public protocol NotchExtension {
    @objc static func make() -> NotchExtension
    @objc var identifier: String { get }              // reverse-DNS, e.g. "com.theboredteam.music"
    @objc var displayName: String { get }
    @objc func activate(host: NotchHost)
    @objc optional func deactivate()
    @objc optional func screenConfigurationChanged()
    @objc optional func screenLocked()
    @objc optional func screenUnlocked()
}
```

### 4.2 `NotchHost`

The only object an extension uses to talk to the core. All registration goes through it.

```swift
@objc public protocol NotchHost {
    func register(tab: NotchTabContribution)
    func register(closedChinItem: NotchClosedChinContribution)
    func register(sneakPeek: NotchSneakPeekContribution)
    func register(expandedItem: NotchExpandedItemContribution)
    func register(hudReplacement: NotchHUDContribution)
    func register(settingsPane: NotchSettingsPaneContribution)
    func register(menuBarItems: [NotchMenuItemContribution])
    func register(onboardingStep: NotchOnboardingContribution)
    func register(keyboardShortcut: NotchKeyboardShortcutContribution)
    func register(permission: NotchPermissionRequest)

    var settings: NotchSettingsStore { get }   // namespaced per extension
    var permissions: NotchPermissionsAPI { get }
    var logger: NotchLogger { get }
}
```

### 4.3 Slot contribution shape

```swift
@objc public final class NotchTabContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let systemImage: String
    @objc public let lifecyclePolicy: NotchSlotLifecycle    // .onDemand | .preInstantiated
    @objc public let makeViewController: () -> NSViewController
}
```

The same shape is used for `NotchClosedChinContribution`, `NotchSneakPeekContribution`, `NotchExpandedItemContribution`, `NotchHUDContribution`, with slot-specific metadata (priority, side, allowed notch states, content-type tag, etc.).

UI contribution rule: extensions return `NSViewController`. SwiftUI views are wrapped via `NSHostingController` on the extension side. The host wraps the controller in `NSViewControllerRepresentable` for SwiftUI composition.

### 4.4 Settings store

```swift
@objc public protocol NotchSettingsStore {
    func setValue(_ value: Any?, forKey key: String)
    func value(forKey key: String) -> Any?
    func observe(key: String, _ handler: @escaping (Any?) -> Void) -> NotchObservation
}
```

Backed by `UserDefaults` with an extension-id prefix. v1 keeps existing `Defaults` keys for migrated features by reading the same keys (see §6 — no migration step).

### 4.5 Permissions API

```swift
@objc public protocol NotchPermissionsAPI {
    func status(for permission: NotchPermissionKind) -> NotchPermissionStatus
    func request(_ permission: NotchPermissionKind, completion: @escaping (NotchPermissionStatus) -> Void)
}
@objc public enum NotchPermissionKind: Int {
    case calendar, reminders, accessibility, camera, microphone, mediaLibrary, fileShelf
}
```

The accessibility case proxies to the existing `BoringNotchXPCHelper` (preserved unchanged).

## 5. Host responsibilities & file disposition

### 5.1 Host (`Notch` target) — files moved via `git mv`

| Source (current path) | Destination | Required edits |
|---|---|---|
| `boringNotch/boringNotchApp.swift` | `Core/Host/boringNotchApp.swift` | Remove direct refs to `MusicManager`, `WebcamManager`, `BatteryStatusViewModel`, `BrightnessManager`, `VolumeManager`, `MediaKeyInterceptor`, `QuickShareService`. Add one `ExtensionHost.shared.start()` call after first window creation. Keep all window / screen / lock / drag-detector / onboarding-window logic verbatim. |
| `boringNotch/BoringViewCoordinator.swift` | `Core/Host/BoringViewCoordinator.swift` | Remove `hudReplacement` observer + `MediaKeyInterceptor` calls (move to HUD extension). Keep notch-state, screen-UUID, sneak-peek/expanded-item dispatch — content for those slots now resolved via the contribution registry. |
| `boringNotch/ContentView.swift` | `Core/Host/ContentView.swift` | Replace hard-coded `NotchHomeView` / `ShelfView` / `WebcamView` / `MusicVisualizer` / `BoringBattery` / `DownloadView` / `OpenNotchHUD` / `InlineHUD` / `LiveActivityModifier` references with iteration over `ExtensionHost.shared.contributions(for: <slot>)`. Keep all layout, animation, shape, gesture, and chin-width logic. |
| `boringNotch/components/Notch/*.swift` (all 6 files) | `Core/Host/Notch/` | Imports only. |
| `boringNotch/components/Tabs/*.swift` | `Core/Host/Tabs/` | `TabSelectionView` reads tab list from extension host instead of fixed enum. |
| `boringNotch/components/Onboarding/*.swift` | `Core/Host/Onboarding/` | `OnboardingView` driver iterates extension-contributed steps in addition to core welcome. Per-feature step files (e.g. `MusicControllerSelectionView.swift`) move to their owning extensions. |
| `boringNotch/components/Settings/{SettingsView,SettingsWindowController,EditPanelView,ListItemPopover,SoftwareUpdater}.swift` | `Core/Host/Settings/` | Shell stays as-is and iterates extension-contributed panes; per-feature section bodies move to their extensions when they are top-level structs (see §5.3). `MusicSlotConfigurationView.swift` is *not* in this row — it moves to MusicExtension (see §6). |
| `boringNotch/menu/StatusBarMenu.swift` | `Core/Host/Menu/StatusBarMenu.swift` | Append extension-contributed menu items after built-in entries. |
| `boringNotch/observers/DragDetector.swift`, `FullscreenMediaDetection.swift` | `Core/Host/Observers/` | Imports only. (`MediaKeyInterceptor` moves to HUD extension.) |
| `boringNotch/managers/NotchSpaceManager.swift`, `ImageService.swift` | `Core/Host/Managers/` | Imports only. |
| `boringNotch/models/{Constants,BoringViewModel,SharingStateManager}.swift` | `Core/Host/Models/` | `Constants.swift`: keep notch-sizing keys + core-feature `Defaults` keys; music/battery-specific keys move with their extensions. `MusicControlButton` and `PlaybackState` move to MusicExtension. |
| `boringNotch/extensions/*.swift` | `Core/Host/Extensions/` | Imports only. |
| `boringNotch/helpers/*.swift` | `Core/Host/Helpers/` (those not moved to extensions) | `AppleScriptHelper`, `MediaChecker` move to MusicExtension. `Clipboard+Content.swift` is currently dead code (no callers in the project) — it stays in `Core/Host/Helpers/` unchanged rather than being relocated. The remaining helpers (`AudioPlayer`, `AppIcons`, `AssociatedObject`, `ApplicationRelauncher`) stay in core. |
| `boringNotch/sizing/matters.swift` | `Core/Host/Sizing/matters.swift` | None. |
| `boringNotch/private/CGSSpace.swift` | `Core/Host/Private/CGSSpace.swift` | None. |
| `boringNotch/utils/Logger.swift` | shared with `NotchKit` | Becomes the backing of `NotchLogger`. |
| `boringNotch/XPCHelperClient/*.swift` | `Core/Host/XPCHelperClient/` | None. Re-exposed to extensions via `NotchPermissionsAPI`. |
| `boringNotch/animations/*.swift` | `Core/Host/Animations/` | None. |
| `boringNotch/Shortcuts/ShortcutConstants.swift` | `Core/Host/Shortcuts/` | Core keeps `toggleNotchOpen`. `toggleSneakPeek` removed (moves to MusicExtension as a registered shortcut). |
| `boringNotch/components/{HoverButton,WhatsNewView,EmptyState,TestView,BottomRoundedRectangle,ProgressIndicator,LottieView,AnimatedFace}.swift` | `Core/Host/Components/` | Imports only. |
| `boringNotch/Localizable.xcstrings` | `Core/Host/Localizable.xcstrings` | All strings stay. Extension-shipped localization is v2. |
| `boringNotch/Assets.xcassets/`, `Info.plist`, `boringNotch.entitlements`, `boring.m4a`, `Preview Content/` | `Core/Host/...` | None. |
| `BoringNotchXPCHelper/`, `mediaremote-adapter/`, `Configuration/`, `updater/` | unchanged paths | None. |

### 5.2 Host new code (written from scratch — small)

- `Core/Host/ExtensionHost.swift` — singleton implementing `NotchHost`; owns the loader and the contribution registry; provides `contributions(for: slot)` lookup.
- `Core/Host/ExtensionLoader.swift` — directory scanning, `Bundle.load()`, principal-class instantiation, `activate(host:)` invocation, error capture.
- Slot-rendering glue inside `ContentView.swift` and `NotchLayout` — the largest host edit: replacing fixed view references with iteration over registered contributions.

### 5.3 SettingsView decomposition rule

`boringNotch/components/Settings/SettingsView.swift` (1,799 lines) is **not rewritten**. It moves verbatim to `Core/Host/Settings/SettingsView.swift`.

- Per-feature section *bodies* are moved to their extensions only when they are already top-level `struct`s (e.g. `MusicSlotConfigurationView.swift` is already extracted — that file moves).
- Sections inlined inside `SettingsView`'s body stay there in v1; the corresponding extension contributes only its non-inline-able controls (e.g., the music-controller selection toggles, the shelf clear-storage button) via `host.register(settingsPane:)`.
- Cosmetic re-extraction of inline sections is deliberately avoided to keep edits small.

### 5.4 `NotchHomeView` note

`boringNotch/components/Notch/NotchHomeView.swift` (578 lines) currently mixes Music presentation (visualizer, controls) and Calendar presentation (event list). Per the no-rewrite rule, the entire file moves verbatim to MusicExtension as the Home tab body. CalendarExtension contributes its tab via the already-separate `BoringCalendar.swift`. If review reveals Calendar UI tightly entangled inside `NotchHomeView`, the smallest possible `git mv` of the offending struct into CalendarExtension is performed — the rest is left alone.

## 6. Per-extension file disposition

Each row: source file → destination extension target. All moves via `git mv`. Edits limited to: imports; `public`/`open` on types `NotchKit` must construct factories with; `@objc` annotations on the principal class; replacing direct `Defaults` / `NotificationCenter` / cross-feature references with `host.settings` / `host.permissions` / contribution-registration calls.

### MusicExtension

| Source | Destination |
|---|---|
| `boringNotch/managers/MusicManager.swift` | `Extensions/Music/Sources/MusicManager.swift` |
| `boringNotch/MediaControllers/MediaControllerProtocol.swift` | `Extensions/Music/Sources/MediaControllerProtocol.swift` |
| `boringNotch/MediaControllers/AppleMusicController.swift` | `Extensions/Music/Sources/AppleMusicController.swift` |
| `boringNotch/MediaControllers/SpotifyController.swift` | `Extensions/Music/Sources/SpotifyController.swift` |
| `boringNotch/MediaControllers/NowPlayingController.swift` | `Extensions/Music/Sources/NowPlayingController.swift` |
| `boringNotch/MediaControllers/YouTube Music Controller/*.swift` (4 files) | `Extensions/Music/Sources/YouTubeMusic/` |
| `boringNotch/components/Music/MusicVisualizer.swift` | `Extensions/Music/Sources/Views/MusicVisualizer.swift` |
| `boringNotch/components/Music/LottieAnimationView.swift` | `Extensions/Music/Sources/Views/LottieAnimationView.swift` |
| `boringNotch/components/Notch/NotchHomeView.swift` | `Extensions/Music/Sources/Views/NotchHomeView.swift` |
| `boringNotch/components/Settings/MusicSlotConfigurationView.swift` | `Extensions/Music/Sources/Settings/MusicSlotConfigurationView.swift` |
| `boringNotch/components/Onboarding/MusicControllerSelectionView.swift` | `Extensions/Music/Sources/Onboarding/MusicControllerSelectionView.swift` |
| `boringNotch/helpers/MediaChecker.swift`, `AppleScriptHelper.swift` | `Extensions/Music/Sources/Helpers/` |
| `boringNotch/models/MusicControlButton.swift`, `PlaybackState.swift` | `Extensions/Music/Sources/Models/` |
| **New (~50 lines):** principal class | `Extensions/Music/Sources/MusicExtension.swift` |

The `toggleSneakPeek` keyboard-shortcut key is deleted from the host's `ShortcutConstants.swift` and re-registered via `host.register(keyboardShortcut:)` in MusicExtension.

### ShelfExtension

| Source | Destination |
|---|---|
| `boringNotch/components/Shelf/**/*.swift` (entire subtree, 18 files: Models, ViewModels, Services, Views) | `Extensions/Shelf/Sources/` (preserve internal subdirs verbatim) |
| `boringNotch/extensions/URL+SecurityScoped.swift` | `Extensions/Shelf/Sources/Extensions/URL+SecurityScoped.swift` (verified: only used by Shelf code) |
| `boringNotch/extensions/NSItemProvider+LoadHelpers.swift` | `Extensions/Shelf/Sources/Extensions/NSItemProvider+LoadHelpers.swift` (verified: only used by `Shelf/Services/QuickShareService.swift` and `Shelf/Services/ShelfDropService.swift`) |
| **New:** principal class | `Extensions/Shelf/Sources/ShelfExtension.swift` |

### CalendarExtension

| Source | Destination |
|---|---|
| `boringNotch/managers/CalendarManager.swift` | `Extensions/Calendar/Sources/CalendarManager.swift` |
| `boringNotch/Providers/CalendarServiceProviding.swift` | `Extensions/Calendar/Sources/CalendarServiceProviding.swift` |
| `boringNotch/models/CalendarModel.swift` | `Extensions/Calendar/Sources/CalendarModel.swift` |
| `boringNotch/models/EventModel.swift` | `Extensions/Calendar/Sources/EventModel.swift` |
| `boringNotch/components/Calendar/BoringCalendar.swift` | `Extensions/Calendar/Sources/Views/BoringCalendar.swift` |
| **New:** principal class | `Extensions/Calendar/Sources/CalendarExtension.swift` |

### BatteryExtension

| Source | Destination |
|---|---|
| `boringNotch/managers/BatteryActivityManager.swift` | `Extensions/Battery/Sources/BatteryActivityManager.swift` |
| `boringNotch/models/BatteryStatusViewModel.swift` | `Extensions/Battery/Sources/BatteryStatusViewModel.swift` |
| `boringNotch/components/Live activities/BoringBattery.swift` | `Extensions/Battery/Sources/Views/BoringBattery.swift` |
| **New:** principal class | `Extensions/Battery/Sources/BatteryExtension.swift` |

### HUDExtension

| Source | Destination |
|---|---|
| `boringNotch/managers/VolumeManager.swift` | `Extensions/HUD/Sources/VolumeManager.swift` |
| `boringNotch/managers/BrightnessManager.swift` | `Extensions/HUD/Sources/BrightnessManager.swift` |
| `boringNotch/observers/MediaKeyInterceptor.swift` | `Extensions/HUD/Sources/MediaKeyInterceptor.swift` |
| `boringNotch/components/Live activities/InlineHUD.swift` | `Extensions/HUD/Sources/Views/InlineHUD.swift` |
| `boringNotch/components/Live activities/OpenNotchHUD.swift` | `Extensions/HUD/Sources/Views/OpenNotchHUD.swift` |
| `boringNotch/components/Live activities/SystemEventIndicatorModifier.swift` | `Extensions/HUD/Sources/Views/SystemEventIndicatorModifier.swift` |
| **New:** principal class (uses `NotchPermissionsAPI` for accessibility, which still proxies to the existing XPC helper) | `Extensions/HUD/Sources/HUDExtension.swift` |

### WebcamExtension

| Source | Destination |
|---|---|
| `boringNotch/managers/WebcamManager.swift` | `Extensions/Webcam/Sources/WebcamManager.swift` |
| `boringNotch/components/Webcam/WebcamView.swift` | `Extensions/Webcam/Sources/Views/WebcamView.swift` |
| **New:** principal class | `Extensions/Webcam/Sources/WebcamExtension.swift` |

### LiveActivitiesExtension

| Source | Destination |
|---|---|
| `boringNotch/components/Live activities/DownloadView.swift` | `Extensions/LiveActivities/Sources/Views/DownloadView.swift` |
| `boringNotch/components/Live activities/MarqueeTextView.swift` | `Extensions/LiveActivities/Sources/Views/MarqueeTextView.swift` |
| `boringNotch/components/Live activities/LiveActivityModifier.swift` | `Extensions/LiveActivities/Sources/Views/LiveActivityModifier.swift` |
| **New:** principal class | `Extensions/LiveActivities/Sources/LiveActivitiesExtension.swift` |

### TipsExtension

| Source | Destination |
|---|---|
| `boringNotch/components/Tips/TipStore.swift` | `Extensions/Tips/Sources/TipStore.swift` |
| **New:** principal class | `Extensions/Tips/Sources/TipsExtension.swift` |

## 7. Data flow & error handling

### 7.1 Slot rendering

- Host's `ContentView` looks up registered contributions for `(slot, currentNotchState, currentScreen)` and asks the host for an `NSViewController` for each. Wrapping happens via `NSViewControllerRepresentable` so SwiftUI can host them.
- Sneak-peek and expanded-item dispatch: `BoringViewCoordinator` keeps its existing `toggleSneakPeek` / `toggleExpandingView` API, but instead of switch-on-`SneakContentType` view rendering, it asks the registry "which extension owns this kind?" and renders that extension's contributed view. The `SneakContentType` enum stays in core as the public taxonomy v1 ships.
- Settings: `SettingsView` keeps its sidebar enum (`SettingsEnum`); the `extensions` case iterates extension-contributed panes. Per-feature panes already in the sidebar (general, charge, download, mediaPlayback, hud, shelf) keep their cases for v1; the body of each is re-wired to render the contributed pane's view.
- Menu bar: built-ins (Settings / Updates / Restart / Quit) render first, then a `Divider`, then iterate extension-contributed entries.

### 7.2 Persistence / migration

Existing `Defaults` keys are preserved verbatim — extensions read the same keys they read today, just through `host.settings` (which is `UserDefaults` underneath). No migration step. Users upgrading from a pre-refactor build see no setting reset.

### 7.3 Error handling

| Failure | Handling |
|---|---|
| Bundle load failure | Log, skip extension, continue. Surface in Settings → Extensions a list of "failed to load" entries with the underlying `Error`. |
| Principal class missing or wrong protocol conformance | Same as bundle load failure. |
| Synchronous exception inside `activate(host:)` | Caught with Obj-C `@try` so a misbehaving extension doesn't take down launch. Best-effort, not crash isolation. |
| Permission denied | Returned as `NotchPermissionStatus.denied`. Extension decides degraded UX. No core fallback. |
| Pure-Swift `fatalError` / deadlock / memory corruption inside an extension | Takes down the host (no v1 mitigation). v2 XPC-isolation addresses this. |

## 8. Risks (accepted for v1)

- **No code-signing on extensions.** Loading arbitrary code into a process holding accessibility / camera / mic / calendar entitlements is an attack surface. Mitigated only by the user directory being inside the user's home (not world-writable). v2 adds signature gating.
- **No process isolation.** A pure-Swift `fatalError`, deadlock, or memory corruption in any extension takes down the host. Mitigation: best-effort `@objc` exception catching at API entry points; no Swift-level safety net.
- **`@objc` API ceiling.** New API surfaces requiring Swift-only types (generics, value types, async sequences) cannot be added without redesign.
- **Big-bang regression risk.** Mitigated by the §2.1 `git mv`-only constraint: post-move diffs are small and reviewable, behavior is byte-identical except for the explicit edits.
- **Localization regression.** Per-feature `Localizable.xcstrings` entries stay in the host file in v1.

## 9. Testing & verification

- `NotchKit` gets a tests target with unit tests on the contribution registry, settings-store namespacing, and permission-status round-trip.
- A `MockExtension.notchext` test fixture registers one of every slot type to exercise the loader and contribution-iteration paths.
- Existing tests (if any) move with their files via `git mv`. New per-feature tests are not required by this refactor.
- **Manual verification gate before merge:** dev runs the host with all built-in `.notchext`s embedded and exercises every flow the upstream README screenshots demonstrate — music live activity, shelf drop + AirDrop, calendar tab, battery notifications, HUD replacement (volume / brightness / backlight), webcam mirror, sneak-peek, expanded-item, onboarding (first-launch + permissions).

## 10. Scope summary

### In scope (v1 — must ship)

- `NotchKit` API: extension protocol, slot registration, per-slot lifecycle, settings store, permissions, keyboard shortcuts, menubar contributions, onboarding contributions.
- Extension loader scanning `Notch.app/Contents/PlugIns/` + `~/Library/Application Support/Notch/Extensions/`.
- All current features rewritten as extensions (Music, Shelf, Calendar, Battery, HUD, Webcam, Live Activities, Tips).
- Settings window aggregates extension-contributed panes.
- Onboarding aggregates extension-contributed permission steps.
- API designed XPC-ready (`Codable`/`NSSecureCoding` boundary, `NSViewController`-based UI contribution).

### Deferred to v2

- Inter-extension messaging bus
- Signature gating / per-extension trust prompts
- Hot-reload of extensions without app restart
- Extension marketplace / browse-and-install UI
- Per-extension crash isolation (XPC)
- Extension-shipped localization
- Themable / skinnable notch surface

### Out of scope

- WASM plugins
- Inter-extension version constraints / dependencies
