# ColimaBar Backlog

Feature ideas for ColimaBar, grouped by priority. Checked boxes are shipped.

## Tier 1 — Daily-driver features

- [x] **State-reactive menu bar icon**
  - Status bar glyph visually reflects global Colima state: all-stopped (outline), any-running (filled), transitioning (pulse), error (red triangle overlay).
  - **Why:** current icon only changes on profile count; users can't tell at a glance whether anything is actually running.
  - **Where:** `ColimaBar/Views/IconRenderer.swift` (add `menuBarIcon(state:runningCount:)` taking an `IconState` enum), `ColimaBar/State/AppModel.swift` (reuse existing `Summary` enum), `ColimaBar/ColimaBarApp.swift` (switch label to state-aware overload).
  - **Constraint:** must remain a template image; "warmer" = filled shape, not color change.

- [x] **Per-container quick actions**
  - Each container row in `RunningContainersView` gets: start / stop / restart, tail logs in an embedded window, open a shell (launch Terminal with `docker exec -it ... sh` prefilled), copy ID, open mapped ports in browser.
  - **Why:** turns ColimaBar from a status viewer into a real control surface and competes with Docker Desktop's UI without the resource cost.
  - **Where:** `ColimaBar/Views/RunningContainersView.swift`, new `Services/ContainerActionsCLI.swift`, new `Views/ContainerLogsWindow.swift`.

- [x] **Native notifications**
  - `UNUserNotificationCenter` notifies on: profile finished starting, profile failed to start (with stderr snippet), container exited non-zero, disk usage > threshold.
  - **Why:** lets users leave ColimaBar running as background infrastructure instead of babysitting a terminal.
  - **Where:** new `Services/NotificationCenter.swift`, hook into `AppModel` state transitions.

- [x] **Sleep / battery awareness**
  - Observe `NSWorkspace.willSleepNotification` and power-source changes; optionally auto-stop profiles on lid-close or after N minutes on battery. User-configurable.
  - **Why:** Colima on battery destroys runtime; users will love never thinking about it again.
  - **Where:** new `Services/PowerMonitor.swift`, wire to `AppModel.stopProfile`; setting in future Preferences pane.

- [x] **Live resource meters**
  - Small CPU / RAM / disk bars per profile row, sampled every 5–10 s via `limactl shell <profile> -- cat /proc/stat` and `df`. Ring turns amber/red above thresholds.
  - **Why:** "disk 92% full" is currently discovered only when builds fail.
  - **Where:** new `Services/ResourceSampler.swift`, new `Views/ResourceMeter.swift`, integrate into `ProfileRowView`.

## Tier 2 — Power-user delights

- [x] **Profile presets / templates**
  - Dropdown in `NewProfileSheet`: *Web dev (2/4/60)*, *Kubernetes lab (4/8/80 + k8s)*, *Minimal (1/2/20)*, *ML (passthrough)*. Save/restore custom presets to `UserDefaults`.
  - **Why:** lowers activation energy for users who don't know what numbers to pick.
  - **Where:** `ColimaBar/Views/NewProfileSheet.swift`, new `Models/ProfilePreset.swift`.

- [x] **Kubernetes integration**
  - When `--kubernetes` is enabled on a profile, show a k8s badge, add a "switch kubectl context" button mirroring the docker one, optionally list pods in a nested disclosure.
  - **Why:** real audience uses colima specifically for local k8s.
  - **Where:** extend `ColimaCLI` with k8s flag handling, new `Services/KubectlContextCLI.swift`, extend `ProfileRowView`.

- [x] **Import / export / edit profile YAML**
  - Read/write `~/.colima/<profile>/colima.yaml`. "Edit in $EDITOR" button. Export as shareable `.colima.yaml`. Import from file/URL.
  - **Why:** colima itself has no way to share configs; fills a real gap.
  - **Where:** new `Services/ProfileYAMLStore.swift`, new `Views/ProfileYAMLEditor.swift`.

- [x] **Global container search**
  - ⌘F in the popover → fuzzy search container names across all running profiles. Selecting a match expands the owning row and highlights the container.
  - **Why:** quality-of-life win once you run 2–3 profiles.
  - **Where:** new `Views/GlobalSearchField.swift`, extend `AppModel` with a cross-profile container index.

## Tier 3 — Polish

- [x] **Right-click menu on the status icon**
  - Right-click bypasses the popover and shows a compact `NSMenu`: Start Default / Stop All / Refresh / Preferences / Quit.
  - **Why:** keyboard-lover catnip, classic macOS pattern.
  - **Where:** drop to a `NSStatusItem` + `NSMenu` fallback, or use `MenuBarExtra` with a secondary `.menu` style — need spike.

- [x] **Onboarding card**
  - First launch with no profiles → friendly wizard. Detects missing `colima`/`docker`, offers `brew install` copy. Creates a default profile from a preset on first confirm.
  - **Why:** removes friction for brand-new users.
  - **Where:** new `Views/OnboardingView.swift`, triggered from `MenuContentView` empty state.

- [x] **Preferences pane**
  - `Settings` scene with: poll interval, auto-start profiles on login, default runtime / VM type, notification categories, battery policy.
  - **Why:** power users will immediately ask for these knobs.
  - **Where:** new `Views/SettingsView.swift`, new `State/Preferences.swift`, hook into `ColimaBarApp` as a `Settings` scene.

- [x] **Compact vs expanded modes**
  - Toggle that hides resource specs and container lists for users who want a tiny dense view.
  - **Why:** accommodates both "dashboard" and "just start/stop" mental models.
  - **Where:** add `@AppStorage` flag, conditional rendering in `MenuContentView` / `ProfileRowView`.
