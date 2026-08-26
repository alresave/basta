import 'package:flutter/material.dart';

import '../domain/models/game_state.dart';
import '../domain/models/player.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    final players = [...state.players]..sort((left, right) => state.registry
        .totalFor(right.id)
        .compareTo(state.registry.totalFor(left.id)));
    return Scaffold(
      appBar: AppBar(title: const Text('Fin del abecedario')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Posiciones finales',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          ...players.asMap().entries.map((entry) => _RankingRow(
                rank: entry.key + 1,
                player: entry.value,
                points: state.registry.totalFor(entry.value.id),
              )),
          const SizedBox(height: 28),
          Text('Premios divertidos',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          _AwardCard(
            icon: Icons.menu_book_rounded,
            title: 'El Enciclopedia',
            winner: _winner(players, state.registry.uniqueFor),
            detail: 'Más palabras únicas',
          ),
          _AwardCard(
            icon: Icons.gavel_rounded,
            title: 'El Abogado',
            winner: _winner(players, state.registry.defencesFor),
            detail: 'Más impugnaciones ganadas',
          ),
          _AwardCard(
            icon: Icons.auto_stories_rounded,
            title: 'El Poeta',
            winner: _winner(players, state.registry.juryApprovedFor),
            detail: 'Más palabras aprobadas por votación',
          ),
        ],
      ),
    );
  }

  String _winner(List<Player> players, int Function(String) score) {
    if (players.isEmpty) return '—';
    final highest = players
        .map((player) => score(player.id))
        .reduce((a, b) => a > b ? a : b);
    if (highest == 0) return 'Sin ganador';
    return players
        .where((player) => score(player.id) == highest)
        .map((player) => player.nickname)
        .join(' · ');
  }
}

class _RankingRow extends StatelessWidget {
  const _RankingRow(
      {required this.rank, required this.player, required this.points});
  final int rank;
  final Player player;
  final int points;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Text(rank <= 3 ? ['🥇', '🥈', '🥉'][rank - 1] : '$rank.º',
              style: Theme.of(context).textTheme.titleLarge),
          title: Text(player.nickname),
          trailing: Text('$points pts',
              style: Theme.of(context).textTheme.titleMedium),
        ),
      );
}

class _AwardCard extends StatelessWidget {
  const _AwardCard(
      {required this.icon,
      required this.title,
      required this.winner,
      required this.detail});
  final IconData icon;
  final String title;
  final String winner;
  final String detail;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: Icon(icon, color: Colors.amber.shade800),
          title: Text(title),
          subtitle: Text('$winner · $detail'),
        ),
      );
}
