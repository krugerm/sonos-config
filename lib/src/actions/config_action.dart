import '../models/change_line.dart';
import '../models/household.dart';
import '../services/sonos_api.dart';

/// A single, previewable, verifiable configuration change.
///
/// Every mutating operation in the app is a [ConfigAction] so it can flow
/// through one guided-safe lifecycle (preview → apply → verify → undo). See
/// `ActionExecutor`.
abstract class ConfigAction {
  /// Short imperative title, e.g. `Bond Sub to TV Room`.
  String get title;

  /// Structured before/after lines shown in the confirm sheet.
  List<ChangeLine> preview(Household household);

  /// True when a clean inverse exists (so undo can be offered).
  bool get isReversible;

  /// Performs the SOAP call(s). Throws [SonosSoapException] on a device fault.
  Future<void> apply(SonosApi api);

  /// True once [after] shows the expected end-state (used to verify across the
  /// reboot a topology change causes).
  bool isSettled(Household after);

  /// The action that undoes this one given the [household] after it settled, or
  /// null if not reversible.
  ConfigAction? inverse(Household household);
}
