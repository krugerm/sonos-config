import 'dart:convert';

import '../models/household.dart';
import 'device_info.dart';
import 'soap_client.dart';
import 'sonos_api.dart';

/// Consistently anonymizes identifying data out of raw Sonos responses so a
/// diagnostics bundle can be shared publicly. Device serials and IPs are mapped
/// to stable pseudonyms (so relationships are preserved); account/service
/// tokens and session GUIDs are redacted outright.
class Anonymizer {
  final Map<String, String> _uuids = {};
  final Map<String, String> _ips = {};

  static final _uuid = RegExp(r'RINCON_[0-9A-Fa-f]{12,24}');
  static final _ipv4 = RegExp(r'\b(?:\d{1,3}\.){3}\d{1,3}\b');
  static final _account = RegExp(r'SA_RINCON[0-9]+_[^<>";\s]+');
  static final _lcToken = RegExp(r'lc_[0-9a-fA-F]{8,}');
  static final _guid = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}');
  static final _householdId = RegExp(r'Sonos_[0-9A-Za-z]+');

  /// Stable pseudonym for a device serial (e.g. `RINCON_DEVICE01`).
  String pseudoUuid(String real) =>
      _uuids.putIfAbsent(real, () => 'RINCON_DEVICE${_uuids.length + 1}');

  String pseudoIp(String real) =>
      _ips.putIfAbsent(real, () => '10.0.0.${_ips.length + 1}');

  /// Redacts a raw string. Order matters: account tokens (which contain digits)
  /// before the generic IP pass.
  String scrub(String input) {
    var s = input;
    s = s.replaceAll(_account, '[REDACTED_ACCOUNT]');
    s = s.replaceAll(_lcToken, '[REDACTED]');
    s = s.replaceAll(_householdId, '[REDACTED_HOUSEHOLD]');
    s = s.replaceAllMapped(_uuid, (m) => pseudoUuid(m[0]!));
    s = s.replaceAll(_guid, '[REDACTED_GUID]');
    s = s.replaceAllMapped(_ipv4, (m) => pseudoIp(m[0]!));
    return s;
  }
}

/// A shareable diagnostics bundle: a short human-readable [summary] and the
/// full anonymized [json] payload.
class DiagnosticsBundle {
  const DiagnosticsBundle({required this.summary, required this.json});

  final String summary;
  final Map<String, dynamic> json;

  String toPrettyJson() => const JsonEncoder.withIndent('  ').convert(json);
}

/// Collects an anonymized diagnostics bundle from the live system: the raw
/// topology, each device's description, and an EQ-support probe — the exact
/// inputs needed to reproduce a parsing/capability bug offline.
class DiagnosticsService {
  DiagnosticsService(
    this._api, {
    Future<String?> Function(String host)? fetchDescription,
  }) : _fetchDescription = fetchDescription ?? fetchDeviceDescription;

  final SonosApi _api;
  final Future<String?> Function(String host) _fetchDescription;

  /// EQ types probed per device to reveal per-model support.
  static const _eqProbe = [
    'NightMode',
    'DialogLevel',
    'SubGain',
    'SubPolarity',
    'SurroundEnable',
    'SurroundLevel',
    'MusicSurroundLevel',
    'HeightChannelLevel',
    'AudioDelay',
  ];

  Future<DiagnosticsBundle> collect(
    Household household, {
    required String appVersion,
    required String platform,
    String problem = '',
  }) async {
    final anon = Anonymizer();
    final devices = household.devices;

    // Raw topology from the first reachable device.
    var rawTopology = '';
    for (final d in devices) {
      try {
        rawTopology = await _api.getZoneGroupStateRaw(d.host);
        if (rawTopology.isNotEmpty) break;
      } catch (_) {}
    }

    final descriptions = <String, String>{};
    final eqSupport = <String, Map<String, String>>{};
    for (final d in devices) {
      final key = anon.pseudoUuid(d.uuid);
      try {
        final desc = await _fetchDescription(d.host);
        if (desc != null) descriptions[key] = anon.scrub(desc);
      } catch (_) {}
      final probe = <String, String>{};
      for (final t in _eqProbe) {
        try {
          probe[t] = 'ok:${await _api.getEq(d.host, t)}';
        } on SonosSoapException catch (e) {
          probe[t] = 'err:${e.statusCode ?? '?'}';
        } catch (_) {
          probe[t] = 'unreachable';
        }
      }
      eqSupport[key] = probe;
    }

    final json = <String, dynamic>{
      'app': {'version': appVersion, 'platform': platform},
      'problem': problem,
      'devices': [
        for (final d in devices)
          {
            'id': anon.pseudoUuid(d.uuid),
            'model': d.model,
            'firmware': d.firmware,
            'role': d.bondRole.name,
            'invisible': d.invisible,
          }
      ],
      'zoneGroupState': anon.scrub(rawTopology),
      'deviceDescriptions': descriptions,
      'eqSupport': eqSupport,
    };

    return DiagnosticsBundle(summary: _summary(json, household), json: json);
  }

  String _summary(Map<String, dynamic> json, Household household) {
    final b = StringBuffer()
      ..writeln('**Sonos Config diagnostics**')
      ..writeln()
      ..writeln('- App: ${json['app']['version']} (${json['app']['platform']})')
      ..writeln('- Rooms: ${household.visibleRooms.length} visible, '
          '${household.devices.length} devices');
    final problem = (json['problem'] as String).trim();
    if (problem.isNotEmpty) b.writeln('- Problem: $problem');
    b.writeln();
    b.writeln('| Device (anonymized) | Model | Role | Firmware |');
    b.writeln('| --- | --- | --- | --- |');
    for (final d in json['devices'] as List) {
      b.writeln(
          '| ${d['id']} | ${d['model'] ?? '?'} | ${d['role']} | ${d['firmware'] ?? '?'} |');
    }
    b.writeln();
    b.writeln('_Full anonymized capture attached / below. Device serials, IPs, '
        'and account tokens have been stripped._');
    return b.toString();
  }
}
