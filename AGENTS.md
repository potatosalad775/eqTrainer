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
