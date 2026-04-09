# ColimaBar

A clean, native macOS menu bar app for managing [Colima](https://github.com/abiosoft/colima) profiles. Start, stop, create, and switch between multiple concurrent Colima instances without ever opening a terminal.

Author: dreuse

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

## Setup

```bash
cd ~/work/sueder/personal/ColimaBar
xcodegen               # generates ColimaBar.xcodeproj from project.yml
open ColimaBar.xcodeproj
```

Then press ⌘R in Xcode to build and run. The app has `LSUIElement = true`, so it runs as a menu bar accessory (no Dock icon).

## Signing

For personal use you can run it unsigned directly from Xcode. To ship a standalone `.app`:

1. Open the project in Xcode.
2. Select the `ColimaBar` target → Signing & Capabilities.
3. Pick your developer team. The bundle identifier is `dev.dreuse.ColimaBar`.
4. Product → Archive → Distribute App → Copy App.

## Project layout

```
ColimaBar/
├── project.yml              # XcodeGen spec
├── ColimaBar/
│   ├── ColimaBarApp.swift   # @main MenuBarExtra scene
│   ├── Models/              # ColimaProfile, Container
│   ├── Services/            # ProcessRunner, ColimaCLI, ContainerCLI, DockerContextCLI
│   ├── State/               # AppModel (observable state + polling)
│   ├── Views/               # MenuContentView, ProfileRowView, NewProfileSheet, ...
│   ├── Resources/           # Info.plist, ColimaBar.entitlements
│   └── Assets.xcassets/     # AppIcon, AccentColor
└── ColimaBarTests/          # JSON parsing unit tests
```

## Architecture notes

- All CLI invocations go through `ProcessRunner` which resolves binary paths at startup (`/opt/homebrew/bin`, `/usr/local/bin`, `$HOME/.colima/bin`) because GUI apps don't inherit the shell `PATH`.
- `colima list --json` and `docker ps --format '{{json .}}'` are both NDJSON; parsed line by line.
- The app sandbox is **disabled** (see `ColimaBar.entitlements`) because spawning arbitrary external processes requires it. Hardened runtime is still on.
- The menu bar icon is a monochrome template image drawn programmatically in `IconRenderer.swift` — it automatically tints correctly in light/dark mode and "reduce transparency" mode.
