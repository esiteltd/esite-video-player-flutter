import 'dart:async';

import 'package:esite_flutter_player/esite_flutter_player.dart';
import 'package:flutter/material.dart';

import 'stub_backend.dart';

/// Stand-in manifest for the stub scenarios.
///
/// Swap this for a real `playback_url` from `GET /api/v1/videos/{id}` to
/// exercise genuine Lite DRM (AES-128) playback — the stub cannot mint one,
/// since presigning happens server-side behind the tenant API key.
const _placeholderHls =
    'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/master.m3u8';

/// The lite video supplied for testing.
const _liteVideoId = '4c2f5fdd-d88e-4d2b-b03d-039edef920a7';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eSITE Player Example',
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C63FF),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

/// Each scenario is one stub backend response, exercising a distinct path
/// through resolution.
enum Scenario {
  lite('Lite DRM', 'AES-128 encrypted HLS — plays with no DRM session'),
  plain('No DRM', 'Unencrypted HLS'),
  fullDrm('Full DRM', 'DASH + Widevine; unsupported on iOS'),
  notReady('Not ready', 'Still packaging — should refuse to play'),
  noPlaybackUrl('No playback URL', 'Ready but nothing presigned yet'),
  notFound('Not found', 'Backend returns 404'),
  unauthorized('Unauthorized', 'Backend returns 401');

  const Scenario(this.label, this.description);
  final String label;
  final String description;

  String get videoId => 'stub-$name';
}

Map<String, StubResponse> _stubResponses() => {
  _liteVideoId: const StubResponse(
    body: {
      'id': _liteVideoId,
      'name': 'Lite DRM sample',
      'status': 'ready',
      'drm_type': 'lite',
      'playback_url': _placeholderHls,
      'renditions': [],
    },
  ),
  Scenario.lite.videoId: const StubResponse(
    body: {
      'id': 'stub-lite',
      'name': 'Lite DRM sample',
      'status': 'ready',
      'drm_type': 'lite',
      'playback_url': _placeholderHls,
      'renditions': [],
    },
  ),
  Scenario.plain.videoId: const StubResponse(
    body: {
      'id': 'stub-plain',
      'name': 'Unprotected sample',
      'status': 'ready',
      'drm_type': null,
      'playback_url': _placeholderHls,
      'renditions': [],
    },
  ),
  Scenario.fullDrm.videoId: const StubResponse(
    body: {
      'id': 'stub-fullDrm',
      'name': 'Full DRM sample',
      'status': 'ready',
      'drm_type': 'full',
      'playback_url': 'https://cdn.example.com/manifest.mpd?token=stub',
      'license_server_url': 'https://license.example.com/widevine',
      'entitlement_message': 'stub-entitlement-token',
      'renditions': [],
    },
  ),
  Scenario.notReady.videoId: const StubResponse(
    body: {
      'id': 'stub-notReady',
      'name': 'Still packaging',
      'status': 'packaging',
      'drm_type': 'lite',
      'playback_url': null,
      'renditions': [],
    },
  ),
  Scenario.noPlaybackUrl.videoId: const StubResponse(
    body: {
      'id': 'stub-noPlaybackUrl',
      'name': 'Nothing presigned',
      'status': 'ready',
      'drm_type': 'lite',
      'playback_url': null,
      'renditions': [],
    },
  ),
  Scenario.unauthorized.videoId: const StubResponse(
    status: 401,
    body: {'detail': 'access token expired'},
  ),
};

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _stub = StubBackend(responses: _stubResponses());
  final _baseUrlController = TextEditingController();
  final _tokenController = TextEditingController();
  final _videoIdController = TextEditingController(text: _liteVideoId);

  bool _useStub = true;
  bool _busy = false;
  String? _stubBaseUrl;

  ESitePlayerController? _controller;
  final _log = <String>[];
  final _subscriptions = <StreamSubscription<dynamic>>[];

  @override
  void initState() {
    super.initState();
    _startStub();
  }

  Future<void> _startStub() async {
    final url = await _stub.start();
    if (!mounted) return;
    setState(() => _stubBaseUrl = url);
    _addLog('Stub backend listening on $url');
    _applyConfiguration();
  }

  /// The plugin talks to the client app's own backend. The stub stands in for
  /// it here; in production this is your server, which holds the eSITE API key.
  void _applyConfiguration() {
    final baseUrl = _useStub ? _stubBaseUrl : _baseUrlController.text.trim();
    if (baseUrl == null || baseUrl.isEmpty) return;

    ESitePlayer.configure(
      baseUrl: baseUrl,
      tokenProvider: () async =>
          _useStub ? 'stub-token' : _tokenController.text.trim(),
    );
  }

  Future<void> _play(String videoId) async {
    if (_busy) return;
    setState(() => _busy = true);

    _applyConfiguration();
    await _disposeController();

    try {
      _addLog('Resolving $videoId …');
      final controller = await ESitePlayerController.forVideo(
        videoId,
        options: ESitePlaybackOptions(
          autoPlay: true,
          preventScreenshots: true,
          preventScreenRecording: true,
          primaryColor: const Color(0xFF6C63FF),
          secondaryColor: Colors.white,
        ),
      );

      _controller = controller;
      _addLog(
        'Resolved: ${controller.config.streamFormat.name.toUpperCase()}, '
        'DRM session: ${controller.config.drm == null ? 'none' : controller.config.drm!.scheme.name}',
      );

      _subscriptions.addAll([
        controller.stateStream.listen((s) => _addLog('State: ${s.name}')),
        controller.drmStream.listen(
          (e) => _addLog('DRM: ${e.type.name} — ${e.message ?? ''}'),
        ),
        controller.errorStream.listen(
          (e) => _addLog('Error: ${e.code.name} — ${e.message}'),
        ),
      ]);

      await controller.launchPlayer();
    } on ESitePlayerException catch (e) {
      _addLog('Failed: ${e.code.name} — ${e.message}');
    } catch (e) {
      _addLog('Failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disposeController() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _controller?.dispose();
    _controller = null;
  }

  void _addLog(String message) {
    if (!mounted) return;
    setState(() => _log.insert(0, message));
  }

  @override
  void dispose() {
    _disposeController();
    _stub.stop();
    _baseUrlController.dispose();
    _tokenController.dispose();
    _videoIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('eSITE Player')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _backendCard(),
          const SizedBox(height: 16),
          _playByIdCard(),
          const SizedBox(height: 16),
          _scenarioCard(),
          const SizedBox(height: 16),
          _logCard(),
        ],
      ),
    );
  }

  Widget _backendCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Backend',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'The plugin calls your app backend, which holds the eSITE API '
              'key and talks to the video service server-to-server.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use built-in stub backend'),
              subtitle: Text(_stubBaseUrl ?? 'starting…'),
              value: _useStub,
              onChanged: (value) {
                setState(() => _useStub = value);
                _applyConfiguration();
              },
            ),
            if (!_useStub) ...[
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'https://api.myapp.com',
                ),
                onChanged: (_) => _applyConfiguration(),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _tokenController,
                decoration: const InputDecoration(
                  labelText: 'Access token',
                  hintText: 'app ↔ backend token',
                ),
                onChanged: (_) => _applyConfiguration(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _playByIdCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Play by video UUID',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _videoIdController,
              decoration: const InputDecoration(labelText: 'Video UUID'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy
                  ? null
                  : () => _play(_videoIdController.text.trim()),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scenarioCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Stub scenarios',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            for (final scenario in Scenario.values)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(scenario.label),
                subtitle: Text(scenario.description),
                trailing: const Icon(Icons.chevron_right),
                enabled: !_busy && _useStub,
                onTap: () => _play(scenario.videoId),
              ),
            if (!_useStub)
              const Text(
                'Enable the stub backend to run these.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
          ],
        ),
      ),
    );
  }

  Widget _logCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Events',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                TextButton(
                  onPressed: () => setState(_log.clear),
                  child: const Text('Clear'),
                ),
              ],
            ),
            if (_log.isEmpty)
              const Text(
                'No events yet.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            for (final entry in _log)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  entry,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
