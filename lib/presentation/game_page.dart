import 'package:flutter/material.dart';

import '../application/game_controller.dart';
import '../data/remote/supabase_config.dart';
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
  final _remoteCode = TextEditingController();

  static const _defaultConfig = GameConfig(
    categories: ['Nombre', 'Flor o fruto', 'Animal', 'Ciudad o país', 'Cosa'],
    totalRounds: 3,
  );

  @override
  void initState() {
    super.initState();
    controller = GameController(nickname: 'Jugador');
    WidgetsBinding.instance.addObserver(controller);
  }

  @override
  void dispose() {
    _remoteCode.dispose();
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            FilledButton.icon(
              onPressed: () => controller.host(_defaultConfig),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('Crear sala local'),
            ),
            if (SupabaseConfig.isConfigured) ...[
              const SizedBox(height: 24),
              Text('Jugar por Internet',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: () async {
                  final code = await controller.hostRemote(_defaultConfig);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Sala remota creada: $code')),
                    );
                  }
                },
                icon: const Icon(Icons.public_rounded),
                label: const Text('Crear sala remota'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _remoteCode,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: 'Código de sala',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: 'Unirse a sala remota',
                    icon: const Icon(Icons.login_rounded),
                    onPressed: () => controller.joinRemote(_remoteCode.text),
                  ),
                ),
                onSubmitted: controller.joinRemote,
              ),
            ],
          ]),
        ),
      );
}
