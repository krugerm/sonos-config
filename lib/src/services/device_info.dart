import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// Fetches the model name (e.g. `Sonos Beam`) from a player's device
/// description document, or null if unreachable/unparseable.
///
/// The model isn't in the topology payload, so the store calls this once per
/// device to enrich the [Household].
Future<String?> fetchDeviceModel(String host, {http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final resp = await c
        .get(Uri.parse('http://$host:1400/xml/device_description.xml'))
        .timeout(const Duration(seconds: 4));
    if (resp.statusCode != 200) return null;
    final doc = XmlDocument.parse(resp.body);
    final model =
        doc.findAllElements('modelName').firstOrNull?.innerText.trim();
    return (model == null || model.isEmpty) ? null : model;
  } catch (_) {
    return null;
  } finally {
    if (client == null) c.close();
  }
}
