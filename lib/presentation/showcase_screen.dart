import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../application/game_controller.dart';
import '../domain/models/game_state.dart';
import 'challenge_modal.dart';

class WordMatch {
  const WordMatch({
    required this.playerIds,
    required this.words,
  });

  final List<String> playerIds;
  final List<String> words;

  int get pointsPerPlayer => 50;

  bool includes(String playerId) => playerIds.contains(playerId);
}

/// Normaliza mayúsculas y diacríticos antes de aplicar Levenshtein.
String normalizeWord(String word) {
  const accents = 'áéíóúüñÁÉÍÓÚÜÑ';
  const plain = 'aeiouunAEIOUUN';
  var result = word.trim().toLowerCase();
  for (var index = 0; index < accents.length; index++) {
    result = result.replaceAll(
        accents[index].toLowerCase(), plain[index].toLowerCase());
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

int levenshteinDistance(String left, String right) {
  if (left.length < right.length) return levenshteinDistance(right, left);
  if (right.isEmpty) return left.length;
  var previous = List<int>.generate(right.length + 1, (index) => index);
  for (var row = 0; row < left.length; row++) {
    final current = <int>[row + 1];
    for (var column = 0; column < right.length; column++) {
      current.add(math.min(
        math.min(current[column] + 1, previous[column + 1] + 1),
        previous[column] + (left[row] == right[column] ? 0 : 1),
      ));
    }
    previous = current;
  }
  return previous.last;
}

/// Identifica respuestas repetidas usando la misma normalización del puntaje.
List<WordMatch> findRepeatedWords(Map<String, String> wordsByPlayer) {
  final entries = wordsByPlayer.entries
      .where((entry) => normalizeWord(entry.value).isNotEmpty)
      .toList();
  final parents = List<int>.generate(entries.length, (index) => index);
  int root(int index) {
    while (parents[index] != index) {
      parents[index] = parents[parents[index]];
      index = parents[index];
    }
    return index;
  }

  void join(int first, int second) {
    final firstRoot = root(first);
    final secondRoot = root(second);
    if (firstRoot != secondRoot) parents[secondRoot] = firstRoot;
  }

  for (var first = 0; first < entries.length; first++) {
    for (var second = first + 1; second < entries.length; second++) {
      if (normalizeWord(entries[first].value) ==
          normalizeWord(entries[second].value)) {
        join(first, second);
      }
    }
  }
  final groups = <int, List<MapEntry<String, String>>>{};
  for (var index = 0; index < entries.length; index++) {
    groups.putIfAbsent(root(index), () => []).add(entries[index]);
  }
  return groups.values
      .where((group) => group.length > 1)
      .map((group) => WordMatch(
            playerIds: group.map((entry) => entry.key).toList(),
            words: group.map((entry) => entry.value).toList(),
          ))
      .toList();
}

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({
    super.key,
    required this.controller,
    required this.state,
    required this.localAnswers,
  });

  final GameController controller;
  final GameState state;
  final Map<String, String> localAnswers;

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _revealController;
  int _categoryIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  Map<String, Map<String, String>> get _answersByPlayer {
    final result = Map<String, Map<String, String>>.from(
      widget.state.currentRound?.answersByPlayer ?? const {},
    );
    result[widget.controller.playerId] = widget.localAnswers;
    return result;
  }

  String _playerName(String playerId) =>
      widget.state.players
          .where((player) => player.id == playerId)
          .map((player) => player.nickname)
          .firstOrNull ??
      'Jugador';

  Future<void> _showRoundResults() async {
    final score = widget.controller.previewReviewScore();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.emoji_events_rounded,
                color: Colors.amber.shade800, size: 42),
            const SizedBox(height: 8),
            Text('Puntos de la ronda',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            const Text('Única: 100 · repetida: 50 · defensa: +20'),
            const SizedBox(height: 16),
            ...score.scores.map((item) => ListTile(
                  leading:
                      CircleAvatar(child: Text(_playerName(item.playerId)[0])),
                  title: Text(_playerName(item.playerId)),
                  subtitle: Text(
                      '${item.uniqueWords} únicas · ${item.successfulDefences} defensas'),
                  trailing: Text('+${item.points}',
                      style: Theme.of(context).textTheme.titleLarge),
                )),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await widget.controller.finishReview();
              },
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Continuar'),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categories = widget.state.config.categories;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisión de ronda')),
      body: Stack(children: [
        Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Text(
              'Categoría: ${categories[_categoryIndex].toUpperCase()} · Letra: ${widget.state.currentRound?.letter ?? '—'}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          const Text('Respuestas reveladas'),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: categories.length,
              onPageChanged: (index) {
                setState(() => _categoryIndex = index);
                _revealController.forward(from: 0);
              },
              itemBuilder: (_, index) => _CategoryShowcase(
                category: categories[index],
                answersByPlayer: _answersByPlayer,
                playerName: _playerName,
                reveal: _revealController,
                onChallenge: (playerId, word) =>
                    widget.controller.challengeWord(
                  playerId: playerId,
                  category: categories[index],
                  word: word,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: widget.controller.isHost
                ? FilledButton.icon(
                    onPressed: widget.controller.activeChallenge == null &&
                            _categoryIndex == categories.length - 1
                        ? _showRoundResults
                        : null,
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(_categoryIndex == categories.length - 1
                        ? 'Ver puntos de la ronda'
                        : 'Revela todas las categorías'),
                  )
                : Text(
                    '${_categoryIndex + 1} / ${categories.length} · Esperando al Host'),
          ),
        ]),
        if (widget.controller.activeChallenge case final challenge?)
          ChallengeModal(controller: widget.controller, challenge: challenge),
      ]),
    );
  }
}

class _CategoryShowcase extends StatelessWidget {
  const _CategoryShowcase({
    required this.category,
    required this.answersByPlayer,
    required this.playerName,
    required this.reveal,
    required this.onChallenge,
  });
  final String category;
  final Map<String, Map<String, String>> answersByPlayer;
  final String Function(String) playerName;
  final Animation<double> reveal;
  final void Function(String playerId, String word) onChallenge;

  @override
  Widget build(BuildContext context) {
    final words = <String, String>{
      for (final entry in answersByPlayer.entries)
        entry.key: entry.value[category] ?? '',
    };
    final matches = findRepeatedWords(words);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ...words.entries.map((entry) => _RevealWordCard(
              playerId: entry.key,
              playerName: playerName(entry.key),
              word: entry.value,
              match: matches
                  .where((match) => match.includes(entry.key))
                  .firstOrNull,
              reveal: reveal,
              onChallenge: () => onChallenge(entry.key, entry.value),
            )),
        ...matches.map((match) => _MatchLabel(
              playerNames: match.playerIds.map(playerName).toList(),
              points: match.pointsPerPlayer,
            )),
      ],
    );
  }
}

class _RevealWordCard extends StatelessWidget {
  const _RevealWordCard({
    required this.playerId,
    required this.playerName,
    required this.word,
    required this.match,
    required this.reveal,
    required this.onChallenge,
  });
  final String playerId;
  final String playerName;
  final String word;
  final WordMatch? match;
  final Animation<double> reveal;
  final VoidCallback onChallenge;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: reveal,
        builder: (_, child) => Opacity(
          opacity: reveal.value,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..rotateY((1 - reveal.value) * math.pi / 2),
            child: child,
          ),
        ),
        child: Card(
          color: match == null ? null : Colors.amber.shade100,
          child: ListTile(
            title: Text(playerName),
            subtitle: Text(word.trim().isEmpty ? 'Sin respuesta' : word,
                style: Theme.of(context).textTheme.titleMedium),
            trailing: IconButton(
              tooltip: 'Poner en duda',
              icon: const Icon(Icons.visibility_outlined),
              onPressed: word.trim().isEmpty ? null : onChallenge,
            ),
          ),
        ),
      );
}

class _MatchLabel extends StatelessWidget {
  const _MatchLabel({required this.playerNames, required this.points});
  final List<String> playerNames;
  final int points;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.amber.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Coincidencia: ${playerNames.join(', ')} ($points pts c/u)',
        ),
      );
}
