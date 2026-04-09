# ColimaBar

A clean, native macOS menu bar app for managing [Colima](https://github.com/abiosoft/colima) profiles. Start, stop, create, and switch between multiple concurrent Colima instances always visible.

## Features

- Menu bar status icon with per-profile state summary and running-count badge
- Start / stop / delete profiles individually (multiple can run concurrently)
- Create new profiles with custom CPU / RAM / disk / runtime / VM type
- Set active `docker context` without stopping other running profiles
- Per-profile running container list (auto-detects docker vs containerd runtime)
- Full light / dark theme support
- Custom monochrome status bar glyph drawn natively — no external assets required

## Requirements

- macOS 13 Ventura or newer
- [Colima](https://github.com/abiosoft/colima) installed (`brew install colima`)
- [Docker CLI](https://docs.docker.com/engine/install/) (`brew install docker`)
- Xcode 15+ to build
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
