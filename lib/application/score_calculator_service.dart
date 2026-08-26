import '../domain/models/game_registry.dart';
import '../domain/models/game_state.dart';
import '../domain/models/round_data.dart';
import '../domain/models/word_challenge.dart';

class ScoreCalculatorService {
  const ScoreCalculatorService();

  RoundScore calculate({
    required RoundData round,
    required GameState state,
    required Iterable<WordChallenge> resolvedChallenges,
  }) {
    final scores = <PlayerRoundScore>[];
    for (final player in state.players) {
      var points = 0;
      var uniqueWords = 0;
      final answers = round.answersByPlayer[player.id] ?? const {};
      for (final category in state.config.categories) {
        final word = answers[category]?.trim() ?? '';
        final invalid =
            round.invalidCategoriesByPlayer[player.id]?.contains(category) ??
                false;
        if (word.isEmpty || invalid) continue;
        final repeated = state.players.where((other) {
          if (other.id == player.id) return false;
          final otherWord =
              round.answersByPlayer[other.id]?[category]?.trim() ?? '';
          final otherInvalid =
              round.invalidCategoriesByPlayer[other.id]?.contains(category) ??
                  false;
          return !otherInvalid &&
              otherWord.isNotEmpty &&
              _normalize(otherWord) == _normalize(word);
        }).isNotEmpty;
        if (repeated) {
          points += 50;
        } else {
          points += 100;
          uniqueWords++;
        }
      }
      final defences = resolvedChallenges
          .where((challenge) =>
              challenge.playerId == player.id && challenge.valid == true)
          .length;
      final juryWords = resolvedChallenges
          .where((challenge) =>
              challenge.playerId == player.id &&
              challenge.valid == true &&
              challenge.resolvedByJury)
          .length;
      scores.add(PlayerRoundScore(
        playerId: player.id,
        points: points + (defences * 20),
        uniqueWords: uniqueWords,
        successfulDefences: defences,
        juryApprovedWords: juryWords,
      ));
    }
    return RoundScore(roundNumber: round.number, scores: scores);
  }

  static String _normalize(String value) {
    const accented = 'áéíóúüñ';
    const plain = 'aeiouun';
    var result = value.trim().toLowerCase();
    for (var index = 0; index < accented.length; index++) {
      result = result.replaceAll(accented[index], plain[index]);
    }
    return result.replaceAll(RegExp(r'\s+'), ' ');
  }
}
