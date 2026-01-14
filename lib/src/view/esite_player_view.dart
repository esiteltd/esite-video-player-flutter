import 'package:flutter/material.dart';

import '../controller/esite_player_controller.dart';

class ESitePlayerView extends StatelessWidget {
  final ESitePlayerController controller;

  const ESitePlayerView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(child: ColoredBox(color: Colors.black));
  }
}
