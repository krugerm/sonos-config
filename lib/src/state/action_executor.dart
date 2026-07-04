import 'package:flutter/foundation.dart';

import '../actions/config_action.dart';
import '../models/household.dart';
import '../services/soap_client.dart';
import '../services/sonos_api.dart';

/// Where a [ConfigAction] is in its lifecycle.
enum ActionPhase {
  idle,
  applying,
  verifying,
  done,
  unconfirmed, // applied, but not observed to settle within the timeout
  failed,
}

/// Runs [ConfigAction]s through the guided-safe lifecycle:
/// apply → verify (poll a fresh [Household] until the action settles or times
/// out) → done/unconfirmed/failed, with one-tap undo for reversible actions.
class ActionExecutor extends ChangeNotifier {
  ActionExecutor({
    required this.api,
    required this.refreshHousehold,
    this.pollInterval = const Duration(seconds: 2),
    this.verifyTimeout = const Duration(seconds: 30),
  });

  final SonosApi api;

  /// Re-polls the system and returns a fresh snapshot (provided by the store).
  final Future<Household> Function() refreshHousehold;

  final Duration pollInterval;
  final Duration verifyTimeout;

  ActionPhase phase = ActionPhase.idle;
  ConfigAction? current;
  String? error;

  ConfigAction? _undoable;

  /// True when the last completed action can be undone.
  bool get canUndo => _undoable != null && phase == ActionPhase.done;

  /// Runs [action] end to end. Never throws — failures land in [phase]/[error].
  Future<void> run(ConfigAction action) async {
    current = action;
    error = null;
    _undoable = null;
    _set(ActionPhase.applying);

    try {
      await action.apply(api);
    } on SonosSoapException catch (e) {
      error = e.message;
      _set(ActionPhase.failed);
      return;
    } catch (e) {
      error = e.toString();
      _set(ActionPhase.failed);
      return;
    }

    _set(ActionPhase.verifying);
    final settled = await _pollUntilSettled(action);
    if (settled) {
      _undoable = action.isReversible ? action : null;
      _set(ActionPhase.done);
    } else {
      _set(ActionPhase.unconfirmed);
    }
  }

  /// Undoes the last completed reversible action.
  Future<void> undo() async {
    final done = _undoable;
    if (done == null) return;
    final inverse = done.inverse(await refreshHousehold());
    if (inverse == null) return;
    await run(inverse);
  }

  Future<bool> _pollUntilSettled(ConfigAction action) async {
    final maxPolls =
        (verifyTimeout.inMilliseconds / pollInterval.inMilliseconds)
            .ceil()
            .clamp(1, 100000);
    for (var i = 0; i < maxPolls; i++) {
      Household snapshot;
      try {
        snapshot = await refreshHousehold();
      } catch (_) {
        await Future<void>.delayed(pollInterval);
        continue;
      }
      if (action.isSettled(snapshot)) return true;
      await Future<void>.delayed(pollInterval);
    }
    return false;
  }

  void _set(ActionPhase p) {
    phase = p;
    notifyListeners();
  }
}
