# Engineering Log / Milestones

Tracking ongoing refactors and decisions for eqTrainer.

## 2025-09-17 — Audio Clip pipeline refactor (Phase 1)

Completed
- Introduced AudioClipService (lib/service/audio_clip_service.dart)
  - Business logic for creating clips
  - Mobile (Android/iOS/macOS): trims via FFmpegKit (-ss/-to in ms)
  - Desktop/Non-edit: full copy
  - Unique filenames with microsecondsSinceEpoch
  - Extension policy: wav/mp3/flac kept; others converted to flac
- Added repository abstraction for persistence
  - IAudioClipRepository (service-facing contract)
  - AudioClipRepository (lib/repository/audio_clip_repository.dart) using Hive box (audioClipBox)
- Rewired UI call sites to the service
  - EditorControlView: replaced local makeAudioClip with AudioClipService.createClip
  - ImportPage: desktop path now calls AudioClipService.createClip; added scoped Providers for repository/service
- Verified static analysis on touched files: no errors in service, repository, and updated widgets/pages

Decisions & Notes
- Keep FFmpeg-based trim only when isEdit=true on mobile targets; otherwise just copy
- Favor flac fallback for unsupported extensions to align with miniaudio constraints
- Store original filename and computed duration in AudioClip Hive model

## Next up (Phase 1.1)
- Dependency injection
  - Consider lifting AudioClipService/Repository Providers to app-level (main.dart) if service is needed beyond ImportPage
- Import pipeline hardening
  - Extract ImportPlayer into its own file to avoid circular imports if needed in multiple widgets
  - Add unit tests for AudioClipService (trim vs copy, unsupported ext→flac, ffmpeg error propagation)
  - Handle edge cases: zero/invalid duration, nonexistent sourcePath, permission errors, partial writes
- Observability
  - Add lightweight logging around clip creation (args, duration, errors)

## Future refactors (Phase 2)
- Session flow decoupling
  - Ensure SessionController mediates submit logic for both portrait/landscape selectors
  - Reduce duplicated provider wiring and centralize where feasible
- Code hygiene
  - Remove legacy makeAudioClip implementations across the codebase (confirmed migrated at current call sites)
  - Organize player-related classes (shared player contracts, isolate boundaries)

## Quick reference
- Service entrypoint: AudioClipService.createClip({sourcePath, startSec, endSec, isEdit})
- Repository contract: IAudioClipRepository.addClip(AudioClip)
- Persistence: Hive box name = audioClipBox (see lib/main.dart)

---

## Scan findings and refactor plan (from earlier discussion)

Findings (요약 스캔 결과)
- State/Provider sprawl: many ChangeNotifier scattered across lib
  - Found: SessionFrequencyData, SessionModel, AudioState, SessionPlaylist, SessionResultData, SessionParameter,
    PlayerIsolate, SessionStateData (currently inside page/session_page.dart), NavBarProvider,
    ImportAudioData (currently inside widget/editor_control_view.dart)
- Logic location issues
  - session_selector_landscape.dart: answer judgment, scoring, band changes, and next-session init hardcoded in widget
  - editor_control_view.dart: file trim/copy logic (makeAudioClip) lives in UI
- FFmpeg/file processing inconsistencies
  - executeWithArguments (no await) vs executeAsync, mixed usage and incomplete failure handling
  - Output extension recalculation bug risk; path separator/platform splits; prefer path.basename/join
- Domain/storage coupling
  - makeAudioClip performs Hive writes and references global audioClipDir directly from UI layer

Architecture improvements (제안)
- Layering
  - services/audio_clip_service.dart: owns clip create/copy/encode, FFmpeg calls, filename/ext policy; await and map errors
  - repositories/audio_clip_repository.dart: Hive-only persistence (add/list/delete/toggle)
  - controllers/session_controller.dart (or view_model/): submitAnswer orchestration
    - UI shows feedback (Flushbar), controller mutates state and runs next session init
- State class placement
  - Create model/state/ or state/ and move scattered notifiers there
  - Extract SessionStateData (from page/session_page.dart)
  - Extract ImportAudioData (from widget/editor_control_view.dart)
  - Apply same rule to NavBarProvider, etc.
- Provider composition
  - Register Notifiers and services centrally (main.dart MultiProvider); widgets only select/consume
- FFmpeg standardization
  - Standardize to one approach (await completion), verify options (-ss, -to/-t) and codecs (-c:a flac for flac)
  - Common error/cancel/timeout handling
- File/path hygiene
  - Use path package: basename, extension, join
  - Ensure output dir exists; unique filenames (timestamp + microseconds)
- Behavior/edge checks
  - Validate time ranges (0 ≤ start < end ≤ duration), epsilon rounding
  - Platform-specific path/permission handling
  - Only persist and pop UI after FFmpeg completes successfully
- UI simplification
  - session selectors: call controller.submitAnswer and display feedback only
  - editor control: call audioClipService.createClip; repo handles persistence

Work plan (저위험 → 고효과)
- [x] Extract AudioClipService/Repository and move makeAudioClip into service (fix ext/path/await/errors)
- [x] Replace service calls in import_page.dart and editor_control_view.dart
- [x] Extract ImportAudioData, SessionStateData to state/ (or model/state/) and update imports
- [x] Extract SessionController and route submit logic through it (applied to portrait/landscape)
- [ ] Unify Provider registration in main.dart; remove page/widget-local registrations where feasible
- [ ] Standardize FFmpeg call sites to service only; remove any stray usage
- [ ] Add tests (service and controller) and basic logging

Specific issues to fix (메모)
- editor_control_view.dart
  - Path/ext handling and awaiting FFmpeg (now addressed by service)
  - Use path.basename instead of Platform/split (handled in service)
  - UI must not write to Hive directly (moved to repo)
- session_selector_landscape.dart
  - Widget contained domain logic (now centralized via SessionController). Ensure portrait version is aligned

Recommended structure (권장 구조)
```
lib/
  service/
    audio_clip_service.dart
  repository/
    audio_clip_repository.dart
  model/
    state/
      import_audio_data.dart
      session_state_data.dart
  controller/
    session_controller.dart
  widget/
    editor_control_view.dart  // UI only
    session/
      session_selector_landscape.dart  // UI only
      session_selector_portrait.dart   // UI only
```

Interface contracts (간단 계약)
- AudioClipService
  - Future<void> createClip({required String sourcePath, required double startSec, required double endSec, required bool isEdit})
  - Throws mapped exceptions on FFmpeg/file errors
- AudioClipRepository
  - Future<void> addClip(AudioClip)
  - (Later) list/delete/toggle
- SessionController
  - Future<SessionSubmitResult> submitAnswer(...) -> {isCorrect, answerIndex}

Quality gates & tests (품질 게이트)
- Build & Analyzer: PASS on touched files; keep warnings at 0 for new modules
- Unit tests (to add):
  - AudioClipService: trim vs copy, unsupported ext→flac, invalid range throws, error propagation
  - SessionController: scoring, threshold band changes, next-session init calls
- Widget tests (optional):
  - Session selector invokes controller and shows correct feedback
- Smoke checks:
  - Path handling (basename/join), FFmpeg options and awaiting, UI only pops after persistence

---

## 2025-09-17 — Session Flow Refactor Plan (Phase 2 kickoff)

Context
- Goal: reduce session state/logic sprawl, move domain rules out of widgets, and converge on a single controller + single store pattern.
- Why now: session scoring/round logic currently lives in UI (session_selector_*), and 5+ ChangeNotifiers increase coupling and complexity.

Repo scan snapshot (session-related)
- Found 14 files under lib/**/session_*.dart (widgets, page, model/state):
  - widget/session/: session_graph.dart, session_picker_portrait.dart, session_selector_landscape.dart, session_picker_landscape.dart, session_control.dart, session_selector_portrait.dart, session_position_slider.dart
  - page/session_page.dart
  - model/session/: session_frequency.dart, session_parameter.dart, session_model.dart, session_playlist.dart, session_result.dart
  - model/state/session_state_data.dart

Problems observed (요약)
- Logic in UI: session_selector_landscape.dart owns answer judgment, scoring, band thresholds, and next-round init.
- State fragmentation: SessionFrequencyData, SessionModel, SessionParameter, SessionPlaylist, SessionResultData, SessionStateData (+ AudioState, PlayerIsolate) scattered as ChangeNotifiers.
- Domain/storage coupling: session_playlist.dart and others directly touch Hive/paths.
- Testability: unit testing is hard since rules live inside widgets/notifiers with side effects.

Target architecture (간단 구조)
- Controller (SessionController): orchestrates submit/nextRound/launch/reset; communicates only via Store/Services.
- Store (SessionStore): single source of truth for session state; immutable snapshots preferred.
- Services/Repositories: PlayerService, PlaylistService, IAudioClipRepository; decouple from Hive and platform details.
- Pure utilities: FrequencyCalculator for graph/center frequencies; result reducers are pure functions.
- UI: thin; triggers controller actions and renders from Store; no domain rules.

File-level actions (각 파일 처리 방침)
- model/session/session_frequency.dart
  - Convert to pure FrequencyCalculator (no ChangeNotifier). Output: {centerFreqs, graphSeries} given startingBand/filterType.
  - Any GraphState enum should live under model/state or view-only.
- model/session/session_model.dart
  - Fold round creation/EQ update logic into SessionController. Deprecate direct mutations here.
- model/session/session_parameter.dart
  - Make it an immutable value object (consider freezed later). Store keeps the active copy.
- model/session/session_playlist.dart
  - Extract to PlaylistService that depends on IAudioClipRepository for persistence; remove direct Hive/path usage from model layer.
- model/session/session_result.dart
  - Keep as value + pure reducers (aggregate/update). Store holds current result snapshot.
- widget/session/session_selector_landscape.dart (and portrait counterpart)
  - Remove domain logic; call SessionController (submitAnswer/nextRound) and only show feedback.
- model/state/session_state_data.dart
  - Becomes SessionStore (single ChangeNotifier or StateNotifier if we later move to Riverpod). Holds viewState/currentRound/graph/progress/result.

Contracts (초안)
- SessionStore (fields)
  - viewState: idle | loading | ready | error
  - currentRound: {graphIndex, freqIndex, centerFreq, gain}
  - graph: {centerFreqsLog, centerFreqsLinear, series}
  - progress: {currentSessionPoint, threshold, startingBand}
  - result: {elapsedMs, correct, incorrect, perBand}
- SessionController (methods)
  - Future<void> launchSession()
  - Future<SessionSubmitResult> submitAnswer({required int pickedIndex}) // returns {isCorrect, answerIndex}
  - Future<void> nextRound()
  - void reset()
- FrequencyCalculator
  - compute({required int startingBand, required FilterType type}) -> {centerFreqs, series}
- PlaylistService
  - Future<List<String>> listEnabledClipPaths()
- PlayerService
  - Future<void> launch(); Future<void> setEQ({freq, gain}); etc.

Step-by-step plan
1) Introduce SessionController + wire UI
   - Route session_selector_landscape/portrait actions through controller.
   - Keep UI feedback only (Flushbar/snackbar). [Planned]
2) Introduce SessionStore as single state
   - Move computed graph/progress/result into Store snapshots; widgets select slices. [Planned]
3) Extract FrequencyCalculator (pure) and update graph usage
   - Remove ChangeNotifier responsibilities from session_frequency.dart. [Planned]
4) Decouple playlist/storage
   - Create PlaylistService using IAudioClipRepository; remove Hive/path logic from session_playlist.dart. [Planned]
5) Consolidate Providers in main.dart
   - Register Store, Controller, Services centrally; delete page/widget-local providers. [Planned]
6) Tests & logging
   - Add unit tests for controller (scoring/threshold/nextRound) and frequency calculator; add lightweight logs. [Planned]

Edge cases to cover
- Empty playlist or disabled all clips -> controller should surface a ready=false/error state.
- Threshold band changes -> ensure picker index bounds reset safely.
- Rapid submits/debounced updates -> guard re-entrancy in controller.
- Player errors/timeouts -> map to Store.error with user-friendly message.

Quality gates
- Build & Analyzer: PASS for new/edited modules; no new warnings.
- Unit tests: controller and frequency calculator cover happy path + boundary conditions.
- Smoke test: selectors trigger controller, UI displays correct/incorrect feedback, next round advances.

Risks & mitigation
- UI regressions due to provider rewiring -> migrate one selector first (landscape), verify, then port portrait.
- Hidden logic in other widgets -> grep for session_* usage and centralize gradually.
- Coupling with PlayerIsolate -> introduce PlayerService adapter to maintain existing isolate boundary.

Decisions & notes
- Keep Provider for now; consider Riverpod(StateNotifier) later if beneficial.
- Prefer immutable state snapshots (optionally freezed later) to simplify testing.
- Maintain existing public APIs where feasible to reduce blast radius during Phase 2.

Acceptance checklist (완료 조건)
- [ ] session_selector_landscape.dart has no scoring/next-round logic; calls controller only.
- [ ] session_selector_portrait.dart aligned with the same controller API.
- [ ] Only one session-related ChangeNotifier (Store) is exposed to UI.
- [ ] Playlist/Hive access is behind a Repository/Service; no direct Hive calls in UI/Controller.
- [ ] Unit tests for SessionController and FrequencyCalculator are green.
