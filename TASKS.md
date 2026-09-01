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

- [ ] **F1 — Offline encode FFI.** Add a native entry point: float32 PCM buffer +
  sample rate + channels → Ogg Opus / FLAC / WAV file on disk. Thin wrapper over
  the existing `src/mixeroutput/` encoder classes; runs on the worker, not the
  platform thread (encode is CPU-seconds on long files). Dart-side wrapper method
  with a completion Future; progress callback optional.
- [ ] **F2 — Opus encoder quality knobs.** `opus_output_encoder.cpp` currently
  runs libopus defaults with no `OPUS_SET_BITRATE`. → Set bitrate (default
  192 kbps stereo, parameterized through F1) + `OPUS_SET_COMPLEXITY(10)` for
  offline encodes.
- [ ] **F3 — Replace the linear resampler.** `OpusOutputEncoder::resampleTo48k`
  linearly interpolates 44.1→48 kHz → imaging/aliasing in the top octave, on the
  very material users train their ears on. → One windowed-sinc (polyphase)
  resampler in C++, shared by all platforms. Also improves the existing capture
  path. FLAC is unaffected (keeps native rate).
- [ ] **F4 — Fix `seekOpus`.** Linear rewind-and-decode today
  (`mb_ogg.cpp:580`). → Bisection over Ogg pages using granule positions (port
  the approach from the streaming path's `ogg_seek_index.h`), then decode-and-
  discard ~80 ms pre-roll before the target and honor pre-skip — without
  pre-roll the first samples after every seek are garbled. Vorbis needs nothing
  (`ov_pcm_seek` already bisects).
- [ ] **F5 — Fork tests.** Encoder round-trip tests (PCM → encode → decode →
  compare length/rate/channels; FLAC bit-exact) and seek-accuracy tests for F4,
  in the fork's own test suite.

## Phase 2 — eqTrainer wiring

- [ ] **F6 — New import-format options in `AudioFormatHelper`.** Options:
  **Smart / FLAC / Opus / WAV** (replacing keep-as-is / all-WAV). Smart: formats
  SoLoud already plays (wav/mp3/flac/ogg/opus) keep as-is — never transcode the
  playable; foreign lossy (m4a/aac/wma) → `.opus`; foreign lossless
  (alac/aiff/caf) → `.flac`. Add `.opus` to `_nativePlayableExts` and to the
  import file-picker filter.
- [ ] **F7 — Trim output follows source lossiness.** `trimOutputExt` is
  hardcoded `.wav`. Trims always re-encode, so: lossless source → `.flac`,
  lossy source → `.opus` at the generous default bitrate (limits generation
  loss). Respect the explicit format setting when it's not Smart.
- [ ] **F8 — Import pipeline through the new encoder.** Foreign formats:
  audio_decoder `convertToWavBytes` (existing) → F1 offline encode → clip file.
  Delete the intermediate WAV/temp on completion or abort.
- [ ] **F9 — Waveform extraction via SoLoud for playable formats.** audio_decoder
  uses AVFoundation on Apple, which cannot open Ogg containers at all — waveform
  for `.opus`/`.ogg` imports would break there (latent bug for `.ogg` today).
  → Route waveform through SoLoud `readSamplesFromMem`/`readSamplesFromFile` for
  SoLoud-playable formats; audio_decoder only for foreign ones.
- [ ] **F10 — Settings migration + UI + i18n.** `ImportFormat` Hive values: map
  the old stored ordinals (keep-as-is / allWav) to sane new values (allWav →
  WAV). Regenerate adapters (`dart run build_runner build`). Settings UI for the
  four options; strings in `en.yaml` + `ko.yaml`.
- [ ] **F11 — Tests.** Unit tests for the Smart mapping table and trim-target
  logic in `AudioFormatHelper`. Integration runs on desktop + a phone (CI proves
  nothing here — no audio hardware): Opus clip playback, seek accuracy after F4,
  EQ toggle over an Opus stream (`peaking_eq_audio_integration_test.dart`
  pattern).
- [ ] **F12 — Return audio_decoder to the hosted package.** The fork's entire
  delta (4 commits: event-driven Android `performM4aConversion`, AAC-encoder
  selection, Linux encoder refactor) serves only the retired m4a-*output* path;
  the decode-to-WAV path is untouched by it. → Replace the git dependency in
  `pubspec.yaml` with hosted `audio_decoder: ^0.8.1`, verify import + trim +
  waveform still pass, then archive the fork (optionally upstream the Android
  perf work first — it may still help upstream's m4a users).

## Phase 3 — library care (optional)

- [ ] **F13 — Offer WAV→FLAC recompress.** Libraries that went through
  `clip_format_migration.dart` (m4a → WAV) hold large WAV files. → Optional,
  user-triggered recompress to FLAC (lossless-safe, roughly halves size). Never
  auto-transcode user clips to Opus.
