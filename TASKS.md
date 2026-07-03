# eqTrainer — Audit Task Backlog

Source: full-repo audit (4 parallel subagents + manual verification), 2026-07-03.
Every item verified against source. IDs are stable — reference them in commits (`fix(H1): thread Q to engine`).

Status legend: `[ ]` todo · `[~]` in progress · `[x]` done · `[-]` won't fix / obsolete.

---

## HIGH — do first

### Training-loop cluster (H1, H3, H4, H5 — mostly 3 files, tackle together)

- [x] **H1 — Q factor is a dead setting.** `lib/shared/player/player_isolate.dart:464` hardcodes `q: 1`; the isolate protocol has no Q message and `SetEQParams` carries no Q. Config UI (`lib/features/config/widget/config_card.dart:124`) offers Q 0.1–10.0, stored in `SessionParameter.qFactor`, read by nothing. → Add Q to `PlayerHostRequestSetEQParams`, thread to `filter.update(q:)`. Unblocks new-method #2.
- [x] **H3 — Second session launch shows stale live UI.** `session_controller.dart:48-83` never sets a loading state first; app-scoped `SessionStore` never reset on session end. Async launch window renders previous session's UI with buttons wired to a not-yet-launched isolate. → Set `SessionState.init` synchronously at top of `launchSession` (and/or reset store in `SessionPage.dispose`).
- [x] **H4 — Picker goes stale after threshold band change.** `session_picker.dart:35` reads `graphBarDataList.length` via `context.read`, only rebuilds on `currentPickerValue`; `resetPickerValue()`→`setPickerValue(1)` early-returns without notify when already at 1 (`session_store.dart:39-46`). After a band increase the user cannot select the new highest band(s) — rounds become unanswerable. → `context.select` the graph count too.
- [x] **H5 — Double-submit race corrupts score.** `submitAnswer` (`session_controller.dart:135-175`) has no re-entrancy guard; `InteractionLock` only blocks after next frame. Double-tap = round counted twice, session point ±2, band-adjustment (uses `==`) can be skipped. → `if (sessionState != SessionState.ready) return;` at top of `submitAnswer`. (Pairs with M1.)

### Audio engine

- [x] **H2 — End-of-track wedges the player.** Feeder clock stops on `isEnd` (`player_isolate.dart:721-724`) but device never stops → `isPlaying` stays true, `play()` early-returns, UI shows "playing" silence, recovery needs pause→play. Decode pump also busy-ticks 100 Hz forever after EOF (battery). → Stop device on `isEnd` + notify host; decide loop vs stop (loop likely right for training clips).

### Data integrity — import / playlist

- [x] **H6 — Deleted clips leak audio files forever.** Delete only calls `_box.deleteAt` (`audio_clip_repository.dart:45-47`); no `File.delete` anywhere in `lib/`. Unbounded storage growth (WAV large). → Service-level delete removes `<clipsDir>/<fileName>` with the record.
- [x] **H7 — Playlist reorder broken two ways.** `playlist_page.dart:40-48` drags as a two-index swap (wrong for >1 position); two sequential `updateAt` awaits emit an intermediate snapshot with one clip at two indices → duplicate `ValueKey` crashes `ReorderableListView`. → Compute fully-reordered list, write in one batch.
- [x] **H8 — Start-only trim silently discarded.** `editor_clip_save_button.dart:38` `isTrimmed` compares only end time. Start-only trim copies whole file. → Also compare `clipStartTime != AudioTime.zero`.
- [x] **H9 — Import save failure bricks Done button.** `editor_clip_save_button.dart:27-42` no try/catch around `createClip`; on failure `_isProcessing` never resets, no feedback, no nav. → try/catch, reset flag, surface error.

### Platform / build

- [x] **H10 — Play Store updater check always false.** `upgrader_service.dart:10` stores `StoreChecker.getSource` (a `Future`) then compares to a `Source` enum at line 18. Play Store installs get direct-APK appcast flow (Play-policy risk). → `await` it.
- [x] **H11 — Core audio deps track mutable branches.** `pubspec.yaml:53-67`: `coast_audio`/`audio_decoder` on `ref: custom`, `store_checker` on `ref: master`, `window_size` no ref. Engine bits change silently on any re-resolve. → Pin exact commit SHAs.
- [x] **H12 — Backend-settings apply leaks native context.** `audio_backend_page.dart:129-171` creates an `AudioDeviceContext` never disposed — while `audio_state.dart:129-133` disposes its identical probe context *because* parallel contexts break AAudio startup on Android (own comment). → Dispose after reading `activeBackend`.

---

## MEDIUM

- [ ] **M1 — Threshold uses `==`, point unclamped.** `session_controller.dart:155,160`. Overshoot at band bounds (25/2) forces clawing back through the whole overshoot before opposite adjustment fires. → `>=`/`<=` + clamp point when adjustment refused at bounds.
- [ ] **M2 — Answer alternates deterministically at 2 graphs.** `session_controller.dart:100-103` "never repeat previous answer" → strict 1,2,1,2 for peak-only/dip-only at band 2 (100% score without listening); halves info per round generally. → Allow repeats, or only forbid when `numOfGraph > 2`.
- [ ] **M3 — `submitAnswer` has no try/catch.** A throw from `initFrequency`/`setEQParams` leaves state `loading`, `InteractionLock` freezes session permanently. → Wrap, set `SessionState.error`.
- [ ] **M4 — EQ-off fade doesn't fade.** `peaking_eq_node.dart:38-44` bypass sets filter to 0 dB immediately → boost vanishes as instant full-level discontinuity (the click the fade was built to mask). Un-bypass direction is correct. → Keep active coeffs while fading out; set 0 dB only after `_wet` passes zero-crossing.
- [ ] **M5 — `setEQParams` bypasses `setEQ` coalescing.** `player_isolate.dart:276-288`. User EQ toggle racing a round transition can leave the new round's answer band audibly enabled at round start. → Route through same in-flight/pending machinery or sequence numbers.
- [ ] **M6 — No `isLaunched` guard on request methods.** During track switch (shutdown→launch) a slider drag / EQ tap throws unhandled `StateError`. → Guard each request method with `if (!isLaunched) return`.
- [ ] **M7 — Track-switch buttons not disabled during relaunch.** `session_control.dart:16-68`. Rapid taps interleave concurrent shutdown/launch; store index advances before launch succeeds. → `_switching` guard / disable during switch.
- [ ] **M8 — EQ-enabled state not re-applied after track switch.** `updatePlayerState` sends only freq/gain → "Filtered" silently becomes "Original". → Pass + re-apply enabled flag.
- [ ] **M9 — volumeCompensation default mismatch.** `main.dart:53` fresh install `false` vs Hive `defaultValue` `true` (`setting_data.dart:23`). Opposite answer-leak protection by install path. → Unify defaults.
- [ ] **M10 — Index-based delete/toggle after await.** `playlist_item_tile.dart:51,80-86` use build-time index after `await showDialog`; if box changed, wrong record destroyed. → Operate by Hive key.
- [ ] **M11 — Import boundary error handling + temp cleanup.** `import_page.dart:157-160` uncaught `FilePicker.pickFiles` → permanent spinner. `import_workflow_service.dart:50-73` temp files never cleaned; partial failure leaves orphans in clips dir. → try/catch → error state; delete temp on completion/abort.
- [ ] **M12 — Clip paths not existence-checked.** `playlist_service.dart:16-34` missing file → unhandled async error; `_player.launch()` in `initState` unawaited/no handler. → `File.exists` filter + reconcile missing records before launch.
- [ ] **M13 — `clearSavedSettings()` on every launch.** `upgrader_service.dart:13` (debug helper) wipes "ignore/later" → update dialog re-nags every start. → Remove it.
- [ ] **M14 — Theme choice never persisted.** `app_theme.dart:26-44` resets to system every launch. → Persist mode in `miscSettingsBox`.
- [ ] **M15 — Device dropdown matches by name; leaks context.** `device_dropdown.dart:55-70` duplicate-named DACs or enumeration failure with a selected device → Flutter dropdown assertion crash; State has no `dispose` for its native context. → Match by `id`, null value when absent from items, dispose context.
- [ ] **M16 — Mobile app-resume creates AAudio context.** `main.dart:114-117` calls `refreshDevices()` on all platforms (desktop guard only in `startDevicePolling`). `stopDevicePolling` (`audio_state.dart:73-77`) nulls context without native dispose. → Gate resume-refresh to desktop; dispose before nulling.
- [ ] **M17 — `dummy` backend always enabled.** `audio_state.dart:99-115` — real backend failure → app plays silence, no error. → Drop dummy or error when `activeBackend == dummy`.
- [ ] **M18 — Test fixtures shipped in release.** `pubspec.yaml:124-125` declares `test/fixtures/audio/` as an app asset → bundled into every release binary, all 5 platforms. → Remove from `flutter: assets:`, load via file I/O in tests.

---

## LOW

- [ ] **L1** — `launch()` doesn't reset cached UI state (`player_isolate.dart:162-179`); position/duration flash from previous clip, a `setEQ(true)` in that window dropped by redundancy check. → Clear caches at top of `launch()`.
- [ ] **L2** — Rapid pause→play can duplicate feeder clocks (`player_isolate.dart:707,738`); doubled tick work, accumulates. → Retain clock instances, stop explicitly in `pause()`.
- [ ] **L3** — Stale in-flight poll can overwrite optimistic seek (`player_isolate.dart:210` vs `337-349`); slider jumps back then corrects. → Sequence/version guard on position updates.
- [ ] **L4** — `lengthInFrames!` force-unwrap (`player_isolate.dart:617,632`) could kill isolate on unknown-length streams. UNCERTAIN — confirm decoders can return null length for headerless streams.
- [ ] **L5** — `ma_peak2` supports only f32/s16; 24-bit WAV import would fail launch (`peaking_eq_filter.dart:18-28`, fade code `peaking_eq_node.dart:132-165`). UNCERTAIN — confirm what formats the import pipeline emits.
- [ ] **L6** — `resetResult()` mutates score without `notifyListeners()` (`session_store.dart:86-92`); appbar shows previous score until next notification. → Add notify.
- [ ] **L7** — `_prevAnswerGraphIndex` never reset across sessions / after band-count change (`session_controller.dart:27`). → Reset to -1 in `launchSession`.
- [ ] **L8** — Launch failure rethrows with destroyed stack trace into uncaught async context (`session_controller.dart:84-87`, `session_page.dart:35-50`). → Don't rethrow (state already signals) or catch in `_init`.
- [ ] **L9** — Exit-during-launch writes `SessionState.error` into global store after page gone (`session_page.dart:29-49`). Masked only by H3's missing reset. → Cancellation flag / ignore results when unmounted.
- [ ] **L10** — Tooltip parity math applied to non-peakDip modes (`session_graph_tooltip.dart:22-27`); peak-only even picks render centered instead of above peak. → Set top/bottom unconditionally for pure peak/dip.
- [ ] **L11** — `'xmp4'` in `allowedExtensions` (`import_page.dart:154`) looks like `mp4` typo; mp4 unpickable. UNCERTAIN — confirm with author.
- [ ] **L12** — `import_page.dart:176-178` `fileNameList.join()` empty separator ("my.song.mp3"→"mysong"), can collide temp names. → `p.basenameWithoutExtension`.
- [ ] **L13** — `interaction_lock.dart:8,40-45` `progress` param accepted but never used. → `progress ?? const CircularProgressIndicator()`.
- [ ] **L14** — `settings_page.dart:172-178` try/catch wraps unawaited `launchUrl`; async failure (no handler, common Linux) escapes. → `await` + check bool result.
- [ ] **L15** — `pubspec.yaml:42` `path: any` unconstrained. → Caret constraint.
- [ ] **L16** — Deprecated `parametric_eq_node.dart` dead (and internally broken: unassigned `x`, shared channel state). → Delete.
- [ ] **L17** — 4 unused contrast theme variants (`app_theme.dart:19-23`), only light/dark used. → Delete dead code.
- [ ] **L18** — Dead translation key `SETTING_CARD_MISC_SETTING_TITLE` (en/ko line 128), referenced nowhere. → Delete or re-wire.
- [ ] **L19** — Historical Hive path move (commit dd1de31) had no migration; very old installs lost data. → One-time box-file move if old-path files exist (low value now).
- [ ] **L20** — No error handling around `Hive.openBox` (`main.dart:47-57`); corrupt box = startup crash loop. → try/catch with `deleteBoxFromDisk` fallback (settings), backup-then-recreate for `audioClipBox`.
- [ ] **L21** — `applyAudioState` (`main.dart:205-214`) swaps in new `AudioState` without disposing old `ChangeNotifier`. → `oldState.dispose()` after swap.
- [ ] **L22** — Appbar score `Consumer<SessionStore>` (`session_page.dart:67-91`) rebuilds on every store notification. → `Selector` on `(resultCorrect, resultIncorrect)`.

---

## Cross-platform / manifest / CI

- [ ] **CP1** — iOS `UIBackgroundModes` declares `remote-notification`+`fetch` with no supporting code (`ios/Runner/Info.plist:36-40`); App Store rejection risk. `audio` mode absent (playback halts on background if ever needed). → Remove stale modes.
- [ ] **CP2** — iPhone plist locks portrait (`Info.plist:45-49`) → Dart landscape branch (`main.dart:125-137`) dead on all iPhones. → Add landscape to plist if intended, else note dead branch.
- [ ] **CP3** — README claims Windows Vista; Flutter 3.41 needs Windows 10+. → Update support matrix.
- [ ] **CP4** — macOS entitlements grant unused `network.server`. → Drop.
- [ ] **CP5** — `min_sdk_android: 26` (icons) vs `minSdkVersion 24`. UNCERTAIN — confirm generated mipmaps; align.
- [ ] **CI1** — No quality gate: `build.yml` runs only on release-publish, no `flutter analyze`/test anywhere. → Add push/PR job (analyze + tests once written).
- [ ] **CI2** — Release binaries never attached to the GitHub release (upload-artifact only, ~90-day expiry). → `gh release upload` / `softprops/action-gh-release`.
- [ ] **CI3** — "Build APK" step builds only appbundle; no APK despite README sideload claim. → Add `flutter build apk` or rename.

---

## Tech debt / testing

- [ ] **TD1 — No tests.** Session math (`FrequencyCalculator`, threshold logic, answer mapping) is pure and trivially testable — where H4/M1/M2 would've been caught. `mocktail` already a dev-dep. → Add `test/` mirroring `lib/`, start with session math.
- [ ] **TD2 — Settings via global mutable singleton** `savedMiscSettingsValue` + parent-rebuild callbacks; every new setting compounds staleness. → Migrate to ChangeNotifier (enables M14).

---

## New training methods (proposals — evaluate, then spec)

Prerequisite worth doing once: **an `Exercise` strategy interface** owning (a) round generation, (b) answer representation + validation, (c) result bucketing — the current flow hardcodes "identify which band changed" across 9 sites (FilterType enum, bare-index answer, NumberPicker-over-graph-count, 7 fixed result bands, difficulty=`startingBand`, config enum, chart constants, EQ-only player protocol, singleton controller).

- [ ] **NM1 — Gain-magnitude estimation** ("boosted by how much?"). ~90% reuse; answer space = gain steps; new state = per-gain-step stats. Cheapest; better difficulty ladder than adding bands.
- [ ] **NM2 — Q/bandwidth discrimination** ("wide or narrow?"). **Requires H1 first** (Q must reach engine). Small protocol add, moderate UI.
- [ ] **NM3 — A/B/X matching.** No graph; needs 3-state EQ in player protocol (store 2 param sets) + 2-choice UI. Moderate.
- [ ] **NM4 — Multi-band identification** (two bands changed, pick both). Reuses graph/picker but answer becomes a set — stresses bare-index model most; do after strategy seam.
- [ ] **NM5 — Filter-type discrimination** (peaking vs low/high shelf vs cut). Most expensive: new DSP nodes (`ma_loshelf2`/`ma_hishelf2`), protocol, graph curves. Highest training value; last.

---

## Verified clean (no action — recorded so we don't re-audit)

Frequency math (log spacing exact 20 Hz–20 kHz); volume-compensation math; Hive schema (no index reuse, adapters registered before boxes); path storage (filename-only, iOS container-move safe); en/ko translation key sets identical; isolate launch/request ordering (no race); worker-side native resource cleanup at isolate exit; ring-buffer partial-write cannot lose data in practice.
