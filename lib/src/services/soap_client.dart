import 'dart:async';

import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';

/// The Sonos UPnP services we talk to, keyed by the pieces of the SOAP call
/// that differ per service: the control URL path and the UPnP service type.
///
/// Every Sonos player exposes these on port 1400.
enum SonosService {
  avTransport(
    controlPath: '/MediaRenderer/AVTransport/Control',
    serviceType: 'urn:schemas-upnp-org:service:AVTransport:1',
  ),
  renderingControl(
    controlPath: '/MediaRenderer/RenderingControl/Control',
    serviceType: 'urn:schemas-upnp-org:service:RenderingControl:1',
  ),
  groupRenderingControl(
    controlPath: '/MediaRenderer/GroupRenderingControl/Control',
    serviceType: 'urn:schemas-upnp-org:service:GroupRenderingControl:1',
  ),
  zoneGroupTopology(
    controlPath: '/ZoneGroupTopology/Control',
    serviceType: 'urn:schemas-upnp-org:service:ZoneGroupTopology:1',
  ),
  deviceProperties(
    controlPath: '/DeviceProperties/Control',
    serviceType: 'urn:schemas-upnp-org:service:DeviceProperties:1',
  ),
  contentDirectory(
    controlPath: '/MediaServer/ContentDirectory/Control',
    serviceType: 'urn:schemas-upnp-org:service:ContentDirectory:1',
  );

  const SonosService({required this.controlPath, required this.serviceType});

  final String controlPath;
  final String serviceType;
}

/// Thrown when a Sonos device returns a SOAP fault or an unexpected response.
class SonosSoapException implements Exception {
  SonosSoapException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => 'SonosSoapException(${statusCode ?? '-'}): $message';
}

/// A tiny SOAP client tailored to Sonos players.
///
/// This deliberately avoids a full generic UPnP stack: Sonos only needs a
/// handful of actions and hand-rolling the envelope keeps the dependency
/// surface small and the behaviour predictable.
class SoapClient {
  SoapClient(
      {http.Client? httpClient, this.timeout = const Duration(seconds: 5)})
      : _http = httpClient ?? http.Client();

  final http.Client _http;
  final Duration timeout;

  /// Invokes [action] on [service] for the player at [host] (its IP address).
  ///
  /// [arguments] are the SOAP action arguments in call order. Returns the
  /// parsed response body element (the `<u:...Response>` node) so callers can
  /// pull out the values they care about.
  Future<XmlElement> invoke(
    String host,
    SonosService service,
    String action, {
    Map<String, String> arguments = const {},
  }) async {
    final uri = Uri.parse('http://$host:1400${service.controlPath}');
    final soapAction = '"${service.serviceType}#$action"';
    final body = _buildEnvelope(service.serviceType, action, arguments);

    late final http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: {
              'Content-Type': 'text/xml; charset="utf-8"',
              'SOAPACTION': soapAction,
            },
            body: body,
          )
          .timeout(timeout);
    } on TimeoutException {
      throw SonosSoapException('Timed out calling $action on $host');
    }

    if (response.statusCode != 200) {
      throw SonosSoapException(
        _extractFault(response.body) ?? 'HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final document = XmlDocument.parse(response.body);
    final responseNode = document
        .findAllElements('${action}Response')
        .followedBy(document.findAllElements('u:${action}Response'))
        .firstOrNull;

    if (responseNode == null) {
      throw SonosSoapException('Missing ${action}Response from $host');
    }
    return responseNode;
  }

  String _buildEnvelope(
    String serviceType,
    String action,
    Map<String, String> arguments,
  ) {
    final args = StringBuffer();
    arguments.forEach((key, value) {
      args.write('<$key>${_escape(value)}</$key>');
    });
    return '<?xml version="1.0" encoding="utf-8"?>'
        '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" '
        's:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">'
        '<s:Body>'
        '<u:$action xmlns:u="$serviceType">'
        '$args'
        '</u:$action>'
        '</s:Body>'
        '</s:Envelope>';
  }

  String? _extractFault(String body) {
    try {
      final doc = XmlDocument.parse(body);
      final detail = doc.findAllElements('errorCode').firstOrNull?.innerText;
      final desc = doc.findAllElements('faultstring').firstOrNull?.innerText;
      if (detail != null) return 'UPnP error $detail';
      return desc;
    } catch (_) {
      return null;
    }
  }

  String _escape(String value) => value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  void close() => _http.close();
}

/// Convenience helpers on the parsed SOAP response element.
extension SoapResponseX on XmlElement {
  /// First child element named [name], as raw text, or `null` if absent.
  String? arg(String name) => findElements(name).firstOrNull?.innerText;

  /// First child element named [name] parsed as int, or `null`.
  int? argInt(String name) {
    final raw = arg(name);
    if (raw == null) return null;
    return int.tryParse(raw.trim());
  }
}
