import 'package:flutter/material.dart';

import '../application/game_controller.dart';
import '../domain/models/game_state.dart';
import 'game_screen.dart';
import 'network_connection_banner.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  late final GameController controller;

  @override
  void initState() {
    super.initState();
    controller = GameController(nickname: 'Jugador');
    WidgetsBinding.instance.addObserver(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (_, __) {
          final state = controller.state;
          if (state != null) {
            return Stack(children: [
              GameScreen(controller: controller),
              NetworkConnectionBanner(controller: controller),
            ]);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Basta Local')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: _initialActions(),
            ),
          );
        },
      );

  Widget _initialActions() => Center(
        child: FilledButton(
          onPressed: () => controller.host(
            const GameConfig(
              categories: ['Nombre', 'Animal', 'País', 'Color'],
              totalRounds: 3,
            ),
          ),
          child: const Text('Crear sala local'),
        ),
      );
}
