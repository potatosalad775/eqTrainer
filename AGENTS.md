# AGENTS.md — eqTrainer Codebase Guide

This document provides AI assistants with an overview of the eqTrainer codebase, conventions, and development workflows.

## Project Overview

**eqTrainer** is a cross-platform Flutter application for ear-training / critical-listening practice. Users listen to audio processed through a parametric EQ, then identify which frequency band was boosted or cut.

- **Framework:** Flutter (stable), Dart ≥ 3.0.0
- **Supported platforms:** Android 7+, iOS 15+, Windows 10+, macOS 12+, Linux

---

## Repository Structure

```
eqTrainer/
├── lib/
│   ├── main.dart              # App bootstrap, provider wiring, Hive init
│   ├── features/              # Feature-first UI modules
│   │   ├── config/            # Session parameter configuration page
│   │   ├── import/            # Audio file import workflow
│   │   ├── playlist/          # Playlist management page
│   │   ├── result/            # Post-session results display
│   │   ├── session/           # Core training session (UI + logic)
│   │   ├── settings/          # App settings page
│   │   └── main_page.dart     # Root navigation/tab controller
│   └── shared/                # Cross-feature code
│       ├── model/             # Data models: AudioClip, AudioState, SettingData, MiscSettingsProvider
│       ├── player/            # Audio engine: PlayerService (flutter_soloud)
│       ├── repository/        # IAudioClipRepository + Hive implementation
│       ├── service/           # Business logic services
│       ├── themes/            # AppColors, AppTheme, AppDimens
│       └── widget/            # Reusable UI widgets
├── assets/
│   ├── fonts/                 # PretendardVariable.ttf
│   ├── icon/                  # App icon
│   └── translations/          # en.yaml, ko.yaml (easy_localization)
├── android/ ios/ macos/ windows/ linux/  # Platform-specific runners
├── .github/workflows/build.yml           # CI/CD (5-platform builds)
├── pubspec.yaml
├── analysis_options.yaml
├── CONTRIBUTING.md
└── README.md
```

---

## Architecture

### State Management

The app uses **Provider** with `ChangeNotifier` throughout. All providers are registered at the root `MultiProvider` in `main.dart`:

| Provider | Type | Purpose |
|---|---|---|
| `NavBarProvider` | ChangeNotifier | Bottom nav state |
| `MiscSettingsProvider` | ChangeNotifier | Hive-backed misc settings: theme mode, frequency tooltip, import format, volume compensation |
| `AudioState` | ChangeNotifier | Audio backend & output device selection |
| `AppDirectories` | Provider | App support directory paths |
| `AudioClipRepository` | Provider | Hive-backed clip storage |
| `IAudioClipRepository` | Provider | Interface alias for DI flexibility |
| `AudioClipService` | Provider | File import / clip management |
| `PlaylistService` | Provider | Playlist operations & enabled-clip queries |
| `ImportWorkflowService` | Provider | File-picker import flow |
| `SessionParameter` | ChangeNotifier | Session config (band, gain, Q, filter type, threshold) |
| `SessionStore` | ChangeNotifier | Session runtime state & results |
| `SessionController` | Provider | Orchestrates session launch & answer submission |

### Feature Layer (`lib/features/`)

Each feature is a self-contained module with:
- `*_page.dart` — top-level page widget
- `widget/` or `widgets/` — feature-local widgets
- `data/` — local state/data classes (if any)
- `model/` — feature-specific models (if any)
- `index.dart` — barrel export

### Shared Layer (`lib/shared/`)

| Sub-directory | Content |
|---|---|
| `model/` | `AudioClip` (Hive model), `AudioState` (backend/device), `SettingData` (Hive settings), `MiscSettingsProvider` (ChangeNotifier over `SettingData`) |
| `player/` | `PlayerService` (flutter_soloud engine + peaking EQ), `ImportPlayer` |
| `repository/` | `IAudioClipRepository` interface + `AudioClipRepository` (Hive impl) |
| `service/` | `AppDirectories`, `AudioClipService`, `PlaylistService`, `ImportWorkflowService`, `UpgraderService`, `AudioFormatHelper` |
| `themes/` | `AppColors`, `AppTheme`, `AppDimens` |
| `widget/` | `DeviceDropdown`, `InteractionLock`, `CustomNumberPicker`, `PlayerControlButtons` |

---

## Key Patterns & Conventions

### Naming

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Private members:** `_camelCase` prefix
- **Barrel exports:** every module exposes an `index.dart`

### Audio Engine (`PlayerService`)

The whole audio path — decode, mixing and the EQ — runs on the native
miniaudio callback thread inside `flutter_soloud`. Dart only sends control
commands over FFI. There is **no Dart in the audio path**, which is the point:
the previous coast_audio engine ran decode and EQ inside a Dart isolate driven
by timer clocks, and the stutter that caused is what the migration removed.

Never call `SoLoud` APIs directly from the UI. Always go through
`PlayerService` (`launch`, `setEQ`, `setEQFreq`, `setEQGain`, `setEQParams`,
`seek`, …).

**The signatures mean something.** Only `launch`, `shutdown`, `seek` and
`setEQParams` return a `Future`; everything else is a synchronous FFI write and
returns `void`. `setEQParams` is the one that genuinely awaits — see below.

**Never step the band's dry/wet mix into live audio.** The peaking EQ is
algebraically refactored so that sweeping `wet` moves no recursive coefficient,
which makes the Original/Filtered toggle click-free by construction. An
instantaneous swap between the dry and filtered signal is the "noise burst out
of nowhere" the migration exists to fix. `PlayerService._setWet` picks a fade
or a step correctly; while nothing is rendering a step is both safe and
*required*, because SoLoud drives parameter faders from stream time and the
output device idle-pauses.

**A round transition owns the band while it runs.** `setEQParams` fades `wet`
out, waits for the engine to report it landed, and only then snaps the new
frequency/gain. Retuning a still-audible filter is a click. Toggles are dropped
while the transition is in flight.

The filter is a **global** filter (engine-scoped), not per-voice — so that
SoLoud's chain stays volume → EQ → clamp, matching the gain compensation's
assumption. Two consequences: `launch()` must reset the band, because the
filter outlives any one `PlayerService`; and every track switch must re-apply
the compensation volume, because a fresh voice starts at 1.0.

Fuller rationale, measurements and landmines: `SOLOUD_MIGRATION.md`.

### Session Flow

```
SessionController.launchSession()
  → playlistService.listEnabledClipPaths()
  → player.launch()
  → sessionStore.initFrequency()     ← FrequencyCalculator.compute()
  → SessionController.initSession()  ← picks random answer freq
  → sessionStore.setSessionState(SessionState.ready)

User submits answer →
SessionController.submitAnswer()
  → sessionStore.applySubmission()   ← updates score & per-band stats
  → adjusts sessionParameter.startingBand if threshold reached
  → SessionController.initSession()  ← next round
```

### Persistence (Hive CE)

- Boxes: `backendBox`, `miscSettingsBox`, `audioClipBox`
- Adapters are generated with `hive_ce_generator` — run `dart run build_runner build` after modifying `@HiveType` / `@HiveField` annotated models
- Generated files (`*.g.dart`) are committed to source control

### Localization

- `easy_localization` with YAML files in `assets/translations/`
- Keys are SCREAMING_SNAKE_CASE strings (e.g. `"SESSION_SNACKBAR_CORRECT"`)
- Access via `.tr()` extension: `"MY_KEY".tr(namedArgs: {'_VAR': value})`
- Supported locales: `en`, `ko`

### Theming

- Material Design 3, seed color `0xFF375778` (slate blue)
- Dark/light modes via `MiscSettingsProvider` (ChangeNotifier) in `lib/shared/model/misc_settings_provider.dart`; theme mode is persisted to the `miscSettingsBox` Hive box (TASKS.md M14)
- Custom font: `PretendardVariable` (supports Korean)
- Colors/dimensions in `lib/shared/themes/` (`AppColors`, `AppDimens`)
- Orientation lock for screens with `shortestSide < 300`

---

## Development Workflows

### Setup

```bash
flutter pub get
flutter run
```

Requires Flutter stable 3.35.3+. See [Flutter install docs](https://docs.flutter.dev/get-started/install).

### Code Generation

After modifying Hive models (`@HiveType`/`@HiveField`) or freezed annotations:

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Running / Building

```bash
# Run on connected device/emulator
flutter run

# Build for a specific platform
flutter build apk          # Android APK
flutter build appbundle    # Android AAB
flutter build ios          # iOS
flutter build macos        # macOS
flutter build windows      # Windows
flutter build linux        # Linux
```

### Linting

```bash
flutter analyze
```

Uses `flutter_lints` (^6.0.0) with Material3 recommendations and `custom_lint`.

### Testing

The project has `flutter_test` + `mocktail` configured. When adding tests, place them in `test/` mirroring the `lib/` structure. Start with the pure session math (`FrequencyCalculator`, threshold logic, answer mapping).

```bash
flutter test test/              # unit tests — headless, this is what CI runs
flutter test integration_test/  # integration tests — local only, see below
```

**Integration tests are not run in CI, and are not meant to be.** The suites in
`integration_test/` drive a real SoLoud engine against a real output device:

| Suite | Needs |
|---|---|
| `audio_clip_service_integration_test.dart` | native decode/convert only |
| `audio_state_integration_test.dart` | a real device list, enumerated *before* the engine starts |
| `player_service_integration_test.dart` | an output device (engine init) |
| `peaking_eq_audio_integration_test.dart` | an output device that actually renders — stream time has to advance for fades to land |

GitHub-hosted runners have no audio hardware, so an engine that comes up there
proves nothing about the environment users are in. Run these on a real machine
(`flutter test integration_test/ --device-id windows|macos|linux`, or a
connected phone) before landing player changes.

### Commiting

**Keep commit messages short.** Default to a subject line alone. Add a body only when the why can't be read off the diff, and cap it at one paragraph of two or three lines. Never one paragraph per design decision. Things like alternatives considered, per-decision tradeoffs, secondary fixes, follow-up caveats — belongs in the PR description, and the doc/code comments are where the durable rationale already lives.

---

## CI/CD

`.github/workflows/test.yml` runs unit tests on Ubuntu / Windows / macOS. It
fires on every branch push (skipping doc-only changes), on PR open/reopen/
ready-for-review — `pull_request` deliberately has no `synchronize`, since the
branch push already covers it — and on manual dispatch. In-progress runs for a
ref are cancelled when a newer commit lands.

`.github/workflows/build.yml` builds all 5 platforms **only on `release: published` + manual dispatch**

| Platform | Artifact |
|---|---|
| Android | APK + AAB |
| iOS | IPA (pod install required) |
| Windows | Windows executable |
| macOS | DMG |
| Linux | DEB (via flutter_distributor) |

---

## Important Files Quick Reference

| File | Purpose |
|---|---|
| `lib/main.dart` | App entry, provider tree, Hive init |
| `lib/features/session/model/session_controller.dart` | Session orchestration logic |
| `lib/features/session/model/session_store.dart` | Session UI state (ChangeNotifier) |
| `lib/features/session/data/session_parameter.dart` | User-configurable session settings |
| `lib/features/session/model/frequency_calculator.dart` | Pure EQ frequency math |
| `lib/shared/player/player_service.dart` | Audio engine wrapper + EQ control |
| `lib/shared/service/clip_format_migration.dart` | One-time conversion of existing libraries off `.m4a`/`.aac`, to whatever the user's import-format setting maps them to (Opus under Smart) |
| `lib/shared/repository/audio_clip_repository.dart` | Hive CRUD for audio clips |
| `lib/shared/service/playlist_service.dart` | Playlist business logic |
| `lib/shared/model/audio_state.dart` | Output device + Android backend state |
| `assets/translations/en.yaml` | English strings |
| `assets/translations/ko.yaml` | Korean strings |

---

## Dependencies Worth Knowing

| Package | Role |
|---|---|
| `provider` | State management |
| `hive_ce` + `hive_ce_flutter` | Local persistence |
| `flutter_soloud` (git fork) | Cross-platform audio engine; the fork adds the peaking EQ filter and an Android backend override |
| `audio_decoder` (git fork) | Audio file decode / trim / conversion (native method channels) |
| `easy_localization` | i18n |
| `fl_chart` | EQ frequency graph visualization |
| `toastification` | In-session answer feedback toasts |
| `upgrader` + `store_checker` | In-app update prompts / install-source detection |
| `file_picker` | Audio file import |
| `device_info_plus` + `version` | OS-version gating for the appcast updater |
| `equatable` | Value equality for Equatable models |

`flutter_soloud`, `audio_decoder`, `store_checker`, and `window_size` are sourced directly from Git (see `pubspec.yaml`).