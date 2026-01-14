import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controller/esite_player_controller.dart';

class ESitePlayerView extends StatelessWidget {
  final ESitePlayerController controller;

  const ESitePlayerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const Center(
        child: Text('ESitePlayerView is only supported on Android'),
      );
    }

    return AndroidView(
      viewType: 'esite_flutter_player/view',
      creationParams: const <String, dynamic>{},
      creationParamsCodec: const StandardMessageCodec(),
    );
  }
}
