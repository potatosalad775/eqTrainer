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

- [x] **M1 — Threshold uses `==`, point unclamped.** `session_controller.dart:155,160`. Overshoot at band bounds (25/2) forces clawing back through the whole overshoot before opposite adjustment fires. → `>=`/`<=` + clamp point when adjustment refused at bounds.
- [x] **M2 — Answer alternates deterministically at 2 graphs.** `session_controller.dart:100-103` "never repeat previous answer" → strict 1,2,1,2 for peak-only/dip-only at band 2 (100% score without listening); halves info per round generally. → Allow repeats, or only forbid when `numOfGraph > 2`.
- [x] **M3 — `submitAnswer` has no try/catch.** A throw from `initFrequency`/`setEQParams` leaves state `loading`, `InteractionLock` freezes session permanently. → Wrap, set `SessionState.error`.
- [x] **M4 — EQ-off fade doesn't fade.** `peaking_eq_node.dart:38-44` bypass sets filter to 0 dB immediately → boost vanishes as instant full-level discontinuity (the click the fade was built to mask). Un-bypass direction is correct. → Keep active coeffs while fading out; set 0 dB only after `_wet` passes zero-crossing.
- [x] **M5 — `setEQParams` bypasses `setEQ` coalescing.** `player_isolate.dart:276-288`. User EQ toggle racing a round transition can leave the new round's answer band audibly enabled at round start. → Route through same in-flight/pending machinery or sequence numbers.
- [x] **M6 — No `isLaunched` guard on request methods.** During track switch (shutdown→launch) a slider drag / EQ tap throws unhandled `StateError`. → Guard each request method with `if (!isLaunched) return`.
- [x] **M7 — Track-switch buttons not disabled during relaunch.** `session_control.dart:16-68`. Rapid taps interleave concurrent shutdown/launch; store index advances before launch succeeds. → `_switching` guard / disable during switch.
- [x] **M8 — EQ-enabled state not re-applied after track switch.** `updatePlayerState` sends only freq/gain → "Filtered" silently becomes "Original". → Pass + re-apply enabled flag.
- [x] **M9 — volumeCompensation default mismatch.** `main.dart:53` fresh install `false` vs Hive `defaultValue` `true` (`setting_data.dart:23`). Opposite answer-leak protection by install path. → Unify defaults.
- [x] **M10 — Index-based delete/toggle after await.** `playlist_item_tile.dart:51,80-86` use build-time index after `await showDialog`; if box changed, wrong record destroyed. → Operate by Hive key.
- [x] **M11 — Import boundary error handling + temp cleanup.** `import_page.dart:157-160` uncaught `FilePicker.pickFiles` → permanent spinner. `import_workflow_service.dart:50-73` temp files never cleaned; partial failure leaves orphans in clips dir. → try/catch → error state; delete temp on completion/abort.
- [x] **M12 — Clip paths not existence-checked.** `playlist_service.dart:16-34` missing file → unhandled async error; `_player.launch()` in `initState` unawaited/no handler. → `File.exists` filter + reconcile missing records before launch.
- [x] **M13 — `clearSavedSettings()` on every launch.** `upgrader_service.dart:13` (debug helper) wipes "ignore/later" → update dialog re-nags every start. → Remove it.
- [x] **M14 — Theme choice never persisted.** `app_theme.dart:26-44` resets to system every launch. → Persist mode in `miscSettingsBox`.
- [x] **M15 — Device dropdown matches by name; leaks context.** `device_dropdown.dart:55-70` duplicate-named DACs or enumeration failure with a selected device → Flutter dropdown assertion crash; State has no `dispose` for its native context. → Match by `id`, null value when absent from items, dispose context.
- [x] **M16 — Mobile app-resume creates AAudio context.** `main.dart:114-117` calls `refreshDevices()` on all platforms (desktop guard only in `startDevicePolling`). `stopDevicePolling` (`audio_state.dart:73-77`) nulls context without native dispose. → Gate resume-refresh to desktop; dispose before nulling.
- [x] **M17 — `dummy` backend always enabled.** `audio_state.dart:99-115` — real backend failure → app plays silence, no error. → Drop dummy or error when `activeBackend == dummy`.
- [-] **M18 — Test fixtures shipped in release.** `pubspec.yaml:124-125` declares `test/fixtures/audio/` as an app asset → bundled into every release binary, all 5 platforms. Initially "fixed" by removing the asset entry, but `integration_test/audio_clip_service_integration_test.dart:35` loads these fixtures via `rootBundle.load(...)` specifically because `Directory.current.path` isn't the project root on sandboxed platforms (see its own comment) — removing the asset entry broke that test. Reverted; won't fix without also reworking how the integration test sources its fixtures (e.g. pushing files onto the device out-of-band), which is riskier than this audit item is worth.

---

## LOW

- [x] **L1** — `launch()` doesn't reset cached UI state (`player_isolate.dart:162-179`); position/duration flash from previous clip, a `setEQ(true)` in that window dropped by redundancy check. → Clear caches at top of `launch()`.
- [x] **L2** — Rapid pause→play can duplicate feeder clocks (`player_isolate.dart:707,738`); doubled tick work, accumulates. → Retain clock instances, stop explicitly in `pause()`.
- [x] **L3** — Stale in-flight poll can overwrite optimistic seek (`player_isolate.dart:210` vs `337-349`); slider jumps back then corrects. → Sequence/version guard on position updates.
- [x] **L4** — `lengthInFrames!` force-unwrap (`player_isolate.dart:617,632`) could kill isolate on unknown-length streams. Confirmed real: the abstract decoder interface is `int?`, and miniaudio's own docs say `MA_NOT_IMPLEMENTED`/unknown length is possible for some backends (the WAV/AAC/miniaudio decoders this app actually selects always resolve a concrete length today, so not currently reachable, but cheap to guard). → Added `_safeLengthInFrames()` (null-coalesce + try/catch) used by both `duration` and `getPosition()`.
- [ ] **L5** — `ma_peak2` supports only f32/s16; 24-bit WAV import would fail launch (`peaking_eq_filter.dart:18-28`, fade code `peaking_eq_node.dart:132-165`). Confirmed real via investigation: `targetExtForImport` (audio_format_helper.dart) skips conversion for source files already `.wav` in `smart`/`keepOriginal`/`allWav` modes, so a native 24-bit WAV imports as `SampleFormat.int24` untouched (`WavAudioDecoder.lengthInFrames`/format parsing confirms it), and `audio_decoder`'s `AudioInfo` doesn't expose bit depth to gate on cheaply. Deferred: the real fix (normalize non-16-bit WAV on import, or insert a format-conversion node before the EQ stage) touches the live audio graph/native FFI path and can't be verified without a device to actually import a 24-bit WAV and hear the result — too risky to ship blind. → Needs manual verification before implementing.
- [x] **L6** — `resetResult()` mutates score without `notifyListeners()` (`session_store.dart:86-92`); appbar shows previous score until next notification. → Add notify.
- [x] **L7** — `_prevAnswerGraphIndex` never reset across sessions / after band-count change (`session_controller.dart:27`). → Reset to -1 in `launchSession` (already fixed) and now also in both mid-session threshold-driven band-change branches in `submitAnswer`.
- [x] **L8** — Launch failure rethrows with destroyed stack trace into uncaught async context (`session_controller.dart:84-87`, `session_page.dart:35-50`). → `_init()` now wraps `launchSession` in try/catch; `sessionStore.sessionState` already carries the error.
- [x] **L9** — Exit-during-launch writes `SessionState.error` into global store after page gone (`session_page.dart:29-49`). Masked only by H3's missing reset. → `launchSession` takes an optional `shouldContinue` callback, checked before every post-await store write; `session_page.dart` passes `() => mounted`.
- [x] **L10** — Tooltip parity math applied to non-peakDip modes (`session_graph_tooltip.dart:22-27`); peak-only even picks render centered instead of above peak. → `top`/`bottom` now set unconditionally for pure peak/dip modes; parity only gates peakDip.
- [-] **L11** — `'xmp4'` in `allowedExtensions` (`import_page.dart:154`) looks like `mp4` typo; mp4 unpickable. UNCERTAIN — confirm with author: keep it as-is for now.
- [x] **L12** — `import_page.dart:176-178` `fileNameList.join()` empty separator ("my.song.mp3"→"mysong"), can collide temp names. → `p.basenameWithoutExtension`.
- [x] **L13** — `interaction_lock.dart:8,40-45` `progress` param accepted but never used. → `progress ?? const CircularProgressIndicator()`.
- [x] **L14** — `settings_page.dart:172-178` try/catch wraps unawaited `launchUrl`; async failure (no handler, common Linux) escapes. → `await` + check bool result; `launchURL` is now `Future<void>`.
- [x] **L15** — `pubspec.yaml:42` `path: any` unconstrained. → `^1.9.0` (matches locked version).
- [x] **L16** — Deprecated `parametric_eq_node.dart` dead (and internally broken: unassigned `x`, shared channel state). → Deleted (no references found; also removed the now-empty `player/deprecated/` dir).
- [x] **L17** — 4 unused contrast theme variants (`app_theme.dart:19-23`), only light/dark used. → Deleted the theme getters and their backing `ColorScheme` consts in `app_colors.dart` (also unreferenced elsewhere).
- [x] **L18** — Dead translation key `SETTING_CARD_MISC_SETTING_TITLE` (en/ko line 128), referenced nowhere. → Deleted from both en.yaml and ko.yaml.
- [ ] **L19** — Historical Hive path move (commit dd1de31) had no migration; very old installs lost data. → One-time box-file move if old-path files exist (low value now).
- [x] **L20** — No error handling around `Hive.openBox` (`main.dart:47-57`); corrupt box = startup crash loop. → Added `_openBoxSafely` (try/catch → `deleteBoxFromDisk` → reopen); `audioClipBox` additionally copies the corrupt file aside first.
- [x] **L21** — `applyAudioState` (`main.dart:205-214`) swaps in new `AudioState` without disposing old `ChangeNotifier`. → `oldState.dispose()` in a post-frame callback after the swap, so `Provider.value` has already detached its listener.
- [x] **L22** — Appbar score `Consumer<SessionStore>` (`session_page.dart:67-91`) rebuilds on every store notification. → `Selector<SessionStore, (int, int)>` on `(resultCorrect, resultIncorrect)`.

---

## Cross-platform / manifest / CI

- [x] **CP1** — iOS `UIBackgroundModes` declares `remote-notification`+`fetch` with no supporting code (`ios/Runner/Info.plist:36-40`); App Store rejection risk. `audio` mode absent (playback halts on background if ever needed). → Confirmed no push/background-fetch code anywhere in `lib/` or `ios/`; removed both stale modes. (`audio` mode not added — playback isn't expected to continue backgrounded today.)
- [x] **CP2** — iPhone plist locks portrait (`Info.plist:45-49`) → Dart landscape branch (`main.dart:125-137`) dead on all iPhones. → Product decision: keep iPhone portrait-only (training UI isn't designed for iPhone landscape). Documented as intentional in `main.dart` rather than wiring up landscape.
- [x] **CP3** — README claims Windows Vista; Flutter 3.41 needs Windows 10+. → Already fixed (README's support matrix already says "Windows 10+" with no Vista mention) — no action needed.
- [x] **CP4** — macOS entitlements grant unused `network.server`. → Dropped from both `Release.entitlements` and `DebugProfile.entitlements` (kept `network.client`, used by update-check/url_launcher).
- [x] **CP5** — `min_sdk_android: 26` (icons) vs `minSdkVersion 24`. → Investigated: `android/app/src/main/res/mipmap-*` already has both the legacy flat icons (API<26) and the `mipmap-anydpi-v26` adaptive icons, so no devices are actually missing an icon today. Aligned the declared config to `24` anyway so it matches `minSdkVersion` and doesn't mislead the next icon regen.
- [ ] **CP6** — macOS release builds are ad-hoc signed (`CODE_SIGN_IDENTITY = "-"`) and never notarized (`build.yml`'s `build-macos` job has no `notarytool submit`/`stapler staple` step). Users downloading the DMG get Gatekeeper's "Apple could not verify.../check with the developer" rejection on first launch — confirmed root cause of a real user report on macOS 15.7.4; stripping the quarantine xattr doesn't reliably bypass it on recent macOS. Root-caused this session; **blocked on enrolling in the paid Apple Developer Program** (required for a Developer ID Application cert + notarytool). Stopgap: added Gatekeeper bypass steps (System Settings → Privacy & Security → Open Anyway) to README. → Once enrolled: add cert/notarization secrets to CI, sign with Developer ID instead of ad-hoc, add `xcrun notarytool submit --wait` + `xcrun stapler staple` to `build-macos` in `build.yml`.
- [ ] **CI1** — No quality gate: `build.yml` runs only on release-publish, no `flutter analyze`/test anywhere. → Add push/PR job (analyze + tests once written).
- [-] **CI2** — Release binaries never attached to the GitHub release (upload-artifact only, ~90-day expiry). → `gh release upload` / `softprops/action-gh-release`: Skip for now
- [ ] **CI3** — "Build APK" step builds only appbundle; no APK despite README sideload claim. → Add `flutter build apk` or rename.

---

## Tech debt / testing

- [x] **TD1 — No tests.** Session math (`FrequencyCalculator`, threshold logic, answer mapping) is pure and trivially testable — where H4/M1/M2 would've been caught. `mocktail` already a dev-dep. → `test/` now mirrors `lib/`: `FrequencyCalculator`, `SessionParameter`, `SessionStore`, `SessionController` (threshold/randomness/scoring), plus `PlaylistService`, `AudioClipService`, `AudioFormatHelper`, and (this pass) `MiscSettingsProvider`. All pass `dart analyze`. Could not execute `flutter test` in this sandbox — pre-existing env mismatch (installed Flutter 3.35.6/Dart 3.9.2 vs `audio_decoder`'s `^3.10.8` SDK constraint, plus a native-assets/`objective_c` tool check that blocks even `--no-pub` runs) unrelated to this change; needs a machine with a newer Flutter or CI to actually execute.
- [x] **TD2 — Settings via global mutable singleton** `savedMiscSettingsValue` + parent-rebuild callbacks; every new setting compounds staleness. → Replaced with `MiscSettingsProvider` (`lib/shared/model/misc_settings_provider.dart`), a `ChangeNotifier` wrapping the Hive-backed `MiscSettings` record (frequencyToolTip/importFormat/volumeCompensation/themeMode), registered once in `main.dart`'s `MultiProvider`. Deleted the old `ThemeProvider` (folded into this) and the `AudioImportFormatCard.onChanged` parent-rebuild callback — `audio_settings_page.dart` now just `context.watch`s the provider. All read sites (`session_graph.dart`, `session_controller.dart`, `session_control.dart`, `session_page.dart`, `import_page.dart`, settings cards) switched from the global to `context.watch/read<MiscSettingsProvider>()`; `SessionController.launchSession` now takes `volumeCompensation` as an explicit parameter instead of reaching for a global.

---

## Verified clean (no action — recorded so we don't re-audit)

Frequency math (log spacing exact 20 Hz–20 kHz); volume-compensation math; Hive schema (no index reuse, adapters registered before boxes); path storage (filename-only, iOS container-move safe); en/ko translation key sets identical; isolate launch/request ordering (no race); worker-side native resource cleanup at isolate exit; ring-buffer partial-write cannot lose data in practice.
