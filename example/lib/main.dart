import 'dart:async';
import 'dart:convert';

import 'package:esite_flutter_player/esite_flutter_player.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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

// Test scenarios with different authentication and access states
enum TestScenario {
  esiteLiveApi, // New: Real API call to eSite backend
  validAuth,
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
      case TestScenario.esiteLiveApi:
        return '🚀 eSite Live API (Production)';
      case TestScenario.validAuth:
        return '✅ Valid Auth (Should Work)';
      case TestScenario.expiredAuth:
        return '❌ Expired Token (DRM Error)';
      case TestScenario.invalidAuth:
        return '❌ Invalid License URL (Network Error)';
      case TestScenario.noAuth:
        return '❌ Missing Auth Header (DRM Error)';
      case TestScenario.wrongScheme:
        return '❌ Wrong DRM Scheme (Error)';
      case TestScenario.networkError:
        return '❌ Network Error (Invalid Domain)';
      case TestScenario.invalidUrl:
        return '❌ Invalid URL Format (Error)';
    }
  }
}

/// Response model for the eSite video license API
class ESiteLicenseResponse {
  final String entitlementMessage;
  final String licenseServerUrl;
  final String manifestUrl;

  ESiteLicenseResponse({
    required this.entitlementMessage,
    required this.licenseServerUrl,
    required this.manifestUrl,
  });

  factory ESiteLicenseResponse.fromJson(Map<String, dynamic> json) {
    return ESiteLicenseResponse(
      entitlementMessage: json['entitlement_message'] as String,
      licenseServerUrl: json['license_server_url'] as String,
      manifestUrl: json['manifest_url'] as String,
    );
  }
}

/// Service to fetch DRM license data from eSite backend
class ESiteVideoService {
  static const String _baseUrl = 'https://video-service.esite-lab.com/api/v1';
  static const String _apiKey = 'sk_live_8f2c1e9a7d4b';

  /// Fetches Widevine license data for a video
  /// 
  /// [videoId] - The unique video identifier
  /// [quality] - Video quality (e.g., '360', '720', '1080')
  static Future<ESiteLicenseResponse> getWidevineeLicense({
    required String videoId,
    String quality = '360',
  }) async {
    final url = Uri.parse(
      '$_baseUrl/public/videos/$videoId/widevine?quality=$quality',
    );

    final response = await http.get(
      url,
      headers: {
        'Api-Key': _apiKey,
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return ESiteLicenseResponse.fromJson(json);
    } else {
      throw Exception(
        'Failed to fetch license: ${response.statusCode} - ${response.body}',
      );
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
  bool _isMuted = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  List<Map<String, dynamic>> _videoTracks = [];
  String? _selectedTrackId;
  TestScenario? _currentScenario;
  bool _isPlayerInitialized = false;
  final List<String> _eventLog = [];

  // Store subscriptions to cancel them
  StreamSubscription<ESitePlayerState>? _stateSubscription;
  StreamSubscription<ESiteDrmEvent>? _drmSubscription;
  StreamSubscription<ESitePlayerError>? _errorSubscription;

  static const int _maxEventLogSize =
      30; // Limit log size to prevent memory issues

  @override
  void initState() {
    super.initState();
    // Don't auto-initialize - let user select scenario first
  }

  void _addToLog(String message) {
    if (!mounted) return;
    setState(() {
      _eventLog.insert(
        0,
        '${DateTime.now().toString().substring(11, 19)} - $message',
      );
      // More aggressive limit to prevent memory bloat
      if (_eventLog.length > _maxEventLogSize) {
        _eventLog.removeRange(_maxEventLogSize, _eventLog.length);
      }
    });
  }

  void _initializePlayer(TestScenario scenario) async {
    // Cancel existing subscriptions first
    _cancelSubscriptions();

    // Dispose existing controller if any
    controller?.dispose();

    setState(() {
      _currentScenario = scenario;
      _errorMessage = null;
      _currentState = ESitePlayerState.idle;
      _isPlayerInitialized = false;
      _videoTracks = [];
      _selectedTrackId = null;
      _eventLog.clear();
    });

    _addToLog('Initializing player with scenario: ${scenario.name}');

    ESitePlayerConfig config;

    // Handle eSite Live API scenario with async fetch
    if (scenario == TestScenario.esiteLiveApi) {
      _addToLog('Fetching license from eSite API...');
      try {
        final licenseData = await ESiteVideoService.getWidevineeLicense(
          videoId: '6a5b2b6833b76d0cca317fece3c7f054',
          quality: '360',
        );
        _addToLog('License fetched successfully!');
        _addToLog('Video URL: ${licenseData.manifestUrl}');
        _addToLog('License URL: ${licenseData.licenseServerUrl}');
        
        config = ESitePlayerConfig(
          sourceUrl: licenseData.manifestUrl,
          drm: ESiteDrmConfig(
            licenseUrl: licenseData.licenseServerUrl,
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {
              'X-AxDRM-Message': licenseData.entitlementMessage,
            },
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );
      } catch (e) {
        _addToLog('Failed to fetch license: $e');
        if (mounted) {
          setState(() {
            _errorMessage = 'API Error: $e';
          });
        }
        return;
      }
    } else {
      config = _getConfigForScenario(scenario);
    }

    controller = ESitePlayerController(config);

    controller!.initialize();

    setState(() {
      _isPlayerInitialized = true;
    });

    // Subscribe to streams and store subscriptions
    _stateSubscription = controller!.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
        _addToLog('State changed: ${state.name}');

        if (state == ESitePlayerState.ready) {
          _loadVideoTracks();
        }
      }
    });

    _drmSubscription = controller!.drmStream.listen((event) {
      _addToLog('DRM event: ${event.type.name} - ${event.message ?? ''}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DRM: ${event.type.name}'),
            duration: const Duration(seconds: 2),
            backgroundColor: event.type == ESiteDrmEventType.licenseFailed
                ? Colors.red
                : Colors.blue,
          ),
        );
      }
    });

    _errorSubscription = controller!.errorStream.listen((error) {
      _addToLog('Error: ${error.code.name} - ${error.message}');
      if (mounted) {
        setState(() {
          _errorMessage = '${error.code.name}: ${error.message}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
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
      case TestScenario.esiteLiveApi:
        // This case is handled separately in _initializePlayer with async API call
        // Return a dummy config (should never be reached)
        throw StateError('esiteLiveApi should be handled separately');

      case TestScenario.validAuth:
        // Valid authentication token - should work (Axinom v10 CMAF test content)
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/Cmaf/protected_1080p_h264_cbcs/manifest.mpd',
          drm: ESiteDrmConfig(
            licenseUrl:
                'https://drm-widevine-licensing.axprod.net/AcquireLicense?AxDrmMessage=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.ewogICJ2ZXJzaW9uIjogMSwKICAiY29tX2tleV9pZCI6ICI2OWU1NDA4OC1lOWUwLTQ1MzAtOGMxYS0xZWI2ZGNkMGQxNGUiLAogICJtZXNzYWdlIjogewogICAgInR5cGUiOiAiZW50aXRsZW1lbnRfbWVzc2FnZSIsCiAgICAidmVyc2lvbiI6IDIsCiAgICAibGljZW5zZSI6IHsKICAgICAgImFsbG93X3BlcnNpc3RlbmNlIjogdHJ1ZQogICAgfSwKICAgICJjb250ZW50X2tleXNfc291cmNlIjogewogICAgICAiaW5saW5lIjogWwogICAgICAgIHsKICAgICAgICAgICJpZCI6ICIzMDJmODBkZC00MTFlLTQ4ODYtYmNhNS1iYjFmODAxOGEwMjQiLAogICAgICAgICAgImVuY3J5cHRlZF9rZXkiOiAicm9LQWcwdDdKaTFpNDNmd3YremZ0UT09IiwKICAgICAgICAgICJ1c2FnZV9wb2xpY3kiOiAiUG9saWN5IEEiCiAgICAgICAgfQogICAgICBdCiAgICB9LAogICAgImNvbnRlbnRfa2V5X3VzYWdlX3BvbGljaWVzIjogWwogICAgICB7CiAgICAgICAgIm5hbWUiOiAiUG9saWN5IEEiLAogICAgICAgICJwbGF5cmVhZHkiOiB7CiAgICAgICAgICAibWluX2RldmljZV9zZWN1cml0eV9sZXZlbCI6IDE1MCwKICAgICAgICAgICJwbGF5X2VuYWJsZXJzIjogWwogICAgICAgICAgICAiNzg2NjI3RDgtQzJBNi00NEJFLThGODgtMDhBRTI1NUIwMUE3IgogICAgICAgICAgXQogICAgICAgIH0KICAgICAgfQogICAgXQogIH0KfQ._NfhLVY7S6k8TJDWPeMPhUawhympnrk6WAZHOVjER6M',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {}, // Token is in the URL query parameter
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );

      case TestScenario.expiredAuth:
        // Expired or invalid token - should fail with DRM error
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
        // Wrong license URL - should fail
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
        // Missing authentication header - should fail
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
          drm: ESiteDrmConfig(
            licenseUrl:
                'https://drm-widevine-licensing.axtest.net/AcquireLicense',
            scheme: ESiteDrmScheme.widevine,
            licenseHeaders: {}, // No auth headers
          ),
          autoPlay: false,
          preventScreenshots: true,
          preventScreenRecording: true,
        );

      case TestScenario.wrongScheme:
        // Wrong DRM scheme - should fail
        return ESitePlayerConfig(
          sourceUrl:
              'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
          drm: ESiteDrmConfig(
            licenseUrl:
                'https://drm-widevine-licensing.axtest.net/AcquireLicense',
            scheme: ESiteDrmScheme.playready, // Wrong scheme for this content
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
        // Non-existent domain - should fail with network error
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
        // Malformed URL - should fail immediately
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

  Future<void> _loadVideoTracks() async {
    try {
      final tracks = await controller!.getAvailableVideoTracks();
      if (mounted) {
        setState(() {
          _videoTracks = tracks;
        });
        _addToLog('Loaded ${tracks.length} video tracks');
      }
    } catch (e) {
      _addToLog('Failed to load video tracks: $e');
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
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Player View
          Expanded(
            flex: 3,
            child: Container(color: Colors.black, child: _buildPlayerArea()),
          ),

          // Controls Panel
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.grey[900],
              child: _isPlayerInitialized
                  ? _buildControlsPanel()
                  : _buildScenarioSelector(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerArea() {
    if (!_isPlayerInitialized) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Select a test scenario below',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 64),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isPlayerInitialized = false;
                    _currentScenario = null;
                  });
                  controller?.dispose();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Try Another Scenario'),
              ),
            ],
          ),
        ),
      );
    }

    return controller != null
        ? ESitePlayerView(controller: controller!)
        : const Center(child: CircularProgressIndicator());
  }

  Widget _buildScenarioSelector() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '🧪 Test Scenarios',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select a scenario to test different authentication and error states:',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ...TestScenario.values.map(
            (scenario) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton(
                onPressed: () => _initializePlayer(scenario),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: scenario == TestScenario.esiteLiveApi
                      ? Colors.purple[700]
                      : scenario == TestScenario.validAuth
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
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
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
                    const Icon(Icons.arrow_forward_ios),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getScenarioDetails(TestScenario scenario) {
    switch (scenario) {
      case TestScenario.esiteLiveApi:
        return 'Fetches license from eSite backend API, then plays with Widevine DRM';
      case TestScenario.validAuth:
        return 'Axinom v10 CMAF test content with valid Widevine license';
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

  Widget _buildControlsPanel() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[850],
            child: Column(
              children: [
                // Current Scenario
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[800],
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Testing: ${_currentScenario?.description ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () {
                          setState(() {
                            _isPlayerInitialized = false;
                            _currentScenario = null;
                          });
                          controller?.dispose();
                        },
                        tooltip: 'Change Scenario',
                      ),
                    ],
                  ),
                ),
                // State Display
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        _getStateIcon(_currentState),
                        color: _getStateColor(_currentState),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'State: ${_currentState.name}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(
                      icon: Icon(Icons.play_circle, size: 20),
                      text: 'Controls',
                    ),
                    Tab(icon: Icon(Icons.settings, size: 20), text: 'Settings'),
                    Tab(icon: Icon(Icons.list, size: 20), text: 'Events'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildControlsTab(),
                _buildSettingsTab(),
                _buildEventsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Playback Controls
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        onPressed: () async {
                          final hasPrev = await controller!.hasPrevious();
                          if (hasPrev) {
                            await controller!.previous();
                          }
                        },
                        tooltip: 'Previous',
                      ),
                      IconButton(
                        icon: Icon(
                          _currentState == ESitePlayerState.playing
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_filled,
                        ),
                        iconSize: 64,
                        onPressed: () async {
                          if (_currentState == ESitePlayerState.playing) {
                            await controller!.pause();
                          } else {
                            await controller!.play();
                          }
                        },
                        tooltip: _currentState == ESitePlayerState.playing
                            ? 'Pause'
                            : 'Play',
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        onPressed: () async {
                          final hasNext = await controller!.hasNext();
                          if (hasNext) {
                            await controller!.next();
                          }
                        },
                        tooltip: 'Next',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => controller!.seekBackward(
                          const Duration(seconds: 10),
                        ),
                        icon: const Icon(Icons.replay_10, size: 20),
                        label: const Text('-10s'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => controller!.seekForward(
                          const Duration(seconds: 10),
                        ),
                        icon: const Icon(Icons.forward_10, size: 20),
                        label: const Text('+10s'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => controller!.seekForward(
                          const Duration(seconds: 30),
                        ),
                        icon: const Icon(Icons.forward_30, size: 20),
                        label: const Text('+30s'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Volume Control
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Volume',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          _isMuted ? Icons.volume_off : Icons.volume_up,
                        ),
                        onPressed: () async {
                          final newMuted = !_isMuted;
                          setState(() {
                            _isMuted = newMuted;
                          });
                          await controller!.setMuted(newMuted);
                        },
                      ),
                      Expanded(
                        child: Slider(
                          value: _volume,
                          min: 0.0,
                          max: 1.0,
                          onChanged: (value) async {
                            setState(() {
                              _volume = value;
                              _isMuted = value == 0.0;
                            });
                            await controller!.setVolume(value);
                          },
                        ),
                      ),
                      Text(
                        '${(_volume * 100).toInt()}%',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Speed Control
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Playback Speed: ${_playbackSpeed}x',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 4.0,
                    divisions: 7,
                    label: '${_playbackSpeed}x',
                    onChanged: (value) async {
                      setState(() {
                        _playbackSpeed = value;
                      });
                      await controller!.setPlaybackSpeed(value);
                    },
                  ),
                  Wrap(
                    spacing: 8,
                    children: [0.5, 1.0, 1.5, 2.0, 4.0]
                        .map(
                          (speed) => ChoiceChip(
                            label: Text('${speed}x'),
                            selected: _playbackSpeed == speed,
                            onSelected: (selected) async {
                              if (selected) {
                                setState(() {
                                  _playbackSpeed = speed;
                                });
                                await controller!.setPlaybackSpeed(speed);
                              }
                            },
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Track Selection
          if (_videoTracks.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Video Quality',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: _videoTracks.map((track) {
                        final trackId = track['id'] as String;
                        final label = track['label'] as String;
                        final isSelected = trackId == _selectedTrackId;
                        return ChoiceChip(
                          label: Text(label),
                          selected: isSelected,
                          onSelected: (selected) async {
                            if (selected) {
                              setState(() {
                                _selectedTrackId = trackId;
                              });
                              await controller!.setVideoTrack(trackId);
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEventsTab() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
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

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ESite Player Test Suite'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This comprehensive test suite allows you to validate:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('✅ Valid DRM authentication'),
              Text('❌ Expired/invalid tokens'),
              Text('❌ Missing authentication'),
              Text('❌ Wrong DRM schemes'),
              Text('❌ Network errors'),
              Text('❌ Invalid URLs'),
              SizedBox(height: 12),
              Text('Features:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('• Screenshot blocking (FLAG_SECURE)'),
              Text('• Screen recording prevention'),
              Text('• Full playback controls'),
              Text('• Quality selection'),
              Text('• Volume & speed control'),
              Text('• Event logging'),
              SizedBox(height: 12),
              Text(
                'Note: Test on a real device for full DRM functionality.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
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
