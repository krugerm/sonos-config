import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/diagnostics.dart';
import '../services/github_reporter.dart';
import '../services/sonos_api.dart';
import '../state/household_store.dart';
import 'theme.dart';
import 'widgets.dart';

/// Collects an anonymized diagnostics bundle and helps the user file a device
/// report — either by attaching the saved file to a prefilled GitHub issue (C),
/// or, if a GitHub OAuth client id is configured, by creating the issue in-app
/// via the OAuth device flow (B). Both show the bundle for review first.
class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _problem = TextEditingController();
  final _api = SonosApi();
  DiagnosticsBundle? _bundle;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _problem.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _collect() async {
    final household = context.read<HouseholdStore>().household;
    if (household == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final info = await PackageInfo.fromPlatform();
      final bundle = await DiagnosticsService(_api).collect(
        household,
        appVersion: info.version,
        platform: defaultTargetPlatform.name,
        problem: _problem.text.trim(),
      );
      setState(() => _bundle = bundle);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareAndOpenIssue(DiagnosticsBundle bundle) async {
    final file = XFile.fromData(
      Uint8List.fromList(utf8.encode(bundle.toPrettyJson())),
      name: 'sonos-diagnostics.json',
      mimeType: 'application/json',
    );
    await SharePlus.instance.share(
      ShareParams(files: [file], text: 'Sonos Config diagnostics'),
    );
    await launchUrl(prefilledIssueUrl(bundle),
        mode: LaunchMode.externalApplication);
  }

  Future<void> _autoCreate(DiagnosticsBundle bundle) async {
    final flow = GithubDeviceFlow();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final code = await flow.requestCode();
      await Clipboard.setData(ClipboardData(text: code.userCode));
      if (!mounted) return;
      // Show the code + open GitHub; poll in the background.
      final tokenFuture = flow.pollForToken(code);
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final nav = Navigator.of(ctx);
          tokenFuture.whenComplete(() {
            if (nav.canPop()) nav.pop();
          });
          return AlertDialog(
            title: const Text('Authorize on GitHub'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter this code on GitHub (copied to clipboard):'),
                const SizedBox(height: 10),
                SelectableText(code.userCode,
                    style:
                        monoStyle(context, size: 22, weight: FontWeight.w700)),
                const SizedBox(height: 16),
                const Row(children: [
                  SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 10),
                  Expanded(child: Text('Waiting for authorization…')),
                ]),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => launchUrl(Uri.parse(code.verificationUri),
                    mode: LaunchMode.externalApplication),
                child: const Text('Open GitHub'),
              ),
            ],
          );
        },
      );
      final token = await tokenFuture;
      final url = await flow.createIssue(token, bundle);
      messenger.showSnackBar(SnackBar(
        content: const Text('Report filed — thank you!'),
        action: SnackBarAction(
            label: 'View',
            onPressed: () => launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication)),
      ));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Couldn\'t file report: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bundle = _bundle;
    final ready = context.watch<HouseholdStore>().household != null;
    return Scaffold(
      appBar: AppBar(title: const Text('Report a problem')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Something not working with your setup? Send an anonymized snapshot '
            'so it can be fixed — your device serials, IPs, and account tokens '
            'are stripped before anything leaves this device.',
            style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _problem,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'What went wrong?',
              hintText:
                  'e.g. "Sub bonded but sub tuning controls never appear"',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (!ready)
            const Text('Waiting for discovery…')
          else if (bundle == null)
            FilledButton.icon(
              onPressed: _busy ? null : _collect,
              icon: _busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.science_outlined, size: 18),
              label: Text(_busy ? 'Collecting…' : 'Prepare report'),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: TextStyle(color: scheme.error)),
            ),
          if (bundle != null) ...[
            const Eyebrow('Review — this is what will be shared (public)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: SelectableText(bundle.summary,
                    style: monoStyle(context, size: 11.5)),
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: const Text('Full anonymized capture'),
              childrenPadding: const EdgeInsets.all(12),
              children: [
                SelectableText(bundle.toPrettyJson(),
                    style: monoStyle(context, size: 10.5)),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => _shareAndOpenIssue(bundle),
              icon: const Icon(Icons.ios_share, size: 18),
              label: const Text('Save file & open GitHub issue'),
            ),
            if (GithubDeviceFlow().available) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _autoCreate(bundle),
                icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                label: const Text('File it for me (sign in to GitHub)'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
