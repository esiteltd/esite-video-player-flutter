import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:esite_flutter_player/esite_flutter_player.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ESite Flutter Player Demo',
      theme: ThemeData.dark(),
      home: const PlayerDemoPage(),
    );
  }
}

enum TestScenario {
  validAuth,
  esiteApi,
  expiredAuth,
  invalidAuth,
  noAuth,
  wrongScheme,
  networkError,
  invalidUrl,
}

extension TestScenarioExtension on TestScenario {
  String get description {
    switch (this) {
      case TestScenario.validAuth:
        return 'Valid Auth (Should Work)';
      case TestScenario.esiteApi:
        return 'ESite API (Live Fetch)';
      case TestScenario.expiredAuth:
        return 'Expired Token (DRM Error)';
      case TestScenario.invalidAuth:
        return 'Invalid License URL (Network Error)';
      case TestScenario.noAuth:
        return 'Missing Auth Header (DRM Error)';
      case TestScenario.wrongScheme:
        return 'Wrong DRM Scheme (Error)';
      case TestScenario.networkError:
        return 'Network Error (Invalid Domain)';
      case TestScenario.invalidUrl:
        return 'Invalid URL Format (Error)';
    }
  }
}

class PlayerDemoPage extends StatefulWidget {
  const PlayerDemoPage({super.key});

  @override
  State<PlayerDemoPage> createState() => _PlayerDemoPageState();
}

class _PlayerDemoPageState extends State<PlayerDemoPage> {
  ESitePlayerController? controller;
  ESitePlayerState _currentState = ESitePlayerState.idle;
  String? _errorMessage;
  final List<String> _eventLog = [];

  StreamSubscription<ESitePlayerState>? _stateSubscription;
  StreamSubscription<ESiteDrmEvent>? _drmSubscription;
  StreamSubscription<ESitePlayerError>? _errorSubscription;

  static const int _maxEventLogSize = 30;

  void _addToLog(String message) {
    if (!mounted) return;
    setState(() {
      _eventLog.insert(
        0,
        '${DateTime.now().toString().substring(11, 19)} - $message',
      );
      if (_eventLog.length > _maxEventLogSize) {
        _eventLog.removeRange(_maxEventLogSize, _eventLog.length);
      }
    });
  }

  bool _isLoading = false;

  void _launchScenario(TestScenario scenario) async {
    _cancelSubscriptions();
    controller?.dispose();

    setState(() {
      _errorMessage = null;
      _currentState = ESitePlayerState.idle;
      _eventLog.clear();
      _isLoading = false;
    });

    _addToLog('Launching scenario: ${scenario.name}');

    ESitePlayerConfig config;

    if (scenario == TestScenario.esiteApi) {
      setState(() => _isLoading = true);
      _addToLog('Fetching entitlement from ESite API...');
      try {
        config = await _fetchEsiteConfig();
        if (!mounted) return;
        _addToLog('API response received, launching player');
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'API fetch failed: $e';
        });
        _addToLog('Error: API fetch failed - $e');
        return;
      }
      setState(() => _isLoading = false);
    } else {
      config = _getConfigForScenario(scenario);
    }

    controller = ESitePlayerController(config);

    _stateSubscription = controller!.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
        _addToLog('State: ${state.name}');
      }
    });

    _drmSubscription = controller!.drmStream.listen((event) {
      _addToLog('DRM: ${event.type.name} - ${event.message ?? ''}');
    });

    _errorSubscription = controller!.errorStream.listen((error) {
      _addToLog('Error: ${error.code.name} - ${error.message}');
      if (mounted) {
        setState(() {
          _errorMessage = '${error.code.name}: ${error.message}';
        });
      }
    });

    controller!.launchPlayer();
  }

  Future<ESitePlayerConfig> _fetchEsiteConfig() async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(
        'https://video-service.esite-lab.com/api/v1/public/videos/c03016d41f341bc4452ac8e610670a3d/widevine?quality=360',
      ));
      request.headers.set('Api-Key', 'sk_test_dfisa02dikbl');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: $body');
      }

      final json = jsonDecode(body) as Map<String, dynamic>;
      final entitlementMessage = json['entitlement_message'] as String;
      final licenseServerUrl = json['license_server_url'] as String;
      final manifestUrl = json['manifest_url'] as String;

      return ESitePlayerConfig(
        sourceUrl: manifestUrl,
        drm: ESiteDrmConfig(
          licenseUrl: licenseServerUrl,
          scheme: ESiteDrmScheme.widevine,
          licenseHeaders: {
            'X-AxDRM-Message': entitlementMessage,
          },
        ),
        autoPlay: true,
        preventScreenshots: true,
        preventScreenRecording: true,
        primaryColor: const Color(0xFF6C63FF),
        secondaryColor: const Color(0xFFFFFFFF),
      );
    } finally {
      client.close();
    }
  }

  void _cancelSubscriptions() {
    _stateSubscription?.cancel();
    _drmSubscription?.cancel();
    _errorSubscription?.cancel();
    _stateSubscription = null;
    _drmSubscription = null;
    _errorSubscription = null;
  }

  ESitePlayerConfig _getConfigForScenario(TestScenario scenario) {
    switch (scenario) {
      case TestScenario.esiteApi:
        throw StateError('esiteApi scenario is handled via async fetch');
      case TestScenario.validAuth:
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/Cmaf/protected_1080p_h264_cbcs/manifest.mpd',
          drm: ESiteDrmConfig(
            licenseUrl:
                'https://drm-widevine-licensing.axprod.net/AcquireLicense?AxDrmMessage=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJ2ZXJzaW9uIjogMSwKICAiY29tX2tleV9pZCI6ICI2OWU1NDA4OC1lOWUwLTQ1MzAtOGMxYS0xZWI2ZGNkMGQxNGUiLAogICJtZXNzYWdlIjogewogICAgInR5cGUiOiAiZW50aXRsZW1lbnRfbWVzc2FnZSIsCiAgICAidmVyc2lvbiI6IDIsCiAgICAibGljZW5zZSI6IHsKICAgICAgImFsbG93X3BlcnNpc3RlbmNlIjogdHJ1ZQogICAgfSwKICAgICJjb250ZW50X2tleXNfc291cmNlIjogewogICAgICAiaW5saW5lIjogWwogICAgICAgIHsKICAgICAgICAgICJpZCI6ICIzMDJmODBkZC00MTFlLTQ4ODYtYmNhNS1iYjFmODAxOGEwMjQiLAogICAgICAgICAgImVuY3J5cHRlZF9rZXkiOiAicm9LQWcwdDdKaTFpNDNmd3YremZ0UT09IiwKICAgICAgICAgICJ1c2FnZV9wb2xpY3kiOiAiUG9saWN5IEEiCiAgICAgICAgfQogICAgICBdCiAgICB9LAogICAgImNvbnRlbnRfa2V5X3VzYWdlX3BvbGljaWVzIjogWwogICAgICB7CiAgICAgICAgIm5hbWUiOiAiUG9saWN5IEEiLAogICAgICAgICJwbGF5cmVhZHkiOiB7CiAgICAgICAgICAibWluX2RldmljZV9zZWN1cml0eV9sZXZlbCI6IDE1MCwKICAgICAgICAgICJwbGF5X2VuYWJsZXJzIjogWwogICAgICAgICAgICAiNzg2NjI3RDgtQzJBNi00NEJFLThGODgtMDhBRTI1NUIwMUE3IgogICAgICAgICAgXQogICAgICAgIH0KICAgICAgfQogICAgXQogIH0KfQ._NfhLVY7S6k8TJDWPeMPhUawhympnrk6WAZHOVjER6M',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {},
          ),
          autoPlay: true,
          preventScreenshots: false,
          preventScreenRecording: false,
          primaryColor: const Color(0xFF6C63FF),
          secondaryColor: const Color(0xFFFFFFFF),
        );

      case TestScenario.expiredAuth:
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
          drm: ESiteDrmConfig(
            licenseUrl:
                'https://drm-widevine-licensing.axtest.net/AcquireLicense',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {
              'X-AxDRM-Message': 'expired_or_invalid_token_here',
            },
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );

      case TestScenario.invalidAuth:
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
          drm: ESiteDrmConfig(
            licenseUrl: 'https://invalid-drm-server.example.com/license',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {'X-AxDRM-Message': 'some_token'},
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );

      case TestScenario.noAuth:
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
          drm: ESiteDrmConfig(
            licenseUrl:
                'https://drm-widevine-licensing.axtest.net/AcquireLicense',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {},
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );

      case TestScenario.wrongScheme:
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
          drm: ESiteDrmConfig(
            licenseUrl:
                'https://drm-widevine-licensing.axtest.net/AcquireLicense',
            scheme: ESiteDrmScheme.playready,
            licenseHeaders: {
              'X-AxDRM-Message':
                  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXJzaW9uIjoxLCJjb21fa2V5X2lkIjoiYjMzNjRlYjUtNTFmNi00YWUzLThjOTgtMzNjZWQ1ZTMxYzc4IiwibWVzc2FnZSI6eyJ0eXBlIjoiZW50aXRsZW1lbnRfbWVzc2FnZSIsImtleXMiOlt7ImlkIjoiOWViNDA1MGQtZTQ0Yi00ODAyLTkzMmUtMjdkNzUwODNlMjY2IiwiZW5jcnlwdGVkX2tleSI6ImxLM09qSExZVzI0Y3Rkbmd5VmRkY2c9PSJ9XX19.4Adl1Qd9Br5n_UCFU-MnpLm3bNJIRrCmCeIxqZqnUNQ',
            },
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );

      case TestScenario.networkError:
        return ESitePlayerConfig(
          sourceUrl: 'https://nonexistent-domain-test-12345.com/video.mpd',
          drm: ESiteDrmConfig(
            licenseUrl: 'https://nonexistent-domain-test-12345.com/license',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {'Authorization': 'Bearer token'},
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );

      case TestScenario.invalidUrl:
        return ESitePlayerConfig(
          sourceUrl: 'not-a-valid-url',
          drm: ESiteDrmConfig(
            licenseUrl: 'also-not-valid',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {},
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );
    }
  }

  @override
  void dispose() {
    _cancelSubscriptions();
    controller?.dispose();
    controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ESite Player Test Suite'),
      ),
      body: Column(
        children: [
          // Status bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey[850],
            child: Row(
              children: [
                Icon(
                  _getStateIcon(_currentState),
                  color: _getStateColor(_currentState),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'State: ${_currentState.name}',
                  style: const TextStyle(fontSize: 14),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Scenario selector + Event log
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Scenarios'),
                      Tab(text: 'Events'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildScenarioSelector(),
                        _buildEventsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSelector() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Select a scenario to launch the native player:',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text(
                    'Fetching entitlement from API...',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ...TestScenario.values.map(
          (scenario) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ElevatedButton(
              onPressed: () => _launchScenario(scenario),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: (scenario == TestScenario.validAuth ||
                        scenario == TestScenario.esiteApi)
                    ? Colors.green[700]
                    : Colors.blue[700],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          scenario.description,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _getScenarioDetails(scenario),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.launch, size: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getScenarioDetails(TestScenario scenario) {
    switch (scenario) {
      case TestScenario.validAuth:
        return 'Axinom v10 CMAF test content with valid Widevine license';
      case TestScenario.esiteApi:
        return 'Fetch entitlement from ESite API, then play with Widevine DRM';
      case TestScenario.expiredAuth:
        return 'Simulate expired authentication token';
      case TestScenario.invalidAuth:
        return 'Test with wrong license server URL';
      case TestScenario.noAuth:
        return 'Attempt playback without auth headers';
      case TestScenario.wrongScheme:
        return 'Use PlayReady for Widevine content';
      case TestScenario.networkError:
        return 'Test network connectivity errors';
      case TestScenario.invalidUrl:
        return 'Test malformed content URLs';
    }
  }

  Widget _buildEventsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: Colors.grey[850],
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Event Log',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _eventLog.clear();
                  });
                },
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _eventLog.isEmpty
              ? const Center(
                  child: Text(
                    'No events yet',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _eventLog.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _eventLog[index],
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  IconData _getStateIcon(ESitePlayerState state) {
    switch (state) {
      case ESitePlayerState.playing:
        return Icons.play_circle_filled;
      case ESitePlayerState.paused:
        return Icons.pause_circle_filled;
      case ESitePlayerState.buffering:
        return Icons.hourglass_empty;
      case ESitePlayerState.ready:
        return Icons.check_circle;
      case ESitePlayerState.completed:
        return Icons.check_circle_outline;
      case ESitePlayerState.error:
        return Icons.error;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _getStateColor(ESitePlayerState state) {
    switch (state) {
      case ESitePlayerState.playing:
        return Colors.green;
      case ESitePlayerState.paused:
        return Colors.orange;
      case ESitePlayerState.buffering:
        return Colors.blue;
      case ESitePlayerState.ready:
        return Colors.green;
      case ESitePlayerState.completed:
        return Colors.grey;
      case ESitePlayerState.error:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
