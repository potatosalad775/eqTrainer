import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:eq_trainer/l10n/l10n.dart';

/// Tells the user a clip that would not load was left out of the session.
///
/// Shared by the session start and the track switch. [l10n] is passed in
/// because both call it after an await, by which time the widget may be gone.
void showClipSkippedToast(AppLocalizations l10n) {
  toastification.show(
    type: ToastificationType.warning,
    style: ToastificationStyle.flatColored,
    description: Text(l10n.sessionSnackbarClipSkipped),
    alignment: Alignment.topCenter,
    autoCloseDuration: const Duration(seconds: 3),
    animationDuration: const Duration(milliseconds: 300),
    dragToClose: true,
    closeOnClick: true,
  );
}
