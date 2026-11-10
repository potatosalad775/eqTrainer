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
│   ├── main.dart              # App bootstrap, provider wiring, legacy data migrations
│   ├── l10n/                  # ARB translations, context.l10n (generated/ is gitignored)
│   ├── ui/                    # Pages, widgets and the state they own
│   │   ├── core/              # Shared widgets and themes, error dialog, updater, licenses
│   │   ├── config/            # Session parameter configuration page
│   │   ├── import/            # Audio file import workflow
│   │   ├── playlist/          # Playlist management page
│   │   ├── result/            # Post-session results display
│   │   ├── session/           # Core training session (page, widgets, state/)
│   │   ├── settings/          # App settings page
│   │   └── main_page.dart     # Root navigation/tab controller
│   ├── domain/                # Pure Dart: AudioClip, format policy, WAV parser, SessionParameter
│   └── data/                  # Disk, preferences and the audio engine
│       ├── clips/             # Clip library, encoder, rewrite passes and import services
│       └── legacy/            # Hive records and the migrations that read them
├── assets/
│   ├── fonts/                 # PretendardVariable.ttf
│   └── icon/                  # App icon
├── test/                      # Unit tests, mirroring lib/ (+ helpers/, layers_test.dart)
├── integration_test/          # Real-engine tests — local only, never CI
├── docs/agents/               # Config the agent skills read; see Agent skills
├── android/ ios/ macos/ windows/ linux/  # Platform-specific runners and packaging
├── .github/workflows/
│   ├── build.yml              # 5-platform release builds
│   └── test.yml               # Unit tests, every push
├── distribute_options.yaml    # fastforge jobs: Linux deb + rpm
├── appcast.xml                # `upgrader` feed
├── l10n.yaml                  # gen-l10n config
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
| `MiscSettingsProvider` | ChangeNotifier | Misc settings: theme mode, frequency tooltip, import format, volume compensation. Loaded in `main()` before `runApp`, so provided by `.value`. See [Persistence](#persistence) |
| `LocaleProvider` | ChangeNotifier | The language picked in settings. Loaded in `main()` before `runApp`, so provided by `.value`. See [Localization](#localization) |
| `AudioState` | ChangeNotifier | Audio backend & output device selection |
| `IAudioClipRepository` | Provider | The clip library. One `AudioClipRepository` opened in `main()` before `runApp`, so provided by `.value`. See [Persistence](#persistence) |
| `ClipLibrary` | Provider | Records and files together: what a session plays, deleting a clip, and the one rewrite protocol. Built in `main()` over that one repository, so provided by `.value`. See [Persistence](#persistence) |
| `AudioClipService` | Provider | Imports a clip: picks the extension, trims or copies, and hands the file to `ClipLibrary.add` |
| `ImportWorkflowService` | Provider | File-picker import flow |
| `ClipRecompressService` | Provider | User-triggered WAV→FLAC recompress |
| `ClipFormatMigration` | ChangeNotifier | Started in `main()` before `runApp`, so provided by `.value`; playback screens pause it. See [Clip Formats](#clip-formats) |
| `SessionParameter` | ChangeNotifier | Session config (band, gain, Q, filter type, threshold) |
| `SessionStore` | ChangeNotifier | Session runtime state & results |
| `SessionController` | Provider | Orchestrates session launch & answer submission |

### Layers

`lib/` has three layers, plus `main.dart` and `l10n/`. `ui/` is pages, widgets and the state they own. `domain/` is pure Dart. `data/` is anything that touches disk, preferences or the audio engine. The import rules:

- `ui` may import `domain` and `data`; `data` may import `domain`; `domain` imports neither.
- `ui` does not import `dart:io`, `package:path`, `shared_preferences` or `AppDirectories`.
- `domain` does not import `dart:io`.
- `domain` and `data` use only `package:flutter/foundation.dart` from Flutter, and never take a `BuildContext`.
- Nothing in the three layers imports `main.dart`.

`test/layers_test.dart` checks these. It carries an allow-list of the violations that remain, which can only shrink: delete an entry when you fix it. The reasons are in `docs/adr/0002-three-layers-enforced-by-test.md`.

There are **no barrel files** (`l10n/l10n.dart` is the one exception, see [Localization](#localization)). Import the specific `package:eq_trainer/...` path.

| Folder | Content |
|---|---|
| `ui/<feature>/` | `config`, `import`, `playlist`, `result`, `session`, `settings`. Each has a `*_page.dart` and `widget/` or `widgets/`. `session/state/` holds `SessionStore`, `SessionController`, `SessionState`, `GraphState` and `FrequencyCalculator`; `import/` holds `ImportAudioData` |
| `ui/core/` | `AppColors`, `AppTheme`, `AppDimens`, the player error dialog (`error.dart`), `UpgraderService`, `third_party_licenses.dart`, and in `widget/` `DeviceDropdown`, `InteractionLock`, `CustomNumberPicker`, `PlayerControlButtons` |
| `domain/` | `AudioClip` (immutable, JSON), `AudioFormatHelper`, `wav_pcm.dart` (WAV parser), `SessionParameter` |
| `data/` | `AppDirectories` (used by `ClipLibrary` only), `AudioState` (backend/device), `MiscSettingsProvider` + `LocaleProvider` (ChangeNotifiers over `shared_preferences`), `PlayerService` (flutter_soloud engine + peaking EQ), `ImportPlayer` |
| `data/clips/` | `IAudioClipRepository` interface + `AudioClipRepository` (JSON file impl), `ClipLibrary`, `AudioClipService`, `ImportWorkflowService`, `ClipEncoder`, `ClipFormatMigration`, `ClipRecompressService` |
| `data/legacy/` | `LegacyAudioClip` + `BackendData` + `MiscSettings` (Hive records, read only by the migrations), `legacy_settings_migration.dart`, `legacy_clip_migration.dart` |

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

The engine is a fork, branch `custom-5.2.2`, based on upstream `main` at
`38dc51b3`: it reports 5.2.2 but sits 5 commits past that tag. It is pinned to an
exact SHA in `pubspec.yaml`, and the branch `custom` and tag `custom-5.0.0-pre.3`
keep the previous pin reachable.

The SHA alone does not fix the codecs. The build hook downloads the Xiph binaries
(libopus and the others) from `alnitak/flutter_soloud_prebuilds`, defaulting to
the `latest` release, so `pubspec.yaml` also pins
`hooks.user_defines.flutter_soloud.prebuild_tag`. **Builds therefore need network
access to GitHub** unless the package's `.dart_tool/flutter_soloud/` cache is
already populated. The fork checks each archive against a SHA-256 pinned per
release in `hook/build.dart`, so bumping the tag means adding its digests there:
a named tag without them fails the build.

Know what is in the fork before considering a move back to upstream — all of this
would be lost:

| Delta | Why it exists |
|---|---|
| Peaking EQ filter | A bandpass-refactored biquad whose poles don't depend on gain, so sweeping dry/wet moves no recursive coefficient. This is what makes the Original/Filtered toggle click-free by construction. |
| Android backend override | Upstream prefers AAudio on API ≥ 30; several DAP devices misbehave on it. |
| Offline PCM-to-file encode | `encodePcmToFile` — Ogg Opus / FLAC / WAV from a float buffer. Runs on a `compute()` isolate and touches no engine state, so it is safe to call while audio is playing and two encodes may overlap. `ClipEncoder.encodeWavBytes` is built on it. |
| Offline file-to-PCM decode | `decodeFileToPcm`: a whole file or a frame-exact time range, with no engine running. Refuses files with no recognised signature, because `dr_mp3` otherwise turns them into a moment of noise and reports success. Looks past ID3v2 tags of any size at what follows, since that can be AAC as well as MP3. MP3 alone is also found behind junk in the first 4 KB, where it takes four consecutive frames to count, since one header turns up by chance. Memory follows the range, except for platform-decoded formats such as M4A, which only decode whole. |
| Offline file-to-file convert | `convertFile`: decodes straight into the encoder, so memory does not follow the length of the audio, except for platform-decoded formats. A whole file or a frame-exact range, and `ClipEncoder.convertFile` and `trimFile` are both built on it. Because a source can now fail after output has begun, a failure removes the output, and a file that cannot be read never touches it. Refuses to write over its own source. |
| Windows ADTS through the AAC transform | `decodeFileToPcm` and `convertFile` skip Media Foundation's source reader for ADTS. It sniffs only the first 2048 bytes, so it refuses audio behind an ID3 tag longer than that, and it believes a `.mp3` extension over the contents, reporting success on 1152 frames of an ADTS file named that way. The transform is the same decoder, and its samples match to the bit. |
| Windows format from the first sample | Media Foundation guesses double the rate in stereo for AAC at 24 kHz and below, and corrects it with the first sample. Believing the guess turned mono 22.05 kHz into 44.1 kHz stereo, a quarter of the length, reported as a success, which a migration would then delete the source over. |
| Opus bitrate + complexity | Upstream ran libopus defaults with no `OPUS_SET_BITRATE`. |
| Kaiser-windowed sinc polyphase resampler | Replaced a linear-interpolation 44.1→48 kHz resampler. Opus mandates 48 kHz, so *every* Opus encode went through it — on the exact top-octave material users train against. |
| Bisected `seekOpus` | Was a linear rewind-and-decode, i.e. O(position), and `PlayerService.seek` is a synchronous FFI call. Deep seeks in long Opus files blocked. |
| Pinned prebuild digests | Upstream's hook links whatever the release serves, with no checksum. A cache with no matching recorded digest is downloaded again. |

Measured, on the fork's own test material:

- **Resampler** — 44.1→48 kHz response went from −3.9 dB at 16 kHz and −6.3 dB
  at 20 kHz to −0.000 dB and −0.279 dB; images went from 1.7 dB down to
  24.7 dB down.
- **Seek** — seeking to 115 s in a two-minute file went from 71.77 ms to
  0.45 ms, and is now flat in position rather than linear.
- **Memory** — peak native memory converting an hour of stereo at 44.1 kHz on
  Windows, where one copy of the PCM is 1214 MB:

  | Source | Decode then encode | `convertFile` |
  |---|---|---|
  | WAV, FLAC, MP3 | 3641 MB | under 1 MB |
  | Ogg Opus | | 7.5 MB |
  | ADTS | | 6 MB |
  | M4A | 3644 MB | 2554 MB |

Three upstream bugs were found and fixed along the way: OpusHead advertised a
pre-skip of 0, granulepos was written before being advanced (truncating ~20 ms
off every file), and FLAC never declared `total_samples`, so every decoder
reported an unknown duration. `convertFile` only knows that count at the end, so
it patches `STREAMINFO` in the finished file.

MP3 output was considered and dropped: it was the only target needing a new
codec (LAME) and an LGPL dependency. WAV remains the zero-work fallback.

### Clip Formats

Clips are app-owned copies, converted once at import rather than on every load.
`AudioFormatHelper` holds the mapping and is the single source of truth for
which extensions the engine streams — `PlayerService` shares that set rather than
restating it, and loads anything else whole in `LoadMode.memory`.

The import picker's list is per platform, from what each was measured to read. It
removes known failures but cannot promise a file works, since `.m4a` does not identify
its codec. A file nothing can read is refused with its own dialog, and on Linux that
is also what a missing FFmpeg looks like, so the Linux message says to install it, and so
do the playback errors on an old `.m4a` or `.aac` clip, which is how an upgraded install
with no FFmpeg finds out. The offline encoder takes mono and stereo only, so a file with
more channels plays but is refused when something has to convert or trim it. It is not
mixed down, because channel order depends on the decoder.

SoLoud is the only decoder. On Linux, M4A, AAC, AIFF and WMA go through a system
FFmpeg that it opens with `dlopen`, measured on 6.1, 7.1, 8.1 and 9.0. The packages
recommend FFmpeg rather than depend on it, since the core formats need nothing. `caf`
is left out of the Linux picker because CAF ALAC decodes about 70 ms short on 8.1 and 9.0.

A trim reads the file the user picked rather than the converted temp file, so a lossy
import is not encoded twice. It falls back to the temp file only if the original can no
longer be read, for example because it was on a drive that has been removed.

**What memory a conversion still takes.** WAV, FLAC, MP3 and Ogg stream everywhere, so
an hour costs what a minute does. Formats only a platform codec reads cannot, and hold
the decoded PCM, about 1.2 GB per hour of stereo:

- M4A, AIFF, WMA and CAF, everywhere, and ADTS on everything but Windows. Android holds
  one copy, planar and sized from the container, and fails rather than truncates past
  2 GiB, about 1.7 hours of stereo at 44.1 kHz, or 512 MiB on a 32-bit device. So an
  hour of M4A is improved but may still not fit on a small DAP.
- Windows peaks at about twice that, because the source reader's interleaved buffer and
  the planar copy exist together for a moment.
- `ClipRecompressService` does not use `convertFile`. It reads the WAV into Dart and goes
  through `encodeWavBytes`, so a long WAV still costs several copies.

Android, iOS and macOS have `NativeStream`, which decodes M4A a piece at a time for
playback, and ADTS has a stream decoder on every platform. Either could feed the encoder
and remove these copies, but neither has been tested on a device for this use.

Two background passes rewrite clips in an existing library:

| Pass | Trigger | Rule |
|---|---|---|
| `ClipFormatMigration` | Automatic, every launch (a no-op scan after the first) | Converts `.m4a`/`.aac` — the formats the app does not play through SoLoud — to whatever the user's import-format setting would produce for them today. |
| `ClipRecompressService` | User-triggered, from audio settings | WAV → FLAC only. Never re-encodes a *lossless* clip to a lossy format. |

**M4A is still converted, by decision.** SoLoud can now read it, and keeping AAC
as-is on Android and Apple would avoid a second lossy generation. It was not
adopted with the 5.2.2 fork because of what is still unknown or awkward:

- Only Android, iOS and macOS stream it. Windows and Linux decode the whole file
  into RAM, and Linux needs system FFmpeg at runtime.
- A streamed voice can underrun if decoding falls behind, which has not been tested
  on a slow DAP.
- `.m4a` does not identify the codec. On an Android 17 (API 37) emulator, AAC
  plays but ALAC has no decoder, so this varies by device. Adopting it needs a load that handles that failure, not just a
  per-platform extension set.

Both passes go through `ClipLibrary.rewrite`, which is the only place a clip's
file is replaced: it produces the new file, checks it is at least 42 bytes (the
smallest valid output of any target), repoints the record, and only then deletes
the old file. The passes decide which clips to rewrite and into what, and give
`rewrite` a `produce` callback; they do not repeat the ordering or the cleanup.
It keeps the record and the basename and changes only the extension. The
basename is the clip's identity (`ClipLibrary.add` names imports after
`microsecondsSinceEpoch`), which is what `ClipLibrary.resolvePath` relies on to
follow a clip that moved underneath a live session.

**Anything that rewrites the library must yield to playback, not block it.** A
decode-plus-encode is CPU-seconds per clip on a phone or a DAP — the hardware
where libraries are largest and the contention is audible. `ClipFormatMigration`
exposes `pause()`/`resume()`, and the screens that play audio (`SessionPage`,
`PlaylistControlView`, `ImportPage`) hold it while they are open; the checkpoint is between
clips, which the per-clip commit makes free. Disabling the UI instead was
considered and rejected: a large library on a slow device is minutes of a dead
Start button, and legacy clips still play through `PlayerService`'s
decode-on-load fallback meanwhile, so there is nothing to wait for.

### Session Flow

```
SessionController.launchSession()
  → clipLibrary.enabledClipPaths()   ← skips a missing clip, keeps its record
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

### Persistence

Settings are in `shared_preferences`, through the legacy `SharedPreferences` API
(see `LocaleProvider` for why). Its cache is in memory, so reads are synchronous
once `main()` has loaded it.

The clip library is `audio_clips.json` in the app support directory, loaded whole
into `AudioClipRepository` and rewritten whole on every change. Things that are
easy to break:

- **Open exactly one repository.** Each instance keeps its own copy, so a second
  would overwrite the first's changes. That includes `ClipFormatMigration`, which
  gets the one `ClipLibrary` built over the same instance as the widget tree. It is also why only one copy of the
  app may run: see [the desktop runners](#dependencies-worth-knowing).
- **A finished write is on disk, and a failed one rolled back.** `ClipLibrary.rewrite`
  deletes a clip's source file straight after repointing its record, so this is
  what stops a record ever pointing at a file that is gone.
- **Writes are atomic and queued**: a flushed temp file renamed over the real one,
  strictly one at a time.

A clip's `id` is what identifies it, not its position. For anything imported now
it is the file's basename, which format rewrites preserve.

**Anything that needs a clip's file asks `ClipLibrary`.** Nothing else joins a file
name onto the clips directory: `pathOf`, `fileSizeOf`, `enabledClipPaths` and
`resolvePath` look the clip up by id in the library as it stands now, because a
record a caller captured earlier can name a file a rewrite has since replaced.
Adding, deleting and rewriting a clip go through `add`, `delete` and `rewrite`,
which keep the record and the file in step. Plain record edits (reorder, enable,
`watchClips`) still go straight to the repository.

**A missing clip's record is kept.** `enabledClipPaths` skips a clip whose file is
gone and never deletes its record, and `rewrite` reports `sourceMissing` and leaves
it alone. Only the user deletes it. See `docs/adr/0003-missing-clips-are-never-auto-deleted.md`.

Hive CE is only read now, to migrate what older versions stored. Both migrations
run in `main()` before anything reads the data, and people can skip releases, so
they stay until dropping users on older versions is acceptable.

| Migration | Boxes | On an unreadable box | After success |
|---|---|---|---|
| `migrateLegacySettings` | `backendBox`, `miscSettingsBox` | Defaults, marked done | Deletes the boxes |
| `migrateLegacyClips` | `audioClipBox` | Not marked done, retried next launch, and `PlaylistPage` tells the user | Keeps the box, as a backup and for downgrades |

The difference is deliberate: a lost setting takes a moment to fix, but a lost
library cannot be rebuilt, since files are named by timestamp. The clip migration
merges rather than overwrites, so clips imported while the box was unreadable
survive a later retry.

**Hive's default on a damaged box is to cut the file at the first bad frame and
open successfully**, so a plain `openBox` reads as a smaller library rather than
an error. `migrateLegacyClips` opens with `crashRecovery: false` first; on failure
it copies the file to `audioclipbox.hive.damaged`, repairs, migrates what survives
and tells the user.

Removing Hive means removing both migrations and the `legacy_audio_clip.dart` and
`setting_data.dart` records, deleting `audioClipBox` from disk, and dropping
`hive_ce`, `hive_ce_flutter`, `hive_ce_generator` and `build_runner`.

- Adapters are generated with `hive_ce_generator` — run `fvm dart run build_runner build` after modifying `@HiveType` / `@HiveField` annotated models
- Generated files (`*.g.dart`) are committed to source control

### Localization

Flutter's own `gen-l10n`, configured in `l10n.yaml`. Translations are ARB files in
`lib/l10n/`, with `app_en.arb` as the template. Supported locales: `en`, `ko`,
`ru`, `uk`.

- Import `package:eq_trainer/l10n/l10n.dart`, which adds `context.l10n` and
  re-exports `AppLocalizations`.
- Keys are lowerCamelCase and become members, so a mistyped key does not compile:
  `context.l10n.sessionSnackbarCorrect`.
- Placeholders are named arguments (`use-named-parameters`), because several
  messages take more than one string and positional ones could be swapped
  unnoticed: `l10n.audioSettingRecompressConfirm(count: 3, size: a, after: b)`.
- Declare placeholder types in the template's `@key` metadata, not in the
  translations.
- `lib/l10n/generated/` is **gitignored**, unlike the `*.g.dart` files, so a
  translation PR stays one file. `pub get`, `run` and `build` regenerate it.

**Adding a language** takes two steps:

1. Add `lib/l10n/app_xx.arb`, including `languageName`: the language's name in
   itself, which is what the settings picker shows.
2. Add the code to `CFBundleLocalizations` in `ios/Runner/Info.plist`.

`supportedLocales` and the picker follow from the ARB files. Nothing generates the
plist, so `l10n_test.dart` fails if it falls out of step.

**Plurals are ICU, wrapping whole sentences**, because verbs and pronouns change
with the count, not just the noun:
`{count, plural, one{...} few{...} many{...} other{...}}`. The placeholder must be
`int`. Russian and Ukrainian use all four forms, and `one` also matches 21 and 31,
so keep `{count}` in the branch rather than writing a literal "1". Korean has no
plural forms and takes the count directly.

gen-l10n fills a missing message in from the template and only warns, so a
half-translated file still builds. `l10n_test.dart` is what catches it.

**Code with no `BuildContext` takes the strings as a parameter**, as
`ConfigCardType.title(l10n)` does. Do not add a global lookup. `Upgrader` is built
before the widget tree exists, so `_LocalizedUpgrader` overrides
`determineMessages(context)` to read them when the alert shows. Capture `l10n`
before an `await` if the widget may be gone after it.

The chosen language is in `shared_preferences`, under the key
easy_localization used, so the migration kept existing users' choices. `null`
means follow the device. The picker's value is `Localizations.localeOf(context)`
rather than the saved value, since only the resolved locale is guaranteed to be
one of its items.

### Theming

- Material Design 3. `AppColors` holds fully enumerated `lightScheme`/`darkScheme`
  `ColorScheme` literals — there is **no** `ColorScheme.fromSeed` call to edit;
  regenerate the pair if the palette changes
- Dark/light modes via `MiscSettingsProvider` (ChangeNotifier) in `lib/data/misc_settings_provider.dart`; theme mode is persisted to `shared_preferences`
- Custom font: `PretendardVariable` (supports Korean)
- Colors/dimensions in `lib/ui/core/` (`AppColors`, `AppDimens`)
- Orientation lock for screens with `shortestSide < 300`

---

## Development Workflows

### Setup

`fvm flutter pub get`, then `fvm flutter run`.

**The Flutter SDK is managed with [fvm](https://fvm.app). Prefix every `flutter`
and `dart` command with `fvm`, including the ones in this document.** A global
`flutter` may be older and fail version solving against the pinned `flutter_soloud`.

`.fvmrc` pins the version and is the only place it is set: every job in both
workflows reads it through `flutter-version-file`, so local and CI builds use the
same SDK. To upgrade, run `fvm use <version>` and commit the result. On a fresh
checkout, `fvm install` fetches the pinned version.

### Code Generation

After modifying Hive models (`@HiveType`/`@HiveField`):

```bash
fvm dart run build_runner build --delete-conflicting-outputs
```

### Linting

`fvm flutter analyze`. `flutter_lints` ^6.0.0 plus five rules turned on explicitly
in `analysis_options.yaml`: `prefer_const_constructors`,
`prefer_const_literals_to_create_immutables`, `use_build_context_synchronously`,
`avoid_empty_else`, `unawaited_futures`. The platform runner directories are
excluded from analysis. No `custom_lint`.

### Testing

Unit tests live in `test/`, mirroring `lib/` (`flutter_test` + `mocktail`).
The session math, store, controller, format policy, WAV parser, repository,
`ClipLibrary`, the two rewrite passes and `AudioClipService` are all covered there.
The passes keep only what is theirs (which clips, which format, progress); the
rewrite protocol is tested once, in `clip_library_test.dart`, against the real
repository. Shared scaffolding is in `test/helpers/`:

| Helper | Use it for |
|---|---|
| `mocks.dart` | The mocktail doubles: repository, `AppDirectories`, `ClipLibrary`, `PlayerService`. `AudioState` is a `final class` and cannot be mocked; construct a real one, it needs no engine. |
| `fake_encoder.dart` | `FakeClipEncoder`: writes a file of a known size, or throws. Records every destination in `encoded`, and `onWrite` runs just before an output is written, to change the library while an encode is in flight. |

Platform channels (`path_provider`) are stubbed per test with
`setMockMethodCallHandler` rather than by depending on the plugin; see
`import_workflow_service_test.dart`. `shared_preferences` is a direct dependency,
so use its `setMockInitialValues`.

`layers_test.dart` checks the import rules of the three layers; see
[Layers](#layers).

`l10n_test.dart` covers what the compiler cannot: every ARB file has every message
and placeholder, the iOS plist matches `supportedLocales`, and the plural forms
come out right for the counts that separate the languages' rules. A widget that
calls `context.l10n` needs `AppLocalizations.localizationsDelegates` on its
`MaterialApp`; see `settings_page_test.dart`.

```bash
fvm flutter test test/              # unit tests — headless, this is what CI runs
fvm flutter test integration_test/  # integration tests — local only, see below
```

**Integration tests are not run in CI, and are not meant to be.** The suites in
`integration_test/` drive a real SoLoud engine against a real output device:

| Suite | Needs |
|---|---|
| `audio_clip_service_integration_test.dart` | native decode/convert only |
| `clip_encoder_integration_test.dart` | the offline encoder, plus an engine to load the result back |
| `audio_state_integration_test.dart` | a real device list, enumerated *before* the engine starts. Android reports no default device, so those checks are skipped there |
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
(`fvm flutter test integration_test/ --device-id windows|macos|linux`, or a
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

- Run the files one at a time (`fvm flutter test integration_test/<one>_test.dart -d windows`).
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
| Windows | Inno Setup installer (`windows/packaging/eq_trainer.iss`) + the release folder, zipped by hand as the portable download |
| macOS | DMG |
| Linux | DEB + RPM (via `fastforge`, jobs in `distribute_options.yaml`) |

The Windows installer is per-user, so it needs no UAC prompt, and takes its version
from the built executable. Three of its values must not drift: `AppId` is what makes
a new version upgrade the old one; `AppMutex` must match the mutex in
`windows/runner/main.cpp`, case included; and `CompanyName`/`ProductName` in
`Runner.rc` decide where the library lives in `%APPDATA%`, so changing them strands
existing users' data. It is unsigned, so SmartScreen warns on it as it does on the zip.

`windows/CMakeLists.txt` copies the Visual C++ runtime DLLs into the release folder,
so both downloads carry them. The build fails if they cannot be found.

---

## Important Files Quick Reference

| File | Purpose |
|---|---|
| `lib/main.dart` | App entry, provider tree, legacy data migrations |
| `lib/ui/session/state/session_controller.dart` | Session orchestration logic |
| `lib/ui/session/state/session_store.dart` | Session UI state (ChangeNotifier) |
| `lib/domain/session_parameter.dart` | User-configurable session settings |
| `lib/ui/session/state/frequency_calculator.dart` | Pure EQ frequency math |
| `lib/data/player_service.dart` | Audio engine wrapper + EQ control |
| `lib/data/clips/clip_format_migration.dart` | See [Clip Formats](#clip-formats) |
| `lib/data/clips/clip_recompress_service.dart` | See [Clip Formats](#clip-formats) |
| `lib/data/clips/clip_encoder.dart` | Convert or trim through SoLoud to Opus/FLAC/WAV |
| `lib/domain/audio_format_helper.dart` | Import/trim format policy and the natively-playable extension set |
| `lib/data/clips/audio_clip_repository.dart` | The clip library's JSON file; see [Persistence](#persistence) |
| `lib/data/legacy/legacy_clip_migration.dart` | Moves the library out of Hive; see [Persistence](#persistence) |
| `lib/data/clips/clip_library.dart` | Records and files together; see [Persistence](#persistence). `resolvePath` follows a clip whose file was rewritten mid-session |
| `lib/data/audio_state.dart` | Output device + Android backend state |
| `lib/l10n/app_en.arb` | Template strings; see [Localization](#localization) |
| `lib/data/locale_provider.dart` | The language picked in settings |

---

## Dependencies Worth Knowing

| Package | Role |
|---|---|
| `provider` | State management |
| `hive_ce` + `hive_ce_flutter` | Reading what older versions stored, nothing else; see [Persistence](#persistence) |
| `flutter_soloud` (git fork) | Cross-platform audio engine, plus the offline encoder `ClipEncoder` writes through. See [What the `flutter_soloud` fork carries](#what-the-flutter_soloud-fork-carries) |
| `flutter_localizations` + `intl` | i18n, through `gen-l10n`. `intl`'s version is pinned by the SDK. See [Localization](#localization) |
| `shared_preferences` | All settings, including the chosen language |
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

Only one copy of the app may run, because each would keep its own clip library in
memory and overwrite the other's saves. A second launch shows the running window
and exits, before Dart starts.

| Platform | How |
|---|---|
| Windows | A named mutex at the top of `wWinMain` in `windows/runner/main.cpp` |
| Linux | `GApplication` uniqueness in `linux/my_application.cc`. It works through the session bus, so with no bus there is no guard |
| macOS | Launch Services reuses the running app. `open -n` or running the binary directly gets past it |
| Android, iOS | One process per app |

The Windows and Linux guards are release-only, so `flutter run` and integration
tests work with the app open. A debug run on desktop can therefore sit beside a
release copy, so it keeps its own data: the boxes, library and clip files go under
`debug/` in the app support directory (`resolveAppDataDir`), and its settings use
a `debug.` key prefix. **Debug builds on desktop start empty and never migrate an
installed copy's data**, so test a desktop upgrade with a release build. Android
and iOS debug builds use the normal paths, which is what upgrade testing there
relies on.

Settings are the one thing still physically shared: `shared_preferences` writes
one file per app from a cached copy, so a debug and a release copy open at once
can revert each other's recent settings. Their library data cannot collide.

On macOS the title is deliberately *not* set from `MainFlutterWindow`.
Assigning `NSWindow.title` in `awakeFromNib` does not survive — AppKit
re-applies the nib's `APP_NAME` afterwards, so the title reverts to the bundle
name a moment after launch. It comes from `CFBundleName` instead, which also
fixes the menu items the nib builds from `APP_NAME` ("Quit eqTrainer" rather
than "Quit eq_trainer"). `PRODUCT_NAME` stays `eq_trainer` because it names the
binary and the `.app`, which the DMG packaging in CI depends on.
---

## Agent skills

### Issue tracker

Issues live in this repo's GitHub Issues (`potatosalad775/eqTrainer`), through the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage labels, each named after its role: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `GLOSSARY.md` and `docs/adr/` at the repo root, created only when a term or decision is settled. See `docs/agents/domain.md`.
