# Notch Core + Extensions Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the forked Boring Notch macOS app into a minimal core (host app + `NotchKit.framework`) plus a set of dynamic `.notchext` bundles loaded at runtime. All current features (Music, Shelf, Calendar, Battery, HUD, Webcam, Live Activities, Tips) ship as built-in extensions.

**Architecture:** Single-process, in-process plug-in loading. Extensions are `.notchext` bundles whose `Info.plist` declares `NSPrincipalClass` conforming to a `NotchExtension` `@objc` protocol from `NotchKit`. The host opts out of library validation (Hardened Runtime + entitlement) so unsigned third-party extensions can load from `~/Library/Application Support/Notch/Extensions/`. Built-ins ship inside `boringNotch.app/Contents/PlugIns/`. UI contributions return `NSViewController`s; cross-bundle state access goes through host-service `@objc` protocols.

**Tech Stack:** Swift, SwiftUI, AppKit, Xcode 16+, macOS 14+, `Defaults` (Sindre Sorhus), Sparkle, Combine, KeyboardShortcuts.

**Spec:** `docs/superpowers/specs/2026-05-05-notch-core-extensions-design.md`

**Hard constraint (carried from spec §2.1):** Files that survive the refactor move via `git mv`. Edits to moved files are limited to the smallest diff that compiles in the new location. No re-typing of file contents, no drive-by refactors. Every task below either creates new code or moves + minimally edits existing code; tasks that say "rewrite" exist only where the spec explicitly justifies them (`NotchHomeView.mainContent`, `BoringViewCoordinator` sneak-peek dispatch).

---

## Phasing

The plan is sequenced into three phases that land as one PR but commit independently:

- **Phase A — Plug-in plumbing proves end-to-end.** Workspace + NotchKit + minimal host stub + TipsExtension. Gate: app launches with one extension loading correctly, no NotchKit duplication in the dyld image graph.
- **Phase B — Host services + registry-driven host.** `BoringViewCoordinator` switches from closed-enum dispatch to string-keyed registry lookup. `ContentView` and `NotchHomeView` iterate contributions. Gate: app launches with empty notch surface that degrades gracefully when no extension claims a slot.
- **Phase C — Feature migrations.** Webcam → Battery → Calendar → LiveActivities → HUD → Shelf → Music. One commit per feature.

Each phase ends with a manual verification step before commit. Reviewers should be able to skim the commit history and see plumbing, then services, then features.

---

## File Structure

### New files (created in this plan)

- `Notch.xcworkspace/contents.xcworkspacedata`
- `Core/Notch.xcodeproj/project.pbxproj` (Xcode-managed; documented as derived from the host's existing `boringNotch.xcodeproj`)
- `Core/NotchKit/Sources/NotchExtension.swift`
- `Core/NotchKit/Sources/NotchHost.swift`
- `Core/NotchKit/Sources/NotchSlotLifecycle.swift`
- `Core/NotchKit/Sources/Contributions/NotchTabContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchClosedChinContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchSneakPeekContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchExpandedItemContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchHUDContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchSettingsPaneContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchMenuItemContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchOnboardingContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchKeyboardShortcutContribution.swift`
- `Core/NotchKit/Sources/Contributions/NotchPermissionRequest.swift`
- `Core/NotchKit/Sources/Contributions/NotchHomeFragmentContribution.swift`
- `Core/NotchKit/Sources/Settings/NotchSettingsStore.swift`
- `Core/NotchKit/Sources/Permissions/NotchPermissionsAPI.swift`
- `Core/NotchKit/Sources/Permissions/NotchPermissionKind.swift`
- `Core/NotchKit/Sources/Logger/NotchLogger.swift`
- `Core/NotchKit/Sources/Observation/NotchObservation.swift`
- `Core/NotchKit/Sources/Services/NotchNotchStateHost.swift`
- `Core/NotchKit/Sources/Services/NotchScreenHost.swift`
- `Core/NotchKit/Sources/Services/NotchCoordinatorHost.swift`
- `Core/NotchKit/Sources/Version/NotchKitVersion.swift`
- `Core/NotchKit/Resources/Info.plist`
- `Core/NotchKitTests/ContributionRegistryTests.swift`
- `Core/NotchKitTests/SettingsStoreTests.swift`
- `Core/NotchKitTests/PermissionsAPITests.swift`
- `Core/Host/ExtensionHost.swift`
- `Core/Host/ExtensionLoader.swift`
- `Core/Host/Services/BoringViewModelServiceAdapter.swift`
- `Core/Host/Services/CoordinatorServiceAdapter.swift`
- `Extensions/Tips/TipsExtension.xcodeproj/project.pbxproj`
- `Extensions/Tips/Sources/TipsExtension.swift` (principal class)
- `Extensions/Tips/Resources/Info.plist`
- `Extensions/Music/MusicExtension.xcodeproj/project.pbxproj`
- `Extensions/Music/Sources/MusicExtension.swift` (principal class)
- `Extensions/Music/Resources/Info.plist`
- `Extensions/Shelf/ShelfExtension.xcodeproj/project.pbxproj`
- `Extensions/Shelf/Sources/ShelfExtension.swift`
- `Extensions/Shelf/Resources/Info.plist`
- `Extensions/Calendar/CalendarExtension.xcodeproj/project.pbxproj`
- `Extensions/Calendar/Sources/CalendarExtension.swift`
- `Extensions/Calendar/Resources/Info.plist`
- `Extensions/Battery/BatteryExtension.xcodeproj/project.pbxproj`
- `Extensions/Battery/Sources/BatteryExtension.swift`
- `Extensions/Battery/Resources/Info.plist`
- `Extensions/HUD/HUDExtension.xcodeproj/project.pbxproj`
- `Extensions/HUD/Sources/HUDExtension.swift`
- `Extensions/HUD/Resources/Info.plist`
- `Extensions/Webcam/WebcamExtension.xcodeproj/project.pbxproj`
- `Extensions/Webcam/Sources/WebcamExtension.swift`
- `Extensions/Webcam/Resources/Info.plist`
- `Extensions/LiveActivities/LiveActivitiesExtension.xcodeproj/project.pbxproj`
- `Extensions/LiveActivities/Sources/LiveActivitiesExtension.swift`
- `Extensions/LiveActivities/Resources/Info.plist`
- `scripts/check_no_notchkit_embed.sh` (CI lint)

### Moved files (`git mv`)

See per-task tables in Phase A and Phase C. Every existing Swift file in `boringNotch/` either moves to `Core/Host/...` or to `Extensions/<Feature>/Sources/...`.

---

# Phase A — Plug-in plumbing proves end-to-end

Goal of Phase A: the app launches, the extension loader finds and instantiates `TipsExtension.notchext`, and `lldb` confirms a single `NotchKit.framework` load image is shared between host and extension.

### Task A1: Create the workspace skeleton and bring the existing project under it

**Files:**
- Create: `Notch.xcworkspace/contents.xcworkspacedata`
- Move: `boringNotch.xcodeproj` → `Core/Notch.xcodeproj` (via `git mv`)

- [ ] **Step 1: Create the directory layout**

```bash
mkdir -p Core Extensions
```

- [ ] **Step 2: Move the existing Xcode project under `Core/`**

```bash
git mv boringNotch.xcodeproj Core/Notch.xcodeproj
```

- [ ] **Step 3: Create the workspace file**

Write `Notch.xcworkspace/contents.xcworkspacedata`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version="1.0">
   <FileRef location="group:Core/Notch.xcodeproj"></FileRef>
</Workspace>
```

- [ ] **Step 4: Open the workspace and verify the host target still builds**

```bash
open Notch.xcworkspace
```

In Xcode: select scheme `boringNotch`, ⌘B. Expected: BUILD SUCCEEDED. The host app must still build before any further changes.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Move boringNotch.xcodeproj under Core/, add workspace"
```

---

### Task A2: Move host source files into `Core/Host/` (no edits)

**Files:** All paths under `boringNotch/` → `Core/Host/...` per spec §5.1.

- [ ] **Step 1: Create destination directory tree**

```bash
mkdir -p Core/Host/Notch Core/Host/Tabs Core/Host/Onboarding \
         Core/Host/Settings Core/Host/Menu Core/Host/Observers \
         Core/Host/Managers Core/Host/Models Core/Host/Extensions \
         Core/Host/Helpers Core/Host/Sizing Core/Host/Private \
         Core/Host/XPCHelperClient Core/Host/Animations \
         Core/Host/Shortcuts Core/Host/Components
```

- [ ] **Step 2: Move root-level host files**

```bash
git mv boringNotch/boringNotchApp.swift           Core/Host/boringNotchApp.swift
git mv boringNotch/BoringViewCoordinator.swift    Core/Host/BoringViewCoordinator.swift
git mv boringNotch/ContentView.swift              Core/Host/ContentView.swift
git mv boringNotch/Info.plist                     Core/Host/Info.plist
git mv boringNotch/boringNotch.entitlements       Core/Host/boringNotch.entitlements
git mv boringNotch/Localizable.xcstrings          Core/Host/Localizable.xcstrings
git mv boringNotch/boring.m4a                     Core/Host/boring.m4a
git mv "boringNotch/Preview Content"              "Core/Host/Preview Content"
git mv boringNotch/Assets.xcassets                Core/Host/Assets.xcassets
```

- [ ] **Step 3: Move per-folder host files**

```bash
git mv boringNotch/components/Notch/*.swift              Core/Host/Notch/
git mv boringNotch/components/Tabs/*.swift               Core/Host/Tabs/
git mv boringNotch/components/Onboarding/*.swift         Core/Host/Onboarding/
git mv boringNotch/components/Settings/SettingsView.swift Core/Host/Settings/
git mv boringNotch/components/Settings/SettingsWindowController.swift Core/Host/Settings/
git mv boringNotch/components/Settings/EditPanelView.swift Core/Host/Settings/
git mv boringNotch/components/Settings/ListItemPopover.swift Core/Host/Settings/
git mv boringNotch/components/Settings/SoftwareUpdater.swift Core/Host/Settings/
git mv boringNotch/menu/StatusBarMenu.swift              Core/Host/Menu/
git mv boringNotch/observers/DragDetector.swift          Core/Host/Observers/
git mv boringNotch/observers/FullscreenMediaDetection.swift Core/Host/Observers/
git mv boringNotch/managers/NotchSpaceManager.swift      Core/Host/Managers/
git mv boringNotch/managers/ImageService.swift           Core/Host/Managers/
git mv boringNotch/models/Constants.swift                Core/Host/Models/
git mv boringNotch/models/BoringViewModel.swift          Core/Host/Models/
git mv boringNotch/models/SharingStateManager.swift      Core/Host/Models/
git mv boringNotch/extensions/*.swift                    Core/Host/Extensions/
git mv boringNotch/helpers/AudioPlayer.swift             Core/Host/Helpers/
git mv boringNotch/helpers/AppIcons.swift                Core/Host/Helpers/
git mv boringNotch/helpers/AssociatedObject.swift        Core/Host/Helpers/
git mv boringNotch/helpers/ApplicationRelauncher.swift   Core/Host/Helpers/
git mv boringNotch/helpers/Clipboard+Content.swift       Core/Host/Helpers/
git mv boringNotch/sizing/matters.swift                  Core/Host/Sizing/
git mv boringNotch/private/CGSSpace.swift                Core/Host/Private/
git mv boringNotch/XPCHelperClient/*.swift               Core/Host/XPCHelperClient/
git mv boringNotch/animations/*.swift                    Core/Host/Animations/
git mv boringNotch/Shortcuts/ShortcutConstants.swift     Core/Host/Shortcuts/
git mv boringNotch/components/HoverButton.swift          Core/Host/Components/
git mv boringNotch/components/WhatsNewView.swift         Core/Host/Components/
git mv boringNotch/components/EmptyState.swift           Core/Host/Components/
git mv boringNotch/components/TestView.swift             Core/Host/Components/
git mv boringNotch/components/BottomRoundedRectangle.swift Core/Host/Components/
git mv boringNotch/components/ProgressIndicator.swift    Core/Host/Components/
git mv boringNotch/components/LottieView.swift           Core/Host/Components/
git mv boringNotch/components/AnimatedFace.swift         Core/Host/Components/
```

- [ ] **Step 4: Move `enums/generic.swift` and `utils/Logger.swift`**

```bash
git mv boringNotch/enums/generic.swift Core/Host/Models/generic.swift
git mv boringNotch/utils/Logger.swift  Core/Host/Logger.swift
```

(`Logger.swift` will later be referenced from NotchKit; for now it stays in Host.)

- [ ] **Step 5: Update file references in Xcode**

Open `Core/Notch.xcodeproj` in the workspace. Many file references are now broken (red names in the Project Navigator). For each red file:

1. Select the file in the navigator.
2. In the File Inspector right panel, click the small folder icon next to "Location".
3. Re-resolve to its new path under `Core/Host/...`.

Alternatively, edit the project file: `Core/Notch.xcodeproj/project.pbxproj` and replace every `boringNotch/...` path prefix with `Core/Host/...`. (Do this carefully — the file is sensitive to formatting. If using sed: back up first.)

- [ ] **Step 6: Verify the host target still builds**

In Xcode: ⌘B. Expected: BUILD SUCCEEDED with zero errors. **No file changed; only paths moved.** If the build fails, do not proceed — fix path references until it builds.

- [ ] **Step 7: Run the app to confirm runtime behavior is identical**

⌘R. Expected: app launches, notch appears, all features work as before. This is the no-op-move verification gate.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Move host source under Core/Host/ via git mv (no content changes)"
```

---

### Task A3: Create `NotchKit.framework` target

**Files:**
- Create: `Core/NotchKit/Sources/.gitkeep`
- Create: `Core/NotchKit/Resources/Info.plist`
- Modify: `Core/Notch.xcodeproj/project.pbxproj` (add framework target)

- [ ] **Step 1: Create directory tree**

```bash
mkdir -p Core/NotchKit/Sources/Contributions \
         Core/NotchKit/Sources/Settings \
         Core/NotchKit/Sources/Permissions \
         Core/NotchKit/Sources/Logger \
         Core/NotchKit/Sources/Observation \
         Core/NotchKit/Sources/Services \
         Core/NotchKit/Sources/Version \
         Core/NotchKit/Resources \
         Core/NotchKitTests
touch Core/NotchKit/Sources/.gitkeep
```

- [ ] **Step 2: Create `Core/NotchKit/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.theboredteam.NotchKit</string>
  <key>CFBundleName</key>
  <string>NotchKit</string>
  <key>CFBundlePackageType</key>
  <string>FMWK</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026 The Boring Team.</string>
</dict>
</plist>
```

- [ ] **Step 3: In Xcode, add a new framework target**

In the workspace: File → New → Target → macOS → Framework. Name: `NotchKit`. Bundle ID: `com.theboredteam.NotchKit`. Embed in Application: `Notch` (host app target). Language: Swift.

- [ ] **Step 4: Configure the new target's build settings**

Select the `NotchKit` target → Build Settings:
- **Dynamic Library Install Name Base:** `@rpath`
- **Dynamic Library Install Name:** `@rpath/NotchKit.framework/Versions/A/NotchKit`
- **Skip Install:** `NO`
- **Build Active Architecture Only (Debug):** `YES`
- **Deployment Target:** macOS 14.0
- **Defines Module:** `YES`
- **Info.plist File:** `Core/NotchKit/Resources/Info.plist`
- **Sources Path:** `Core/NotchKit/Sources`
- **Headers Path:** (default)

Select the `Notch` (host) target → Build Settings:
- **Runpath Search Paths:** add `@executable_path/../Frameworks`

Select the `Notch` target → Build Phases:
- Confirm a "Embed Frameworks" phase exists with `NotchKit.framework`. Set Destination = `Frameworks`. Set "Code Sign on Copy" = ✓.

- [ ] **Step 5: Add a placeholder source file so the framework target compiles**

Create `Core/NotchKit/Sources/Version/NotchKitVersion.swift`:

```swift
import Foundation

@objc public final class NotchKitVersion: NSObject {
    @objc public static let current: String = "1.0.0"
}
```

Add it to the `NotchKit` target in Xcode (drag into the target).

- [ ] **Step 6: Verify both targets build**

⌘B. Expected: BUILD SUCCEEDED for `NotchKit` and `Notch`. The host's `Frameworks/NotchKit.framework` should appear in the built `boringNotch.app` bundle (verify via `ls -R DerivedData/.../boringNotch.app/Contents/Frameworks/`).

- [ ] **Step 7: Verify the host can `import NotchKit` (sanity check)**

Add a temporary line at the top of `Core/Host/boringNotchApp.swift`:

```swift
import NotchKit
```

⌘B. Expected: BUILD SUCCEEDED. Now remove the line — we'll add it for real in Task A11.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add NotchKit framework target with @rpath install name"
```

---

### Task A4: Define the `NotchExtension` protocol

**Files:**
- Create: `Core/NotchKit/Sources/NotchExtension.swift`
- Test: `Core/NotchKitTests/ContributionRegistryTests.swift` (later)

- [ ] **Step 1: Create `Core/NotchKit/Sources/NotchExtension.swift`**

```swift
import Foundation

/// Principal-class protocol that every `.notchext` bundle must implement.
///
/// Exactly one class in the bundle conforms to this protocol and is declared
/// as `NSPrincipalClass` in the bundle's `Info.plist`. The host loader
/// instantiates that class via `make()` after `Bundle.load()`.
@objc public protocol NotchExtension: NSObjectProtocol {
    /// Factory called by the loader after the bundle is loaded. Implementations
    /// typically just `return Self()` after running zero-cost initialisation.
    @objc static func make() -> NotchExtension

    /// Reverse-DNS identifier, e.g. `"com.theboredteam.music"`. Must be unique
    /// across all loaded extensions in a session.
    @objc var identifier: String { get }

    /// Human-readable display name shown in Settings → Extensions.
    @objc var displayName: String { get }

    /// Called once after the principal class has been instantiated. The
    /// extension uses the supplied host to register every contribution it
    /// makes. After `activate(host:)` returns, the extension's contributions
    /// are visible to the host's slot lookup.
    @objc func activate(host: NotchHost)

    /// Called once at app termination, before the bundle is unloaded.
    @objc optional func deactivate()

    /// Called whenever the screen configuration changes (display added/removed,
    /// arrangement changed, resolution changed).
    @objc optional func screenConfigurationChanged()

    /// Called when the screen is locked.
    @objc optional func screenLocked()

    /// Called when the screen is unlocked.
    @objc optional func screenUnlocked()
}
```

Add to `NotchKit` target.

- [ ] **Step 2: Build NotchKit**

⌘B with `NotchKit` scheme selected. Expected: BUILD SUCCEEDED. (At this stage `NotchHost` is undefined; we'll add it next.)

If the build fails with "cannot find type 'NotchHost'", that's expected for now. Skip the build step — proceed to the next task.

- [ ] **Step 3: Commit (after Task A5 closes the type, otherwise build fails)**

We'll commit after A5 lands `NotchHost`. Continue without committing.

---

### Task A5: Define the `NotchHost` protocol

**Files:**
- Create: `Core/NotchKit/Sources/NotchHost.swift`

- [ ] **Step 1: Create `Core/NotchKit/Sources/NotchHost.swift`**

```swift
import AppKit
import Foundation

/// The single object an extension uses to communicate with the core. An
/// instance is passed to `NotchExtension.activate(host:)` and remains valid
/// for the lifetime of the extension.
///
/// All methods are safe to call from any thread, but slot registrations
/// must happen synchronously from `activate(host:)` (the host snapshots the
/// registry once `activate` returns). Service observations registered after
/// `activate` are honoured.
@objc public protocol NotchHost: NSObjectProtocol {

    // MARK: - Slot registration

    @objc func register(tab: NotchTabContribution)
    @objc func register(homeFragment: NotchHomeFragmentContribution)
    @objc func register(closedChinItem: NotchClosedChinContribution)
    @objc func register(sneakPeek: NotchSneakPeekContribution)
    @objc func register(expandedItem: NotchExpandedItemContribution)
    @objc func register(hudReplacement: NotchHUDContribution)
    @objc func register(settingsPane: NotchSettingsPaneContribution)
    @objc func register(menuBarItems: [NotchMenuItemContribution])
    @objc func register(onboardingStep: NotchOnboardingContribution)
    @objc func register(keyboardShortcut: NotchKeyboardShortcutContribution)
    @objc func register(permission: NotchPermissionRequest)

    // MARK: - Settings, permissions, logging

    @objc var settings: NotchSettingsStore { get }
    @objc var permissions: NotchPermissionsAPI { get }
    @objc var logger: NotchLogger { get }

    // MARK: - Host services

    /// Returns a service object for the given kind, or `nil` if unknown.
    /// Known kinds in v1: `"notch-state"`, `"screen"`, `"coordinator"`.
    /// The returned object conforms to one of the host-service protocols
    /// declared in `Services/`.
    @objc func service(of kind: String) -> NSObject?

    /// Multi-display variant. Returns a service scoped to the given screen.
    @objc func service(of kind: String, screenUUID: String) -> NSObject?
}
```

Add to `NotchKit` target.

---

### Task A6: Define slot lifecycle and contribution types

**Files:**
- Create: `Core/NotchKit/Sources/NotchSlotLifecycle.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchTabContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchClosedChinContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchSneakPeekContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchExpandedItemContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchHUDContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchSettingsPaneContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchMenuItemContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchOnboardingContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchKeyboardShortcutContribution.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchPermissionRequest.swift`
- Create: `Core/NotchKit/Sources/Contributions/NotchHomeFragmentContribution.swift`

- [ ] **Step 1: Create `NotchSlotLifecycle.swift`**

```swift
import Foundation

@objc public enum NotchSlotLifecycle: Int {
    /// View controller is constructed each time the slot becomes visible
    /// and released when the slot hides.
    case onDemand = 0

    /// View controller is constructed eagerly on first slot use and retained
    /// for the lifetime of the extension. Use for live activities that must
    /// observe events while hidden.
    case preInstantiated = 1
}
```

- [ ] **Step 2: Create `NotchTabContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchTabContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let systemImage: String
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        title: String,
        systemImage: String,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.title = title
        self.systemImage = systemImage
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 3: Create `NotchHomeFragmentContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchHomeFragmentContribution: NSObject {
    @objc public let identifier: String
    /// Sort priority; lower values render first (left). Music = 100,
    /// Calendar = 200, Webcam = 300 by convention.
    @objc public let priority: Int
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        priority: Int,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.priority = priority
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 4: Create `NotchClosedChinContribution.swift`**

```swift
import AppKit
import Foundation

@objc public enum NotchClosedChinSide: Int { case left = 0, right = 1 }

@objc public final class NotchClosedChinContribution: NSObject {
    @objc public let identifier: String
    @objc public let side: NotchClosedChinSide
    @objc public let priority: Int
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        side: NotchClosedChinSide,
        priority: Int,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.side = side
        self.priority = priority
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 5: Create `NotchSneakPeekContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchSneakPeekContribution: NSObject {
    /// String identifier for the sneak-peek kind. Examples: `"music"`,
    /// `"battery"`, `"volume"`, `"brightness"`, `"backlight"`, `"mic"`.
    /// Each kind must be claimed by exactly one extension; double-registration
    /// is logged and the second registration is dropped.
    @objc public let kind: String
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        kind: String,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.kind = kind
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 6: Create `NotchExpandedItemContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchExpandedItemContribution: NSObject {
    @objc public let kind: String
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        kind: String,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.kind = kind
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 7: Create `NotchHUDContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchHUDContribution: NSObject {
    @objc public let kind: String         // "volume", "brightness", "backlight"
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        kind: String,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.kind = kind
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 8: Create `NotchSettingsPaneContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchSettingsPaneContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let systemImage: String
    @objc public let priority: Int
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        title: String,
        systemImage: String,
        priority: Int,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 9: Create `NotchMenuItemContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchMenuItemContribution: NSObject {
    @objc public let title: String
    @objc public let action: @convention(block) () -> Void
    /// Optional `KeyEquivalent` rendering string, e.g. `"q"`. Empty for none.
    @objc public let keyEquivalent: String
    /// `NSEvent.ModifierFlags.rawValue` for the shortcut. Zero for none.
    @objc public let keyEquivalentModifiers: UInt

    @objc public init(
        title: String,
        keyEquivalent: String,
        keyEquivalentModifiers: UInt,
        action: @escaping @convention(block) () -> Void
    ) {
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.keyEquivalentModifiers = keyEquivalentModifiers
        self.action = action
        super.init()
    }
}
```

- [ ] **Step 10: Create `NotchOnboardingContribution.swift`**

```swift
import AppKit
import Foundation

@objc public final class NotchOnboardingContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let priority: Int
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        title: String,
        priority: Int,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.title = title
        self.priority = priority
        self.makeViewController = makeViewController
        super.init()
    }
}
```

- [ ] **Step 11: Create `NotchKeyboardShortcutContribution.swift`**

```swift
import Foundation

@objc public final class NotchKeyboardShortcutContribution: NSObject {
    /// Stable identifier the shortcut is persisted under (matches the user's
    /// existing `KeyboardShortcuts.Name` string when migrating).
    @objc public let identifier: String
    @objc public let displayName: String
    @objc public let action: @convention(block) () -> Void

    @objc public init(
        identifier: String,
        displayName: String,
        action: @escaping @convention(block) () -> Void
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.action = action
        super.init()
    }
}
```

- [ ] **Step 12: Create `NotchPermissionRequest.swift`**

```swift
import Foundation

@objc public final class NotchPermissionRequest: NSObject {
    @objc public let kind: NotchPermissionKind
    @objc public let rationale: String

    @objc public init(kind: NotchPermissionKind, rationale: String) {
        self.kind = kind
        self.rationale = rationale
        super.init()
    }
}
```

- [ ] **Step 13: Add all created files to the `NotchKit` target in Xcode**

Drag the `Core/NotchKit/Sources/Contributions/` folder into the `NotchKit` group in Xcode. Confirm each file is checked under "Target Membership = NotchKit" (and *not* the host target).

- [ ] **Step 14: Build NotchKit**

⌘B with the `NotchKit` scheme. Expected: build will fail because `NotchPermissionKind` and the other supporting types are not yet defined. That's expected — Task A7/A8 add them.

---

### Task A7: Define settings store, permissions API, logger, observation token

**Files:**
- Create: `Core/NotchKit/Sources/Settings/NotchSettingsStore.swift`
- Create: `Core/NotchKit/Sources/Permissions/NotchPermissionsAPI.swift`
- Create: `Core/NotchKit/Sources/Permissions/NotchPermissionKind.swift`
- Create: `Core/NotchKit/Sources/Logger/NotchLogger.swift`
- Create: `Core/NotchKit/Sources/Observation/NotchObservation.swift`

- [ ] **Step 1: Create `NotchObservation.swift`**

```swift
import Foundation

/// Token returned from `observe(...)` calls. Holding the token keeps the
/// observation alive; releasing it cancels the observation.
@objc public final class NotchObservation: NSObject {
    private let cancelHandler: () -> Void
    private var cancelled = false
    private let lock = NSLock()

    public init(cancel: @escaping () -> Void) {
        self.cancelHandler = cancel
        super.init()
    }

    @objc public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { return }
        cancelled = true
        cancelHandler()
    }

    deinit { cancel() }
}
```

- [ ] **Step 2: Create `NotchPermissionKind.swift`**

```swift
import Foundation

@objc public enum NotchPermissionKind: Int {
    case calendar      = 0
    case reminders     = 1
    case accessibility = 2
    case camera        = 3
    case microphone    = 4
    case mediaLibrary  = 5
    case fileShelf     = 6
}

@objc public enum NotchPermissionStatus: Int {
    case notDetermined = 0
    case granted       = 1
    case denied        = 2
    case unsupported   = 3
}
```

- [ ] **Step 3: Create `NotchPermissionsAPI.swift`**

```swift
import Foundation

@objc public protocol NotchPermissionsAPI: NSObjectProtocol {
    @objc func status(for permission: NotchPermissionKind) -> NotchPermissionStatus
    @objc func request(_ permission: NotchPermissionKind,
                       completion: @escaping (NotchPermissionStatus) -> Void)
}
```

- [ ] **Step 4: Create `NotchSettingsStore.swift`**

```swift
import Foundation

@objc public protocol NotchSettingsStore: NSObjectProtocol {
    @objc func setValue(_ value: Any?, forKey key: String)
    @objc func value(forKey key: String) -> Any?
    @objc func observe(key: String,
                       handler: @escaping (Any?) -> Void) -> NotchObservation
}
```

- [ ] **Step 5: Create `NotchLogger.swift`**

```swift
import Foundation

@objc public enum NotchLogLevel: Int {
    case debug = 0, info = 1, notice = 2, warning = 3, error = 4
}

@objc public protocol NotchLogger: NSObjectProtocol {
    @objc func log(level: NotchLogLevel, message: String)
}
```

- [ ] **Step 6: Add all created files to the `NotchKit` target**

Drag the new folders into the Xcode `NotchKit` group. Verify Target Membership.

- [ ] **Step 7: Build NotchKit**

⌘B with `NotchKit` scheme. Expected: BUILD SUCCEEDED.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Define NotchKit public API: NotchExtension, NotchHost, contributions, settings/permissions/logger"
```

---

### Task A8: Define host service protocols

**Files:**
- Create: `Core/NotchKit/Sources/Services/NotchNotchStateHost.swift`
- Create: `Core/NotchKit/Sources/Services/NotchScreenHost.swift`
- Create: `Core/NotchKit/Sources/Services/NotchCoordinatorHost.swift`

- [ ] **Step 1: Create `NotchNotchStateHost.swift`**

```swift
import Foundation

@objc public enum NotchOpenState: Int { case closed = 0, open = 1 }

@objc public protocol NotchNotchStateHost: NSObjectProtocol {
    @objc var notchState: NotchOpenState { get }
    @objc var hovering: Bool { get }
    @objc func observeNotchState(_ handler: @escaping (NotchOpenState) -> Void) -> NotchObservation
    @objc func observeHover(_ handler: @escaping (Bool) -> Void) -> NotchObservation
    @objc func open()
    @objc func close()
}
```

- [ ] **Step 2: Create `NotchScreenHost.swift`**

```swift
import Foundation

@objc public protocol NotchScreenHost: NSObjectProtocol {
    @objc var selectedScreenUUID: String { get }
    @objc func observeSelectedScreen(_ handler: @escaping (String) -> Void) -> NotchObservation
}
```

- [ ] **Step 3: Create `NotchCoordinatorHost.swift`**

```swift
import Foundation

@objc public protocol NotchCoordinatorHost: NSObjectProtocol {
    @objc var currentTabIdentifier: String { get }
    @objc func observeCurrentTab(_ handler: @escaping (String) -> Void) -> NotchObservation
    @objc func showTab(_ identifier: String)

    /// Show a sneak-peek pill of the given kind. The view comes from whichever
    /// extension registered the kind via `register(sneakPeek:)`.
    @objc func toggleSneakPeek(kind: String,
                               value: Double,
                               icon: String,
                               durationSeconds: Double)

    @objc func toggleExpandedItem(kind: String,
                                  value: Double,
                                  durationSeconds: Double)
}
```

- [ ] **Step 4: Add to `NotchKit` target, build**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Define NotchKit host service protocols (state, screen, coordinator)"
```

---

### Task A9: Implement `ExtensionHost` (singleton + registry)

**Files:**
- Create: `Core/Host/ExtensionHost.swift`

- [ ] **Step 1: Create `Core/Host/ExtensionHost.swift`**

```swift
import AppKit
import Foundation
import NotchKit

/// Concrete implementation of `NotchHost`. Singleton owned by the host app.
final class ExtensionHost: NSObject, NotchHost {

    static let shared = ExtensionHost()

    // MARK: - Registries (keyed lookups used by the host's render path)

    private(set) var tabs: [NotchTabContribution] = []
    private(set) var homeFragments: [NotchHomeFragmentContribution] = []
    private(set) var closedChinItems: [NotchClosedChinContribution] = []
    private(set) var sneakPeeks: [String: NotchSneakPeekContribution] = [:]
    private(set) var expandedItems: [String: NotchExpandedItemContribution] = [:]
    private(set) var hudReplacements: [String: NotchHUDContribution] = [:]
    private(set) var settingsPanes: [NotchSettingsPaneContribution] = []
    private(set) var menuBarItems: [NotchMenuItemContribution] = []
    private(set) var onboardingSteps: [NotchOnboardingContribution] = []
    private(set) var keyboardShortcuts: [NotchKeyboardShortcutContribution] = []
    private(set) var permissionRequests: [NotchPermissionRequest] = []

    /// Posted after `ExtensionLoader.load()` finishes, on the main thread.
    static let didLoadExtensionsNotification = Notification.Name("NotchExtensionsDidLoad")

    // MARK: - Service registry (filled by host adapters in Phase B)

    private var serviceFactories: [String: () -> NSObject?] = [:]
    private var screenScopedServiceFactories: [String: (String) -> NSObject?] = [:]

    func registerService(kind: String, factory: @escaping () -> NSObject?) {
        serviceFactories[kind] = factory
    }
    func registerScreenScopedService(kind: String, factory: @escaping (String) -> NSObject?) {
        screenScopedServiceFactories[kind] = factory
    }

    // MARK: - Boot

    func start() {
        ExtensionLoader().load(into: self)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: ExtensionHost.didLoadExtensionsNotification, object: nil)
        }
    }

    // MARK: - NotchHost

    @objc func register(tab: NotchTabContribution) { tabs.append(tab) }
    @objc func register(homeFragment: NotchHomeFragmentContribution) {
        homeFragments.append(homeFragment)
        homeFragments.sort { $0.priority < $1.priority }
    }
    @objc func register(closedChinItem: NotchClosedChinContribution) {
        closedChinItems.append(closedChinItem)
        closedChinItems.sort { $0.priority < $1.priority }
    }
    @objc func register(sneakPeek: NotchSneakPeekContribution) {
        if sneakPeeks[sneakPeek.kind] != nil {
            NSLog("⚠️ NotchKit: sneak-peek kind \(sneakPeek.kind) already registered — dropping duplicate")
            return
        }
        sneakPeeks[sneakPeek.kind] = sneakPeek
    }
    @objc func register(expandedItem: NotchExpandedItemContribution) {
        if expandedItems[expandedItem.kind] != nil {
            NSLog("⚠️ NotchKit: expanded-item kind \(expandedItem.kind) already registered — dropping duplicate")
            return
        }
        expandedItems[expandedItem.kind] = expandedItem
    }
    @objc func register(hudReplacement: NotchHUDContribution) {
        if hudReplacements[hudReplacement.kind] != nil {
            NSLog("⚠️ NotchKit: HUD kind \(hudReplacement.kind) already registered — dropping duplicate")
            return
        }
        hudReplacements[hudReplacement.kind] = hudReplacement
    }
    @objc func register(settingsPane: NotchSettingsPaneContribution) {
        settingsPanes.append(settingsPane)
        settingsPanes.sort { $0.priority < $1.priority }
    }
    @objc func register(menuBarItems: [NotchMenuItemContribution]) {
        self.menuBarItems.append(contentsOf: menuBarItems)
    }
    @objc func register(onboardingStep: NotchOnboardingContribution) {
        onboardingSteps.append(onboardingStep)
        onboardingSteps.sort { $0.priority < $1.priority }
    }
    @objc func register(keyboardShortcut: NotchKeyboardShortcutContribution) {
        keyboardShortcuts.append(keyboardShortcut)
    }
    @objc func register(permission: NotchPermissionRequest) {
        permissionRequests.append(permission)
    }

    @objc lazy var settings: NotchSettingsStore = HostSettingsStore()
    @objc lazy var permissions: NotchPermissionsAPI = HostPermissionsAPI()
    @objc lazy var logger: NotchLogger = HostLogger()

    @objc func service(of kind: String) -> NSObject? {
        serviceFactories[kind]?()
    }
    @objc func service(of kind: String, screenUUID: String) -> NSObject? {
        screenScopedServiceFactories[kind]?(screenUUID) ?? service(of: kind)
    }
}
```

Add to `Notch` (host) target. Note: `HostSettingsStore`, `HostPermissionsAPI`, `HostLogger` are forward-referenced — created in Task A10.

---

### Task A10: Implement host backings for settings store, permissions API, logger; implement `ExtensionLoader`

**Files:**
- Create: `Core/Host/HostSettingsStore.swift`
- Create: `Core/Host/HostPermissionsAPI.swift`
- Create: `Core/Host/HostLogger.swift`
- Create: `Core/Host/ExtensionLoader.swift`

- [ ] **Step 1: Create `HostLogger.swift`**

```swift
import Foundation
import NotchKit
import os

final class HostLogger: NSObject, NotchLogger {
    private let logger = os.Logger(subsystem: "com.theboredteam.notch", category: "extension")

    @objc func log(level: NotchLogLevel, message: String) {
        switch level {
        case .debug:   logger.debug("\(message, privacy: .public)")
        case .info:    logger.info("\(message, privacy: .public)")
        case .notice:  logger.notice("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error:   logger.error("\(message, privacy: .public)")
        @unknown default:
            logger.info("\(message, privacy: .public)")
        }
    }
}
```

- [ ] **Step 2: Create `HostSettingsStore.swift`**

```swift
import Foundation
import NotchKit

/// `UserDefaults`-backed settings store. Keys are *not* namespaced in v1 to
/// preserve existing user defaults across the refactor (see spec §6.2). v2
/// will introduce extension-id prefixes via a migration step.
final class HostSettingsStore: NSObject, NotchSettingsStore {

    private let defaults = UserDefaults.standard
    private var observers: [String: Set<ObjectIdentifier>] = [:]
    private var observationCallbacks: [ObjectIdentifier: (Any?) -> Void] = [:]
    private let lock = NSLock()

    @objc func setValue(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    @objc func value(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    @objc func observe(key: String,
                       handler: @escaping (Any?) -> Void) -> NotchObservation {
        let kvoToken = NSObject()
        let id = ObjectIdentifier(kvoToken)
        lock.lock()
        observers[key, default: []].insert(id)
        observationCallbacks[id] = handler
        lock.unlock()

        defaults.addObserver(self, forKeyPath: key, options: [.new], context: nil)

        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.observers[key]?.remove(id)
            self.observationCallbacks.removeValue(forKey: id)
            self.lock.unlock()
            self.defaults.removeObserver(self, forKeyPath: key)
        }
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath else { return }
        let value = change?[.newKey]
        lock.lock()
        let ids = observers[keyPath] ?? []
        let callbacks = ids.compactMap { observationCallbacks[$0] }
        lock.unlock()
        callbacks.forEach { $0(value) }
    }
}
```

- [ ] **Step 3: Create `HostPermissionsAPI.swift`**

```swift
import AVFoundation
import EventKit
import Foundation
import NotchKit

final class HostPermissionsAPI: NSObject, NotchPermissionsAPI {

    @objc func status(for permission: NotchPermissionKind) -> NotchPermissionStatus {
        switch permission {
        case .calendar:      return mapEK(EKEventStore.authorizationStatus(for: .event))
        case .reminders:     return mapEK(EKEventStore.authorizationStatus(for: .reminder))
        case .camera:        return mapAV(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:    return mapAV(AVCaptureDevice.authorizationStatus(for: .audio))
        case .accessibility: return AXIsProcessTrusted() ? .granted : .notDetermined
        case .mediaLibrary:  return .unsupported // No current extension uses MediaLibrary; v2 wires this up
        case .fileShelf:     return .granted     // file access is implicit
        @unknown default:    return .unsupported
        }
    }

    @objc func request(_ permission: NotchPermissionKind,
                       completion: @escaping (NotchPermissionStatus) -> Void) {
        switch permission {
        case .calendar:
            EKEventStore().requestFullAccessToEvents { granted, _ in
                completion(granted ? .granted : .denied)
            }
        case .reminders:
            EKEventStore().requestFullAccessToReminders { granted, _ in
                completion(granted ? .granted : .denied)
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { completion($0 ? .granted : .denied) }
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { completion($0 ? .granted : .denied) }
        case .accessibility:
            // Proxy to existing XPC helper. Triggers the system prompt.
            Task { @MainActor in
                let granted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                completion(granted ? .granted : .denied)
            }
        case .mediaLibrary, .fileShelf:
            completion(status(for: permission))
        @unknown default:
            completion(.unsupported)
        }
    }

    private func mapEK(_ s: EKAuthorizationStatus) -> NotchPermissionStatus {
        switch s {
        case .notDetermined: return .notDetermined
        case .fullAccess, .authorized: return .granted
        case .denied, .restricted, .writeOnly: return .denied
        @unknown default: return .notDetermined
        }
    }

    private func mapAV(_ s: AVAuthorizationStatus) -> NotchPermissionStatus {
        switch s {
        case .notDetermined: return .notDetermined
        case .authorized:    return .granted
        case .denied, .restricted: return .denied
        @unknown default: return .notDetermined
        }
    }
}
```

- [ ] **Step 4: Create `ExtensionLoader.swift`**

```swift
import AppKit
import Foundation
import NotchKit

/// Discovers `.notchext` bundles, loads them, and activates each on the
/// supplied host. Failures are logged and skipped — one bad extension does
/// not abort loading.
final class ExtensionLoader {

    struct LoadFailure {
        let bundleURL: URL
        let reason: String
    }

    private(set) var failures: [LoadFailure] = []

    func load(into host: ExtensionHost) {
        let urls = scanBundles()
        for url in urls {
            loadBundle(url: url, into: host)
        }
    }

    private func scanBundles() -> [URL] {
        var urls: [URL] = []

        // 1. Built-ins: Contents/PlugIns
        if let plugInsURL = Bundle.main.builtInPlugInsURL {
            urls.append(contentsOf: scan(directory: plugInsURL))
        }

        // 2. User-installed: ~/Library/Application Support/Notch/Extensions
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask).first {
            let userDir = appSupport
                .appendingPathComponent("Notch", isDirectory: true)
                .appendingPathComponent("Extensions", isDirectory: true)
            urls.append(contentsOf: scan(directory: userDir))
        }
        return urls
    }

    private func scan(directory: URL) -> [URL] {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil) else { return [] }
        return entries.filter { $0.pathExtension == "notchext" }
    }

    private func loadBundle(url: URL, into host: ExtensionHost) {
        guard let bundle = Bundle(url: url) else {
            failures.append(.init(bundleURL: url, reason: "Bundle(url:) returned nil"))
            return
        }
        do {
            try bundle.loadAndReturnError()
        } catch {
            failures.append(.init(bundleURL: url, reason: "loadAndReturnError: \(error)"))
            return
        }
        guard let principalClass = bundle.principalClass as? NSObject.Type,
              let extType = principalClass as? NotchExtension.Type else {
            failures.append(.init(bundleURL: url, reason: "principalClass is not NotchExtension"))
            return
        }

        // Best-effort exception trap for misbehaving extensions during activate.
        let ext = extType.make()
        let result = ObjCExceptionCatcher.try {
            ext.activate(host: host)
        }
        if let exception = result {
            failures.append(.init(bundleURL: url,
                reason: "activate threw NSException: \(exception)"))
            host.logger.log(level: .error,
                message: "Extension \(ext.identifier) threw during activate: \(exception)")
        }
    }
}
```

- [ ] **Step 5: Create the Obj-C exception catcher**

Create `Core/Host/ObjCExceptionCatcher.h`:

```objc
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject
+ (nullable NSException *)tryBlock:(void (^)(void))block NS_SWIFT_NAME(try(_:));
@end

NS_ASSUME_NONNULL_END
```

Create `Core/Host/ObjCExceptionCatcher.m`:

```objc
#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher
+ (NSException *)tryBlock:(void (^)(void))block {
    @try {
        block();
        return nil;
    } @catch (NSException *exception) {
        return exception;
    }
}
@end
```

In Xcode: add both files to the host target. If the host target doesn't already have a bridging header, add one (`Core/Host/Notch-Bridging-Header.h`) and import:

```objc
#import "ObjCExceptionCatcher.h"
```

Set the host's `SWIFT_OBJC_BRIDGING_HEADER` build setting to `Core/Host/Notch-Bridging-Header.h`.

- [ ] **Step 6: Build the host target**

⌘B. Expected: BUILD SUCCEEDED. Both `ExtensionHost` and `ExtensionLoader` reference symbols from `NotchKit`, so this verifies the import chain works end-to-end.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "Implement host's NotchHost adapters and ExtensionLoader"
```

---

### Task A11: NotchKit unit tests for the contribution registry

**Files:**
- Create: `Core/NotchKitTests/ContributionRegistryTests.swift`

- [ ] **Step 1: Add an XCTest target `NotchKitTests` to the workspace**

In Xcode: File → New → Target → macOS → Unit Testing Bundle. Name: `NotchKitTests`. Target to be tested: `NotchKit`.

- [ ] **Step 2: Write the failing test**

Create `Core/NotchKitTests/ContributionRegistryTests.swift`:

```swift
import XCTest
@testable import NotchKit
import AppKit

@MainActor
final class ContributionRegistryTests: XCTestCase {

    // The registry under test lives in Host code (ExtensionHost). For unit
    // testing we substitute a minimal in-NotchKit shim that has the same
    // contract: append-style registration, dedup-by-kind for keyed slots.
    //
    // This test exercises the *contribution types' init paths* (which are in
    // NotchKit) and the dedup contract documented on each registration method.

    func testTabContributionInitPreservesIdentity() {
        let factory: @convention(block) () -> NSViewController = { NSViewController() }
        let tab = NotchTabContribution(
            identifier: "test.tab",
            title: "Test",
            systemImage: "star",
            lifecyclePolicy: .onDemand,
            makeViewController: factory)
        XCTAssertEqual(tab.identifier, "test.tab")
        XCTAssertEqual(tab.title, "Test")
        XCTAssertEqual(tab.systemImage, "star")
        XCTAssertEqual(tab.lifecyclePolicy, .onDemand)
        // Factory is callable
        let vc = tab.makeViewController()
        XCTAssertNotNil(vc.view)
    }

    func testSneakPeekKindIsRequired() {
        let factory: @convention(block) () -> NSViewController = { NSViewController() }
        let s = NotchSneakPeekContribution(kind: "music",
                                            lifecyclePolicy: .onDemand,
                                            makeViewController: factory)
        XCTAssertEqual(s.kind, "music")
    }

    func testHomeFragmentPriorityIsStable() {
        let factory: @convention(block) () -> NSViewController = { NSViewController() }
        let f1 = NotchHomeFragmentContribution(identifier: "music",  priority: 100,
                                                lifecyclePolicy: .onDemand,
                                                makeViewController: factory)
        let f2 = NotchHomeFragmentContribution(identifier: "calendar", priority: 200,
                                                lifecyclePolicy: .onDemand,
                                                makeViewController: factory)
        XCTAssertLessThan(f1.priority, f2.priority)
    }
}
```

- [ ] **Step 3: Run the test**

⌘U with the `NotchKitTests` scheme. Expected: tests **pass** (these tests are about NotchKit-only init paths; nothing depends on the loader yet). If anything fails, fix the contribution types until they pass.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "NotchKit unit tests for contribution-type init paths"
```

---

### Task A12: Configure host entitlements for library validation opt-out

**Files:**
- Modify: `Core/Host/boringNotch.entitlements`

- [ ] **Step 1: Read current entitlements**

```bash
cat Core/Host/boringNotch.entitlements
```

Note the current keys.

- [ ] **Step 2: Add the library-validation disable key**

In Xcode: select `Core/Host/boringNotch.entitlements` → add row:

- Key: `com.apple.security.cs.disable-library-validation`
- Type: `Boolean`
- Value: `YES`

(Or edit the plist XML directly — same effect.)

- [ ] **Step 3: Confirm Hardened Runtime is enabled in build settings**

In Xcode: select host target → Signing & Capabilities → confirm "Hardened Runtime" is enabled. If not, add it via the `+` button. (Should already be enabled if the host has notarization configured.)

- [ ] **Step 4: Build and run the host**

⌘R. Expected: app launches normally. The entitlement opt-out has no functional effect until extensions are loaded.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Disable library validation on host to allow third-party .notchext loading"
```

---

### Task A13: Configure host's "Copy Files (PlugIns)" build phase

**Files:**
- Modify: `Core/Notch.xcodeproj/project.pbxproj` (via Xcode UI)

- [ ] **Step 1: Add a Copy Files build phase to the host target**

In Xcode: select host target → Build Phases → click `+` at the top-left of the phases list → "New Copy Files Phase".

- Name: `Embed Plug-ins`
- Destination: `Plugins` (this is `Contents/PlugIns/` at runtime)
- Subpath: (leave empty)

- [ ] **Step 2: Verify the embed framework phase is correct**

Confirm the existing "Embed Frameworks" phase has `NotchKit.framework` with **Code Sign on Copy = ✓**. If not, fix it.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "Add Embed Plug-ins build phase to host target (empty for now)"
```

---

### Task A14: Create `Extensions/Tips/TipsExtension.xcodeproj`

**Files:**
- Create: `Extensions/Tips/TipsExtension.xcodeproj/project.pbxproj`
- Create: `Extensions/Tips/Resources/Info.plist`
- Create: `Extensions/Tips/Sources/.gitkeep`
- Modify: `Notch.xcworkspace/contents.xcworkspacedata`

- [ ] **Step 1: Create directories**

```bash
mkdir -p Extensions/Tips/Sources Extensions/Tips/Resources
touch Extensions/Tips/Sources/.gitkeep
```

- [ ] **Step 2: Create `Extensions/Tips/Resources/Info.plist`**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key>
  <string>com.theboredteam.notch.extensions.tips</string>
  <key>CFBundleName</key>
  <string>Tips</string>
  <key>CFBundleDisplayName</key>
  <string>Tips</string>
  <key>CFBundlePackageType</key>
  <string>BNDL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>NSPrincipalClass</key>
  <string>$(PRODUCT_MODULE_NAME).TipsExtension</string>
</dict>
</plist>
```

- [ ] **Step 3: In Xcode, add a new project under the workspace**

File → New → Project → macOS → Bundle. Project name: `TipsExtension`. Save in `Extensions/Tips/` so the project file lands at `Extensions/Tips/TipsExtension.xcodeproj`. **Important:** when prompted for "Add to Workspace", select `Notch.xcworkspace`.

- [ ] **Step 4: Configure the bundle target build settings**

Select `TipsExtension` target → Build Settings:

- **Wrapper Extension:** `notchext`
- **Info.plist File:** `Extensions/Tips/Resources/Info.plist`
- **Product Bundle Identifier:** `com.theboredteam.notch.extensions.tips`
- **Deployment Target:** macOS 14.0
- **Bundle Loader:** (leave empty)
- **Skip Install:** `NO`
- **Mach-O Type:** `Bundle`
- **Other Linker Flags:** add `-undefined dynamic_lookup` is *not* needed; instead link against NotchKit (next step).
- **Runpath Search Paths:** `@loader_path/../../../../Frameworks`
- **Defines Module:** `YES`

- [ ] **Step 5: Link against `NotchKit.framework` without embedding**

Select `TipsExtension` target → Build Phases:

1. "Link Binary With Libraries" → `+` → add `NotchKit.framework` from the workspace.
2. **Do not** add an "Embed Frameworks" phase. Confirm the framework is "Do Not Embed" / "Required" linkage in General → Frameworks.

- [ ] **Step 6: Add `TipsExtension` as a target dependency of the host**

Select host `Notch` target → Build Phases → "Target Dependencies" → `+` → add `TipsExtension`.

Add to host's "Embed Plug-ins" phase: `+` → `TipsExtension.notchext` (the product). Set "Code Sign on Copy = ✓".

- [ ] **Step 7: Verify project layout**

```bash
ls Extensions/Tips/
```

Should show: `Resources/`, `Sources/`, `TipsExtension.xcodeproj`.

```bash
cat Notch.xcworkspace/contents.xcworkspacedata
```

Should now contain a `<FileRef location="group:Extensions/Tips/TipsExtension.xcodeproj">` entry alongside the `Core/Notch.xcodeproj` entry.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "Add TipsExtension.xcodeproj scaffold (no source yet)"
```

---

### Task A15: Move `TipStore.swift` and write the principal class

**Files:**
- Move: `boringNotch/components/Tips/TipStore.swift` → `Extensions/Tips/Sources/TipStore.swift`
- Create: `Extensions/Tips/Sources/TipsExtension.swift`

- [ ] **Step 1: Move `TipStore.swift`**

```bash
git mv boringNotch/components/Tips/TipStore.swift Extensions/Tips/Sources/TipStore.swift
```

(There is no `Core/Host/Tips/` because Tips is *fully* an extension — no leftover host code.)

- [ ] **Step 2: Add `TipStore.swift` to the `TipsExtension` target**

In Xcode: drag `TipStore.swift` into the `TipsExtension` group. Confirm Target Membership = `TipsExtension`.

- [ ] **Step 3: Read the moved file to confirm what's inside**

Read `Extensions/Tips/Sources/TipStore.swift`. It defines the existing tips data model. The only edit needed is access modifiers on types we expose — but since this file is internal to the extension's bundle (the host doesn't use it), no edits are required at this step.

- [ ] **Step 4: Create `Extensions/Tips/Sources/TipsExtension.swift`**

```swift
import AppKit
import NotchKit
import SwiftUI

@objc(TipsExtension)
public final class TipsExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { TipsExtension() }

    @objc public var identifier: String { "com.theboredteam.notch.tips" }
    @objc public var displayName: String { "Tips" }

    @objc public func activate(host: NotchHost) {
        let factory: @convention(block) () -> NSViewController = {
            NSHostingController(rootView: TipsTabView())
        }

        host.register(tab: NotchTabContribution(
            identifier: "com.theboredteam.notch.tips.tab",
            title: "Tips",
            systemImage: "lightbulb",
            lifecyclePolicy: .onDemand,
            makeViewController: factory))
    }
}

// Minimal placeholder UI for Phase A. Real content is wired up in Phase C.
private struct TipsTabView: View {
    var body: some View {
        VStack {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 32))
            Text("Tips")
                .font(.headline)
            Text("Loaded from TipsExtension.notchext")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 5: Add file to target**

Drag `TipsExtension.swift` into the Xcode `TipsExtension` group. Confirm target membership.

- [ ] **Step 6: Build the extension target alone**

In Xcode, select the `TipsExtension` scheme, ⌘B. Expected: BUILD SUCCEEDED. The product `TipsExtension.notchext` should appear in DerivedData.

- [ ] **Step 7: Verify the bundle structure**

```bash
find ~/Library/Developer/Xcode/DerivedData -name "TipsExtension.notchext" -type d 2>/dev/null | head -1
```

Inspect `Contents/`:

```
Contents/
├── Info.plist
├── MacOS/TipsExtension     # the dylib
└── _CodeSignature/CodeResources
```

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "TipsExtension principal class + move TipStore.swift"
```

---

### Task A16: Wire `ExtensionHost.shared.start()` into the host's launch sequence

**Files:**
- Modify: `Core/Host/boringNotchApp.swift`

- [ ] **Step 1: Find the right place in `applicationDidFinishLaunching`**

Read `Core/Host/boringNotchApp.swift` lines 282-440. The first window is created near line 415-421. We add the `ExtensionHost.shared.start()` call **after** that block and **before** `setupDragDetectors()`.

- [ ] **Step 2: Add the import and call**

Edit `Core/Host/boringNotchApp.swift`:

At the top of the file, after existing imports, add:

```swift
import NotchKit
```

In `applicationDidFinishLaunching`, immediately after the `if !Defaults[.showOnAllDisplays] { ... } else { ... }` block that creates the first window (around line 421), add:

```swift
        ExtensionHost.shared.start()
```

- [ ] **Step 3: Build and run**

⌘R. Expected: app launches normally; in the Xcode console, log lines from `ExtensionLoader` appear if any bundle fails. With `TipsExtension.notchext` correctly embedded, no failures should appear.

- [ ] **Step 4: Verify in lldb that the loader instantiated TipsExtension**

While the app is running:

1. In Xcode: Debug → Pause (⌘⌃Y).
2. In the lldb console:

```
(lldb) po (id)[ExtensionHost shared].tabs
```

Expected output: an array containing one `NotchTabContribution` with identifier `"com.theboredteam.notch.tips.tab"`.

```
(lldb) image list NotchKit
```

Expected output: exactly one entry for `NotchKit.framework` — no duplicate. The extension must resolve to the host's NotchKit.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Boot ExtensionHost from boringNotchApp.applicationDidFinishLaunching"
```

---

### Task A17: Add CI lint to forbid NotchKit embedding inside extension bundles

**Files:**
- Create: `scripts/check_no_notchkit_embed.sh`
- Modify: `.github/workflows/cicd.yml` (or wherever existing CI runs)

- [ ] **Step 1: Create the lint script**

Create `scripts/check_no_notchkit_embed.sh`:

```bash
#!/usr/bin/env bash
# Verifies that no .notchext bundle embeds NotchKit.framework. Extensions
# must link against the host-embedded copy via @rpath; embedding leads to
# two separate type identities at runtime.
set -euo pipefail

APP_PATH="${1:?Usage: $0 <path-to-boringNotch.app>}"

if [ ! -d "$APP_PATH/Contents/PlugIns" ]; then
    echo "No PlugIns directory; nothing to check."
    exit 0
fi

failures=0
for ext in "$APP_PATH/Contents/PlugIns"/*.notchext; do
    if [ -d "$ext/Contents/Frameworks/NotchKit.framework" ]; then
        echo "ERROR: $ext embeds NotchKit.framework — extensions must NOT embed NotchKit."
        failures=$((failures + 1))
    fi
done

if [ "$failures" -gt 0 ]; then
    exit 1
fi
echo "OK: no extension embeds NotchKit.framework"
```

```bash
chmod +x scripts/check_no_notchkit_embed.sh
```

- [ ] **Step 2: Run the script locally against the just-built app**

```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -name "boringNotch.app" -type d 2>/dev/null | head -1)
./scripts/check_no_notchkit_embed.sh "$APP"
```

Expected output: `OK: no extension embeds NotchKit.framework`

- [ ] **Step 3: Add the check to CI**

Edit `.github/workflows/cicd.yml`. After the existing build step that produces the app, add (under the same job):

```yaml
      - name: Verify NotchKit dedup
        run: ./scripts/check_no_notchkit_embed.sh "$BUILD_DIR/boringNotch.app"
```

(Adjust `$BUILD_DIR` to match the existing workflow's variable for the built app's directory.)

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "CI lint: forbid NotchKit embedding inside .notchext bundles"
```

---

### Task A18: Manual verification gate for Phase A

- [ ] **Step 1: Clean build and run**

```bash
# In Xcode: Product → Clean Build Folder, then ⌘R
```

Expected: app launches with no errors, the existing notch UI appears unchanged (only Tips is loaded as an extension; Music/Shelf/Calendar/etc. are still in core code at this point — Phase C migrates them).

- [ ] **Step 2: Verify a third-party signed extension also loads**

Build TipsExtension separately with `xcodebuild`, copy the output to the user directory:

```bash
mkdir -p ~/Library/Application\ Support/Notch/Extensions/
cp -R "$(find ~/Library/Developer/Xcode/DerivedData -name TipsExtension.notchext -type d | head -1)" \
      ~/Library/Application\ Support/Notch/Extensions/TipsUserCopy.notchext
# Re-sign with an ad-hoc identity to simulate a third-party
codesign --force --sign - ~/Library/Application\ Support/Notch/Extensions/TipsUserCopy.notchext
```

Relaunch the app. Expected: `ExtensionHost.shared.tabs` contains *two* tab contributions (the built-in Tips and the user-installed copy), confirming the loader scans both directories and library validation is correctly disabled.

- [ ] **Step 3: Clean up the user-installed copy before continuing**

```bash
rm -rf ~/Library/Application\ Support/Notch/Extensions/TipsUserCopy.notchext
```

- [ ] **Step 4: Document the verification result**

If both verifications pass, Phase A is complete. Note in the PR description that lldb confirmed single-image NotchKit resolution and ad-hoc-signed extensions load correctly.

---

# Phase B — Host services + registry-driven host

Goal of Phase B: `BoringViewCoordinator` and `ContentView` switch from hard-coded slot rendering to registry-based lookup. After this phase, the notch surface is empty for any slot whose claiming extension hasn't been migrated yet — but the *core* still renders.

### Task B1: Implement host-side service adapters

**Files:**
- Create: `Core/Host/Services/NotchStateServiceAdapter.swift`
- Create: `Core/Host/Services/ScreenServiceAdapter.swift`
- Create: `Core/Host/Services/CoordinatorServiceAdapter.swift`

- [ ] **Step 1: Create `NotchStateServiceAdapter.swift`**

```swift
import AppKit
import Combine
import Foundation
import NotchKit

/// Adapts a single `BoringViewModel` to the `NotchNotchStateHost` protocol.
final class NotchStateServiceAdapter: NSObject, NotchNotchStateHost {

    private let viewModel: BoringViewModel
    private var cancellables: Set<AnyCancellable> = []
    private var notchStateHandlers: [UUID: (NotchOpenState) -> Void] = [:]
    private var hoverHandlers: [UUID: (Bool) -> Void] = [:]
    private let lock = NSLock()

    init(viewModel: BoringViewModel) {
        self.viewModel = viewModel
        super.init()

        viewModel.$notchState.sink { [weak self] state in
            guard let self else { return }
            let mapped: NotchOpenState = (state == .open ? .open : .closed)
            self.lock.lock()
            let handlers = Array(self.notchStateHandlers.values)
            self.lock.unlock()
            handlers.forEach { $0(mapped) }
        }.store(in: &cancellables)

        viewModel.$hovering.sink { [weak self] hovering in
            guard let self else { return }
            self.lock.lock()
            let handlers = Array(self.hoverHandlers.values)
            self.lock.unlock()
            handlers.forEach { $0(hovering) }
        }.store(in: &cancellables)
    }

    @objc var notchState: NotchOpenState {
        viewModel.notchState == .open ? .open : .closed
    }

    @objc var hovering: Bool { viewModel.hovering }

    // NOTE: handler removal uses UUID tokens, not closure-as-AnyObject identity.
    // Bridging a Swift closure to AnyObject does not produce a stable identity
    // (each `as AnyObject` cast may box anew), so `===` would never match the
    // stored handler and `invalidate()` would silently leak observers.

    @objc func observeNotchState(_ handler: @escaping (NotchOpenState) -> Void) -> NotchObservation {
        let id = UUID()
        lock.lock(); notchStateHandlers[id] = handler; lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.notchStateHandlers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc func observeHover(_ handler: @escaping (Bool) -> Void) -> NotchObservation {
        let id = UUID()
        lock.lock(); hoverHandlers[id] = handler; lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.hoverHandlers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc func open()  { Task { @MainActor in viewModel.open()  } }
    @objc func close() { Task { @MainActor in viewModel.close() } }
}
```

(If `BoringViewModel` doesn't currently expose `hovering` as `@Published`, that's a known gap — handle it by having the adapter publish from `BoringViewModel`'s existing hover state mechanism or, if absent, default to `false` and update in B5.)

NOTE: `NotchStateServiceAdapter` does NOT need the cached-snapshot pattern used by the other two adapters below. `BoringViewModel` is not `@MainActor`-isolated, so `viewModel.notchState` and `viewModel.hovering` are safe to read from any thread via the `@objc` getters above. The Combine `.sink` callbacks already deliver on the publisher's queue (typically main), and `Task { @MainActor in viewModel.open() }` handles the `@MainActor`-only methods on `BoringViewModel` (currently none, but the open/close path goes through MainActor anyway).

- [ ] **Step 2: Create `ScreenServiceAdapter.swift`**

```swift
import Foundation
import NotchKit

final class ScreenServiceAdapter: NSObject, NotchScreenHost {

    private let coordinator: BoringViewCoordinator
    private var observers: [UUID: (String) -> Void] = [:]
    private var cachedScreenUUID: String
    private let lock = NSLock()

    init(coordinator: BoringViewCoordinator) {
        self.coordinator = coordinator
        // Read once at init under MainActor (init is called from host start() on main).
        self.cachedScreenUUID = MainActor.assumeIsolated { coordinator.selectedScreenUUID }
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(screenChanged),
            name: .selectedScreenChanged, object: nil)
    }

    // NOTE: BoringViewCoordinator is @MainActor-isolated; the @objc protocol surface
    // is nonisolated. Extensions are free to invoke this getter from a background
    // queue, so we cannot use MainActor.assumeIsolated here (it would trap). Instead
    // we keep a cached snapshot guarded by the same lock used for handler storage,
    // refreshed on the .selectedScreenChanged notification.
    @objc var selectedScreenUUID: String {
        lock.lock(); defer { lock.unlock() }
        return cachedScreenUUID
    }

    @objc func observeSelectedScreen(_ handler: @escaping (String) -> Void) -> NotchObservation {
        let id = UUID()
        lock.lock(); observers[id] = handler; lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.observers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc private func screenChanged() {
        // Notification can fire on any thread; hop to MainActor to read the
        // @MainActor-isolated coordinator, then refresh the cached snapshot
        // and dispatch to observers.
        Task { @MainActor in
            let uuid = self.coordinator.selectedScreenUUID
            self.lock.lock()
            self.cachedScreenUUID = uuid
            let copy = Array(self.observers.values)
            self.lock.unlock()
            copy.forEach { $0(uuid) }
        }
    }
}
```

- [ ] **Step 3: Create `CoordinatorServiceAdapter.swift`**

```swift
import Foundation
import NotchKit

final class CoordinatorServiceAdapter: NSObject, NotchCoordinatorHost {

    private let coordinator: BoringViewCoordinator
    private var tabHandlers: [UUID: (String) -> Void] = [:]
    private var cachedTabIdentifier: String
    private let lock = NSLock()

    init(coordinator: BoringViewCoordinator) {
        self.coordinator = coordinator
        // Read once at init under MainActor (init is called from host start() on main).
        self.cachedTabIdentifier = MainActor.assumeIsolated { coordinator.currentTabIdentifier }
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(currentTabChanged),
            name: .currentTabIdentifierChanged, object: nil)
    }

    // See ScreenServiceAdapter for the rationale on cached-snapshot reads.
    @objc var currentTabIdentifier: String {
        lock.lock(); defer { lock.unlock() }
        return cachedTabIdentifier
    }

    @objc func observeCurrentTab(_ handler: @escaping (String) -> Void) -> NotchObservation {
        let id = UUID()
        lock.lock(); tabHandlers[id] = handler; lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.tabHandlers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc func showTab(_ identifier: String) {
        // TODO(B4): writing currentTabIdentifier doesn't yet flow back to
        // ContentView's tab switch — ContentView still observes
        // coordinator.currentView (the NotchViews enum). Task B4 rewrites
        // ContentView to iterate ExtensionHost.shared.tabs keyed by
        // currentTabIdentifier; until then, calls to showTab from
        // extensions are visible to other adapters/observers but won't
        // change the rendered tab.
        Task { @MainActor in coordinator.currentTabIdentifier = identifier }
    }

    @objc func toggleSneakPeek(kind: String, value: Double, icon: String, durationSeconds: Double) {
        Task { @MainActor in
            coordinator.toggleSneakPeek(
                status: true, kind: kind, duration: durationSeconds, value: CGFloat(value), icon: icon)
        }
    }

    @objc func toggleExpandedItem(kind: String, value: Double, durationSeconds: Double) {
        Task { @MainActor in
            coordinator.toggleExpandingView(
                status: true, kind: kind, duration: durationSeconds, value: CGFloat(value))
        }
    }

    @objc private func currentTabChanged() {
        // Notification can fire on any thread; hop to MainActor to read the
        // @MainActor-isolated coordinator, then refresh the cached snapshot
        // and dispatch to observers.
        Task { @MainActor in
            let id = self.coordinator.currentTabIdentifier
            self.lock.lock()
            self.cachedTabIdentifier = id
            let copy = Array(self.tabHandlers.values)
            self.lock.unlock()
            copy.forEach { $0(id) }
        }
    }
}
```

NOTE: B2 must add a `duration: TimeInterval? = nil` parameter to `BoringViewCoordinator.toggleExpandingView` so `toggleExpandedItem`'s `durationSeconds` flows through. The coordinator stores it in a private `expandingViewDurationOverride: TimeInterval?` field that the `expandingView.didSet` consumes (overriding the existing 2-or-3-second hardcoded fallback). The `Notification.Name.currentTabIdentifierChanged` extension lives in `BoringViewCoordinator.swift` (next to where the notification is posted) — not in `CoordinatorServiceAdapter.swift`.

- [ ] **Step 4: Add files to host target, build**

⌘B. Expected: build will fail because:
- `BoringViewCoordinator.currentTabIdentifier` doesn't exist yet (it has `currentView: NotchViews` instead)
- `toggleSneakPeek` / `toggleExpandingView` signatures don't match (they use `SneakContentType`)

These are fixed in Tasks B2 and B3 — proceed without committing.

---

### Task B2: Replace `SneakContentType` enum dispatch with string-keyed dispatch in `BoringViewCoordinator`

**Files:**
- Modify: `Core/Host/BoringViewCoordinator.swift`

This is the non-verbatim host edit called out in spec §4.3 and §5.1.

- [ ] **Step 1: Read the existing coordinator**

Read `Core/Host/BoringViewCoordinator.swift` lines 1-300. Note the `SneakContentType` enum (lines 13-21), the `sneakPeek` struct (line 23), and the `toggleSneakPeek` / `toggleExpandingView` methods.

- [ ] **Step 2: Replace `SneakContentType` with `String`**

Edit `BoringViewCoordinator.swift`:

Replace lines 13-21:

```swift
enum SneakContentType {
    case brightness
    case volume
    case backlight
    case music
    case mic
    case battery
    case download
}
```

with:

```swift
// Sneak-peek and expanded-item kinds are open string identifiers in v1.
// The well-known kinds used by built-in extensions are documented here for
// reference. Each kind must be claimed by exactly one extension via
// host.register(sneakPeek:) / host.register(expandedItem:).
//
//   "brightness", "volume", "backlight"  → HUDExtension
//   "music"                              → MusicExtension
//   "mic"                                → HUDExtension
//   "battery"                            → BatteryExtension
//   "download"                           → LiveActivitiesExtension
```

- [ ] **Step 3: Update `sneakPeek` struct and `ExpandedItem` struct**

Replace `var type: SneakContentType = .music` with `var kind: String = "music"`. Same for `ExpandedItem.type` → `ExpandedItem.kind`.

- [ ] **Step 4: Update `toggleSneakPeek` signature**

Find:

```swift
func toggleSneakPeek(
    status: Bool, type: SneakContentType, duration: TimeInterval = 1.5, value: CGFloat = 0,
    icon: String = ""
) {
```

Replace with:

```swift
func toggleSneakPeek(
    status: Bool, kind: String, duration: TimeInterval = 1.5, value: CGFloat = 0,
    icon: String = ""
) {
```

In the body, replace `if type != .music` with `if kind != "music"`. Replace `self.sneakPeek.type = type` with `self.sneakPeek.kind = kind`. Replace `if type == .mic` with `if kind == "mic"`.

- [ ] **Step 5: Update `toggleExpandingView`**

Same treatment: parameter name `type: SneakContentType` → `kind: String`. Body comparisons: `expandingView.type == .download` → `expandingView.kind == "download"`.

Also add a `duration: TimeInterval? = nil` parameter and a private `expandingViewDurationOverride: TimeInterval?` field. The function body sets `expandingViewDurationOverride = duration`. The `expandingView.didSet` reads `expandingViewDurationOverride ?? (expandingView.kind == "download" ? 2 : 3)` to choose the auto-hide duration. This lets `CoordinatorServiceAdapter.toggleExpandedItem(durationSeconds:)` flow through to the actual auto-hide timer instead of being silently swallowed.

- [ ] **Step 6: Add `currentTabIdentifier`**

After the `currentView` declaration, add:

```swift
@Published var currentTabIdentifier: String = "home" {
    didSet {
        NotificationCenter.default.post(
            name: .currentTabIdentifierChanged, object: nil)
    }
}
```

The existing `currentView: NotchViews` enum is kept and made a thin wrapper that derives from `currentTabIdentifier`: setting `currentView = .shelf` is rewritten to `currentTabIdentifier = "com.theboredteam.notch.shelf.tab"`. Replace the `currentView` declaration body with:

```swift
@Published var currentView: NotchViews = .home {
    didSet {
        switch currentView {
        case .home:  currentTabIdentifier = "home"
        case .shelf: currentTabIdentifier = "com.theboredteam.notch.shelf.tab"
        }
    }
}
```

(The `home` identifier is the well-known string used by Tips' tab placeholder; once Music registers its home-tab fragment in Phase C the home view becomes Music + Calendar + Webcam fragments composed by `NotchHomeView`.) `currentView` is left in place because `boringNotchApp.swift:230` and `:366` set `coordinator.currentView = .shelf` from drag-detector and onboarding code paths — those callsites stay unchanged in Phase B and continue working through this wrapper.

- [ ] **Step 7: Find every caller of the old methods inside the host**

```bash
grep -rn "SneakContentType\|toggleSneakPeek(.*type:\|toggleExpandingView(.*type:" Core/Host/
```

Each match needs the keyword changed from `type:` to `kind:` and the enum value to its string equivalent (`.music` → `"music"`, etc.). Update all matches.

- [ ] **Step 8: Build**

⌘B. Expected: build now succeeds for the host. The `CoordinatorServiceAdapter` should compile. The `NotchStateServiceAdapter` may still be missing `BoringViewModel.hovering` — see Task B3.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "Switch BoringViewCoordinator from SneakContentType enum to string kinds"
```

---

### Task B3: Wire host service adapters into `ExtensionHost.start()`

**Files:**
- Modify: `Core/Host/ExtensionHost.swift`
- Modify: `Core/Host/boringNotchApp.swift`
- Modify: `Core/Host/Models/BoringViewModel.swift` (add `hovering` if missing)

- [ ] **Step 1: Verify `BoringViewModel.hovering` exists**

```bash
grep -n "hovering" Core/Host/Models/BoringViewModel.swift
```

If missing, add a `@Published var hovering: Bool = false` property near the other `@Published` properties. Wire it from `ContentView.swift`'s hover detection (find existing `isHovering` references and mirror them into `vm.hovering`).

- [ ] **Step 2: Modify `ExtensionHost.start()` to register service factories before loading extensions**

Edit `Core/Host/ExtensionHost.swift`:

Replace `func start()` body with:

```swift
func start() {
    // Single-display path: services bind to the AppDelegate's primary `vm`.
    // Multi-display path: callers pass a screenUUID; we look up per-screen
    // adapters from the AppDelegate's viewModels dictionary.
    registerService(kind: "notch-state") {
        guard let vm = (NSApp.delegate as? AppDelegate)?.vm else { return nil }
        return NotchStateServiceAdapter(viewModel: vm)
    }
    registerScreenScopedService(kind: "notch-state") { uuid in
        guard let vm = (NSApp.delegate as? AppDelegate)?.viewModels[uuid] else { return nil }
        return NotchStateServiceAdapter(viewModel: vm)
    }
    registerService(kind: "screen") {
        ScreenServiceAdapter(coordinator: BoringViewCoordinator.shared)
    }
    registerService(kind: "coordinator") {
        CoordinatorServiceAdapter(coordinator: BoringViewCoordinator.shared)
    }

    ExtensionLoader().load(into: self)
    DispatchQueue.main.async {
        NotificationCenter.default.post(
            name: ExtensionHost.didLoadExtensionsNotification, object: nil)
    }
}
```

- [ ] **Step 3: Build**

⌘B. Expected: BUILD SUCCEEDED.

- [ ] **Step 4: Run; verify Tips tab still shows**

⌘R. Expected: app runs, Tips tab is visible (placeholder UI from Task A15). The string-kinded coordinator now drives sneak-peek dispatch but is exercised only by core code; that core code (in `ContentView` for sneak-peek rendering) still uses the *built-in* feature switches in v1 — Phase B's next step replaces those.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Register host service factories on ExtensionHost.start()"
```

---

### Task B4: Switch `ContentView` to registry-based slot rendering

**Files:**
- Modify: `Core/Host/ContentView.swift`

This is the largest rewrite in the host. The spec calls it out (§5.1, §5.4). Ground rules:

- All layout / animation / shape / gesture / chin-width logic stays verbatim.
- Hard-coded references to `MusicVisualizer`, `BoringBattery`, `DownloadView`, `OpenNotchHUD`, `InlineHUD`, `LiveActivityModifier`, `WebcamView`, `NotchHomeView`, `ShelfView`, `BoringCalendar` are replaced with iteration over `ExtensionHost.shared.<slot>`.

- [ ] **Step 1: Read the existing `ContentView` and `NotchLayout`**

```bash
wc -l Core/Host/ContentView.swift
grep -n "MusicVisualizer\|BoringBattery\|DownloadView\|OpenNotchHUD\|InlineHUD\|LiveActivityModifier\|CameraPreviewView\|ShelfView\|BoringCalendar\|NotchHomeView" Core/Host/ContentView.swift
```

Note every line where a feature view is referenced.

- [ ] **Step 2: Add a helper view that renders a contribution**

At the bottom of `Core/Host/ContentView.swift`:

```swift
import NotchKit

struct ContributionViewControllerHost: NSViewControllerRepresentable {
    let make: @convention(block) () -> NSViewController

    func makeNSViewController(context: Context) -> NSViewController { make() }
    func updateNSViewController(_ nsViewController: NSViewController, context: Context) {}
}
```

- [ ] **Step 3: Replace tab content rendering**

Find the `switch coordinator.currentView` block (search for `case .home` / `case .shelf`). Replace its body with iteration over `ExtensionHost.shared.tabs` matching `currentTabIdentifier`:

```swift
Group {
    if let tab = ExtensionHost.shared.tabs.first(
        where: { $0.identifier == coordinator.currentTabIdentifier }) {
        ContributionViewControllerHost(make: tab.makeViewController)
    } else {
        EmptyView()
    }
}
```

- [ ] **Step 4: Replace closed-chin live activities**

Find the section of `NotchLayout` where the closed-chin music live activity is rendered (search for `MusicLiveActivity` / `MusicVisualizer` near the closed-state branch). Replace with:

```swift
HStack {
    ForEach(ExtensionHost.shared.closedChinItems.filter { $0.side == .left },
            id: \.identifier) { contribution in
        ContributionViewControllerHost(make: contribution.makeViewController)
    }
    Spacer()
    ForEach(ExtensionHost.shared.closedChinItems.filter { $0.side == .right },
            id: \.identifier) { contribution in
        ContributionViewControllerHost(make: contribution.makeViewController)
    }
}
```

- [ ] **Step 5: Replace sneak-peek body**

Find the `if coordinator.sneakPeek.show` block. Replace its inner content with:

```swift
if let s = ExtensionHost.shared.sneakPeeks[coordinator.sneakPeek.kind] {
    ContributionViewControllerHost(make: s.makeViewController)
}
```

- [ ] **Step 6: Replace expanded-item body**

Same treatment, looking up `ExtensionHost.shared.expandedItems[coordinator.expandingView.kind]`.

- [ ] **Step 7: Replace HUD replacement body**

Find references to `OpenNotchHUD` / `InlineHUD`. Replace with iteration over `ExtensionHost.shared.hudReplacements` keyed by the HUD kind set elsewhere by the coordinator.

- [ ] **Step 8: Build**

⌘B. Expected: BUILD SUCCEEDED. With no Music/Battery/HUD/Webcam/Shelf/Calendar extensions present yet, those slots render empty.

- [ ] **Step 9: Run**

⌘R. Expected: app launches; the notch shows the empty closed-chin (no music/battery indicator); the open notch shows the Tips tab when selected. The base notch shape, hover, drag, and screen-management still work.

This is the "core still renders" milestone.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "Switch ContentView to registry-based slot rendering"
```

---

### Task B5: Decompose `NotchHomeView.mainContent` into fragments

**Files:**
- Modify: `Core/Host/Notch/NotchHomeView.swift`

This is the second non-verbatim edit called out in spec §5.4.

- [ ] **Step 1: Read the file**

```bash
wc -l Core/Host/Notch/NotchHomeView.swift
```

The composing `struct NotchHomeView: View` is at lines 421-467.

- [ ] **Step 2: Replace `mainContent` with fragment iteration**

Edit `Core/Host/Notch/NotchHomeView.swift` lines 442-466 (the `private var mainContent: some View`):

```swift
private var mainContent: some View {
    HStack(alignment: .top, spacing: 15) {
        ForEach(ExtensionHost.shared.homeFragments, id: \.identifier) { fragment in
            ContributionViewControllerHost(make: fragment.makeViewController)
        }
    }
    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .top)), removal: .opacity))
    .blur(radius: vm.notchState == .closed ? 30 : 0)
}
```

- [ ] **Step 3: Move the existing `MusicPlayerView` / `CalendarView` / `CameraPreviewView` references**

The structs `MusicPlayerView`, `CalendarView`, `CameraPreviewView`, and any other supporting structs in this file *stay in this file for now* — Phase C migrates them to their owning extensions. After Phase C the file shrinks dramatically; in Phase B we leave them as dead code.

- [ ] **Step 4: Build, run**

⌘B, ⌘R. Expected: app launches, Home tab now shows nothing (because no extension has yet registered a `NotchHomeFragmentContribution`). This is the expected Phase B end-state — the fragment plumbing works, but no fragments are claimed.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Replace NotchHomeView.mainContent with fragment iteration"
```

---

### Task B6: Aggregate extension-contributed settings panes

**Files:**
- Modify: `Core/Host/Settings/SettingsView.swift`
- Modify: `Core/Host/Menu/StatusBarMenu.swift`

- [ ] **Step 1: Find the `extensions` case in `SettingsView`**

```bash
grep -n "case extensions\|SettingsEnum" Core/Host/Settings/SettingsView.swift
```

The spec confirmed an `extensions` case exists in `SettingsEnum`.

- [ ] **Step 2: Render extension-contributed panes in the `extensions` case**

In `SettingsView`'s body switch on the selected sidebar enum, replace the `extensions` case body with:

```swift
case .extensions:
    List {
        ForEach(ExtensionHost.shared.settingsPanes, id: \.identifier) { pane in
            DisclosureGroup(pane.title) {
                ContributionViewControllerHost(make: pane.makeViewController)
                    .frame(minHeight: 200)
            }
        }
    }
```

- [ ] **Step 3: Append extension menu items to `StatusBarMenu`**

Edit `Core/Host/Menu/StatusBarMenu.swift`. Find the existing menu construction (built-in entries: Settings, Updates, Restart, Quit). After the existing entries, append:

```swift
if !ExtensionHost.shared.menuBarItems.isEmpty {
    Divider()
    ForEach(ExtensionHost.shared.menuBarItems, id: \.title) { item in
        Button(item.title, action: { item.action() })
    }
}
```

- [ ] **Step 4: Build, run**

⌘B, ⌘R. Expected: Settings → Extensions sidebar entry shows "Tips" with an empty pane (since Tips registers no settings pane in Task A15). Menu bar dropdown shows just the built-ins.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "Aggregate extension-contributed settings panes and menu items"
```

---

### Task B7: Phase B verification gate

- [ ] **Step 1: Manual test the empty-slot fallback**

Launch the app. Expected:
- Notch closed: empty chin (no music/battery indicator).
- Notch open, Tips tab selected: Tips placeholder UI shows.
- Notch open, no other tabs available.
- Settings → Extensions: Tips listed (empty pane).
- Menu bar: only built-in items.

If any feature still renders out of `ContentView`'s old code path, that's a missed substitution from Task B4 — fix and recommit.

- [ ] **Step 2: Verify the regression scope**

The current state of the app *intentionally* lacks Music, Shelf, Calendar, Battery, HUD, Webcam visibility. Confirm that's the case; this is what each Phase C feature migration restores.

---

# Phase C — Feature migrations

Each feature migration is one commit. Per spec §2.1, all moves are `git mv`; edits to moved files are minimal.

The pattern for every migration:

1. Create the extension's xcodeproj under `Extensions/<Feature>/` (similar setup to TipsExtension in Task A14).
2. `git mv` the feature's source files from `boringNotch/<paths>` to `Extensions/<Feature>/Sources/...`.
3. Add the moved files to the extension's target (drag into Xcode).
4. Apply minimal edits to moved files: imports, access modifiers, replace direct host references with `host.service(of:)` calls.
5. Write the principal class file (`<Feature>Extension.swift`) declaring contributions.
6. Add the extension as a target dependency of the host's "Embed Plug-ins" phase.
7. Build, run, manually verify the feature.
8. Commit.

For each feature below, the per-task content lists *exactly* the source-→-destination paths and the *specific* edits needed.

### Task C1: WebcamExtension

**Files moved:**

```bash
mkdir -p Extensions/Webcam/Sources/Views Extensions/Webcam/Resources
git mv boringNotch/managers/WebcamManager.swift Extensions/Webcam/Sources/WebcamManager.swift
git mv boringNotch/components/Webcam/WebcamView.swift Extensions/Webcam/Sources/Views/WebcamView.swift
```

**Files created:**

`Extensions/Webcam/Resources/Info.plist` (parallel to Tips' Info.plist; bundle id `com.theboredteam.notch.extensions.webcam`, NSPrincipalClass `$(PRODUCT_MODULE_NAME).WebcamExtension`).

`Extensions/Webcam/Sources/WebcamExtension.swift`:

```swift
import AppKit
import NotchKit
import SwiftUI

@objc(WebcamExtension)
public final class WebcamExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { WebcamExtension() }
    @objc public var identifier: String { "com.theboredteam.notch.webcam" }
    @objc public var displayName: String { "Webcam" }

    @objc public func activate(host: NotchHost) {
        host.register(permission: NotchPermissionRequest(
            kind: .camera,
            rationale: "Used for the notch's mirror feature."))

        host.register(homeFragment: NotchHomeFragmentContribution(
            identifier: "com.theboredteam.notch.webcam.home-fragment",
            priority: 300,
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: WebcamHomeFragmentView())
            }))
    }
}

private struct WebcamHomeFragmentView: View {
    @StateObject private var manager = WebcamManager.shared
    var body: some View {
        WebcamView()
            .environmentObject(manager)
    }
}
```

**Edits to `WebcamView.swift`:** none expected — it imports SwiftUI and consumes `WebcamManager.shared`. `WebcamManager.shared` is now an extension-internal singleton; the host no longer touches it. If `WebcamView` references `BoringViewModel` via `@EnvironmentObject`, that breaks at the bundle boundary — replace with the host service:

```swift
// At the top of the struct:
@StateObject private var notchState = NotchStateBridge()
```

where `NotchStateBridge` is a small extension-internal `ObservableObject` that wraps `host.service(of: "notch-state") as? NotchNotchStateHost`. This bridge is a recurring pattern across every UI-bearing extension; its template is stored in a shared file `Extensions/_Shared/NotchStateBridge.swift` (created on first migration; reused by Battery, Music, etc.).

**Verification:** webcam mirror toggles in/out; permission prompt shows on first use; closed/open notch hover still works.

**Commit message:** `Migrate WebcamManager and WebcamView into WebcamExtension.notchext`

### Task C2: BatteryExtension

**Files moved:**

```bash
mkdir -p Extensions/Battery/Sources/Views Extensions/Battery/Resources
git mv boringNotch/managers/BatteryActivityManager.swift Extensions/Battery/Sources/BatteryActivityManager.swift
git mv boringNotch/models/BatteryStatusViewModel.swift   Extensions/Battery/Sources/BatteryStatusViewModel.swift
git mv "boringNotch/components/Live activities/BoringBattery.swift" Extensions/Battery/Sources/Views/BoringBattery.swift
```

**Files created:**

`Extensions/Battery/Resources/Info.plist` (bundle id `com.theboredteam.notch.extensions.battery`).

`Extensions/Battery/Sources/BatteryExtension.swift`:

```swift
import AppKit
import NotchKit
import SwiftUI

@objc(BatteryExtension)
public final class BatteryExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { BatteryExtension() }
    @objc public var identifier: String { "com.theboredteam.notch.battery" }
    @objc public var displayName: String { "Battery" }

    @objc public func activate(host: NotchHost) {
        host.register(closedChinItem: NotchClosedChinContribution(
            identifier: "com.theboredteam.notch.battery.chin",
            side: .right,
            priority: 100,
            lifecyclePolicy: .preInstantiated,   // observes power events while hidden
            makeViewController: {
                NSHostingController(rootView: BatteryChinView())
            }))

        host.register(expandedItem: NotchExpandedItemContribution(
            kind: "battery",
            lifecyclePolicy: .onDemand,
            makeViewController: {
                NSHostingController(rootView: BatteryExpandedView())
            }))
    }
}

private struct BatteryChinView: View {
    @StateObject private var model = BatteryStatusViewModel.shared
    var body: some View { BoringBattery(percentage: model.percentage, isCharging: model.isCharging) }
}

private struct BatteryExpandedView: View {
    @StateObject private var model = BatteryStatusViewModel.shared
    var body: some View { /* existing expanded view code */ }
}
```

**Edits to moved files:**
- `BatteryStatusViewModel.swift`: keep `static let shared` (extension-internal singleton). If it references host types like `BoringViewCoordinator` directly, replace with `NotchCoordinatorHost` lookup via the shared bridge file.
- `BoringBattery.swift`: imports SwiftUI; if it references `BoringViewModel`, replace via `NotchStateBridge`.
- `Constants.swift` in core: delete the battery-related `Defaults` keys (the keys themselves stay in `UserDefaults` — only the constant declarations are removed; extension code reads the raw key strings).

**Verification:** plug/unplug power adapter — battery sneak-peek pill appears; expanded item shows charging stats.

**Commit message:** `Migrate Battery feature into BatteryExtension.notchext`

### Task C3: CalendarExtension

**Files moved:**

```bash
mkdir -p Extensions/Calendar/Sources/Views Extensions/Calendar/Resources
git mv boringNotch/managers/CalendarManager.swift             Extensions/Calendar/Sources/CalendarManager.swift
git mv boringNotch/Providers/CalendarServiceProviding.swift   Extensions/Calendar/Sources/CalendarServiceProviding.swift
git mv boringNotch/models/CalendarModel.swift                 Extensions/Calendar/Sources/CalendarModel.swift
git mv boringNotch/models/EventModel.swift                    Extensions/Calendar/Sources/EventModel.swift
git mv boringNotch/components/Calendar/BoringCalendar.swift   Extensions/Calendar/Sources/Views/BoringCalendar.swift
```

**Files created:** `Extensions/Calendar/Resources/Info.plist`, `Extensions/Calendar/Sources/CalendarExtension.swift`.

`CalendarExtension.swift`:

```swift
import AppKit
import NotchKit
import SwiftUI

@objc(CalendarExtension)
public final class CalendarExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { CalendarExtension() }
    @objc public var identifier: String { "com.theboredteam.notch.calendar" }
    @objc public var displayName: String { "Calendar" }

    @objc public func activate(host: NotchHost) {
        host.register(permission: NotchPermissionRequest(
            kind: .calendar,
            rationale: "Show today's events on the notch."))

        host.register(homeFragment: NotchHomeFragmentContribution(
            identifier: "com.theboredteam.notch.calendar.home-fragment",
            priority: 200,
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: BoringCalendar())
            }))
    }
}
```

**Edits to moved files:**
- `CalendarManager.swift` references `BoringViewModel` for hover state — replace with `NotchStateBridge`.
- The existing `BoringCalendar` view has an `@EnvironmentObject var vm: BoringViewModel` for hover detection — replace with `@StateObject var notchState = NotchStateBridge()`.

**Verification:** open notch → calendar tab shows today's events; permission prompt on first launch.

**Commit message:** `Migrate Calendar feature into CalendarExtension.notchext`

### Task C4: LiveActivitiesExtension (downloads + marquee + modifier)

**Files moved:**

```bash
mkdir -p Extensions/LiveActivities/Sources/Views Extensions/LiveActivities/Resources
git mv "boringNotch/components/Live activities/DownloadView.swift"           Extensions/LiveActivities/Sources/Views/DownloadView.swift
git mv "boringNotch/components/Live activities/MarqueeTextView.swift"        Extensions/LiveActivities/Sources/Views/MarqueeTextView.swift
git mv "boringNotch/components/Live activities/LiveActivityModifier.swift"   Extensions/LiveActivities/Sources/Views/LiveActivityModifier.swift
```

**Files created:** `Extensions/LiveActivities/Resources/Info.plist`, `Extensions/LiveActivities/Sources/LiveActivitiesExtension.swift`.

`LiveActivitiesExtension.swift`:

```swift
import AppKit
import NotchKit
import SwiftUI

@objc(LiveActivitiesExtension)
public final class LiveActivitiesExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { LiveActivitiesExtension() }
    @objc public var identifier: String { "com.theboredteam.notch.live-activities" }
    @objc public var displayName: String { "Live Activities" }

    @objc public func activate(host: NotchHost) {
        host.register(expandedItem: NotchExpandedItemContribution(
            kind: "download",
            lifecyclePolicy: .onDemand,
            makeViewController: {
                NSHostingController(rootView: DownloadView())
            }))
    }
}
```

**Edits to moved files:** if `LiveActivityModifier` is a SwiftUI ViewModifier consumed only inside this extension's bundle, no edits. If it's still referenced from core's `ContentView`, we already routed `ContentView` to registry-driven sneak-peek/expanded-item rendering in Task B4 — confirm by grepping `Core/Host/ContentView.swift` for `LiveActivityModifier` (should be zero matches by now; if not, fix in this commit).

**Commit message:** `Migrate LiveActivities (downloads + marquee + modifier) into extension`

### Task C5: HUDExtension

**Files moved:**

```bash
mkdir -p Extensions/HUD/Sources/Views Extensions/HUD/Resources
git mv boringNotch/managers/VolumeManager.swift            Extensions/HUD/Sources/VolumeManager.swift
git mv boringNotch/managers/BrightnessManager.swift        Extensions/HUD/Sources/BrightnessManager.swift
git mv boringNotch/observers/MediaKeyInterceptor.swift     Extensions/HUD/Sources/MediaKeyInterceptor.swift
git mv "boringNotch/components/Live activities/InlineHUD.swift"                Extensions/HUD/Sources/Views/InlineHUD.swift
git mv "boringNotch/components/Live activities/OpenNotchHUD.swift"             Extensions/HUD/Sources/Views/OpenNotchHUD.swift
git mv "boringNotch/components/Live activities/SystemEventIndicatorModifier.swift" Extensions/HUD/Sources/Views/SystemEventIndicatorModifier.swift
```

**Files created:** `Extensions/HUD/Resources/Info.plist`, `Extensions/HUD/Sources/HUDExtension.swift`.

`HUDExtension.swift`:

```swift
import AppKit
import NotchKit
import SwiftUI

@objc(HUDExtension)
public final class HUDExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { HUDExtension() }
    @objc public var identifier: String { "com.theboredteam.notch.hud" }
    @objc public var displayName: String { "HUD Replacement" }

    private var hostRef: NotchHost?

    @objc public func activate(host: NotchHost) {
        self.hostRef = host

        host.register(permission: NotchPermissionRequest(
            kind: .accessibility,
            rationale: "Required to intercept system volume / brightness keys."))

        for kind in ["volume", "brightness", "backlight"] {
            host.register(sneakPeek: NotchSneakPeekContribution(
                kind: kind,
                lifecyclePolicy: .onDemand,
                makeViewController: {
                    NSHostingController(rootView: InlineHUD(kind: kind))
                }))
            host.register(hudReplacement: NotchHUDContribution(
                kind: kind,
                lifecyclePolicy: .onDemand,
                makeViewController: {
                    NSHostingController(rootView: OpenNotchHUD(kind: kind))
                }))
        }

        // Start media-key interceptor when accessibility is granted
        host.permissions.request(.accessibility) { status in
            if status == .granted {
                Task { @MainActor in MediaKeyInterceptor.shared.start() }
            }
        }
    }

    @objc public func deactivate() {
        MediaKeyInterceptor.shared.stop()
    }
}
```

**Edits to moved files:**
- `MediaKeyInterceptor.swift`: previously called `BoringViewCoordinator.shared.toggleSneakPeek(status:type:duration:value:icon:)`. Replace with `host.service(of: "coordinator").toggleSneakPeek(kind: "volume", value: ..., icon: ..., durationSeconds: ...)`. Hold a `NotchCoordinatorHost` reference acquired in `start()`.
- `Constants.swift` in core: delete `hudReplacement` `Defaults` key declaration; HUDExtension owns it.

**Verification:** press volume / brightness keys → notch HUD appears (no system overlay).

**Commit message:** `Migrate HUD replacement (volume + brightness + backlight + media keys) into HUDExtension`

### Task C6: ShelfExtension

**Files moved:**

```bash
mkdir -p Extensions/Shelf/Sources Extensions/Shelf/Resources
# Preserve internal subdirectories verbatim
git mv boringNotch/components/Shelf Extensions/Shelf/Sources/Shelf
git mv boringNotch/extensions/URL+SecurityScoped.swift          Extensions/Shelf/Sources/URL+SecurityScoped.swift
git mv boringNotch/extensions/NSItemProvider+LoadHelpers.swift  Extensions/Shelf/Sources/NSItemProvider+LoadHelpers.swift
```

(Verified spec §6: 18 files in the Shelf subtree; URL+SecurityScoped and NSItemProvider+LoadHelpers are only used by Shelf.)

**Files created:** `Extensions/Shelf/Resources/Info.plist`, `Extensions/Shelf/Sources/ShelfExtension.swift`.

`ShelfExtension.swift`:

```swift
import AppKit
import NotchKit
import SwiftUI

@objc(ShelfExtension)
public final class ShelfExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { ShelfExtension() }
    @objc public var identifier: String { "com.theboredteam.notch.shelf" }
    @objc public var displayName: String { "Shelf" }

    @objc public func activate(host: NotchHost) {
        host.register(tab: NotchTabContribution(
            identifier: "com.theboredteam.notch.shelf.tab",
            title: "Shelf",
            systemImage: "tray.full",
            lifecyclePolicy: .preInstantiated,    // keeps drag listeners alive
            makeViewController: {
                NSHostingController(rootView: ShelfView())
            }))

        host.register(settingsPane: NotchSettingsPaneContribution(
            identifier: "com.theboredteam.notch.shelf.settings",
            title: "Shelf",
            systemImage: "tray.full",
            priority: 500,
            makeViewController: {
                NSHostingController(rootView: ShelfSettingsPane())
            }))
    }
}
```

**Edits to moved files:**
- `ShelfStateViewModel.swift`: has `static let shared` — keep. Previously referenced from `BoringViewCoordinator.swift:68` (the `alwaysShowTabs.didSet` block); we already removed that reference in Task B2's coordinator edits, so the host no longer reaches into Shelf state.
- `QuickShareService.swift`: previously assigned to `appDelegate.quickShareService`. Drop that line from `boringNotchApp.swift` (already done in Task A2 / B-series host edits).

**Commit message:** `Migrate Shelf feature into ShelfExtension.notchext`

### Task C7: MusicExtension

**Files moved:**

```bash
mkdir -p Extensions/Music/Sources/{Views,Settings,Onboarding,Helpers,Models,YouTubeMusic} Extensions/Music/Resources

git mv boringNotch/managers/MusicManager.swift                                Extensions/Music/Sources/MusicManager.swift
git mv boringNotch/MediaControllers/MediaControllerProtocol.swift             Extensions/Music/Sources/MediaControllerProtocol.swift
git mv boringNotch/MediaControllers/AppleMusicController.swift                Extensions/Music/Sources/AppleMusicController.swift
git mv boringNotch/MediaControllers/SpotifyController.swift                   Extensions/Music/Sources/SpotifyController.swift
git mv boringNotch/MediaControllers/NowPlayingController.swift                Extensions/Music/Sources/NowPlayingController.swift
git mv "boringNotch/MediaControllers/YouTube Music Controller"/*.swift        Extensions/Music/Sources/YouTubeMusic/

git mv boringNotch/components/Music/MusicVisualizer.swift                     Extensions/Music/Sources/Views/MusicVisualizer.swift
git mv boringNotch/components/Music/LottieAnimationView.swift                 Extensions/Music/Sources/Views/LottieAnimationView.swift
git mv boringNotch/components/Notch/NotchHomeView.swift                       Extensions/Music/Sources/Views/NotchHomeView.swift
git mv boringNotch/components/Settings/MusicSlotConfigurationView.swift       Extensions/Music/Sources/Settings/MusicSlotConfigurationView.swift
git mv boringNotch/components/Onboarding/MusicControllerSelectionView.swift   Extensions/Music/Sources/Onboarding/MusicControllerSelectionView.swift

git mv boringNotch/helpers/MediaChecker.swift                                 Extensions/Music/Sources/Helpers/MediaChecker.swift
git mv boringNotch/helpers/AppleScriptHelper.swift                            Extensions/Music/Sources/Helpers/AppleScriptHelper.swift

git mv boringNotch/models/MusicControlButton.swift                            Extensions/Music/Sources/Models/MusicControlButton.swift
git mv boringNotch/models/PlaybackState.swift                                 Extensions/Music/Sources/Models/PlaybackState.swift
```

**Files created:** `Extensions/Music/Resources/Info.plist`, `Extensions/Music/Sources/MusicExtension.swift`.

`MusicExtension.swift`:

```swift
import AppKit
import KeyboardShortcuts
import NotchKit
import SwiftUI

@objc(MusicExtension)
public final class MusicExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { MusicExtension() }
    @objc public var identifier: String { "com.theboredteam.notch.music" }
    @objc public var displayName: String { "Music" }

    @objc public func activate(host: NotchHost) {
        // Home tab fragment
        host.register(homeFragment: NotchHomeFragmentContribution(
            identifier: "com.theboredteam.notch.music.home-fragment",
            priority: 100,
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: MusicPlayerView())
            }))

        // Closed-chin live activity
        host.register(closedChinItem: NotchClosedChinContribution(
            identifier: "com.theboredteam.notch.music.chin",
            side: .left,
            priority: 100,
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: MusicLiveActivityView())
            }))

        // Sneak-peek for music change
        host.register(sneakPeek: NotchSneakPeekContribution(
            kind: "music",
            lifecyclePolicy: .onDemand,
            makeViewController: {
                NSHostingController(rootView: MusicSneakPeekView())
            }))

        // Settings
        host.register(settingsPane: NotchSettingsPaneContribution(
            identifier: "com.theboredteam.notch.music.settings",
            title: "Music",
            systemImage: "music.note",
            priority: 100,
            makeViewController: {
                NSHostingController(rootView: MusicSlotConfigurationView())
            }))

        // Onboarding step
        host.register(onboardingStep: NotchOnboardingContribution(
            identifier: "com.theboredteam.notch.music.onboarding",
            title: "Choose music source",
            priority: 200,
            makeViewController: {
                NSHostingController(rootView: MusicControllerSelectionView())
            }))

        // Keyboard shortcut (the toggleSneakPeek key from core's old shortcuts)
        host.register(keyboardShortcut: NotchKeyboardShortcutContribution(
            identifier: "toggleSneakPeek",
            displayName: "Toggle Music Sneak Peek",
            action: {
                MusicManager.shared.toggleMusicSneakPeek()
            }))
    }
}
```

**Edits to moved files:**
- `MusicManager.swift`: replace `BoringViewCoordinator.shared.toggleSneakPeek(...)` calls with `host.service(of: "coordinator").toggleSneakPeek(kind: "music", ...)`. Hold the `NotchCoordinatorHost` reference acquired in MusicExtension.activate.
- `NotchHomeView.swift`: this is the file we partially gutted in Task B5. It's now mostly the structs `MusicPlayerView`, `MusicSliderView`, etc. The composing `NotchHomeView` struct itself is **deleted from this file** — the host owns the equivalent shell in Phase B. Only the per-feature structs remain.
- `Core/Host/Shortcuts/ShortcutConstants.swift`: delete the `toggleSneakPeek` `KeyboardShortcuts.Name` declaration. Music now registers it via `host.register(keyboardShortcut:)`.
- `Constants.swift` in core: delete music-related `Defaults` key declarations.

**Verification (the most important manual gate):**
- Music plays → live activity in closed chin (album art + visualizer).
- Track change → sneak-peek pill briefly shows.
- Open notch → home tab shows player + (if Calendar enabled) calendar + (if Webcam enabled) mirror in the correct visual order via fragments.
- Onboarding flow on fresh install includes the music-source selection step.
- Keyboard shortcut for toggle-sneak-peek works.

**Commit message:** `Migrate Music feature (manager + 4 controllers + views + onboarding) into MusicExtension`

### Task C8: Final cleanup pass

After C1-C7, the `boringNotch/` directory should contain *no Swift files*. Verify and remove the empty directory:

```bash
find boringNotch -type f -name "*.swift" 2>/dev/null
# expected: no output
git rm -rf boringNotch  # if any non-Swift residue remains, e.g., empty dirs git already pruned
```

Run the full app one more time and check the upstream README's screenshots — every shown feature must work.

**Commit message:** `Remove empty boringNotch/ directory; refactor complete`

---

## Final verification gate (before marking PR ready for review)

- [ ] App launches with all eight built-in extensions loading.
- [ ] `lldb` shows exactly one `NotchKit.framework` load image.
- [ ] `scripts/check_no_notchkit_embed.sh` passes against the built app.
- [ ] All upstream README features work: music live activity, shelf drop + AirDrop, calendar tab, battery notifications, HUD replacement (volume / brightness / backlight), webcam mirror, sneak-peek, expanded-item, onboarding (first-launch + permissions).
- [ ] Settings → Extensions lists all eight built-ins; each has a working pane (or none if the feature has no settings).
- [ ] Menu bar dropdown shows built-ins (Settings / Updates / Restart / Quit) and any extension-contributed entries.
- [ ] No regression in onboarding (welcome step + per-feature permission steps).
- [ ] Persistent settings from a pre-refactor build are preserved (test by running the pre-refactor build briefly to set `Defaults`, then running the new build and confirming the values survived).
- [ ] Drop a third-party-signed `.notchext` into `~/Library/Application Support/Notch/Extensions/` — it loads.

---

## Notes on phase decomposition

Per spec §11, the three phases land as commits inside one PR. If the PR is too large for review (or if a reviewer wants to merge incrementally), the phase boundaries are clean enough that you can:

- Ship Phase A as its own PR (just the plumbing and Tips) — the app stays fully functional because Tips is the only migrated feature.
- Ship Phase B alongside it — the app's notch surface degrades to "core only + Tips" until Phase C lands.
- Phase C feature migrations could ship as separate PRs in the order listed above.

The user's stated preference is single-PR big-bang; this plan honors that as the default. The fallback decomposition is documented here so it can be adopted if review pressure makes the single-PR approach untenable.
