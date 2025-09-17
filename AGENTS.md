# Engineering Log / Milestones (condensed)

Tracking ongoing refactors and decisions for eqTrainer.

## 2025-09-17 — Audio Clip pipeline refactor (Phase 1) — Summary
Completed
- AudioClipService introduced: edit(trim via FFmpegKit) vs copy, unique filenames, ext policy (wav/mp3/flac, else→flac), basename/join policy planned.
- Repository abstraction: IAudioClipRepository contract; AudioClipRepository (Hive box: audioClipBox).
- UI rewiring: import/editor now call AudioClipService.createClip (UI no longer writes to Hive directly).

Decisions & notes
- Mobile edit→FFmpeg (-ss/-to in ms); desktop/non-edit→copy.
- Store original filename and computed duration in Hive model.
- Favor flac fallback to align with playback constraints.

Next up (Phase 1.1)
- DI: lift repository/service providers to app-level when broadly used.
- Observability: add lightweight logs around clip creation and failures.
- Tests: AudioClipService (trim vs copy, ext fallback, error propagation).

---

## 2025-09-17 — Session Flow Refactor (Phase 2) — Plan
Context
- Goal: reduce session state/logic sprawl; move domain rules out of widgets; converge on a single controller + single store.

Pain points (snapshot)
- Logic in UI (selectors): judgment, scoring, band changes, next-session init mixed into widgets.
- State fragmentation: many ChangeNotifiers (SessionFrequencyData, SessionModel, SessionParameter, SessionPlaylist, SessionResultData, SessionStateData, AudioState…).
- Domain/storage coupling: playlist and UI touching Hive/paths.
- Testability: hard while rules live inside widgets with side effects.

Target architecture
- Controller (SessionController): orchestrates launch/submit/nextRound; mutates Store only.
- Store (SessionStore): single source of truth for session state (viewState, round, graph, progress, result).
- Services/Repositories: PlayerService adapter, PlaylistService, IAudioClipRepository (Hive hidden).
- Pure utilities: FrequencyCalculator (graph/center freqs), reducers for results.
- UI: thin; triggers controller; renders from Store; no domain rules.

Contracts (quick)
- SessionController: launchSession(), submitAnswer(pickedIndex) → {isCorrect, answerIndex}, nextRound(), reset().
- SessionStore: viewState, currentRound, graph, progress, result.
- PlaylistService: listEnabledClipPaths() and/or resolvePath(fileName).
- IAudioClipRepository: addClip(), getAllClips(), (later) watch/list/delete/toggle.

Acceptance checklist
- [x] Playlist/Hive access behind Repository/Service; no direct Hive/path in session playlist model (Plan 4 DONE).
- [x] Selectors have no domain logic; call controller only (landscape+portrait).
- [ ] Only one session-related ChangeNotifier (Store) exposed to UI.
- [ ] Frequency/graph computed via pure utility; state held in Store.
- [ ] Unit tests: controller + frequency calculator.

---

## Improvements to do before provider consolidation (practical, high impact)
1) Consolidate DI/providers in main.dart [Complete]
- Register Repository, Services, Store, Controller centrally; pages/widgets only consume.

2) Remove global audioClipDir [Complete]
- Introduce PathProvider (AppDirectories) service; services read paths via this, not global vars.
- Use path.join everywhere (no Platform.pathSeparator/manual splits).

3) Expand IAudioClipRepository and decouple playlist page [Complete]
- Add getAllClips(), watchClips(), delete/update/toggleEnabled.
- playlist_page uses Repository/Service streams; remove Hive.box(...).listenable() from UI.

4) PlaylistService refinements [Complete]
- Use path.join and add resolvePath(fileName) for UI convenience.
- Optionally return List<AudioClip> and resolve paths only when needed.

5) Absorb or slim SessionPlaylist [Complete]
- Move playlistPaths/currentIndex into SessionStore; drop or reduce SessionPlaylist.

6) Fold SessionModel into SessionController [Complete]
- Move launch/init/next-round/EQ update logic into controller; deprecate SessionModel.

7) FrequencyCalculator purity [Complete]
- Ensure session_frequency is pure; Store holds results; no ChangeNotifier in calculator.

8) UI cleanup [Complete]
- Make selectors Stateless and call controller; keep feedback display only. [Complete]

9) Errors & logging
- Standardize FFmpeg error/timeout mapping; controller maps to Store.error with user-friendly messages.
- Add minimal logging hooks (debug build only).

10) Tests & smoke
- Unit: AudioClipService, SessionController.
- Smoke: selectors trigger controller, UI advances rounds, correct/incorrect path verified.

---

## Step-by-step next actions (safe order)
- [x] Provider consolidation in main.dart (Repo/Services/Store/Controller registration; remove local news in pages/widgets).
- [x] Replace global audioClipDir with PathProvider service; migrate services to it; update path handling to path.join.
- [x] Repository contract: add watch/list/delete/toggle; migrate playlist_page to consume repository/service streams.
- [x] SessionPlaylist → Store absorption (or minimal wrapper), update controller/UI wiring.
- [x] SessionModel → Controller migration; delete legacy calls.
- [ ] Tests: add basic unit tests (service/controller) and enable lightweight logging.

Quality gates
- Build & Analyzer: PASS; zero new warnings.
- Tests: service/controller cover happy + boundaries.
- Smoke: empty playlist, threshold band change, rapid submits, player errors mapped to Store.error.

Risks & mitigation
- UI regressions after provider rewiring → migrate one page at a time and verify.
- Hidden logic in other widgets → grep session_* and centralize gradually.
- Player isolate coupling → add PlayerService adapter to preserve boundaries.
