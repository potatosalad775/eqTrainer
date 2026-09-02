# eqTrainer — Clip Format Plan (Opus/FLAC)

Source: format investigation with Claude, 2026-09-01. Replaces WAV-only conversion
output with Opus (lossy) and FLAC (lossless) targets, encoded through the
flutter_soloud fork's bundled xiph libraries. MP3 output was considered and
dropped — it was the only option requiring a new codec (LAME) and an LGPL
dependency; WAV remains the zero-work safe fallback.

Key findings the plan builds on:

- The flutter_soloud fork's file-load path already decodes Ogg Opus, Ogg Vorbis
  and Ogg FLAC (`src/soloud/src/audiosource/wav/mb_ogg.{h,cpp}` — libopus +
  libvorbisfile + libFLAC, not stb_vorbis). Playback needs **zero work**.
- Working Opus/Vorbis/FLAC/WAV encoders already exist in the fork
  (`src/mixeroutput/*_output_encoder.cpp`), built for mixer capture. They only
  lack an offline entry point.
- `MBOggDecoder::seekOpus` is a linear rewind-and-decode — O(position), and
  `PlayerService.seek` is a synchronous FFI call, so deep seeks in long Opus
  files block. Must be fixed (F4).
- Opus mandates 48 kHz; the encoder's internal 44.1→48 resampler is linear
  interpolation (fine for voice capture, not for ear-training material) (F3).
- audio_decoder stays: it is the only decoder for foreign formats (m4a/aac/
  wma/alac/aiff) via platform codecs. But the *fork* of it only exists for the
  retired m4a-output path, so the dependency returns to the hosted package (F12).

Status legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[-]` won't fix / obsolete.

---

## Phase 1 — flutter_soloud fork (enables everything else)

- [x] **F1 — Offline encode FFI.** Add a native entry point: float32 PCM buffer +
  sample rate + channels → Ogg Opus / FLAC / WAV file on disk. Thin wrapper over
  the existing `src/mixeroutput/` encoder classes; runs on the worker, not the
  platform thread (encode is CPU-seconds on long files). Dart-side wrapper method
  with a completion Future; progress callback optional.
- [x] **F2 — Opus encoder quality knobs.** `opus_output_encoder.cpp` currently
  runs libopus defaults with no `OPUS_SET_BITRATE`. → Set bitrate (default
  192 kbps stereo, parameterized through F1) + `OPUS_SET_COMPLEXITY(10)` for
  offline encodes.
- [x] **F3 — Replace the linear resampler.** `OpusOutputEncoder::resampleTo48k`
  linearly interpolates 44.1→48 kHz → imaging/aliasing in the top octave, on the
  very material users train their ears on. → One windowed-sinc (polyphase)
  resampler in C++, shared by all platforms. Also improves the existing capture
  path. FLAC is unaffected (keeps native rate).
- [x] **F4 — Fix `seekOpus`.** Linear rewind-and-decode today
  (`mb_ogg.cpp:580`). → Bisection over Ogg pages using granule positions (port
  the approach from the streaming path's `ogg_seek_index.h`), then decode-and-
  discard ~80 ms pre-roll before the target and honor pre-skip — without
  pre-roll the first samples after every seek are garbled. Vorbis needs nothing
  (`ov_pcm_seek` already bisects).
- [x] **F5 — Fork tests.** Encoder round-trip tests (PCM → encode → decode →
  compare length/rate/channels; FLAC bit-exact) and seek-accuracy tests for F4,
  in the fork's own test suite.

## Phase 2 — eqTrainer wiring

- [x] **F6 — New import-format options in `AudioFormatHelper`.** Options:
  **Smart / FLAC / Opus / WAV** (replacing keep-as-is / all-WAV). Smart: formats
  SoLoud already plays (wav/mp3/flac/ogg/opus) keep as-is — never transcode the
  playable; foreign lossy (m4a/aac/wma) → `.opus`; foreign lossless
  (alac/aiff/caf) → `.flac`. Add `.opus` to `_nativePlayableExts` and to the
  import file-picker filter.
- [x] **F7 — Trim output follows source lossiness.** `trimOutputExt` is
  hardcoded `.wav`. Trims always re-encode, so: lossless source → `.flac`,
  lossy source → `.opus` at the generous default bitrate (limits generation
  loss). Respect the explicit format setting when it's not Smart.
- [x] **F8 — Import pipeline through the new encoder.** Foreign formats:
  audio_decoder `convertToWavBytes` (existing) → F1 offline encode → clip file.
  Delete the intermediate WAV/temp on completion or abort.
- [-] **F9 — Waveform extraction via SoLoud for playable formats.** Not
  applicable as written: eqTrainer has no waveform extraction to move. The
  import editor uses a position slider and `AudioDecoder.getWaveform()` is
  never called. The hazard behind it was real one layer down, and was fixed:
  `PlayerService` kept its own list of natively-playable extensions, still
  missing `.opus`, so an Opus clip would have fallen through to the
  `convertToWavBytes` fallback — i.e. into the AVFoundation path that cannot
  open Ogg. That set is now shared with `audio_format_helper`.
- [x] **F10 — Settings migration + UI + i18n.** `ImportFormat` Hive values: map
  the old stored ordinals (keep-as-is / allWav) to sane new values (allWav →
  WAV). Regenerate adapters (`dart run build_runner build`). Settings UI for the
  four options; strings in `en.yaml` + `ko.yaml`.
- [x] **F11 — Tests.** Unit tests for the Smart mapping table and trim-target
  logic in `AudioFormatHelper`. Integration runs on desktop + a phone (CI proves
  nothing here — no audio hardware): Opus clip playback, seek accuracy after F4,
  EQ toggle over an Opus stream (`peaking_eq_audio_integration_test.dart`
  pattern).
- [x] **F12 — Return audio_decoder to the hosted package.** The fork's entire
  delta (4 commits: event-driven Android `performM4aConversion`, AAC-encoder
  selection, Linux encoder refactor) serves only the retired m4a-*output* path;
  the decode-to-WAV path is untouched by it. → Replace the git dependency in
  `pubspec.yaml` with hosted `audio_decoder: ^0.8.1`, verify import + trim +
  waveform still pass, then archive the fork (optionally upstream the Android
  perf work first — it may still help upstream's m4a users).

## Phase 3 — library care (optional)

- [x] **F13 — Offer WAV→FLAC recompress.** Libraries that went through
  `clip_format_migration.dart` back when it hardcoded WAV hold large WAV files,
  and a WAV-mode import still produces more. → Optional, user-triggered
  recompress to FLAC (lossless-safe, roughly halves size). Never auto-transcode
  a *lossless* clip to Opus — see F14 for why that qualifier matters.

- [x] **F14 — Migrate legacy clips to the import policy, not to WAV.**
  `clip_format_migration.dart` hardcoded WAV, so the same `.m4a` became `.wav`
  or `.opus` depending only on *when* it was imported — `targetExtForImport`
  has sent a lossy non-native source to Opus since F10. WAV there stored a
  decode of an already-lossy file at roughly 6× the source's size (a 3-minute
  256 kbps AAC: 5.5 MB → 31 MB WAV, 16 MB FLAC, 4.3 MB Opus).

  F13's "never auto-transcode to Opus" was really a rule about *lossless*
  sources — the reasoning in `clip_recompress_service.dart` is that re-encoding
  clips the user still has lossless throws audio away. `.m4a`/`.aac` are already
  lossy, so there is nothing lossless to protect, and a second Opus generation
  at 192 kbps sits far below the multi-dB EQ boost being identified. → The
  migration now derives its target from `targetExtForImport` against the stored
  `ImportFormat` (`MiscSettingsProvider.storedImportFormat()`), so All-FLAC and
  All-WAV are honoured for anyone who wants the decoded signal kept intact.

  Two details: the `_minWavBytes = 44` gate became a format-agnostic
  `_minOutputBytes = 64` (above a WAV header, FLAC STREAMINFO and an OpusHead
  page alike), and WAV targets still take audio_decoder's file-based path
  rather than `ClipEncoder`, which buffers the whole clip as float PCM.

---

## Status — all tasks complete (2026-09-01)

Phase 1 landed in the **flutter_soloud fork**, on a local branch
`feat/offline-encode` off the pinned `c8ead6ed`. **Not pushed yet**, so
eqTrainer's `pubspec.yaml` carries a temporary `dependency_overrides` path to
`../flutter_soloud`. Once the fork branch is pushed, replace that override
with a pinned ref.

Fork commits, in order:

| Commit | Task |
|---|---|
| `8439b0ef` | F1 — offline PCM-to-file encode entry point + Dart wrapper |
| `6660545f` | F2 — Opus bitrate/complexity, plus pre-skip and granulepos fixes |
| `de83c46c` | F3 — Kaiser-windowed sinc polyphase resampler |
| `7fedbdce` | F4 — bisected `seekOpus` with 80 ms pre-roll |
| `208099e7` | F5 — encoder, resampler and seek test suites |
| `a1c2693e` | FLAC `total_samples`, found by the eqTrainer integration test |

Measured results:

- **F3** — 44.1→48 kHz response went from -3.9 dB at 16 kHz and -6.3 dB at
  20 kHz (linear interpolation) to -0.000 dB and -0.279 dB. Images went from
  1.7 dB down to 24.7 dB down.
- **F4** — seeking to 115 s in a two-minute file went from 71.77 ms to
  0.45 ms, and is now flat in position rather than linear.
- **F2** — Opus files now carry a real pre-skip (312) and a correct final
  granulepos; the tail frame is no longer truncated.

Three bugs were found that the plan had not anticipated: OpusHead advertised a
pre-skip of 0, granulepos was written before being advanced (truncating ~20 ms
off every file), and FLAC never declared `total_samples` so every decoder
reported its duration as unknown.

### Outstanding

- The fork branch needs review and a push; then re-pin `pubspec.yaml`.
- **Listening check.** F3 and F4 are verified numerically and by test, not by
  ear. Worth auditioning: a seek into a long Opus clip (no click or garble at
  the landing point), and top-octave material through a 44.1 kHz import.
