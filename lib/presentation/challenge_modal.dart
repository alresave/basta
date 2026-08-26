import 'dart:async';

import 'package:flutter/material.dart';

import '../application/game_controller.dart';
import '../domain/models/word_challenge.dart';

/// Capa sincronizada por [WordChallenge]; los votos son solicitudes al Host.
class ChallengeModal extends StatefulWidget {
  const ChallengeModal(
      {super.key, required this.controller, required this.challenge});

  final GameController controller;
  final WordChallenge challenge;

  @override
  State<ChallengeModal> createState() => _ChallengeModalState();
}

class _ChallengeModalState extends State<ChallengeModal> {
  Timer? _clock;
  bool _voted = false;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final challenge = widget.challenge;
    return Material(
      color: Colors.black54,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: Card(
            margin: const EdgeInsets.all(24),
            color: challenge.status == ChallengeStatus.resolved &&
                    challenge.valid == true
                ? Colors.green.shade50
                : null,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: switch (challenge.status) {
                ChallengeStatus.checking => _checking(context, challenge),
                ChallengeStatus.juryVoting => _jury(context, challenge),
                ChallengeStatus.resolved => _resolved(context, challenge),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _checking(BuildContext context, WordChallenge challenge) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text('Tribunal de Palabras',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Verificando “${challenge.word}” en el diccionario…',
              textAlign: TextAlign.center),
        ],
      );

  Widget _jury(BuildContext context, WordChallenge challenge) {
    final remaining =
        ((challenge.deadlineEpochMs! - DateTime.now().millisecondsSinceEpoch) /
                1000)
            .clamp(0, 5)
            .ceil();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text('Votación del Jurado',
          style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Text('¿“${challenge.word}” es válida?',
          style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text('$remaining s', style: Theme.of(context).textTheme.displaySmall),
      const SizedBox(height: 20),
      Row(children: [
        Expanded(
            child: _voteButton(
                Icons.thumb_up_alt_rounded, 'VÁLIDA', Colors.green, true)),
        const SizedBox(width: 12),
        Expanded(
            child: _voteButton(
                Icons.thumb_down_alt_rounded, 'FALSA', Colors.red, false)),
      ]),
      if (_voted)
        const Padding(
          padding: EdgeInsets.only(top: 14),
          child: Text('Voto enviado al Host.'),
        ),
    ]);
  }

  Widget _voteButton(IconData icon, String label, Color color, bool valid) =>
      SizedBox(
        height: 96,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: _voted
              ? null
              : () {
                  setState(() => _voted = true);
                  widget.controller.voteOnChallenge(valid);
                },
          icon: Icon(icon, size: 32),
          label: Text(label),
        ),
      );

  Widget _resolved(BuildContext context, WordChallenge challenge) {
    final valid = challenge.valid == true;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(valid ? Icons.verified_rounded : Icons.cancel_rounded,
          color: valid ? Colors.green : Colors.red, size: 54),
      const SizedBox(height: 12),
      Text(valid ? 'PALABRA VÁLIDA · 100 pts' : 'PALABRA FALSA · 0 pts',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center),
      if (valid && challenge.definition != null) ...[
        const SizedBox(height: 12),
        Text(challenge.definition!, textAlign: TextAlign.center),
      ],
      const SizedBox(height: 20),
      FilledButton(
          onPressed: widget.controller.dismissChallenge,
          child: const Text('Continuar')),
    ]);
  }
}
