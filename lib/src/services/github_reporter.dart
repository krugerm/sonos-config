import 'dart:convert';

import 'package:http/http.dart' as http;

import 'diagnostics.dart';

/// The repository device reports are filed against.
const kGithubRepo = 'krugerm/sonos-config';

/// GitHub OAuth App client id for in-app auto-create (device flow). Client ids
/// are **not** secrets and are safe to ship. Register an OAuth App with device
/// flow enabled and paste its id here to enable path (B); leave empty to offer
/// only the manual "attach on GitHub" flow (C).
const kGithubClientId = String.fromEnvironment('GITHUB_CLIENT_ID');

/// (C) A URL that opens a prefilled "device report" issue. The full capture is
/// attached as a file by the user; only the short summary is prefilled (URLs
/// have a size limit).
Uri prefilledIssueUrl(DiagnosticsBundle bundle) {
  final model = (bundle.json['devices'] as List)
      .map((d) => d['model'])
      .whereType<String>()
      .toSet()
      .join(', ');
  return Uri.https('github.com', '/$kGithubRepo/issues/new', {
    'labels': 'device-report',
    'title': 'Device report: ${model.isEmpty ? 'my Sonos setup' : model}',
    'body': '${bundle.summary}\n\n'
        '<!-- Attach the diagnostics file you just saved (drag it in), or '
        'paste its contents in a code block below. -->\n',
  });
}

class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.interval,
    required this.expiresIn,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final int interval;
  final int expiresIn;
}

/// (B) GitHub OAuth **device flow** + issue creation. No client secret needed;
/// the issue is created as the signed-in user, so there's no shippable token to
/// abuse and no backend to run.
class GithubDeviceFlow {
  GithubDeviceFlow({http.Client? client, this.clientId = kGithubClientId})
      : _http = client ?? http.Client();

  final http.Client _http;
  final String clientId;

  bool get available => clientId.isNotEmpty;

  Future<DeviceCode> requestCode() async {
    final r = await _http.post(
      Uri.https('github.com', '/login/device/code'),
      headers: {'Accept': 'application/json'},
      body: {'client_id': clientId, 'scope': 'public_repo'},
    );
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    return DeviceCode(
      deviceCode: j['device_code'] as String,
      userCode: j['user_code'] as String,
      verificationUri: j['verification_uri'] as String,
      interval: (j['interval'] as int?) ?? 5,
      expiresIn: (j['expires_in'] as int?) ?? 900,
    );
  }

  /// Polls until the user authorizes on github.com, then returns the token.
  Future<String> pollForToken(DeviceCode code) async {
    var interval = code.interval;
    final deadline = DateTime.now().add(Duration(seconds: code.expiresIn));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: interval));
      final r = await _http.post(
        Uri.https('github.com', '/login/oauth/access_token'),
        headers: {'Accept': 'application/json'},
        body: {
          'client_id': clientId,
          'device_code': code.deviceCode,
          'grant_type': 'urn:ietf:params:oauth:grant-type:device_code',
        },
      );
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['access_token'] != null) return j['access_token'] as String;
      switch (j['error']) {
        case 'authorization_pending':
          continue;
        case 'slow_down':
          interval += 5;
          continue;
        default:
          throw Exception(
              j['error_description'] ?? j['error'] ?? 'auth failed');
      }
    }
    throw Exception('Authorization timed out — please try again.');
  }

  /// Creates the issue as the authenticated user; returns its html_url. The full
  /// capture is inlined in the body (no public attachment API); very large
  /// captures are truncated with a note.
  Future<String> createIssue(String token, DiagnosticsBundle bundle) async {
    var payload = bundle.toPrettyJson();
    var note = '';
    if (payload.length > 55000) {
      payload = payload.substring(0, 55000);
      note = '\n\n_Capture truncated to fit; attach the saved file for the '
          'full version._';
    }
    final body = '${bundle.summary}\n\n<details><summary>Full anonymized '
        'capture</summary>\n\n```json\n$payload\n```\n</details>$note';
    final r = await _http.post(
      Uri.https('api.github.com', '/repos/$kGithubRepo/issues'),
      headers: {
        'Accept': 'application/vnd.github+json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': 'Device report (in-app)',
        'body': body,
        'labels': ['device-report'],
      }),
    );
    if (r.statusCode >= 300) {
      throw Exception('GitHub returned ${r.statusCode}');
    }
    return (jsonDecode(r.body) as Map<String, dynamic>)['html_url'] as String;
  }
}
