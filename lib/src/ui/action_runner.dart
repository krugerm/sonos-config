import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../actions/config_action.dart';
import '../models/change_line.dart';
import '../state/action_executor.dart';
import '../state/household_store.dart';

/// Runs [action] through the guided-safe flow: a confirm sheet showing the
/// before/after preview, a progress dialog while it applies and verifies, then
/// a result snackbar with Undo when the action is reversible.
Future<void> runConfigAction(BuildContext context, ConfigAction action) async {
  final store = context.read<HouseholdStore>();
  final executor = context.read<ActionExecutor>();
  final messenger = ScaffoldMessenger.of(context);
  final lines =
      store.household == null ? <ChangeLine>[] : action.preview(store.household!);

  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (_) => _ConfirmSheet(action: action, lines: lines),
  );
  if (confirmed != true || !context.mounted) return;

  final runFuture = executor.run(action);
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ProgressDialog(executor: executor),
  );
  await runFuture;

  final (text, undoable) = switch (executor.phase) {
    ActionPhase.done => ('Done — ${executor.current?.title}', executor.canUndo),
    ActionPhase.unconfirmed => (
        "Applied, but couldn't confirm it settled — check the system map",
        false
      ),
    ActionPhase.failed => ('Failed — ${executor.error ?? 'unknown error'}', false),
    _ => ('', false),
  };
  if (text.isEmpty) return;
  messenger.showSnackBar(SnackBar(
    content: Text(text),
    duration: const Duration(seconds: 6),
    action: undoable
        ? SnackBarAction(label: 'Undo', onPressed: executor.undo)
        : null,
  ));
}

class _ConfirmSheet extends StatelessWidget {
  const _ConfirmSheet({required this.action, required this.lines});

  final ConfigAction action;
  final List<ChangeLine> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(action.title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            for (final l in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.label, style: theme.textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text('${l.before ?? '—'}   →   ${l.after ?? '—'}',
                        style: theme.textTheme.bodyLarge),
                  ],
                ),
              ),
            if (!action.isReversible)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('This action cannot be undone from the app.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel')),
                const SizedBox(width: 8),
                FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Apply')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog({required this.executor});

  final ActionExecutor executor;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: executor,
      builder: (context, _) {
        final phase = executor.phase;
        final terminal = phase == ActionPhase.done ||
            phase == ActionPhase.unconfirmed ||
            phase == ActionPhase.failed;
        if (terminal) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final nav = Navigator.of(context);
            if (nav.canPop()) nav.pop();
          });
        }
        final label = switch (phase) {
          ActionPhase.applying => 'Applying…',
          ActionPhase.verifying => 'Waiting for the change to settle…',
          _ => 'Working…',
        };
        return AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3)),
              const SizedBox(width: 20),
              Expanded(child: Text(label)),
            ],
          ),
        );
      },
    );
  }
}
