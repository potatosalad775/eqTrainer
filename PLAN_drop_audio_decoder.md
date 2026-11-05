# Plan: drop `audio_decoder`

Written 2026-11-04. This is a working note, not project documentation. Delete it
when the decision is made and recorded in `AGENTS.md`.

**Status:** not decided. Windows and macOS are measured, iOS on the simulator only, and
Android on one device, a FiiO JM21. A real iOS device, other Android devices and Linux
are not.

**Progress:** stages 1 and 2 are done and tested on macOS, the iOS simulator, the JM21 and
Windows. On Linux they have only been compiled, by CI. The pin is on the fork's
`custom-5.2.2`. Gate 5 passed on the JM21. On every platform but Linux, nothing in the app
calls `audio_decoder` any more. See [Stage 3 so far](#stage-3-so-far).

**Next:** test Linux and decide its packaging, then stage 4. Test a real iPhone before
release. That needs the Mac, since iOS builds need Xcode.

**Recommendation:** make SoLoud the only decoder, in stages. Stop if the gates below
fail on a phone. Moving the trim is worth doing even if the package never fully goes,
because it fixes a bug users can hit today.

## Why

### Trimming Ogg files fails on Windows today

Confirmed through `AudioClipService.createClip` on Windows. `audio_decoder` uses Media
Foundation there, which cannot open Ogg.

| Trim source | Result |
|---|---|
| `.wav`, `.flac`, `.mp3` | ok |
| `.opus`, `.ogg` | `Audio trim failed: Failed to create source reader` |

The reach is probably wider than Ogg imports. The trim reads `player.filePath`, which
is the converted temp file, so an M4A, AAC or WMA import under Smart should fail the
same way once trimmed, and so should every trimmed import under All-Opus. This part
comes from reading the code. It has not been clicked through in the app.

macOS 27.2 does not fail this way. AVFoundation read Ogg Opus and Vorbis there, and
`createClip` trims of `.opus` and `.ogg` did not throw, though the spike does not check
their audio. `audio_decoder` has no Ogg code of its own, so this comes from the OS and
may not hold on older versions, down to the supported macOS 12. Ogg FLAC still fails.

The iOS 18.6 and 26.5 simulators do fail on part of this. `createClip` throws
`Audio trim failed` on `.ogg` (Vorbis), but not on `.opus`, so the bug is real on iOS
for a narrower set of files than on Windows.

The FiiO JM21 on Android 13 does not fail this way: `createClip` trims of `.opus` and
`.ogg` did not throw.

### `audio_decoder` can crash the app on ALAC on Android

On the JM21, `convertToWavBytes` on an ALAC M4A sometimes ends the process with a native
SIGSEGV, a `memcpy` inside `MediaExtractor.readSampleData`. Dart cannot catch that. It
happens with `audio_decoder` alone: a loop of it died on round 2, and a loop of SoLoud
alone ran 60 rounds clean. It is intermittent, since a loop of both ran 60 rounds clean
as well. `ClipEncoder` makes the same call on import, so importing such a file should be
able to crash the app today. That last part has not been clicked through in the app.

### A trimmed import loses an extra generation

Because of the same temp file, a trimmed lossy import goes source → Opus → Opus on
platforms where the trim works at all.

### The app decodes the same files two ways

Clips play through SoLoud but are trimmed by a different decoder. The two disagree: an
MP3 fixture comes back as 0.300 s from SoLoud and 0.368 s from `audio_decoder` on
Windows.

## What `audio_decoder` does now

| Call site | Call | Job | Replacement |
|---|---|---|---|
| `audio_clip_service.dart:50,57` | `trimAudio` | Trim | Decode, slice, encode |
| `clip_encoder.dart:44` | `convertToWavBytes` | Convert on import | Decode, encode |
| `import_workflow_service.dart:62` | `convertToWav` | All-WAV import | Decode, encode WAV |
| `clip_format_migration.dart:275` | `convertToWav` | Migration to WAV | Decode, encode WAV |
| `player_service.dart:236` | `convertToWavBytes` | Playback fallback | `loadFile`, or remove |

It has other costs outside the Dart code: GStreamer in the Linux `deb` and `rpm`
dependencies, in `build.yml` and in the README.

## Why not `readSamplesFromFile`

It looked usable but is not. It samples for waveform drawing: `waveform.cpp` writes
`pSamples[id] = tempBuffer[0]`, so stereo silently becomes left-only, and it reports
no sample rate or channel count.

The spike adds `SoLoud.decodeFileToPcm` to the fork instead, built on `SoLoud::Wav`
and the Ogg path `player.cpp` already uses. It returns interleaved float PCM with the
file's channel count and sample rate, and needs no running engine.

## Results so far: Windows

Each file is 0.3 s of stereo with different tones left and right, so the test catches
swapped or collapsed channels. Timing below is on Windows only.

| Format | SoLoud | `audio_decoder` |
|---|---|---|
| WAV 16/24, FLAC, FLAC mono | correct | correct |
| MP3 | correct, 0.300 s | correct, but 0.368 s long |
| Ogg Vorbis, Ogg FLAC | correct | **fails** |
| Ogg Opus, stereo and mono | correct, always 48 kHz | **fails** |
| M4A AAC, MP4 AAC, raw AAC | correct, 0.325 s | same, 0.325 s |
| M4A ALAC | correct | correct |
| WMA | correct | correct |
| AIFF | fails | fails |
| CAF ALAC | fails | fails |
| CAF PCM | **wrong audio, no error** | fails |

On Windows, `audio_decoder` reads nothing that SoLoud cannot.

Other Windows results:

- **Trim through SoLoud:** frame-exact, and a FLAC round trip stays within one 16-bit
  step (−90.1 dB).
- **Non-ASCII paths:** `decodeFileToPcm` reads `한글 파일 é` in all four formats tried.
- **Long files, 10 minutes stereo:**

| Path | Time | RSS rise |
|---|---|---|
| `decodeFileToPcm`, FLAC | 0.4 s | 403 MB |
| `decodeFileToPcm`, Opus | 1.3 s | 439 MB |
| `audio_decoder` trim of 10 s near the end, FLAC | 0.5 s | 0 MB (sampled) |

Decoding is fast. Memory is the real cost.

## Results so far: macOS

Measured on macOS 27.2, on the same fixtures.

| Format | SoLoud | `audio_decoder` |
|---|---|---|
| WAV 16/24, Ogg Vorbis | correct, 0.300 s | correct, 0.300 s |
| MP3 | correct, 0.300 s | correct, but 0.366 s long |
| FLAC, FLAC mono | correct, 0.300 s | correct, but 0.313 s long |
| Ogg Opus, stereo and mono | correct, always 48 kHz, 0.300 s | correct, but 0.314 s long |
| Ogg FLAC | correct | **fails** |
| M4A AAC, M4A ALAC, MP4 AAC | correct, 0.300 s | correct, 0.300 s |
| Raw AAC | correct, 0.325 s | correct, 0.325 s |
| AIFF, AIF, CAF ALAC | correct | correct |
| CAF PCM | **wrong audio, no error** | correct |
| WMA | fails | fails |

On macOS, `audio_decoder` reads one format that SoLoud cannot: CAF PCM.

Other macOS results:

- **Trim through SoLoud:** frame-exact, and a FLAC round trip stays within one 16-bit
  step (−90.1 dB).
- **Non-ASCII paths:** `decodeFileToPcm` and `loadFile` in `LoadMode.disk` both read
  `한글 파일 é` in all four formats tried, so problem 3 below did not appear.
- **Long files, 10 minutes stereo:**

| Path | Time | RSS rise |
|---|---|---|
| `decodeFileToPcm`, FLAC | 0.4 s | 412 MB |
| `decodeFileToPcm`, Opus | 0.9 s | 575 MB |
| `audio_decoder` trim of 10 s near the end, FLAC | 0.0 s, output not checked | 0 MB (sampled) |

## Results so far: iOS simulator

Measured on the iOS 18.6 and 26.5 simulators, which gave the same matrix. Not a real
device, so codec support may differ and the time and memory figures are not a phone's.

Everything matches macOS except one row, where `audio_decoder` also fails:

| Format | SoLoud | `audio_decoder` |
|---|---|---|
| Ogg Vorbis | correct, 0.300 s | **fails** |

So SoLoud again reads everything `audio_decoder` does except CAF PCM, where it returns
the same wrong audio, and WMA fails on both.

Other iOS simulator results:

- **Trim through SoLoud:** frame-exact, and a FLAC round trip stays within one 16-bit
  step (−90.1 dB).
- **Non-ASCII paths:** `decodeFileToPcm` and `loadFile` in `LoadMode.disk` both read
  `한글 파일 é` in all four formats tried.
- **Long files, 10 minutes stereo:**

| Path | Time | RSS rise |
|---|---|---|
| `decodeFileToPcm`, FLAC | 0.3 s | 404 MB |
| `decodeFileToPcm`, Opus | 0.8 to 0.9 s | 382 to 405 MB |
| `audio_decoder` trim of 10 s near the end, FLAC | 0.0 s, output not checked | 0 MB (sampled) |

## Results so far: Android

Measured on a FiiO JM21: Snapdragon 680, Android 13, 2.7 GB of RAM visible, 1.1 to 1.5 GB
available before each run. One device, so codec support may differ elsewhere.

| Format | SoLoud | `audio_decoder` |
|---|---|---|
| WAV 16/24, MP3, FLAC, FLAC mono, Ogg Vorbis | correct, 0.300 s | correct, 0.300 s |
| Ogg Opus, stereo and mono | correct, always 48 kHz, 0.300 s | correct, but 0.314 s long |
| Ogg FLAC | correct | **fails** |
| M4A AAC, MP4 AAC | correct, 0.302 s | correct, 0.302 s |
| Raw AAC | correct, 0.325 s | correct, 0.325 s |
| M4A ALAC | fails | fails, **and can crash the app** |
| AIFF, AIF, CAF ALAC, WMA | fails | fails |
| CAF PCM | **wrong audio, no error** | fails |

On this device, `audio_decoder` reads nothing that SoLoud cannot.

Other Android results:

- **Trim:** through SoLoud it is frame-exact at 2205 frames, and a FLAC round trip stays
  within one 16-bit step (−90.1 dB). `audio_decoder` returned 2403 frames for the same
  range, about 9 ms too long.
- **Engine down:** `decodeFileToPcm` worked with no engine running, in the app's process.
- **Non-ASCII paths:** `decodeFileToPcm` and `loadFile` in `LoadMode.disk` both read
  `한글 파일 é` in all four formats tried.
- **AAudio:** `SoLoud.init` with the default backend failed on this device, in
  `ma_device_start`. OpenSL ES, which the app pins, worked. The spike now uses the app's
  backend.
- **Long files, 10 minutes stereo, across two runs:**

| Path | Time | RSS rise |
|---|---|---|
| `decodeFileToPcm`, FLAC | 1.7 to 3.1 s | 397 to 400 MB |
| `decodeFileToPcm`, Opus | 4.4 to 9.5 s | 412 to 440 MB |
| `audio_decoder` trim of 10 s near the end, FLAC | 0.3 to 0.7 s, output not checked | 0 to 5 MB (sampled) |

The low memory killer never ended the app. It ended 15 other processes while the app was
up in one full run, and 2 at some point during another. The test's own 200 MB synthesis
buffer contributes to that, and the kills were not matched to specific steps.

## Problems the spike found in the new path

1. **Memory.** The rise is about twice the PCM size or more, because the native buffer
   and the Dart copy exist at once, and a trim of 10 s still decodes the whole file. An
   hour of stereo would be around 2.4 GB on Windows, the iOS simulator and the JM21, and
   2.5 to 3.5 GB on macOS. The JM21 has only 1.1 to 1.5 GB available, so that would not
   fit. Removing the copy halves it, which is still marginal there, so whole-file decoding
   does not pass this gate on its own. A trim needs the time range. See gate 3.
2. **Unknown files can decode to junk.** CAF PCM came back as 0.157 s of wrong audio
   with no error on every platform so far, most likely from a lenient decoder guessing.
   Check file signatures before decoding, and refuse what is not recognised.
3. **An M4A with a non-ASCII path fails in `LoadMode.disk` on Windows.** `loadFile`
   reads the header in `Player::decodeFile` through `readFileBytes`, which uses a narrow
   `std::ifstream`. `decodeFileToPcm` is not affected, and neither is memory mode. Fix
   this in the fork before playing M4A through `loadFile` directly.

## After stage 1

Measured with the new `decodeFileToPcm`, which decodes incrementally into one buffer that
Dart takes over without a copy, and accepts a time range. Debug builds, so CPU times are
pessimistic.

| 10 minutes stereo | macOS | iOS simulator | JM21 |
|---|---|---|---|
| FLAC, 10 s range near the end | 0.1 s, 0 MB | 0.1 s, 0 MB | 0.4 s, 0 MB |
| Opus, 10 s range near the end | 0.6 s, 0 MB | 0.7 s, 0 MB | 8.0 s, 0 MB |
| FLAC, whole file | 0.2 s, not reliable | 0.2 s, 202 MB | 1.7 s, 190 MB |
| Opus, whole file | 0.7 s, 223 MB | 0.8 s, 220 MB | 10.7 s, 411 MB |

The figures are RSS rise, which only counts memory beyond what the process already holds,
so a 0 means little more than that the 3 MB range was not noticeable.

- **Problem 1:** a trim now holds its range. It is not fixed for three cases. Platform
  formats such as M4A still hold the whole file in a planar buffer while decoding, Opus
  still decodes up to the range, since nothing seeks it, which on the JM21 extrapolates to
  about 48 s near the end of an hour, and a whole Opus decode can still reach twice its
  size on the JM21, because its length is not known in advance and the buffer grows.
- **Problem 2:** fixed. A file with no recognised signature is refused. CAF PCM never
  reaches dr_mp3 now, so on macOS and iOS it decodes correctly through the platform codec,
  and on the JM21 it fails cleanly. That removes the only format loss on Apple platforms.
- **Problem 3:** `readFileBytes` now uses `DiskFile`. Not retested, since only Windows
  showed it.
- **Trim on iOS:** `createClip` no longer fails on `.ogg`.
- **Every range is exact:** on all three, in every format SoLoud reads there, a range equals
  the same frames of the whole decode, sample for sample.

**Gate 5.** On the JM21, a steady chord played through `PlayerService` during every phase
of `gate5_listening_test.dart`: the two new trims, a whole Opus decode, and the old trim.
Someone listened through it on headphones and heard no problems or drops, as if nothing
else were running. AudioFlinger's underrun counter also stayed at 0, sampled every 4 s, in
both complete runs. The material was a steady synthetic chord, not music, and this is
a debug build.

## Stage 3 so far

`ClipEncoder.convertFile` decodes through SoLoud, so it covers lossy, FLAC and Opus imports
and the migration of old M4A clips. `audio_decoder` remains its fallback on Linux only,
until the FFmpeg decision. Falling back everywhere would keep the ALAC crash, since a file
SoLoud cannot read is exactly what reaches it.

| JM21 | Before | Now |
|---|---|---|
| ALAC M4A, 60 conversions | crashed on round 2 of the plugin loop | 60 clean refusals |
| 10 minute M4A import | **`OutOfMemoryError` ends the app** | works, 97 to 99 s, RSS up 377 to 378 MB |

The crash comes from `audio_decoder` returning about 105 MB of WAV over a method channel,
which the Java heap cannot hold. It is uncaught, so nothing in Dart can handle it.

| 10 minute M4A import | SoLoud | `audio_decoder` |
|---|---|---|
| macOS | 4.3 s, 467 MB | 4.5 s, 616 MB |
| iOS simulator | 4.4 s, 529 MB | 4.6 s, 305 MB |

Debug builds, and RSS rise depends on what the process freed earlier, so these are rough.

All-WAV imports and the WAV migration now go through `convertFile` too. WAV output stays
16-bit, the default of `audio_decoder`'s path as well. `PlayerService` loads old `.m4a` and
`.aac` clips with `loadFile` in `LoadMode.memory`. The picker's list is per platform, and a
refused file gets its own dialog, which on Linux says to install FFmpeg. Nothing outside
Linux can now reach `audio_decoder`, so the ALAC crash is closed there.

**Not measured:** a long All-WAV M4A import on a slow device. `convertToWav` was described
as not holding the clip in memory, so this one path may be worse than before.

**Not tried by hand:** the new dialog and the per-platform picker in the running app. The
Linux message only appears after stage 4, since `ClipEncoder` falls back until then.

**Gate 3 for imports:** an hour of M4A extrapolates to about 2.3 GB on the JM21, so it does
not fit. A 10 minute import does, which is more than the old path managed. The gate is now
"no worse than today" rather than a fixed hour.

## Results after stage 3: Windows

Windows 11 build 26300, debug build, with the same fixtures. All 8 spike tests passed.

- **Matrix:** unchanged from [the first Windows run](#results-so-far-windows), except that
  CAF PCM is now refused rather than returning wrong audio.
- **Trim:** `createClip` on `.opus`, `.ogg`, `.flac`, `.mp3` and `.wav` all work, so the bug
  this plan started from is fixed here. `audio_decoder` still fails on `.opus`.
- **Ranges and paths:** every range equals the same frames of the whole decode, and
  `한글 파일 é` loads through both `decodeFileToPcm` and `loadFile` in disk mode, so
  problem 3 is confirmed fixed.
- **ALAC:** 60 of 60 conversions worked. Windows has a decoder for it.

| 10 minutes stereo | Time | RSS rise |
|---|---|---|
| FLAC, whole file | 0.2 s | 202 MB |
| FLAC, 10 s range near the end | 0.1 s | 0 MB |
| Opus, whole file | 1.1 s | 285 MB |
| Opus, 10 s range near the end | 0.9 s | 0 MB |
| M4A import through SoLoud | 12.0 s | 403 MB |
| M4A import through `audio_decoder` | 12.5 s | 302 MB |

## Gates

All of these need passing results before the switch.

| # | Gate | Windows | macOS | iOS | Android | Linux |
|---|---|---|---|---|---|---|
| 1 | SoLoud decodes WAV, MP3, FLAC, Vorbis and Opus correctly | pass | pass | pass (simulator) | pass (JM21) | ? |
| 2 | Trim through SoLoud is frame-exact | pass | pass | pass (simulator) | pass (JM21) | ? |
| 3 | A long file fits in memory on the weakest supported device | ~2.4 GB for the target below, extrapolated from 10 min | ~2.5 GB FLAC, ~3.5 GB Opus, extrapolated from 10 min | ~2.4 GB on the simulator before stage 1, device limit unknown | Before stage 1, ~2.4 to 2.6 GB extrapolated with 1.1 to 1.5 GB available (JM21). **Passes for trims of WAV, FLAC, MP3 and Ogg now**, not yet for M4A or a whole-file conversion | ? |
| 4 | The formats lost are acceptable (see below) | none lost | none lost since stage 1 | none lost since stage 1 (simulator) | none lost (JM21) | ? |
| 5 | Decoding during a session does not cause audible problems | not run | not run | not run | pass: nothing heard, 0 underruns (JM21) | ? |

Gate 3's table records the original target of one hour of stereo at 44.1 kHz. The target is
now "no worse than today", since the old path crashed at 10 minutes on the JM21.

Gate 5 needs a person listening: import or trim on a slow DAP while audio plays. The
decode runs on an isolate, but it is still CPU-seconds.

The JM21 is a good candidate for gate 5, and decoding there took 1.7 to 9.5 s of CPU per
10-minute file.

### Linux needs its own decision

SoLoud's M4A and AAC paths need system FFmpeg at runtime, per its README, where
`audio_decoder` uses GStreamer. WMA on Linux is undocumented, so test it. The switch swaps one system dependency for another, so test on a clean
machine with no FFmpeg. The options are to depend on FFmpeg in the `deb` and `rpm`, or
to refuse those formats on Linux.

### Formats that may be lost

Fill this in from the matrix. A format works in the app only where the matrix says so,
and it can be dropped from the picker per platform.

| Format | If SoLoud cannot read it on a platform |
|---|---|
| AIFF | PCM, so a small Dart parser beside `wav_pcm.dart` can cover it everywhere, including Windows and the JM21, where it fails today |
| CAF | Mostly an Apple format. Drop it from the picker elsewhere, since it already fails on Windows |
| WMA | Probably only ever worked on Windows, and SoLoud reads it there |
| ALAC | Varies by Android device already, and fails on the JM21 through both decoders. Say so in the error |

## How to run the spike

Nothing plays, but engine init needs an output device.

```
fvm flutter test integration_test/drop_audio_decoder_spike_test.dart -d macos
```

Use `-d <device-id>` for a phone, and try the slowest one available. Keep the `SPIKE|`
lines. Lower `_longMinutes` if a slow device takes too long.

Gate 5 is `integration_test/gate5_listening_test.dart`, run the same way, with someone
listening and the screen awake. It names each phase on screen.

It builds against the fork's SHA pinned in `pubspec.yaml`.

## Stages

Each stage can ship by itself, and stopping after any of them leaves things better.

**Stage 1: fork API.** Harden `decodeFileToPcm`, then pin it:
- Refuse unrecognised signatures (problem 2).
- Reduce the memory peak (problem 1). Hand the native buffer to Dart with a finalizer
  rather than copying it, which removes the double. Add a time range so a trim stops
  decoding at its end point, and seeks where the format allows it.
- Fix `readFileBytes` (problem 3).
- Add a C++ test beside `offline_encode_test.cpp`, and a row in the fork table in
  `AGENTS.md`.
- Move the pin in `pubspec.yaml`, and delete `pubspec_overrides.yaml`.

**Stage 2: trim.** Decode, slice and encode in `AudioClipService`, and read from the
original file rather than the converted temp. This fixes the Ogg failure and removes
the extra generation. It stands alone if the rest stalls, and is the most valuable
stage.

**Stage 3: conversion.** Move `ClipEncoder.convertFile`, `convertTo` and the WAV
migration path onto `decodeFileToPcm`. Update the picker per platform from the matrix,
and add the AIFF parser if wanted.

**Stage 4: remove.** Remove the `PlayerService` fallback. Then:
- Drop `audio_decoder` from `pubspec.yaml`.
- Drop GStreamer from both Linux `make_config.yaml` files, `build.yml` and the README.
- Replace the `MethodChannel('audio_decoder')` stubs in `audio_clip_service_test`,
  `clip_format_migration_test` and `import_workflow_service_test`.
- Update `AGENTS.md`: Clip Formats, the Ogg-on-Apple rationale, Testing and Dependencies.

## Considered and not doing

**Keeping or writing M4A.** Reading it gains one avoided Opus 192k generation, in
exchange for a per-platform policy and a streaming path that can underrun on slow
DAPs. Stage 2 gets most of that benefit at lower risk, so this stays "not now", as
`AGENTS.md` already says.

Writing it is worse. The only encoder is `audio_decoder`'s, fixed at 128 kbps on Android
and Windows. The same pink noise, measured against the source on Windows:

| Band | AAC 128k | Opus 192k |
|---|---|---|
| 8–14 kHz | −0.3 dB | 0.0 dB |
| 15–16 kHz | −1.6 dB | 0.0 dB |
| 16–17 kHz | −69 dB | 0.0 dB |
| 18–19 kHz | −90 dB | −0.1 dB |

**Bundling FFmpeg.** One decoder everywhere, but a bigger app, per-platform builds and
LGPL obligations. MP3 output was dropped to avoid exactly that kind of dependency.

**Keeping `audio_decoder` for rare formats only.** This is the fallback if gate 4 fails
on a platform. Stages 1 to 3 still help, so the plan does not depend on full removal.
