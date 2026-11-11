import 'package:eq_trainer/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:eq_trainer/ui/settings/widget/settings_card.dart';
import 'package:eq_trainer/data/clips/clip_recompress_service.dart';

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
              ? context.l10n.audioSettingRecompressDone(
                  count: result.converted,
                  saved: _formatBytes(result.bytesSaved),
                )
              : context.l10n.audioSettingRecompressDoneWithErrors(
                  count: result.converted,
                  saved: _formatBytes(result.bytesSaved),
                  failed: result.failed,
                ),
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
        title: Text(context.l10n.audioSettingRecompressTitle),
        content: Text(
          context.l10n.audioSettingRecompressConfirm(
            count: estimate.clipCount,
            size: _formatBytes(estimate.totalBytes),
            after: _formatBytes(estimate.estimatedBytesAfter),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.dialogCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.audioSettingRecompressStart),
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

    // The spacer above and the description below belong to the card, so a
    // hidden card leaves no orphaned text or doubled gap on the page.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        _buildCard(context, estimate),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          child: Text(context.l10n.audioSettingRecompressDesc),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, RecompressEstimate? estimate) {
    return SettingsCard(
      icon: Icons.compress,
      title: context.l10n.audioSettingRecompressTitle,
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
                context.l10n.audioSettingRecompressAction(
                  size: _formatBytes(estimate!.totalBytes),
                ),
              ),
            ),
    );
  }
}
