<h1 align="center">
  <br>
  Capsule
  <br>
</h1>

<p align="center">
  <em>A programmable, extensible notch-space framework for macOS.</em>
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
- **CapsuleKit.framework** — the public extension SDK. Third-party `.notchext` extensions link against this framework to contribute UI and behavior.
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
