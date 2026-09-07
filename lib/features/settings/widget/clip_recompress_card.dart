import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eq_trainer/features/settings/widget/settings_card.dart';
import 'package:eq_trainer/shared/service/clip_recompress_service.dart';

/// Offers a one-off WAV→FLAC recompress of the library.
///
/// Only appears when there is actually something to reclaim: a library with no
/// WAV clips gets no card rather than a button that does nothing.
class ClipRecompressCard extends StatefulWidget {
  const ClipRecompressCard({super.key});

  @override
  State<ClipRecompressCard> createState() => _ClipRecompressCardState();
}

class _ClipRecompressCardState extends State<ClipRecompressCard> {
  RecompressEstimate? _estimate;
  bool _running = false;
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _refreshEstimate();
  }

  Future<void> _refreshEstimate() async {
    final service = context.read<ClipRecompressService>();
    final estimate = await service.estimate();
    if (!mounted) return;
    setState(() => _estimate = estimate);
  }

  static String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> _run() async {
    final service = context.read<ClipRecompressService>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _running = true;
      _done = 0;
      _total = _estimate?.clipCount ?? 0;
    });

    final result = await service.run(
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      },
    );

    if (!mounted) return;
    setState(() => _running = false);
    await _refreshEstimate();
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.failed == 0
              ? "AUDIO_SETTING_RECOMPRESS_DONE".tr(namedArgs: {
                  '_COUNT': '${result.converted}',
                  '_SAVED': _formatBytes(result.bytesSaved),
                })
              : "AUDIO_SETTING_RECOMPRESS_DONE_WITH_ERRORS".tr(namedArgs: {
                  '_COUNT': '${result.converted}',
                  '_SAVED': _formatBytes(result.bytesSaved),
                  '_FAILED': '${result.failed}',
                }),
        ),
      ),
    );
  }

  Future<void> _confirmAndRun() async {
    final estimate = _estimate;
    if (estimate == null || estimate.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text("AUDIO_SETTING_RECOMPRESS_TITLE".tr()),
        content: Text(
          "AUDIO_SETTING_RECOMPRESS_CONFIRM".tr(namedArgs: {
            '_COUNT': '${estimate.clipCount}',
            '_SIZE': _formatBytes(estimate.totalBytes),
            '_AFTER': _formatBytes(estimate.estimatedBytesAfter),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text("DIALOG_CANCEL".tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text("AUDIO_SETTING_RECOMPRESS_START".tr()),
          ),
        ],
      ),
    );

    if (confirmed ?? false) await _run();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimate;

    // Nothing to reclaim, or the estimate has not arrived yet.
    if (!_running && (estimate == null || estimate.isEmpty)) {
      return const SizedBox.shrink();
    }

    return SettingsCard(
      icon: Icons.compress,
      title: "AUDIO_SETTING_RECOMPRESS_TITLE".tr(),
      trailing: _running
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_total == 0 ? '' : '$_done / $_total'),
                const SizedBox(width: 12),
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            )
          : TextButton(
              onPressed: _confirmAndRun,
              child: Text(
                "AUDIO_SETTING_RECOMPRESS_ACTION".tr(namedArgs: {
                  '_SIZE': _formatBytes(estimate!.totalBytes),
                }),
              ),
            ),
    );
  }
}
