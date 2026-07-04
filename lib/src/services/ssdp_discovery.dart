import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:network_info_plus/network_info_plus.dart';

/// Discovers the IP addresses of Sonos players on the LAN.
///
/// Primary path is SSDP: a UDP M-SEARCH multicast that Sonos players answer
/// with their `LOCATION` (`http://<ip>:1400/...`). When multicast is blocked
/// (some mesh/enterprise Wi-Fi), we fall back to a bounded unicast probe of the
/// local /24 on port 1400.
class SsdpDiscovery {
  SsdpDiscovery({http.Client? httpClient})
      : _http = httpClient ?? http.Client();

  final http.Client _http;

  static const _multicastAddress = '239.255.255.250';
  static const _multicastPort = 1900;

  // Sonos players are `ZonePlayer` devices; searching this ST keeps the noise
  // from other UPnP gear (TVs, routers) out of the results.
  static const _searchTarget = 'urn:schemas-upnp-org:device:ZonePlayer:1';

  /// Returns the set of Sonos IPs found within [timeout].
  ///
  /// Only one reachable player is needed to bootstrap the full topology later,
  /// but returning all of them lets discovery survive a single offline unit.
  Future<Set<String>> discover({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final found = await _ssdpSearch(timeout);
    if (found.isNotEmpty) return found;
    // Multicast produced nothing — try the unicast fallback.
    return _unicastScan();
  }

  Future<Set<String>> _ssdpSearch(Duration timeout) async {
    final results = <String>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.readEventsEnabled = true;

      const message = 'M-SEARCH * HTTP/1.1\r\n'
          'HOST: $_multicastAddress:$_multicastPort\r\n'
          'MAN: "ssdp:discover"\r\n'
          'MX: 1\r\n'
          'ST: $_searchTarget\r\n'
          '\r\n';
      final bytes = message.codeUnits;
      final target = InternetAddress(_multicastAddress);

      final done = Completer<void>();
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket!.receive();
        if (datagram == null) return;
        final ip = _hostFromResponse(String.fromCharCodes(datagram.data)) ??
            datagram.address.address;
        results.add(ip);
      });

      // Send a few times; UDP is lossy and Sonos units can be slow to wake.
      for (var i = 0; i < 3; i++) {
        socket.send(bytes, target, _multicastPort);
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      Timer(timeout, () {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
      await sub.cancel();
    } on SocketException {
      // Binding/multicast can fail on locked-down platforms; caller falls back.
    } finally {
      socket?.close();
    }
    return results;
  }

  /// Parses the `LOCATION: http://<ip>:1400/...` header from an SSDP reply.
  String? _hostFromResponse(String response) {
    for (final line in response.split('\r\n')) {
      final lower = line.toLowerCase();
      if (lower.startsWith('location:')) {
        final value = line.substring(line.indexOf(':') + 1).trim();
        final uri = Uri.tryParse(value);
        if (uri != null && uri.host.isNotEmpty) return uri.host;
      }
    }
    return null;
  }

  /// Fallback: probe every host on the local /24 for an open Sonos port 1400.
  ///
  /// Bounded and best-effort — it runs the 254 probes with a short per-host
  /// timeout so the whole sweep finishes in a couple of seconds.
  Future<Set<String>> _unicastScan() async {
    final wifiIp = await _localIp();
    if (wifiIp == null) return {};

    final prefix = wifiIp.substring(0, wifiIp.lastIndexOf('.') + 1);
    final results = <String>{};
    final probes = <Future<void>>[];

    for (var i = 1; i < 255; i++) {
      final ip = '$prefix$i';
      probes.add(_probeSonos(ip).then((ok) {
        if (ok) results.add(ip);
      }));
    }
    await Future.wait(probes);
    return results;
  }

  Future<bool> _probeSonos(String ip) async {
    try {
      final resp = await _http
          .get(Uri.parse('http://$ip:1400/xml/device_description.xml'))
          .timeout(const Duration(milliseconds: 800));
      return resp.statusCode == 200 && resp.body.contains('Sonos');
    } catch (_) {
      return false;
    }
  }

  Future<String?> _localIp() async {
    try {
      return await NetworkInfo().getWifiIP();
    } catch (_) {
      return null;
    }
  }

  void close() => _http.close();
}
