import 'device.dart';

/// A coordinator device plus its bonded satellites (sub / surrounds), shown as
/// one configurable unit.
class Room {
  const Room({
    required this.name,
    required this.coordinator,
    required this.satellites,
  });

  final String name;
  final Device coordinator;
  final List<Device> satellites;

  /// Coordinator first, then bonded satellites.
  List<Device> get devices => [coordinator, ...satellites];
}
