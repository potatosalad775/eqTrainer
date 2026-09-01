# coast_audio → flutter_soloud migration

Handoff notes. Written 2026-09-01. Read this before touching audio code.

## Why

Users report "strong noise burst out of nowhere" and stuttering when switching
the EQ filter. Two root causes:

1. **The noise burst is the toggle itself.** `AudioPlayer.setEQ` flips
   `_peakingEQNode.bypassed`, an instantaneous swap between the dry and the
   fully-filtered signal. At 12–15 dB that step edge is a click. Measured: a
   hard switch puts broadband energy only 52–67 dB below the signal, worst when
   it lands on a waveform crest — which is why it feels random to users. An
   earlier crossfade attempt made things worse because crossfading two
   *separately filtered* paths still moves filter coefficients.
2. **The stutter is Dart in the audio path.** coast_audio runs decode, ring
   buffering and EQ inside a Dart isolate driven by 10 ms timer clocks.
   `lib/shared/player/player_isolate.dart` is ~900 lines that are mostly
   workarounds for that (in-flight guards, poll cooldowns "to give the audio
   isolate breathing room for MP3 decoding", stale-clock races).

flutter_soloud runs the whole audio path on the native miniaudio callback
thread; Dart only sends control commands over FFI. coast_audio is also
unmaintained.

## Current state

**The migration is complete.** All six steps below are done: coast_audio is
gone from `pubspec.yaml`, from every call site, and from the Android, iOS,
macOS, Windows and Linux runners (jniLibs, the `CoastAudio` pod and its
`AppDelegate` symbol keeper, the xcframework entries in `Runner.xcodeproj`, and
the bundled `.dll`/`.so` install rules). `PlayerIsolate`, `PeakingEqNode` and
`PeakingEqFilter` are deleted.

Verified on Windows: `flutter analyze` clean, 192 unit tests pass,
`flutter build windows` links, and all four integration suites pass against
real audio hardware. **Not yet verified on Android, iOS, macOS or Linux** —
the runner edits for those are mechanical but unbuilt, and the Android backend
override in particular has only ever been exercised by an example APK build in
the fork, never by eqTrainer on a real device. Build each before release.

- Fork: `potatosalad775/flutter_soloud`, at `~/source/repos/flutter_soloud`
- Branch `main`, based on upstream `e38c5240` (v5.0.0-pre.3)
- The filter changes are committed to `feat/peaking-eq` branch. (commit 32b1843d144b6fcbabf1dfe1dcc82657696934f0)
- The Android backend override is commit `c8ead6edc5e7a3b5ef03f15f643fe7b1deebca7f`
  on the same branch — this is the SHA eqTrainer's `pubspec.yaml` pins.

### Toolchain

Both repos use the fvm **stable channel** (3.47.2 at the time of writing) — a
channel, not a version pin, and that's deliberate: the 3.44 global install
broke dependency resolution, and newer stables are expected to keep working.
Do not go back to 3.44.x: flutter_soloud 5.0.0-pre.3 needs `code_assets
^2.0.0` → `native_toolchain_c ≥0.19.4` → `meta ^1.19.0`, and 3.44.9's SDK pins
`meta 1.18.0`, so `pub get` fails outright. Use `fvm flutter ...` for every
command.

~~**CI is still on 3.44.4.**~~ Done: `flutter-version` is 3.47.2 across
`.github/workflows/build.yml` and `.github/workflows/test.yml`. It occurs in
**9** places, not 8 — the extra one is a commented-out job in `test.yml`,
bumped as well so re-enabling it can't reintroduce a stale pin that fails
`pub get` on `meta`.

### Files changed in the fork

New:
- `src/filters/peaking_eq_filter.h` / `.cpp` — the filter
- `lib/src/filters/peaking_eq.dart` — `PeakingEqSingle` / `PeakingEqGlobal`
- `test/peaking_eq_test.cpp` / `test/run_peaking_eq_test.sh` — 21 checks

Modified (registration only):
- `src/enums.h` — `PeakingEQFilter` appended to `FilterType` (ordinal 12)
- `src/filters/filters.cpp` — include, `addFilter`, `getFilterParamNames`
- `src/CMakeLists.txt` — added the `.cpp` to `PLUGIN_SOURCES`
- `lib/src/filters/filters.dart` — `FilterType.peakingEq`, `toString`,
  `numParameters => 4`, plus the getters on `FiltersSingle`/`FiltersGlobal`
- `lib/src/bindings/flutter_soloud_ffigen.dart` — `PeakingEQFilter(12)`

The other modified files in `git status` (`.gitignore`, `.vscode/settings.json`,
`.fvmrc`, generated plugin registrants, `pubspec.lock`) are fvm/pub side effects,
not migration work. Same in eqTrainer — only lockfile and registrants changed
there so far.

## The filter's design — do not "simplify" this

The filter is **not** a direct port of RBJ. It is algebraically refactored to

```
y[n] = x[n] + wet · (G − 1) · bp[n]
```

where `bp` is a bandpass whose **poles do not depend on gain**. Derivation is in
the comment block in `updateTargetCoefficients`.

This is the whole point. Dry and wet share the same `x[n]` term, so sweeping
`wet` from 0 to 1 changes **no recursive coefficient** and the filter state
never sees a discontinuity. The transition is click-free by construction, not
by tuning. Anyone who "cleans this up" back into a normal biquad plus a
crossfade reintroduces the original bug.

It costs nothing in fidelity: the identity is exact, so at `wet = 1` the
response *is* the RBJ peaking filter, the same curve `ma_peak2` gives today. The
existing frequency graph and difficulty calibration carry over unchanged.

Parameters — `wet` (0), `frequency` (1), `gain` in dB (2), `q` (3):

```dart
SoLoud.instance.filters.peakingEqFilter.wet
    .fadeFilterParameter(to: 1, time: const Duration(milliseconds: 20));
```

Fade `wet` whenever audio is rendering; never step it into a live signal.
(While nothing is rendering a step is both safe and required — see the
correction under "Round-transition sequencing".) `wet = 0` is bit-exact
bypass.

### Round-transition sequencing

Coefficients snap instantly while `wet` is inaudible — but "while inaudible"
is a real precondition the player service must enforce, because the user can
submit an answer while sitting in the Filtered view (`wet = 1`):

1. take `wet` to 0 — **fade it only while audio is actually rendering**
2. **wait until the engine reports `wet == 0`**, then
3. snap `frequency` / `gain` (and `q` at launch) to the new round's values
4. round is ready; the Original/Filtered toggle moves `wet` 0↔1 freely

If `wet` is already 0 (user was on Original), skip straight to step 3. Do not
replicate the current worker's order — `PlayerHostRequestSetEQParams` retunes
the still-active filter *before* bypassing it (`player_isolate.dart:503-507`),
which is part of today's click.

> **Correction (measured 2026-09-01, during the step-3 implementation).** An
> earlier draft of this section said to fade `wet` and then await "a 20 ms
> delay in Dart". That is wrong twice over, and both cases snap coefficients
> while the band is still fully in the signal — i.e. they reintroduce the exact
> click this migration removes:
>
> - **A fade does not advance while nothing is rendering.** SoLoud drives
>   parameter faders from the engine's stream time, and the output device
>   idle-pauses (500 ms by default) once no voice is playing. Measured: with
>   the voice paused, `fade(wet → 0)` still read `wet == 1.0` 775 ms later, and
>   only landed when playback resumed. The user can absolutely submit an answer
>   while paused. So when nothing is rendering, **set `wet` in a step** — there
>   is no signal for a step to click on, and it is the only thing that lands.
> - **A fade does not finish in its nominal duration.** It completes on a
>   mix-block boundary — ~46 ms at the default 2048-frame buffer. Measured: a
>   20 ms fade while playing still read its *old* value 25 ms later.
>   So don't wait a fixed time; **poll the applied value until it reaches the
>   target** (`PlayerService._awaitWet`), which stays correct on any buffer
>   size, with a timeout as a safety net.
>
> Both paths are covered by
> `integration_test/player_service_integration_test.dart`.

**Rapid Original/Filtered toggling is safe, and needs no guard.**
`FilterInstance::fadeFilterParameter` starts each new fade from the
*currently applied* value — `mParamFader[i].set(mParam[i], to, ...)`
(`soloud_filter.cpp:141`), where `mParam[i]` is rewritten from the fader every
block (`:109`). Interrupting a fade mid-flight is therefore continuous: the
parameter is piecewise-linear and never steps. If not even one block has
elapsed, `:135` sees `to == mParam[i]` and cancels the fader instead. So the
old isolate's toggle coalescing (`_eqToggleInFlight` / `_pendingEQValue`) does
not need porting — it existed to serialize isolate round-trips, and there are
no round-trips left.

**One guard from the old isolate does still need porting**, though: the
round transition must own the band while it runs. The user can tap Filtered in
the same frame as they submit an answer, and `setEQParams` genuinely awaits
(step 2 above). Without the guard the tap fades the band back in underneath
the transition, which then waits out its full timeout and *force-steps* `wet`
into live audio — a click at precisely the wrong moment — and leaves
`fetchEQState` disagreeing with what is audible. `PlayerService` drops toggles
while `_roundTransitionActive`, which is what `player_isolate.dart` meant by
"a round transition's EQ-enable state must win over a stale toggle tap".
Regression test: "a toggle during a round transition does not desync the
band".

### Verified results

`./test/run_peaking_eq_test.sh` from the fork root — 21/21 pass.

| Property | Result |
|---|---|
| Response vs RBJ, 6 configs (±3…±15 dB, 30 Hz–14 kHz, Q 0.7–10) | max deviation 1.8e-7 dB |
| `wet = 0` | bit-exact bypass (0.0) |
| 20 ms fade in/out | artifact 110–125 dB below signal |
| Hard bypass switch (today's behavior) | artifact 52–67 dB below signal |
| Retune band + immediate fade-in | settles bit-exactly onto the new band |

Also confirmed: `fvm flutter analyze lib/` clean, and a real Windows plugin
build compiles `peaking_eq_filter.obj` (so the CMake and `hook/build.dart`
wiring both pick it up).

**End-to-end, in eqTrainer, on the rendered audio.** The above is the filter
in isolation; `integration_test/peaking_eq_audio_integration_test.dart` closes
the loop by capturing SoLoud's mixer output
(`startMixerOutputStream`, tapped straight after `soloud->mix()` in
`soloud_miniaudio.cpp:506`, so it is downstream of global filters) and
measuring it while the app plays the 440 Hz fixture:

| Check | Result |
|---|---|
| Engine renders audio at all | RMS > 0 |
| +15 dB band on the tone | **+15.00 dB** measured |
| −15 dB band on the tone | −15 dB measured (±2 dB tolerance) |
| +15 dB band at 7 kHz, Q 4 | < 1 dB change — it is a bell, not a broadband gain |

Worth keeping: parameter-level assertions cannot catch a filter that is
correctly configured but never applied, and this suite is what caught the
`launch()` reset bug in the landmines below.

## Remaining work, in order

1. ~~**Android backend override**~~ **DONE** (fork commit `c8ead6ed`, pushed on
   `feat/peaking-eq`). `SoLoud.init` gained an `androidBackend` parameter
   (`AndroidAudioBackend.auto | aaudio | openSles`), threaded exactly the way
   `lowLatency` / `androidAAudioAttributes` already were. `auto` preserves the
   previous behavior; a request for AAudio below API 30 resolves to OpenSL.
   Verified by an example APK build (the Android path compiles) and the 21
   native filter checks still passing.
2. ~~**Branch setup in eqTrainer**~~ **DONE.** CI `flutter-version` bumped to
   3.47.2 — note it is **9** places, not 8: one is a commented-out job in
   `test.yml`, bumped too so re-enabling it can't reintroduce a stale pin.
   flutter_soloud added pinned to `c8ead6edc5e7a3b5ef03f15f643fe7b1deebca7f`.
3. ~~**Player service in eqTrainer**~~ **DONE** —
   `lib/shared/player/player_service.dart`. Keeps the old public surface
   (`launch`/`play`/`pause`/`seek`/`setEQ*`/`fetch*`) with `Duration` in place
   of `AudioTime`, so the session UI and `session_controller_test.dart` carry
   over. All the in-flight guards, coalescing and poll cooldowns are gone:
   every control call is now a synchronous FFI write. Covered by 19 checks in
   `integration_test/player_service_integration_test.dart`, run on the Windows
   desktop device. (Now 21 checks, and it *is* the UI's player — see step 5.)
4. ~~**Make the synchronous methods synchronous.**~~ **DONE.** `setEQ`,
   `setEQGain`, `setEQFreq`, `setEQQ`, `play`, `pause` and `setVolume` return
   `void`; only `launch`, `shutdown`, `seek` and `setEQParams` are async, so a
   call site can see at a glance which one genuinely waits. Done across steps
   5-6 as planned. `session_controller_test.dart`'s stubs are `thenReturn(null)`.
5. ~~**Session wiring**~~ **DONE.** `session_controller.dart` (which also lost
   its `updatePlayerState`/`setEqEnabled` futures), `session_page.dart`,
   `session_control.dart`, `session_position_slider.dart`,
   `session_eq_button_row.dart`, `session_selector.dart`.
   `session_control` no longer calls `shutdown()` before a track switch:
   `launch()` disposes the old source itself and keeps the device open.
6. ~~**Import & settings**~~ **DONE.**
   - `ImportPlayer` is a bare `PlayerService` subclass; its `filePath` is the
     base class's, set by `launch()`.
   - `ImportWorkflowService.loadAudioFile` lost its duration poll loop — SoLoud
     knows a source's length as soon as it is loaded — and `convertToM4a` is
     gone.
   - Format policy reworked per "Audio formats", plus one thing that section
     did not anticipate: **`keepOriginal` and `smart` are now byte-identical**,
     because mp3 and ogg became native. Two dropdown entries doing the same
     thing is worse than one, so the settings UI offers only Smart and
     All-WAV. Both retired constants (`allM4a`, `keepOriginal`) are still
     recognized as stored values and behave as `smart`; the dropdown displays
     them as Smart so it can't trip its "exactly one matching item" assertion.
     The `IMPORT_FORMAT_ORIGINAL_WARN` string and its `.tr()` keys are gone.
   - One-time m4a migration: `ClipFormatMigration`, fired unawaited from
     `main()` before `runApp`. Awaiting it would hold a blank screen for a
     whole library's worth of native decodes; it commits one clip at a time
     (record repointed *before* the original is deleted, and only after the
     output verifiably exceeds a WAV header), so a clip the user reaches
     mid-run is either fully converted or untouched. Idempotent, so it is safe
     to run on every launch and an interrupted run just resumes. Covered by 8
     unit tests against a mocked `audio_decoder` channel.
   - `PlayerService._loadSource` keeps the decode-to-memory fallback for
     anything non-native, i.e. clips the migration could not convert.
   - Backend settings page is now an Android-only radio of
     `auto | AAudio | OpenSL ES`, and the card that opens it is hidden on
     every other platform. The saved-setting mapping is in `audio_state.dart`
     and is unit-tested off-device (`androidBackendFromSavedListOnAndroid`) —
     it is the one piece of this migration that fails *silently* if wrong.
   - `audio_session` removed from `pubspec.yaml` (it was declared and never
     referenced). flutter_soloud still does not manage the iOS audio session
     category; if that turns out to matter on iOS, wire it up deliberately.
   - README's Linux row updated per the PulseAudio landmine. `AGENTS.md`'s
     audio-engine section rewritten.

Two files turned up in step 5-6 that a `coast_audio` grep missed, because they
imported `player_isolate.dart` without importing coast_audio itself:
`editor_control_button_group.dart` and `session_selector.dart`. `flutter
analyze` found both once the dependency went, which is the reliable way to
enumerate them.

### Decisions already taken

- **`AudioTime` → `Duration`.** 54 references across 10 files. Mechanical, and
  it's the bulk of the diff.
- **`LoadMode.disk` everywhere, not `memory`** (see "Audio formats").
- **WAV is the only conversion/trim target; m4a is retired** (see "Audio
  formats").
- **Global filter + per-handle volume**, never a per-voice filter (see the
  volume-compensation landmine).
- **Backend settings page shrinks to an Android-only control** rather than
  disappearing (see below).
- **README edit is deferred into the migration branch**, not done on master —
  the current README correctly describes shipped v2.5.0 on coast_audio.

## Backend selection

Not impossible — the machinery exists, it just isn't reachable from Dart.
`SoLoud.init()` has no `backend` parameter, but
`src/soloud/src/backend/miniaudio/soloud_miniaudio.cpp:874` already builds a
backend list:

```cpp
ma_backend backends[] = { ma_backend_aaudio, ma_backend_opensl };
ma_uint32 backendCount = 2;
if (android_get_device_api_level() <= 29) {
    backends[0] = ma_backend_opensl;
    backendCount = 1;
}
```

**This is a regression risk.** eqTrainer today defaults Android to OpenSL and
explicitly disables AAudio (`audio_state.dart:116-117`), because several
Digital Audio Player devices misbehave on AAudio. SoLoud's hardcoded default is
the opposite — AAudio first on API ≥ 30. Migrating as-is silently puts those
devices back on AAudio.

Automatic fallback does not help: `ma_context_init` takes the first backend that
*initializes*, and on those DAPs AAudio initializes fine and then glitches. An
explicit override is required.

To implement, mirror how `lowLatency` is already threaded:
`SoLoud.init(lowLatency:)` → `bindings_player.dart` → `bindings.cpp` →
`Player::init` → `miniaudio_setLowLatency()` (declared `soloud_internal.h:85`)
→ `gMiniaudioLowLatency`, read at device init. Add a `backend` parameter the
same way, consumed at the `ma_context_init` above. Only the init path needs it —
`changeDevice` reuses the existing context on Android and CoreAudio, so the
choice survives device switches.

Scope it to Android (`auto | aaudio | opensl`) and default eqTrainer to OpenSL.
Desktop backend selection is harder and optional: Windows defers device init
with `useContext = false` to avoid blocking the COM message pump, and Linux
passes a `NULL` context, so neither creates an explicit `ma_context` at all.

**Migrating the saved setting:** done, in `androidBackendFromSavedList`
(`audio_state.dart`), with the mapping the plan called for: list contains
`"aaudio"` and not `"openSLES"` → `aaudio`; anything else, empty list included
→ `opensl`; non-Android → `auto`.

The box is *kept* rather than deleted, and the settings page writes back into
the same `BackendData(List<String>)` shape — a single entry, `['auto']`,
`['aaudio']` or `['openSLES']`. That avoids a new Hive field (and the codegen
round-trip) and makes one read/write cycle lossless, which the
`androidBackendFromSavedListOnAndroid` round-trip test asserts. The `'auto'`
marker is checked first, before the legacy list heuristic, so a deliberate
`auto` isn't read back as `opensl`.

## Audio formats

SoLoud natively decodes **wav, mp3, flac, ogg**. Import those as-is.

**Load with `LoadMode.disk`, not `memory`.** Memory mode holds the fully
decoded float PCM in RAM (~21 MB per stereo minute at 44.1 kHz); a
`keepOriginal` full song is 80–100 MB+, and target devices include DAPs with
3 GB of RAM. Disk mode streams and decodes on the native audio thread, so the
stutter fix (no Dart in the audio path) holds either way — the only thing
memory mode buys is decode-cost avoidance, which the format policy below makes
irrelevant (wav streaming is a raw PCM read; flac/mp3/ogg are cheap on a
native thread).

**WAV becomes the only conversion target; m4a is retired.** m4a/wav were
originally preferred because coast_audio decoded them fastest under rapid
filter switching. That reason is gone — the SoLoud filter switch is a `wet`
fade on an already-running stream and never touches the decoder — and m4a is
now the one common format SoLoud *cannot* play, i.e. the only one that would
need conversion on every load. Concretely, in `audio_format_helper.dart`:

- `ImportFormat.smart`: keep wav/mp3/flac/ogg as-is; convert everything else
  (m4a/aac, wma, aiff, alac, caf) → wav.
- `ImportFormat.allM4a`: remove the mode from the settings UI, keep the stored
  Hive value recognized and treat it as `smart` so existing users don't break.
- `ImportFormat.keepOriginal`: convert only what SoLoud can't read — and stop
  converting `.ogg`, it's native now.
- `trimOutputExt`: always `.wav`. Trimming a lossy clip to m4a re-encoded
  lossily anyway; wav avoids the generation loss and plays natively.

`audio_decoder` stays for those conversions, so its GStreamer requirement on
Linux stays too.

**Existing `.m4a` clips: one-time migration, not per-load conversion.** Clips
are app-owned copies in the app support directory, so on first launch after
the update: convert each `.m4a` clip to `.wav` (`AudioDecoder.convertToWav`),
update the Hive record, and delete the `.m4a` only after the new file
verifiably loads. Keep load-time `convertToWavBytes(..., formatHint: 'm4a')`
→ `loadMem()` solely as a fallback for clips the migration couldn't handle.
Converting on every session launch and track switch would otherwise pay a
per-clip GStreamer/MediaCodec decode delay forever.

Follow-up (disk-size win, not required for the migration): fork
`audio_decoder` to add FLAC output. Lossless, about half the size of WAV,
decoded natively by SoLoud, and every platform has a native encoder
(AVFoundation, MediaCodec API 24+, Media Foundation FLAC MFT, GStreamer
`flacenc`). Verify the Windows 10 baseline covers the FLAC MFT. Once it
lands, switch the conversion target and trim output from wav to flac.

## Landmines

- **Never put a `.cpp` with `main()` in `src/filters/`.** `hook/build.dart`
  globs that whole directory (`addDir('filters/')`), so it would land in the
  plugin build. Native tests belong in the repo-root `test/`, which is outside
  `src/` and never globbed.
- **Keep the three `FilterType` orderings in lockstep**: `src/enums.h`,
  `lib/src/filters/filters.dart`, and the ffigen enum in
  `lib/src/bindings/flutter_soloud_ffigen.dart`. `bindings_player_ffi.dart` maps
  Dart→native by `.index`, so a mismatch silently applies the wrong filter.
  Append new types at the end; the prebuilt web wasm depends on the ordinals.
- **Linux loses the native PulseAudio backend.** `MA_NO_PULSEAUDIO` is defined
  in both build paths (`src/src.cmake:259`, `hook/build.dart:52`) — the only
  `MA_NO_*` in the repo — so Linux keeps ALSA and JACK only. PulseAudio and
  PipeWire *systems* still work, via their ALSA compatibility plugin, but the
  device dropdown will enumerate ALSA device names instead of Pulse sink names.
  README line 45 currently claims PulseAudio support and must be updated:

  ```markdown
  | Linux    | -               | Works with ALSA & JACK <br/> <sub>*PulseAudio / PipeWire systems are supported through their ALSA compatibility layer.*</sub> <br/> <sub>*GStreamer 1.0+ required for audio format conversion.*</sub> |
  ```

- **Keep the volume compensation behavior — and its ordering.** `setEQGain`
  pre-attenuates by `10^(-|gainDb|/20)` at all times, not only when EQ is
  active, so dry and wet match in loudness and the user cannot identify the
  boosted round by level alone. Today the attenuation sits *before* the EQ so
  a boosted peak can't clip. The SoLoud mapping that preserves this: **the
  global peaking EQ filter plus per-handle volume, never a per-voice filter.**
  SoLoud applies handle volume while mixing each voice, then global filters on
  the mixed output, then the final clipper — volume → EQ → clamp, the same
  chain as today. (A per-voice filter would flip it: SoLoud runs voice filters
  before the voice's volume.) SoLoud is float32 end-to-end with its only
  clipper at the final output, so nothing clips mid-chain either way, but the
  global-filter arrangement keeps the proven ordering and survives track
  switches without re-attaching. One duty remains on every track switch:
  re-apply the compensation volume to the **new handle** — a fresh voice
  starts at volume 1.0.
- **The Windows runner needs a native-assets install rule.** flutter_soloud
  has no plugin class and ships nothing through CMake — its entire native
  engine is built by `hook/build.dart` as a *code asset*. eqTrainer's
  `windows/CMakeLists.txt` predates native assets and had no rule to copy
  them, so `flutter_soloud_plugin.dll` was built into
  `build/native_assets/windows/` and then never bundled; every FFI lookup
  failed at runtime with `Failed to load dynamic library`. Fixed by adding the
  standard `NATIVE_ASSETS_DIR` install block (`windows/CMakeLists.txt`).
  `linux/CMakeLists.txt` already had it; macOS/iOS bundle code assets through
  Xcode and need nothing. Note this bites `flutter build` as much as
  `flutter test`, so it is not a test-only concern.
- **The global filter outlives the player object — reset the band on every
  `launch()`.** The peaking EQ is a *global* filter, so it belongs to the
  engine, but a player's `_eqEnabled` mirror is per-instance and starts false.
  `session_page.dart` builds a new player per page, so leaving a session on
  "Filtered" and re-entering gives you a fresh player that believes the band
  is out over an engine still holding `wet = 1`. Round 1 would then be audibly
  filtered while the UI said "Original" — handing the user the answer — and
  `setEQParams` would skip its fade-out and snap coefficients into a fully-wet
  signal. `PlayerService.launch()` steps `wet` to 0 unconditionally (safe: the
  source is loaded paused, nothing is rendering). The old isolate got this for
  free because a fresh isolate really did start bypassed. Caught only by the
  rendered-audio test, not by any parameter-level assertion.
- **The engine is a singleton, so `_activeDeviceId` is `static`.** Three
  `PlayerService` instances exist over one SoLoud instance (session page,
  playlist preview, import editor). Per-instance, a newly built player always
  reads `null` there and re-runs `changeDevice` on a device that is already
  open — a needless output restart on entering the import editor or the
  playlist preview.
- **`listPlaybackDevices()` really is safe before `init()`, and the app
  depends on it.** `AudioState.initialize` runs in `AppState.initState`, long
  before anything plays, and the settings dropdown enumerates on every build.
  This is what replaced coast_audio's probe-context dance (build an
  `AudioDeviceContext`, read it, dispose it immediately so it couldn't collide
  with the playback context on AAudio). Verified on real hardware by
  `integration_test/audio_state_integration_test.dart`, which is the only
  suite that deliberately runs with the engine *down* — every other one brings
  it up in `setUpAll`, so none of them would catch a regression here.
- Windows/MSVC: `soloud.h` pulls in `windows.h`, so `min`/`max` macros collide
  with `std::` versions. `peaking_eq_filter.cpp` avoids `std::min`/`std::max`
  entirely for this reason; the native test builds with `-DNOMINMAX`.

## Commands

```bash
# fork
cd ~/source/repos/flutter_soloud
./test/run_peaking_eq_test.sh          # native filter tests
fvm flutter analyze lib/
cd example && fvm flutter build windows --debug   # validates native wiring

# app
cd ~/source/repos/eqTrainer
fvm flutter analyze
```
