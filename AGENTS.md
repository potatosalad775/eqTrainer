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
│       ├── model/             # AudioClip, AudioState, BackendData/MiscSettings, MiscSettingsProvider
│       ├── player/            # Audio engine: PlayerService (flutter_soloud)
│       ├── repository/        # IAudioClipRepository + Hive implementation
│       ├── service/           # Business logic services
│       ├── themes/            # AppColors, AppTheme, AppDimens
│       └── widget/            # Reusable UI widgets
├── assets/
│   ├── fonts/                 # PretendardVariable.ttf
│   ├── icon/                  # App icon
│   └── translations/          # en.json, ko.json (easy_localization)
├── test/                      # Unit tests, mirroring lib/ (+ helpers/)
├── integration_test/          # Real-engine tests — local only, never CI
├── android/ ios/ macos/ windows/ linux/  # Platform-specific runners
├── .github/workflows/
│   ├── build.yml              # 5-platform release builds
│   └── test.yml               # Unit tests, every push
├── distribute_options.yaml    # fastforge jobs: Linux deb + rpm
├── appcast.xml                # `upgrader` feed
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
| `ClipRecompressService` | Provider | User-triggered WAV→FLAC recompress |
| `ClipFormatMigration` | ChangeNotifier | Started in `main()` before `runApp`, so provided by `.value`; playback screens pause it. See [Clip Formats](#clip-formats) |
| `SessionParameter` | ChangeNotifier | Session config (band, gain, Q, filter type, threshold) |
| `SessionStore` | ChangeNotifier | Session runtime state & results |
| `SessionController` | Provider | Orchestrates session launch & answer submission |

### Feature Layer (`lib/features/`)

Each feature is a self-contained module with:
- `*_page.dart` — top-level page widget
- `widget/` or `widgets/` — feature-local widgets
- `data/` — local state/data classes (if any)
- `model/` — feature-specific models (if any)

There are **no barrel files.** Import the specific `package:eq_trainer/...` path.

### Shared Layer (`lib/shared/`)

| Sub-directory | Content |
|---|---|
| `model/` | `AudioClip` (Hive model), `AudioState` (backend/device), `BackendData` + `MiscSettings` (the two Hive records, both in `setting_data.dart`), `MiscSettingsProvider` (ChangeNotifier over `MiscSettings`) |
| `player/` | `PlayerService` (flutter_soloud engine + peaking EQ), `ImportPlayer` |
| `repository/` | `IAudioClipRepository` interface + `AudioClipRepository` (Hive impl) |
| `service/` | `AppDirectories`, `AudioClipService`, `PlaylistService`, `ImportWorkflowService`, `UpgraderService`, `AudioFormatHelper`, `ClipEncoder`, `ClipFormatMigration`, `ClipRecompressService`, `wav_pcm.dart` (WAV parser), `third_party_licenses.dart` |
| `themes/` | `AppColors`, `AppTheme`, `AppDimens` |
| `widget/` | `DeviceDropdown`, `InteractionLock`, `CustomNumberPicker`, `PlayerControlButtons` |

---

## Key Patterns & Conventions

### Naming

- **Files:** `snake_case.dart`
- **Classes:** `PascalCase`
- **Private members:** `_camelCase` prefix

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

### What the `flutter_soloud` fork carries

The engine is a fork, pinned to an exact SHA in `pubspec.yaml`. Know what is in
it before considering a move back to upstream — all of this would be lost:

| Delta | Why it exists |
|---|---|
| Peaking EQ filter | A bandpass-refactored biquad whose poles don't depend on gain, so sweeping dry/wet moves no recursive coefficient. This is what makes the Original/Filtered toggle click-free by construction. |
| Android backend override | Upstream prefers AAudio on API ≥ 30; several DAP devices misbehave on it. |
| Offline PCM-to-file encode | `encodePcmToFile` — Ogg Opus / FLAC / WAV from a float buffer. Runs on a `compute()` isolate and touches no engine state, so it is safe to call while audio is playing and two encodes may overlap. `ClipEncoder` is built on it. |
| Opus bitrate + complexity | Upstream ran libopus defaults with no `OPUS_SET_BITRATE`. |
| Kaiser-windowed sinc polyphase resampler | Replaced a linear-interpolation 44.1→48 kHz resampler. Opus mandates 48 kHz, so *every* Opus encode went through it — on the exact top-octave material users train against. |
| Bisected `seekOpus` | Was a linear rewind-and-decode, i.e. O(position), and `PlayerService.seek` is a synchronous FFI call. Deep seeks in long Opus files blocked. |

Measured, on the fork's own test material:

- **Resampler** — 44.1→48 kHz response went from −3.9 dB at 16 kHz and −6.3 dB
  at 20 kHz to −0.000 dB and −0.279 dB; images went from 1.7 dB down to
  24.7 dB down.
- **Seek** — seeking to 115 s in a two-minute file went from 71.77 ms to
  0.45 ms, and is now flat in position rather than linear.

Three upstream bugs were found and fixed along the way: OpusHead advertised a
pre-skip of 0, granulepos was written before being advanced (truncating ~20 ms
off every file), and FLAC never declared `total_samples`, so every decoder
reported an unknown duration.

MP3 output was considered and dropped: it was the only target needing a new
codec (LAME) and an LGPL dependency. WAV remains the zero-work fallback.

### Clip Formats

Clips are app-owned copies, converted once at import rather than on every load.
`AudioFormatHelper` holds the mapping and is the single source of truth for
which extensions the engine plays natively — `PlayerService` shares that set
rather than restating it, because the two drifting apart is what breaks Ogg on
Apple platforms (the `audio_decoder` fallback is AVFoundation, which cannot
open an Ogg container at all).

Two background passes rewrite clips in an existing library:

| Pass | Trigger | Rule |
|---|---|---|
| `ClipFormatMigration` | Automatic, every launch (a no-op scan after the first) | Converts `.m4a`/`.aac` — the formats SoLoud cannot read — to whatever the user's import-format setting would produce for them today. |
| `ClipRecompressService` | User-triggered, from audio settings | WAV → FLAC only. Never re-encodes a *lossless* clip to a lossy format. |

Both keep the record and the basename and change only the extension. The
basename is the clip's identity (`AudioClipService` names imports after
`microsecondsSinceEpoch`), which is what `PlaylistService.resolveClipPath`
relies on to follow a clip that moved underneath a live session.

**Anything that rewrites the library must yield to playback, not block it.** A
decode-plus-encode is CPU-seconds per clip on a phone or a DAP — the hardware
where libraries are largest and the contention is audible. `ClipFormatMigration`
exposes `pause()`/`resume()`, and the screens that play audio (`SessionPage`,
`PlaylistControlView`) hold it while they are open; the checkpoint is between
clips, which the per-clip commit makes free. Disabling the UI instead was
considered and rejected: a large library on a slow device is minutes of a dead
Start button, and legacy clips still play through `PlayerService`'s
decode-on-load fallback meanwhile, so there is nothing to wait for.

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

- `easy_localization` with **JSON** files in `assets/translations/` (`en.json`, `ko.json`)
- Keys are SCREAMING_SNAKE_CASE strings (e.g. `"SESSION_SNACKBAR_CORRECT"`)
- Access via `.tr()` extension: `"MY_KEY".tr(namedArgs: {'_VAR': value})`
- Supported locales: `en`, `ko`

JSON, not YAML, because it is what easy_localization's built-in
`RootBundleAssetLoader` reads. The YAML that used to live here needed
`easy_localization_loader`, which drags in `connectivity_plus` — a **native
plugin on all five platforms** — purely for a network loader the app never
calls. Do not reintroduce it; a custom `AssetLoader` is the cheaper way back to
YAML if the section comments are ever worth it. Chosen locale persists through
`shared_preferences` (easy_localization's own storage, not the Hive boxes), so
tests that boot it must stub that channel — see `l10n_asset_smoke_test.dart`.

### Theming

- Material Design 3. `AppColors` holds fully enumerated `lightScheme`/`darkScheme`
  `ColorScheme` literals — there is **no** `ColorScheme.fromSeed` call to edit;
  regenerate the pair if the palette changes
- Dark/light modes via `MiscSettingsProvider` (ChangeNotifier) in `lib/shared/model/misc_settings_provider.dart`; theme mode is persisted to the `miscSettingsBox` Hive box
- Custom font: `PretendardVariable` (supports Korean)
- Colors/dimensions in `lib/shared/themes/` (`AppColors`, `AppDimens`)
- Orientation lock for screens with `shortestSide < 300`

---

## Development Workflows

### Setup

`flutter pub get`, then `flutter run`. CI pins Flutter stable **3.47.2**
(every job in both workflows); match it locally when reproducing a CI failure.

### Code Generation

After modifying Hive models (`@HiveType`/`@HiveField`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

### Linting

`flutter analyze`. `flutter_lints` ^6.0.0 plus five rules turned on explicitly
in `analysis_options.yaml`: `prefer_const_constructors`,
`prefer_const_literals_to_create_immutables`, `use_build_context_synchronously`,
`avoid_empty_else`, `unawaited_futures`. The platform runner directories are
excluded from analysis. No `custom_lint`.

### Testing

Unit tests live in `test/`, mirroring `lib/` (`flutter_test` + `mocktail`).
The session math, store, controller, format policy, WAV parser, repository
and the three library-rewrite services are all covered there. Shared
scaffolding is in `test/helpers/`:

| Helper | Use it for |
|---|---|
| `mocks.dart` | The mocktail doubles: repository, `AppDirectories`, `PlayerService`, `PlaylistService`. `AudioState` is a `final class` and cannot be mocked; construct a real one, it needs no engine. |
| `fake_encoder.dart` | `FakeClipEncoder`: writes a file of a known size, or throws. Records every destination in `encoded`. |
| `hive_test_box.dart` | `HiveTestBox`: a throwaway `AudioClip` box. Anything that goes through `clip.key` needs clips added via a box: a bare `AudioClip(...)` has a **null** key, so two of them compare equal and a "was this record deleted?" check passes for the wrong reason. |

Platform channels (`audio_decoder`, `path_provider`, `shared_preferences`) are
stubbed per test with `setMockMethodCallHandler` rather than by depending on the
plugin; see `import_workflow_service_test.dart`.

`l10n_asset_smoke_test.dart` boots a real `EasyLocalization` and asserts both
locales resolve out of the bundle. It exists because nothing else catches a
broken translation asset: rename a file or drop the `assets:` entry and every
string silently falls back to rendering its own raw key.

```bash
flutter test test/              # unit tests — headless, this is what CI runs
flutter test integration_test/  # integration tests — local only, see below
```

**Integration tests are not run in CI, and are not meant to be.** The suites in
`integration_test/` drive a real SoLoud engine against a real output device:

| Suite | Needs |
|---|---|
| `audio_clip_service_integration_test.dart` | native decode/convert only |
| `clip_encoder_integration_test.dart` | the offline encoder, plus an engine to load the result back |
| `audio_state_integration_test.dart` | a real device list, enumerated *before* the engine starts |
| `player_service_integration_test.dart` | an output device (engine init) |
| `peaking_eq_audio_integration_test.dart` | an output device that actually renders — stream time has to advance for fades to land |

**Fixtures are synthesised, not bundled.** `integration_test/helpers/fixtures.dart`
writes the test audio into a temp directory at suite start: the WAVs are
generated in Dart, the FLAC is encoded from one of them through `ClipEncoder`,
and the MP3 is an embedded base64 constant (`fixture_mp3.dart`). Do not add
audio under `assets:` in `pubspec.yaml` for tests; everything listed there
ships in every release build.

GitHub-hosted runners have no audio hardware, so an engine that comes up there
proves nothing about the environment users are in. Run these on a real machine
(`flutter test integration_test/ --device-id windows|macos|linux`, or a
connected phone) before landing player changes.

**The directory form fails on an unpatched SDK — it is a `flutter_tools` bug,
not ours.** Every file after the first dies with "Error waiting for a debug
connection: The log reader stopped unexpectedly, or never started." The tool
resolves the target device *once* per `flutter test` invocation and reuses that
one `Device` for every test file, but `DesktopDevice` holds a single
`DesktopLogReader` whose broadcast controller is **closed when the first app
process exits**. The relaunch for file two then subscribes the new process's
stdout to a dead controller, so `ProtocolDiscovery` sees an
already-done stream and never finds the VM service URI. Nothing about the app
is involved — two empty `testWidgets` files reproduce it. It affects every
desktop device, not just Windows.

Two ways out:

- Run the files one at a time (`flutter test integration_test/<one>_test.dart -d windows`).
- Patch the SDK — in `packages/flutter_tools/lib/src/desktop_device.dart`, make
  `DesktopLogReader._inputController` non-`final` and re-create it at the top of
  `initializeProcess` when `isClosed`. Delete `bin/cache/flutter_tools.stamp`
  (delete it — do not blank it, an empty stamp makes `shared.bat` fail to parse)
  so the tool snapshot rebuilds. The whole suite then passes in one directory
  run. The patch lives in the SDK checkout, so `fvm` reinstalling the pinned
  version wipes it.

**Still unaudited by ear.** The fork's resampler and `seekOpus` rewrite are
verified numerically and by test, never by listening. Two things are worth
auditioning when someone next has the hardware in front of them: a seek into a
long Opus clip (no click or garble at the landing point), and top-octave
material through a 44.1 kHz import.

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
| Android | AAB only (`flutter build appbundle`; the step is misnamed "Build APK") |
| iOS | IPA |
| Windows | Windows executable |
| macOS | DMG |
| Linux | DEB + RPM (via `fastforge`, jobs in `distribute_options.yaml`) |

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
| `lib/shared/service/clip_format_migration.dart` | See [Clip Formats](#clip-formats) |
| `lib/shared/service/clip_recompress_service.dart` | See [Clip Formats](#clip-formats) |
| `lib/shared/service/clip_encoder.dart` | Decode-to-WAV then encode to Opus/FLAC/WAV; the one place the two decoders meet |
| `lib/shared/service/audio_format_helper.dart` | Import/trim format policy and the natively-playable extension set |
| `lib/shared/repository/audio_clip_repository.dart` | Hive CRUD for audio clips |
| `lib/shared/service/playlist_service.dart` | Playlist business logic; `resolveClipPath` follows a clip whose file was rewritten mid-session |
| `lib/shared/model/audio_state.dart` | Output device + Android backend state |
| `assets/translations/en.json` | English strings |
| `assets/translations/ko.json` | Korean strings |

---

## Dependencies Worth Knowing

| Package | Role |
|---|---|
| `provider` | State management |
| `hive_ce` + `hive_ce_flutter` | Local persistence |
| `flutter_soloud` (git fork) | Cross-platform audio engine, plus the offline encoder `ClipEncoder` writes through. See [What the `flutter_soloud` fork carries](#what-the-flutter_soloud-fork-carries) |
| `audio_decoder` (hosted) | Decodes foreign containers (m4a/aac/wma/alac/aiff) via platform codecs, and emits WAV. The only thing that can open a format SoLoud cannot — which is the whole reason it is still here |
| `easy_localization` | i18n. Default `RootBundleAssetLoader` only — no `easy_localization_loader`, see [Localization](#localization) |
| `fl_chart` | EQ frequency graph visualization |
| `toastification` | In-session answer feedback toasts |
| `upgrader` | In-app update prompts |
| `file_picker` | Audio file import |
| `device_info_plus` + `version` | OS-version gating for the appcast updater |
| `equatable` | Value equality for Equatable models |

`flutter_soloud` is the only Git dependency, pinned to an exact commit SHA
rather than a mutable branch so builds are reproducible and the audio engine
cannot change under a re-resolve (see `pubspec.yaml`).

Neither Apple platform uses CocoaPods any more — every plugin the app depends
on ships as a Swift Package, so `flutter build` resolves them itself and there
is no `Podfile` on either side. Nothing in CI runs `pod install`. If a future
dependency is CocoaPods-only, `flutter create` templates are the reference for
putting a `Podfile` back.

Desktop window title and minimum size are set per platform, not from Dart.
They used to come from the `window_size` plugin, which was dropped: the values
are constants, and the plugin had no Swift Package Manager support, which
Flutter is moving to require.

| Platform | Minimum size | Title |
|---|---|---|
| macOS | `NSWindow.minSize` in `macos/Runner/MainFlutterWindow.swift` | `PRODUCT_DISPLAY_NAME` in `macos/Runner/Configs/AppInfo.xcconfig` |
| Windows | `WM_GETMINMAXINFO` in `windows/runner/win32_window.cpp` | `window.Create` in `windows/runner/main.cpp` |
| Linux | `gtk_window_set_geometry_hints` in `linux/my_application.cc` | same file, both titlebar branches |

On macOS the title is deliberately *not* set from `MainFlutterWindow`.
Assigning `NSWindow.title` in `awakeFromNib` does not survive — AppKit
re-applies the nib's `APP_NAME` afterwards, so the title reverts to the bundle
name a moment after launch. It comes from `CFBundleName` instead, which also
fixes the menu items the nib builds from `APP_NAME` ("Quit eqTrainer" rather
than "Quit eq_trainer"). `PRODUCT_NAME` stays `eq_trainer` because it names the
binary and the `.app`, which the DMG packaging in CI depends on.