import 'package:flutter/material.dart';

import '../application/game_controller.dart';
import '../data/network/local_discovery_service.dart';
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
  final _localHost = TextEditingController();
  final _localPort = TextEditingController();
  final Map<String, LocalRoom> _localRooms = {};
  bool _searchingRooms = false;
  String? _localError;

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
    _localHost.dispose();
    _localPort.dispose();
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
          child: ListView(shrinkWrap: true, children: [
            Text('Jugar en la misma red Wi‑Fi',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: () => controller.host(_defaultConfig),
              icon: const Icon(Icons.wifi_rounded),
              label: const Text('Crear sala local'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _searchingRooms ? null : _findLocalRooms,
              icon: Icon(
                  _searchingRooms ? Icons.sync_rounded : Icons.search_rounded),
              label: Text(_searchingRooms ? 'Buscando salas…' : 'Buscar salas'),
            ),
            const SizedBox(height: 14),
            Text('Entrar por IP',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Úsalo si el emulador no encuentra la sala automáticamente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _localHost,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'IP del Host',
                    hintText: '192.168.1.24',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _joinManualRoom(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _localPort,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Puerto',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _joinManualRoom(),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: _joinManualRoom,
                icon: const Icon(Icons.login_rounded),
                label: const Text('Unirse por IP'),
              ),
            ),
            if (_localError != null) ...[
              const SizedBox(height: 8),
              Text(_localError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (_localRooms.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Salas disponibles',
                  style: Theme.of(context).textTheme.titleMedium),
              ..._localRooms.values.map((room) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.groups_rounded),
                      title: Text('Sala ${room.id.toUpperCase()}'),
                      subtitle: Text('${room.host}:${room.port}'),
                      trailing: FilledButton(
                        onPressed: () => _joinLocalRoom(room),
                        child: const Text('Unirse'),
                      ),
                    ),
                  )),
            ],
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

  Future<void> _findLocalRooms() async {
    setState(() {
      _searchingRooms = true;
      _localError = null;
      _localRooms.clear();
    });
    try {
      await controller.findRooms((room) {
        if (!mounted) return;
        setState(() => _localRooms[room.id] = room);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _localError =
            'No se pudieron buscar salas. Verifica la red local y sus permisos.');
      }
    } finally {
      if (mounted) setState(() => _searchingRooms = false);
    }
  }

  Future<void> _joinLocalRoom(LocalRoom room) async {
    setState(() => _localError = null);
    try {
      await controller.join(room);
    } catch (_) {
      if (mounted) {
        setState(() => _localError =
            'No fue posible entrar a la sala. Confirma que el Host siga conectado.');
      }
    }
  }

  Future<void> _joinManualRoom() async {
    final port = int.tryParse(_localPort.text.trim());
    if (_localHost.text.trim().isEmpty || port == null) {
      setState(() => _localError = 'Indica la IP y el puerto de la sala.');
      return;
    }
    setState(() => _localError = null);
    try {
      await controller.joinAddress(_localHost.text, port);
    } on ArgumentError catch (error) {
      if (mounted) setState(() => _localError = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(() => _localError =
            'No fue posible entrar a la sala. Confirma IP, puerto y Wi‑Fi.');
      }
    }
  }
}
