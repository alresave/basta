import 'package:flutter/material.dart';

import '../application/game_controller.dart';
import '../domain/models/game_state.dart';

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
          return Scaffold(
            appBar: AppBar(title: const Text('Basta Local')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: state == null ? _initialActions() : _game(state),
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

  Widget _game(GameState state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sala ${state.roomId} · ${state.players.length} jugadores'),
          const SizedBox(height: 12),
          Text('Estado: ${state.phase.name}'),
          if (state.currentRound?.letter != null)
            Text(
              'Letra: ${state.currentRound!.letter}',
              style: Theme.of(context).textTheme.displaySmall,
            ),
          if (state.secondsRemaining > 0)
            Text('Basta en ${state.secondsRemaining}s'),
          const Spacer(),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: controller.startRound,
                child: const Text('Girar'),
              ),
              FilledButton(
                onPressed: controller.stopLetter,
                child: const Text('Detener letra'),
              ),
              FilledButton(
                onPressed: controller.triggerBasta,
                child: const Text('¡BASTA!'),
              ),
            ],
          ),
        ],
      );
}
