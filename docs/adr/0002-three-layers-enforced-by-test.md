# Three layers under lib/, enforced by a test

`lib/` is split into `ui/`, `domain/` and `data/`, plus `main.dart` and `l10n/`.

- `ui/` holds what was `features/`, `shared/widget/` and `shared/themes/`, with the feature folders kept inside it. Widgets and themes that more than one feature uses live in `ui/core/`, which replaces `shared/`.
- `domain/` is pure Dart: models, frequency math, format policy and session rules.
- `data/` is anything that touches disk, preferences or the audio engine: the repository, the clip library, the encoder, the migrations, `AppDirectories`, settings and `PlayerService`.

Import rules:

- `ui` may import `domain` and `data`.
- `data` may import `domain`.
- `domain` imports neither, and no `dart:io`.
- `domain` and `data` use only `package:flutter/foundation.dart` from Flutter, which is enough for `ChangeNotifier`, and they never take a `BuildContext`.
- `ui` does not import `dart:io`, `package:path`, `AppDirectories` or `shared_preferences`.
- Nothing inside `ui`, `domain` or `data` imports `main.dart`.

A unit test checks the imports. It carries an allow-list of the violations that exist at the time of the move. The list only shrinks, and each refactor removes its entries.

Presentation code and data or domain code were mixed: widgets joined file paths, a settings page wrote preferences, and shared widgets imported `main.dart`. The owner chose to reorganise folders rather than rely on a rule alone, because a path that names its layer makes a wrong import visible where it is written. The move is done as one change of pure moves and import rewrites, before any refactor.

## Consequences

`test/` mirrors the new tree. Files that are still mixed live where most of their content belongs and stay on the allow-list until cleaned.
