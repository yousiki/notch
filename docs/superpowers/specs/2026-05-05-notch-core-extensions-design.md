# Notch — Core + Extension System Refactor

> **Note (2026-05-06, post-Capsule-rebrand):** This design was authored BEFORE the boringNotch → Capsule rebrand. File paths (`Core/NotchKit/`, `Core/Notch.xcodeproj`, `Notch.xcworkspace`), type names (`NotchKit`, `NotchHost`, `NotchExtension`, `Notch*Contribution`, …), and bundle IDs in this document are historical. The post-rebrand equivalents are `Core/CapsuleKit/`, `Core/Capsule.xcodeproj`, `Capsule.xcworkspace`, and the `Capsule*` / `CapsuleKit` symbols. The rebrand plan is at `docs/superpowers/plans/2026-05-06-capsule-rebrand.md`.

**Date:** 2026-05-05
**Status:** Design approved, implementation plan pending
**Scope:** Refactor the forked Boring Notch app into a minimal core + dynamic-bundle extension system. v1.

---

## 1. Goal

Split the current monolithic `boringNotch` app target into:

- A minimal **core** (host app + `NotchKit.framework`) that owns app lifecycle, the notch window/screen plumbing, and an extension API.
- A set of **extensions** — dynamic `.capsule` bundles loaded at runtime — that implement every user-visible feature (Music, Shelf, Calendar, Battery, HUD, Webcam, Live Activities, Tips).

Built-in features ship as extensions inside the host bundle. Third parties can ship extensions independently by dropping a `.capsule` into a known user directory.

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
- No shared mutable globals between core and extensions; all *cross-bundle* communication goes through the explicit `NotchHost` API and the host-services protocols defined in §4.6. Within an extension's own bundle, the existing singleton patterns (`MusicManager.shared`, `WebcamManager.shared`, etc.) are preserved unchanged — they're just no longer reachable from the host or other extensions.
- View contributions return `NSViewController` instances (not raw `NSView` references) so a v2 swap to `NSRemoteView`-hosted controllers is a smaller surgery.
- Results that need to round-trip from the host back to the extension are delivered via completion handlers, not synchronous returns of complex Swift values.
- Factory closures crossing the `@objc` boundary are stored as `@convention(block)` blocks (Obj-C-compatible block ABI), not arbitrary Swift function values. See §4.3.

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
│   ├── Music/MusicExtension.xcodeproj             → MusicExtension.capsule
│   ├── Shelf/ShelfExtension.xcodeproj             → ShelfExtension.capsule
│   ├── Calendar/CalendarExtension.xcodeproj       → CalendarExtension.capsule
│   ├── Battery/BatteryExtension.xcodeproj         → BatteryExtension.capsule
│   ├── HUD/HUDExtension.xcodeproj                 → HUDExtension.capsule
│   ├── Webcam/WebcamExtension.xcodeproj           → WebcamExtension.capsule
│   ├── LiveActivities/LiveActivitiesExtension.xcodeproj → LiveActivitiesExtension.capsule
│   └── Tips/TipsExtension.xcodeproj               → TipsExtension.capsule
└── mediaremote-adapter/                     (preserved, unchanged)
```

`NotchKit.framework` is embedded in the host bundle (`boringNotch.app/Contents/Frameworks/NotchKit.framework`). Every extension links it as a regular dynamic dependency but **does not embed it**. The shared install name + `@rpath` rules in §3.4 ensure the dyld loader resolves the extension's NotchKit dependency to the host's single embedded image, so all `@objc` protocol identities are shared. Each `.xcodeproj` is independent enough that an extension could later be lifted to its own repo.

### 3.2 Process & loading model

- Single process. All extensions load in-process at app launch.
- Extension is a `.capsule` bundle whose `Info.plist` declares `NSPrincipalClass` conforming to the `@objc` `NotchExtension` protocol from `NotchKit`.
- Loader scans, in order:
  1. `Notch.app/Contents/PlugIns/*.capsule` (built-ins)
  2. `~/Library/Application Support/Capsule/Extensions/*.capsule` (user-installed)
- No in-app signature gating in v1; loading is allowed for any code-signed bundle the OS lets through (see §3.4 for the entitlement story). Risk documented in §8.
- Built-in extensions ship via the host's "Copy Files (PlugIns)" build phase with **Code Sign on Copy** enabled, fed from each extension project's product. Build dependency: host target depends on every extension target so they build first.

### 3.4 Code-signing & loading policy

The host today has accessibility, camera, mic, and calendar entitlements. Apple's Hardened Runtime enables library validation by default, which forbids loading code unless it is Apple-signed or shares the host's Team ID. To allow third-party `.capsule` bundles dropped into `~/Library/Application Support/Capsule/Extensions/`, the host must opt out of library validation:

- Host adds the `com.apple.security.cs.disable-library-validation` entitlement.
- Host keeps Hardened Runtime enabled (a hard requirement for the entitlement to be respected).
- Built-in extensions are signed with the host's Team ID at build time (Code Sign on Copy in the embed phase).
- User-installed extensions may be signed with any Team ID (or ad-hoc) and will load. v1 explicitly accepts the security tradeoff.
- v2 plans: in-app per-extension trust prompts on first load, persisted; optional "developer mode" flag that gates the disable-library-validation behavior.

**dyld / framework deduplication rule (must be enforced by every extension's build settings):**

- `NotchKit.framework`'s install name is `@rpath/NotchKit.framework/Versions/A/NotchKit`.
- Host's `LD_RUNPATH_SEARCH_PATHS` includes `@executable_path/../Frameworks`.
- Each extension's `LD_RUNPATH_SEARCH_PATHS` includes `@loader_path/../../../../Frameworks` so an extension at `boringNotch.app/Contents/PlugIns/Foo.capsule/Contents/MacOS/Foo` resolves NotchKit out of the host's `Frameworks` directory. User-installed extensions inherit the same value; the loader rebases relative to the host before linking.
- Extension targets must explicitly *not* embed NotchKit. CI lints reject any plugin product that contains `NotchKit.framework` in its bundle.

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

The factory closure is stored as a `@convention(block)` block so it crosses the `@objc` boundary cleanly (an arbitrary Swift `() -> NSViewController` cannot be exposed to Obj-C):

```swift
@objc public final class NotchTabContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let systemImage: String
    @objc public let lifecyclePolicy: NotchSlotLifecycle    // .onDemand | .preInstantiated
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        title: String,
        systemImage: String,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) { ... }
}
```

The same shape is used for `NotchClosedChinContribution`, `NotchSneakPeekContribution`, `NotchExpandedItemContribution`, `NotchHUDContribution`, with slot-specific metadata.

**Sneak-peek and expanded-item kinds are open (string-identified), not closed enums.** Today's `SneakContentType` enum in `BoringViewCoordinator.swift` is *deleted* in v1. Each `NotchSneakPeekContribution` and `NotchExpandedItemContribution` declares the kind it owns via `@objc public let kind: String` (e.g. `"music"`, `"battery"`, `"volume"`). `BoringViewCoordinator.toggleSneakPeek` / `toggleExpandingView` take a kind string instead of an enum case. Each kind must be claimed by exactly one extension; double-registration is logged and the second registration is dropped. This is the single non-trivial host edit caused by the migration — it's localized to `BoringViewCoordinator.swift` plus its callers (currently only inside core after the HUD/Music/Battery code moves to extensions).

UI contribution rule: extensions return `NSViewController`. SwiftUI views are wrapped via `NSHostingController` on the extension side. The host wraps the controller in `NSViewControllerRepresentable` for SwiftUI composition.

### 4.6 Host services (replaces shared-singleton access)

Today the SwiftUI views in `boringNotch/components/` consume host state via `@EnvironmentObject` (`BoringViewModel`) and direct singletons (`WebcamManager.shared`, `BatteryStatusViewModel.shared`, `BoringViewCoordinator.shared`). Once those views move to extensions, the bundle boundary forbids that pattern: an extension cannot see the host's `@EnvironmentObject` graph.

The host therefore exposes a small set of `@objc` *service protocols* on `NotchHost`:

```swift
@objc public protocol NotchHost {
    // ... (registration + settings + permissions APIs from §4.2) ...

    @objc func service(of kind: String) -> NSObject?     // returns one of the protocols below
}

@objc public protocol NotchNotchStateHost {
    @objc var notchState: NotchState { get }              // .closed | .open
    @objc var hovering: Bool { get }
    @objc func observeNotchState(_ handler: @escaping (NotchState) -> Void) -> NotchObservation
    @objc func observeHover(_ handler: @escaping (Bool) -> Void) -> NotchObservation
    @objc func open()
    @objc func close()
}

@objc public protocol NotchScreenHost {
    @objc var selectedScreenUUID: String { get }
    @objc func observeSelectedScreen(_ handler: @escaping (String) -> Void) -> NotchObservation
}

@objc public protocol NotchCoordinatorHost {
    @objc var currentTabIdentifier: String { get }
    @objc func observeCurrentTab(_ handler: @escaping (String) -> Void) -> NotchObservation
    @objc func showTab(_ identifier: String)
    @objc func toggleSneakPeek(kind: String, value: Double, icon: String, durationSeconds: Double)
    @objc func toggleExpandedItem(kind: String, value: Double, durationSeconds: Double)
}
```

Extensions get these via `host.service(of: "notch-state")` etc. **Extensions wrap the service into their own SwiftUI `ObservableObject` inside the controller they return** — one of the small new pieces of code each extension's principal-class file contains. Concretely, each extension's view-controller factory creates a SwiftUI `View` with its own per-extension state object that mirrors the relevant service primitives via the observation tokens. This is how a `Music` extension's `NotchHomeView` gets `notchState` after the move: it observes `NotchNotchStateHost.notchState` rather than reading `BoringViewModel.notchState` from an `@EnvironmentObject`.

**The host does not pass `BoringViewModel` across the bundle boundary.** `BoringViewModel` becomes a host-internal type; its public surface that extensions need (notch state, hover, screen) is re-exposed via the service protocols above. Per-screen view-model behavior (the multi-display case) is exposed by giving each service instance a screen UUID it represents — `host.service(of: "notch-state", screenUUID: ...)` is the multi-display variant.

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
| `boringNotch/BoringViewCoordinator.swift` | `Core/Host/BoringViewCoordinator.swift` | Edits: (1) remove `hudReplacement` observer + `MediaKeyInterceptor.shared.start/stop` calls at lines 133, 153, 159 — relocates to HUD extension's principal class via `host.permissions` and direct interceptor ownership; (2) remove the `ShelfStateViewModel.shared.isEmpty` check in `alwaysShowTabs.didSet` at line 68 — replaced with `host.service(of: "coordinator")?.currentTabIdentifier` lookup or simply dropped (the special-case is "if shelf is empty when tabs hidden, show home"; with extensions, the host doesn't know about Shelf, so the special-case is moved to ShelfExtension's own `didSet` on its tab visibility); (3) replace the `SneakContentType` enum with `String` kind dispatch (see §4.3); (4) `toggleSneakPeek` / `toggleExpandingView` keep their existing public API shape but switch to string-keyed dispatch and lookup the contributed view from the registry. Notch-state, screen-UUID, hover-tracking logic stays verbatim and is the backing for the host services in §4.6. |
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

### 5.4 `NotchHomeView` decomposition

`boringNotch/components/Notch/NotchHomeView.swift` (578 lines) is **not** verbatim-movable to a single extension — verified by inspection at lines 421-467 (`struct NotchHomeView`):

- Line 444: renders `MusicPlayerView` (Music)
- Line 447: renders `CalendarView` (Calendar)
- Line 457: renders `CameraPreviewView` with `WebcamManager.shared` (Webcam)

This is *the* most entangled host file. The plan is:

- `NotchHomeView` itself (the composing parent struct, ~lines 421-467) stays in core as a struct that arranges contributions side-by-side — but its body changes from hard-coded child view references to iteration over all extensions that registered as a `home-tab-fragment` contribution kind. *This is a real edit, not a verbatim move.*
- `MusicPlayerView` and supporting Music structs in the same file move to MusicExtension via per-struct `git mv` (extracting blocks of the file). Each extracted struct contributes a `NotchHomeFragmentContribution` for the home tab.
- `CalendarView` is already a separate symbol but its definition lives in `BoringCalendar.swift` — CalendarExtension contributes a fragment that wraps it.
- `CameraPreviewView` moves to WebcamExtension and contributes a fragment.

`NotchHomeFragmentContribution` is a slot type added to NotchKit (see §4.3). It declares ordering/priority so the three fragments lay out in their current visual order (Music → Calendar → Camera).

This is the largest deviation from the "verbatim move" rule in the spec, called out explicitly. The edit to `NotchHomeView` body is a contained ~30-line rewrite of the `mainContent` property; the rest of the file's contents are still moved by `git mv` of the per-feature structs.

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

- **No in-app code-signing gate on extensions.** The host opts out of library validation (§3.4) so user-installed `.capsule`s with any signing identity load. Combined with the host's accessibility / camera / mic / calendar entitlements, this is a real attack surface — a malicious extension inherits all of those grants without a separate user dialog. Mitigated only by the user directory being inside the user's home (not world-writable). v2 adds in-app per-extension trust prompts.
- **TCC consent inheritance.** macOS scopes calendar / camera / mic / accessibility consent at the host bundle level. A loaded extension reads through the host's already-granted permissions without ever surfacing a per-extension consent UI. Documented; v2 designs an explicit consent layer.
- **No process isolation.** A pure-Swift `fatalError`, deadlock, or memory corruption in any extension takes down the host. Mitigation: best-effort `@objc` exception catching at API entry points; no Swift-level safety net.
- **`@objc` API ceiling.** New API surfaces requiring Swift-only types (generics, value types, async sequences) cannot be added without redesign. Workaround pattern: data crossing the boundary uses `Codable` JSON via `Data` parameters when expressing it as Foundation types is awkward.
- **NotchKit binary/API versioning.** v1 has no formal ABI / API versioning for `NotchKit`. A host upgrade may break user-installed third-party extensions silently. Mitigation: extensions read `NotchKit.version` at activation and refuse to run on unknown versions; the host logs and skips. v2 designs proper semver gating.
- **Defaults schema duplication.** `Constants.swift` currently centralizes `Defaults` keys for many features. After migration, each extension owns its keys and reads via `host.settings`. v1 keeps the existing key strings unchanged for backwards compatibility, which means there are two notations for the same data: literal strings inside extension code, and the host's old (now-unreferenced) constants. The spec mandates *deleting* the migrated `Defaults` keys from `Constants.swift` as part of each feature's migration to avoid drift.
- **Inter-extension UI coupling already in source.** `NotchHomeView.swift` directly composes Music + Calendar + Camera UI (§5.4). The decomposition is non-trivial and is the single largest source of regression risk; called out explicitly so reviewers focus on it.
- **Big-bang regression risk.** Mitigated by the §2.1 `git mv`-only constraint and the §11 internal phasing. Post-move diffs should be small and reviewable, behavior should be byte-identical except for the explicit edits.
- **Localization regression.** Per-feature `Localizable.xcstrings` entries stay in the host file in v1.

## 9. Testing & verification

- `NotchKit` gets a tests target with unit tests on the contribution registry, settings-store namespacing, and permission-status round-trip.
- A `MockExtension.capsule` test fixture registers one of every slot type to exercise the loader and contribution-iteration paths.
- Existing tests (if any) move with their files via `git mv`. New per-feature tests are not required by this refactor.
- **Manual verification gate before merge:** dev runs the host with all built-in `.capsule`s embedded and exercises every flow the upstream README screenshots demonstrate — music live activity, shelf drop + AirDrop, calendar tab, battery notifications, HUD replacement (volume / brightness / backlight), webcam mirror, sneak-peek, expanded-item, onboarding (first-launch + permissions).

## 10. Scope summary

### In scope (v1 — must ship)

- `NotchKit` API: extension protocol, slot registration, per-slot lifecycle, settings store, permissions, keyboard shortcuts, menubar contributions, onboarding contributions.
- Extension loader scanning `Notch.app/Contents/PlugIns/` + `~/Library/Application Support/Capsule/Extensions/`.
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

## 11. Internal phasing of the big-bang landing

The refactor lands as one PR. Internally, the work is sequenced so that risk surfaces early and cheaply. Reviewers can evaluate each phase independently in commit history; the PR ships only when all three are green.

### Phase A — Plug-in plumbing proves end-to-end

Smallest viable end-state: workspace, `NotchKit.framework`, host app stub, **TipsExtension** (chosen because it has the smallest surface — single `TipStore.swift`).

- Create `Notch.xcworkspace`, `Core/Notch.xcodeproj` with host app + `NotchKit` targets.
- Implement `NotchExtension` protocol, `NotchHost`, `ExtensionLoader`, `ExtensionHost`, contribution registry. New code only.
- Implement `@convention(block)` factory shape; verify it compiles and crosses bundle boundary.
- Configure host entitlements (Hardened Runtime + library-validation disable), `LD_RUNPATH_SEARCH_PATHS`, install names, Code Sign on Copy.
- Create `Extensions/Tips/TipsExtension.xcodeproj`, link NotchKit, ship a `TipsExtension.swift` principal class registering one minimal contribution.
- Verify: host launches, loader finds the bundle, principal class instantiates, contribution registers, registry lookup works, `NotchKit.framework` is *not* duplicated in the loaded image graph (verify with `lldb` or `dyldinfo`).
- Verify: a manually-signed third-party `.capsule` placed in `~/Library/Application Support/Capsule/Extensions/` also loads.

Phase A is the *technical* gate. If any of the dyld / signing / `@objc` mechanics don't work, this phase fails fast before any feature migration begins.

### Phase B — Host services and registry stabilize

- Implement `NotchNotchStateHost`, `NotchScreenHost`, `NotchCoordinatorHost` service protocols (§4.6) backed by the existing `BoringViewModel` / `BoringViewCoordinator` instances.
- Edit `BoringViewCoordinator.swift` to switch sneak-peek / expanded-item dispatch from `SneakContentType` enum to string-keyed registry lookup.
- Edit `ContentView.swift` to look up slot contributions from the registry instead of referencing concrete views (initially, the registry is empty for everything except Tips, so the notch surface degrades gracefully — the *core* still renders).
- Add `NotchHomeFragmentContribution` (§5.4) and rewrite `NotchHomeView.mainContent` to iterate fragments.
- Verify: app still launches and shows the empty notch + the Tips extension's tab. Settings window aggregates Tips' (empty) pane. Menu bar still works.

Phase B is the *architecture* gate. If host-service protocols or string-keyed dispatch turn out to be wrong shape, this phase exposes it before seven more migrations pile on.

### Phase C — Feature migrations

In this order (smallest / least entangled first; most coupled last):

1. **Webcam** (single manager, single view, fragment contribution to home)
2. **Battery** (live activity + sneak-peek + expanded-item kinds; exercises Codec for sneak-peek values)
3. **Calendar** (tab + permission flow; exercises `NotchPermissionsAPI` end-to-end)
4. **LiveActivities** (download view + marquee + modifier; mostly view-only)
5. **HUD** (volume + brightness + media-key interceptor + accessibility; exercises XPC integration through the permission API)
6. **Shelf** (largest single feature; sustained state, multiple services, AirDrop)
7. **Music** (last; multiple controllers, NotchHomeView fragment, onboarding step, keyboard shortcut)

Each migration is one-feature-per-commit. Each commit is independently reviewable as: `git mv` of files into the extension's project + the documented minimal edits + the principal-class file. After every migration, the manual verification gate (§9) is rerun against the affected feature.

The single PR's diff therefore decomposes into ~10 self-contained commits whose order matches risk: phase-A commits at the top fail loudly if the plumbing is wrong, phase-B commits expose architectural mistakes, and phase-C commits land features one at a time. Codex's "this is three projects stacked" critique is honored by sequencing them, while still landing as a coherent unit per the user's big-bang preference.
