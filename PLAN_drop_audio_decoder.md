# Plan: drop `audio_decoder`

Written 2026-11-04. This is a working note, not project documentation. Delete it
when the decision is made and recorded in `AGENTS.md`.

**Status:** not decided. Windows is measured. macOS, iOS, Android and Linux are not,
and their results decide this.

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

macOS and iOS are suspected to fail too, because AVFoundation cannot open Ogg either.
That is what the Mac run will show.

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

## Problems the spike found in the new path

1. **Memory.** The rise is about twice the PCM size, because the native buffer and the
   Dart copy exist at once, and a trim of 10 s still decodes the whole file. An hour
   of stereo would be around 2.4 GB, which is not acceptable on a phone. See gate 3.
2. **Unknown files can decode to junk.** CAF PCM came back as 0.157 s of wrong audio
   with no error, most likely from a lenient decoder guessing. Check file signatures
   before decoding, and refuse what is not recognised.
3. **An M4A with a non-ASCII path fails in `LoadMode.disk` on Windows.** `loadFile`
   reads the header in `Player::decodeFile` through `readFileBytes`, which uses a narrow
   `std::ifstream`. `decodeFileToPcm` is not affected, and neither is memory mode. Fix
   this in the fork before playing M4A through `loadFile` directly.

## Gates

All of these need passing results before the switch.

| # | Gate | Windows | macOS | iOS | Android | Linux |
|---|---|---|---|---|---|---|
| 1 | SoLoud decodes WAV, MP3, FLAC, Vorbis and Opus correctly | pass | ? | ? | ? | ? |
| 2 | Trim through SoLoud is frame-exact | pass | ? | ? | ? | ? |
| 3 | A long file fits in memory on the weakest supported device | ~2.4 GB for the target below, extrapolated from 10 min | ? | ? | ? | ? |
| 4 | The formats lost are acceptable (see below) | none lost | ? | ? | ? | ? |
| 5 | Decoding during a session does not cause audible problems | not run | ? | ? | ? | ? |

Gate 3's target is one hour of stereo at 44.1 kHz. Pick the real number from the longest
file anyone would reasonably import.

Gate 5 needs a person listening: import or trim on a slow DAP while audio plays. The
decode runs on an isolate, but it is still CPU-seconds.

Android has the most unknowns. `NativeAudioDecoder` has only been used with the engine
up, and the spike runs it with the engine down.

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
| AIFF | PCM, so a small Dart parser beside `wav_pcm.dart` can cover it everywhere, including Windows, where it fails today |
| CAF | Mostly an Apple format. Drop it from the picker elsewhere, since it already fails on Windows |
| WMA | Probably only ever worked on Windows, and SoLoud reads it there |
| ALAC | Varies by Android device already. Say so in the error |

## How to run the spike

Nothing plays, but engine init needs an output device.

```
fvm flutter test integration_test/drop_audio_decoder_spike_test.dart -d macos
```

Use `-d <device-id>` for a phone, and try the slowest one available. Keep the `SPIKE|`
lines. Lower `_longMinutes` if a slow device takes too long.

It needs the fork's `feat/offline-decode` branch beside this repo as `../flutter_soloud`.
`pubspec_overrides.yaml` points there.

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
