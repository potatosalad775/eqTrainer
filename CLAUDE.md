# CLAUDE.md — eqTrainer Codebase Guide

This document provides AI assistants with an overview of the eqTrainer codebase, conventions, and development workflows.

## Project Overview

**eqTrainer** is a cross-platform Flutter application for ear-training / critical-listening practice. Users listen to audio processed through a parametric EQ, then identify which frequency band was boosted or cut.

- **Version:** 2.3.0+250917
- **Framework:** Flutter (stable, 3.35.3+), Dart ≥ 3.0.0
- **Supported platforms:** Android 7+, iOS 14+, Windows (Vista+), macOS 11+, Linux

---

## Repository Structure

```
eqTrainer/
├── lib/
│   ├── main.dart              # App bootstrap, provider wiring, Hive init
│   ├── theme_data.dart        # Material 3 theme helpers & ReactiveElementData
│   ├── features/              # Feature-first UI modules
│   │   ├── config/            # Session parameter configuration page
│   │   ├── import/            # Audio file import workflow
│   │   ├── playlist/          # Playlist management page
│   │   ├── result/            # Post-session results display
│   │   ├── session/           # Core training session (UI + logic)
│   │   ├── settings/          # App settings page
│   │   └── main_page.dart     # Root navigation/tab controller
│   └── shared/                # Cross-feature code
│       ├── model/             # Data models: AudioClip, AudioState, SettingData
│       ├── player/            # Audio engine: PlayerIsolate, EQ filters
│       ├── repository/        # IAudioClipRepository + Hive implementation
│       ├── service/           # Business logic services
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
| `model/` | `AudioClip` (Hive model), `AudioState` (backend/device), `SettingData` (Hive settings) |
| `player/` | `PlayerIsolate` (audio engine in a Dart isolate), `PeakingEqNode`, `PeakingEqFilter` |
| `repository/` | `IAudioClipRepository` interface + `AudioClipRepository` (Hive impl) |
| `service/` | `AudioClipService`, `PlaylistService`, `ImportWorkflowService`, `UpgraderService` |
| `widget/` | `DeviceDropdown`, `InteractionLock`, `MaxWidthCenterBox` |

---

## Key Patterns & Conventions

### Naming

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Private members:** `_camelCase` prefix
- **Barrel exports:** every module exposes an `index.dart`

### Audio Engine (`PlayerIsolate`)

Audio runs in a **Dart isolate** via `coast_audio`. Communication uses a sealed class hierarchy:

```dart
sealed class PlayerHostRequest { ... }
class PlayerHostRequestStart extends PlayerHostRequest { ... }
class PlayerHostRequestSetEQ extends PlayerHostRequest { ... }
// etc.
```

Never call audio APIs directly from the UI. Always go through `PlayerIsolate` methods (`launch`, `setEQ`, `setEQFreq`, `setEQGain`, `seek`, etc.).

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
- Dark/light modes via `easy_dynamic_theme`
- Custom font: `PretendardVariable` (supports Korean)
- Responsive breakpoints managed by `ReactiveElementData` in `theme_data.dart`
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

The project has `flutter_test` configured but no tests are currently written. When adding tests, place them in `test/` mirroring the `lib/` structure.

---

## CI/CD

`.github/workflows/build.yml` builds all 5 platforms on every push:

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
| `lib/shared/player/player_isolate.dart` | Audio isolate + request protocol |
| `lib/shared/player/peaking_eq_filter.dart` | Biquad peaking EQ DSP |
| `lib/shared/repository/audio_clip_repository.dart` | Hive CRUD for audio clips |
| `lib/shared/service/playlist_service.dart` | Playlist business logic |
| `lib/shared/model/audio_state.dart` | Backend/device state |
| `assets/translations/en.yaml` | English strings |
| `assets/translations/ko.yaml` | Korean strings |

---

## Dependencies Worth Knowing

| Package | Role |
|---|---|
| `provider` | State management |
| `hive_ce` + `hive_ce_flutter` | Local persistence |
| `coast_audio` (git fork) | Cross-platform audio engine |
| `ffmpeg_kit_flutter_new_audio` | Audio file processing |
| `easy_localization` | i18n |
| `easy_dynamic_theme` | Dark/light mode |
| `fl_chart` | EQ frequency graph visualization |
| `toastification` | In-session answer feedback toasts |
| `upgrader` | In-app update prompts |
| `equatable` | Value equality for Equatable models |

`coast_audio`, `numberpicker`, `store_checker`, and `window_size` are sourced directly from Git (see `pubspec.yaml`).
