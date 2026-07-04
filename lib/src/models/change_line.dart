/// One before/after line in an action preview, e.g.
/// `ChangeLine(label: 'Sub', before: 'Standalone', after: 'Bonded to TV Room')`.
class ChangeLine {
  const ChangeLine({required this.label, this.before, this.after});

  final String label;
  final String? before;
  final String? after;
}
