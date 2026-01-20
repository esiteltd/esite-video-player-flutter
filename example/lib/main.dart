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

class PlayerDemoPage extends StatefulWidget {
  const PlayerDemoPage({super.key});

  @override
  State<PlayerDemoPage> createState() => _PlayerDemoPageState();
}

class _PlayerDemoPageState extends State<PlayerDemoPage> {
  late final ESitePlayerController controller;
  ESitePlayerState _currentState = ESitePlayerState.idle;
  String? _errorMessage;
  bool _isMuted = false;
  double _volume = 1.0;
  double _playbackSpeed = 1.0;
  List<Map<String, dynamic>> _videoTracks = [];
  String? _selectedTrackId;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    controller = ESitePlayerController(
      ESitePlayerConfig(
        sourceUrl:
            'https://media.axprod.net/TestVectors/v7-MultiDRM-SingleKey/Manifest_1080p.mpd',
        drm: ESiteDrmConfig(
          licenseUrl:
              'https://drm-widevine-licensing.axtest.net/AcquireLicense',
          scheme: ESiteDrmScheme.widevine,
          licenseHeaders: {
            'X-AxDRM-Message':
                'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJ2ZXJzaW9uIjoxLCJjb21fa2V5X2lkIjoiYjMzNjRlYjUtNTFmNi00YWUzLThjOTgtMzNjZWQ1ZTMxYzc4IiwibWVzc2FnZSI6eyJ0eXBlIjoiZW50aXRsZW1lbnRfbWVzc2FnZSIsImtleXMiOlt7ImlkIjoiOWViNDA1MGQtZTQ0Yi00ODAyLTkzMmUtMjdkNzUwODNlMjY2IiwiZW5jcnlwdGVkX2tleSI6ImxLM09qSExZVzI0Y3Rkbmd5VmRkY2c9PSJ9XX19.4Adl1Qd9Br5n_UCFU-MnpLm3bNJIRrCmCeIxqZqnUNQ',
          },
        ),
        autoPlay: false,
        preventScreenshots: true,
        preventScreenRecording: true,
      ),
    );

    controller.initialize();

    controller.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          _currentState = state;
        });
        debugPrint('Player state: $state');

        if (state == ESitePlayerState.ready) {
          _loadVideoTracks();
        }
      }
    });

    controller.drmStream.listen((event) {
      debugPrint('DRM event: ${event.type} - ${event.message ?? ''}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('DRM: ${event.type.name}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    controller.errorStream.listen((error) {
      debugPrint('Player error: ${error.code} - ${error.message}');
      if (mounted) {
        setState(() {
          _errorMessage = '${error.code.name}: ${error.message}';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${error.message}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  Future<void> _loadVideoTracks() async {
    try {
      final tracks = await controller.getAvailableVideoTracks();
      if (mounted) {
        setState(() {
          _videoTracks = tracks;
        });
      }
    } catch (e) {
      debugPrint('Failed to load video tracks: $e');
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ESite Player Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About'),
                  content: const Text(
                    'This demo shows DRM-protected video playback with:\n'
                    '• Screenshot blocking (FLAG_SECURE)\n'
                    '• Screen recording prevention\n'
                    '• Playback controls\n'
                    '• Track selection\n'
                    '• Volume control\n'
                    '\nNote: Replace URLs with your actual DRM content.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Player View
          Expanded(
            flex: 3,
            child: Container(
              color: Colors.black,
              child: _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ESitePlayerView(controller: controller),
            ),
          ),

          // Controls Panel
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.grey[900],
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // State Display
                    _buildStateCard(),

                    const SizedBox(height: 16),

                    // Playback Controls
                    _buildPlaybackControls(),

                    const SizedBox(height: 16),

                    // Speed Control
                    _buildSpeedControl(),

                    const SizedBox(height: 16),

                    // Volume Control
                    _buildVolumeControl(),

                    const SizedBox(height: 16),

                    // Track Selection
                    if (_videoTracks.isNotEmpty) _buildTrackSelection(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStateCard() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(
              _getStateIcon(_currentState),
              color: _getStateColor(_currentState),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'State: ${_currentState.name}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: const Icon(Icons.skip_previous),
              onPressed: () async {
                final hasPrev = await controller.hasPrevious();
                if (hasPrev) {
                  await controller.previous();
                }
              },
              tooltip: 'Previous',
            ),
            IconButton(
              icon: Icon(
                _currentState == ESitePlayerState.playing
                    ? Icons.pause
                    : Icons.play_arrow,
              ),
              iconSize: 48,
              onPressed: () async {
                if (_currentState == ESitePlayerState.playing) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
              },
              tooltip: _currentState == ESitePlayerState.playing
                  ? 'Pause'
                  : 'Play',
            ),
            IconButton(
              icon: const Icon(Icons.skip_next),
              onPressed: () async {
                final hasNext = await controller.hasNext();
                if (hasNext) {
                  await controller.next();
                }
              },
              tooltip: 'Next',
            ),
            IconButton(
              icon: const Icon(Icons.replay_10),
              onPressed: () =>
                  controller.seekBackward(const Duration(seconds: 10)),
              tooltip: 'Seek -10s',
            ),
            IconButton(
              icon: const Icon(Icons.forward_10),
              onPressed: () =>
                  controller.seekForward(const Duration(seconds: 10)),
              tooltip: 'Seek +10s',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Playback Speed: ${_playbackSpeed}x',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 4.0,
                    divisions: 7,
                    label: '${_playbackSpeed}x',
                    onChanged: (value) async {
                      setState(() {
                        _playbackSpeed = value;
                      });
                      await controller.setPlaybackSpeed(value);
                    },
                  ),
                ),
                ...([0.5, 1.0, 1.5, 2.0, 4.0].map(
                  (speed) => Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: TextButton(
                      onPressed: () async {
                        setState(() {
                          _playbackSpeed = speed;
                        });
                        await controller.setPlaybackSpeed(speed);
                      },
                      child: Text('${speed}x'),
                    ),
                  ),
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            IconButton(
              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
              onPressed: () async {
                final newMuted = !_isMuted;
                setState(() {
                  _isMuted = newMuted;
                });
                await controller.setMuted(newMuted);
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
                  await controller.setVolume(value);
                },
              ),
            ),
            Text(
              '${(_volume * 100).toInt()}%',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackSelection() {
    return Card(
      color: Colors.grey[800],
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Video Quality',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
                      await controller.setVideoTrack(trackId);
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
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
