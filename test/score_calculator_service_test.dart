import 'package:flutter_test/flutter_test.dart';

import 'package:basta_local/application/score_calculator_service.dart';
import 'package:basta_local/domain/models/game_state.dart';
import 'package:basta_local/domain/models/player.dart';
import 'package:basta_local/domain/models/round_data.dart';
import 'package:basta_local/domain/models/word_challenge.dart';

void main() {
  const players = [
    Player(id: 'a', nickname: 'Ana'),
    Player(id: 'b', nickname: 'Beto')
  ];
  const state = GameState(
    roomId: 'room',
    hostId: 'a',
    players: players,
    config: GameConfig(categories: ['Animal', 'Color'], totalRounds: 1),
  );

  test('calcula única, repetida, inválida y bonus de defensa', () {
    const round = RoundData(
      number: 1,
      letter: 'P',
      stopperPlayerId: 'a',
      answersByPlayer: {
        'a': {'Animal': 'Perro', 'Color': 'Púrpura'},
        'b': {'Animal': 'perro', 'Color': ' '},
      },
      invalidCategoriesByPlayer: {
        'a': {'Color'},
      },
    );
    const defended = WordChallenge(
      id: '1',
      playerId: 'a',
      category: 'Animal',
      word: 'Perro',
      status: ChallengeStatus.resolved,
      valid: true,
    );

    final score = const ScoreCalculatorService().calculate(
      round: round,
      state: state,
      resolvedChallenges: [defended],
    );

    expect(score.scores.firstWhere((item) => item.playerId == 'a').points, 70);
    expect(score.scores.firstWhere((item) => item.playerId == 'b').points, 50);
  });

  test('da 100 puntos a una palabra única válida', () {
    const round = RoundData(
      number: 1,
      letter: 'P',
      stopperPlayerId: 'a',
      answersByPlayer: {
        'a': {'Animal': 'Perro', 'Color': ''},
        'b': {'Animal': 'Pato', 'Color': ''},
      },
    );
    final score = const ScoreCalculatorService().calculate(
      round: round,
      state: state,
      resolvedChallenges: const [],
    );
    expect(score.scores.firstWhere((item) => item.playerId == 'a').points, 100);
    expect(
        score.scores.firstWhere((item) => item.playerId == 'a').uniqueWords, 1);
  });
}
