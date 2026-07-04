import 'package:flutter_test/flutter_test.dart';
import 'package:personal_sonos/src/actions/config_action.dart';
import 'package:personal_sonos/src/models/change_line.dart';
import 'package:personal_sonos/src/models/household.dart';
import 'package:personal_sonos/src/services/soap_client.dart';
import 'package:personal_sonos/src/services/sonos_api.dart';
import 'package:personal_sonos/src/state/action_executor.dart';
import 'support/fake_soap_client.dart';

/// A controllable action for exercising the executor lifecycle.
class _StubAction extends ConfigAction {
  _StubAction({
    required this.settledWhen,
    this.throwOnApply = false,
  });

  final bool Function(Household) settledWhen;
  final bool throwOnApply;
  bool applied = false;

  @override
  String get title => 'stub';
  @override
  List<ChangeLine> preview(Household household) => const [];
  @override
  bool get isReversible => true;
  @override
  Future<void> apply(SonosApi api) async {
    applied = true;
    if (throwOnApply) throw SonosSoapException('boom', statusCode: 500);
  }

  @override
  bool isSettled(Household after) => settledWhen(after);
  @override
  ConfigAction? inverse(Household household) =>
      _StubAction(settledWhen: (_) => true);
}

ActionExecutor _executor() => ActionExecutor(
      api: SonosApi(client: FakeSoapClient()),
      refreshHousehold: () async => const Household(groups: []),
      pollInterval: const Duration(milliseconds: 1),
      verifyTimeout: const Duration(milliseconds: 10),
    );

void main() {
  test('settles: apply then verify -> done, undo offered', () async {
    var polls = 0;
    final exec = _executor();
    await exec.run(_StubAction(settledWhen: (_) {
      polls++;
      return polls >= 2; // settles on the second poll
    }));
    expect(exec.phase, ActionPhase.done);
    expect(exec.canUndo, isTrue);
  });

  test('never settles -> unconfirmed, no undo', () async {
    final exec = _executor();
    await exec.run(_StubAction(settledWhen: (_) => false));
    expect(exec.phase, ActionPhase.unconfirmed);
    expect(exec.canUndo, isFalse);
  });

  test('device fault -> failed with the fault message', () async {
    final exec = _executor();
    final action = _StubAction(settledWhen: (_) => true, throwOnApply: true);
    await exec.run(action);
    expect(action.applied, isTrue);
    expect(exec.phase, ActionPhase.failed);
    expect(exec.error, 'boom');
  });

  test('undo runs the inverse and completes', () async {
    final exec = _executor();
    await exec.run(_StubAction(settledWhen: (_) => true));
    expect(exec.phase, ActionPhase.done);
    await exec.undo();
    expect(exec.phase, ActionPhase.done); // inverse settled immediately
  });
}
