import 'package:flutter/material.dart';

import '../controller/esite_player_controller.dart';
import '../events/esite_player_state.dart';

class ESitePlayerView extends StatelessWidget {
  final ESitePlayerController controller;

  const ESitePlayerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ESitePlayerState>(
      stream: controller.stateStream,
      initialData: controller.currentState,
      builder: (context, snapshot) {
        final state = snapshot.data ?? ESitePlayerState.idle;
        return GestureDetector(
          onTap: () => controller.launchPlayer(),
          child: Container(
            color: Colors.black,
            child: Center(
              child: state == ESitePlayerState.initializing ||
                      state == ESitePlayerState.buffering
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Icon(
                      Icons.play_circle_outline,
                      size: 72,
                      color: Colors.white,
                    ),
            ),
          ),
        );
      },
    );
  }
}
