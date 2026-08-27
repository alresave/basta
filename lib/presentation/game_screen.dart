import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../application/game_controller.dart';
import '../domain/models/game_state.dart';
import 'showcase_screen.dart';
import 'leaderboard_screen.dart';

/// Pantalla de respuesta de cada cliente durante una ronda local.
/// Los borradores permanecen locales hasta FREEZE_INPUTS, cuando se entregan al Host.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final Map<String, String> _answers = {};
  GamePhase? _previousPhase;
  String? _editingCategory;
  bool _answersSent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onGameStateChanged);
    _previousPhase = widget.controller.state?.phase;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onGameStateChanged);
    super.dispose();
  }

  void _onGameStateChanged() {
    final phase = widget.controller.state?.phase;
    if (phase == GamePhase.bastaCountdown &&
        _previousPhase != GamePhase.bastaCountdown) {
      HapticFeedback.mediumImpact();
    }
    if (phase == GamePhase.frozen && _previousPhase != GamePhase.frozen) {
      FocusManager.instance.primaryFocus?.unfocus();
      if (!_answersSent) {
        _answersSent = true;
        widget.controller.submitAnswers(_answers);
      }
    }
    _previousPhase = phase;
  }

  bool _isComplete(GameState state) => state.config.categories.every(
        (category) => (_answers[category] ?? '').trim().isNotEmpty,
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final state = widget.controller.state;
        if (state == null) return const Scaffold(body: SizedBox.shrink());
        if (state.phase == GamePhase.finished) {
          return LeaderboardScreen(state: state);
        }
        if (state.phase == GamePhase.frozen) {
          return ShowcaseScreen(
            controller: widget.controller,
            state: state,
            localAnswers: _answers,
          );
        }
        if (state.phase == GamePhase.lobby) {
          return _LobbySetup(controller: widget.controller, state: state);
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('Ronda ${state.currentRound?.number ?? '-'}'),
            centerTitle: true,
          ),
          floatingActionButton: _roundAction(state),
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    _RoundHeader(state: state),
                    Expanded(child: _categoryGrid(state)),
                  ],
                ),
              ),
              if (state.phase == GamePhase.bastaCountdown)
                _BastaCountdownBanner(seconds: state.secondsRemaining),
            ],
          ),
        );
      },
    );
  }

  Widget _roundAction(GameState state) {
    if (state.phase == GamePhase.lobby && widget.controller.isHost) {
      return FloatingActionButton.extended(
        onPressed: widget.controller.startRound,
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Iniciar ronda'),
      );
    }
    if (state.phase == GamePhase.spinning &&
        state.currentRound?.stopperPlayerId == widget.controller.playerId) {
      return FloatingActionButton.extended(
        onPressed: widget.controller.stopLetter,
        icon: const Icon(Icons.stop_circle_outlined),
        label: const Text('Detener abecedario'),
      );
    }
    return FloatingActionButton.extended(
      onPressed: _isComplete(state) && widget.controller.inputsEnabled
          ? widget.controller.triggerBasta
          : null,
      icon: const Icon(Icons.timer_outlined),
      label: const Text('¡BASTA!'),
    );
  }

  Widget _categoryGrid(GameState state) {
    final canEdit = widget.controller.inputsEnabled;
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: state.config.categories.length,
      itemBuilder: (context, index) {
        final category = state.config.categories[index];
        final answer = _answers[category] ?? '';
        final completed = answer.trim().isNotEmpty;
        return _CategoryCard(
          category: category,
          answer: answer,
          completed: completed,
          inProgress: category == _editingCategory,
          enabled: canEdit,
          onTap: () => _editCategory(category),
        );
      },
    );
  }

  Future<void> _editCategory(String category) async {
    if (!widget.controller.inputsEnabled) return;
    final textController = TextEditingController(text: _answers[category]);
    setState(() => _editingCategory = category);
    widget.controller.setActiveCategory(category);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(category, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: textController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => setState(() => _answers[category] = value),
            onSubmitted: (_) => Navigator.pop(context),
            decoration: const InputDecoration(
              hintText: 'Escribe tu respuesta',
              border: OutlineInputBorder(),
            ),
          ),
        ]),
      ),
    );
    widget.controller.setActiveCategory(null);
    if (mounted) setState(() => _editingCategory = null);
    textController.dispose();
  }
}

class _LobbySetup extends StatefulWidget {
  const _LobbySetup({required this.controller, required this.state});
  final GameController controller;
  final GameState state;

  @override
  State<_LobbySetup> createState() => _LobbySetupState();
}

class _LobbySetupState extends State<_LobbySetup> {
  final _category = TextEditingController();

  @override
  void dispose() {
    _category.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Sala · Configuración')),
        floatingActionButton: widget.controller.isHost
            ? FloatingActionButton.extended(
                onPressed: widget.controller.startRound,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Iniciar ronda'),
              )
            : null,
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('Categorías',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 6),
            Text(widget.controller.isHost
                ? 'Como admin puedes agregar o quitar categorías antes de empezar.'
                : 'Esperando a que el admin configure la partida.'),
            const SizedBox(height: 16),
            ...widget.state.config.categories.map((category) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.category_outlined),
                    title: Text(category),
                    trailing: widget.controller.isHost
                        ? IconButton(
                            tooltip: 'Quitar categoría',
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () =>
                                widget.controller.removeCategory(category),
                          )
                        : null,
                  ),
                )),
            if (widget.controller.isHost) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _category,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nueva categoría',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: _addCategory,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  tooltip: 'Agregar categoría',
                  onPressed: () => _addCategory(_category.text),
                  icon: const Icon(Icons.add_rounded),
                ),
              ]),
            ],
          ],
        ),
      );

  void _addCategory(String value) {
    widget.controller.addCategory(value);
    _category.clear();
  }
}

class _RoundHeader extends StatelessWidget {
  const _RoundHeader({required this.state});
  final GameState state;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
        child: Column(children: [
          Text('LETRA DE LA RONDA',
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            width: 142,
            height: 142,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                  colors: [Color(0xFFFFD92F), Color(0xFFFF9D20)]),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 16,
                    offset: Offset(0, 7))
              ],
              border: Border.all(color: Colors.white, width: 5),
            ),
            child: Text(
              state.currentRound?.letter ?? '…',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 92,
                    height: .95,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF13255D),
                  ),
            ),
          ),
          const SizedBox(height: 10),
          if (state.phase == GamePhase.spinning)
            const Text('Esperando a que se detenga el abecedario…'),
        ]),
      );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.answer,
    required this.completed,
    required this.inProgress,
    required this.enabled,
    required this.onTap,
  });
  final String category;
  final String answer;
  final bool completed;
  final bool inProgress;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = completed
        ? Colors.green
        : inProgress
            ? Colors.orange
            : Colors.blueGrey;
    final status = completed
        ? 'Completada'
        : inProgress
            ? 'En progreso'
            : 'Pendiente';
    return Material(
      color: color.withValues(alpha: enabled ? .14 : .07),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(completed ? Icons.check_circle : Icons.edit_outlined,
                  color: color),
              const Spacer(),
              Text(category, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(status,
                  style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BastaCountdownBanner extends StatelessWidget {
  const _BastaCountdownBanner({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              '¡BASTA! Completa lo que falta · $seconds s',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface),
            ),
          ),
        ),
      );
}
