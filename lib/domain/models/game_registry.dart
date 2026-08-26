class PlayerRoundScore {
  const PlayerRoundScore({
    required this.playerId,
    required this.points,
    this.uniqueWords = 0,
    this.successfulDefences = 0,
    this.juryApprovedWords = 0,
  });

  final String playerId;
  final int points;
  final int uniqueWords;
  final int successfulDefences;
  final int juryApprovedWords;

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'points': points,
        'uniqueWords': uniqueWords,
        'successfulDefences': successfulDefences,
        'juryApprovedWords': juryApprovedWords,
      };

  factory PlayerRoundScore.fromJson(Map<String, dynamic> json) =>
      PlayerRoundScore(
        playerId: json['playerId'] as String,
        points: json['points'] as int,
        uniqueWords: json['uniqueWords'] as int? ?? 0,
        successfulDefences: json['successfulDefences'] as int? ?? 0,
        juryApprovedWords: json['juryApprovedWords'] as int? ?? 0,
      );
}

class RoundScore {
  const RoundScore({required this.roundNumber, required this.scores});

  final int roundNumber;
  final List<PlayerRoundScore> scores;

  Map<String, dynamic> toJson() => {
        'roundNumber': roundNumber,
        'scores': scores.map((score) => score.toJson()).toList(),
      };

  factory RoundScore.fromJson(Map<String, dynamic> json) => RoundScore(
        roundNumber: json['roundNumber'] as int,
        scores: (json['scores'] as List)
            .map((item) => PlayerRoundScore.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(),
      );
}

/// Historial autoritativo de una partida: puntajes y letras no repetibles.
class GameRegistry {
  const GameRegistry({this.rounds = const [], this.playedLetters = const []});

  final List<RoundScore> rounds;
  final List<String> playedLetters;

  GameRegistry copyWith(
          {List<RoundScore>? rounds, List<String>? playedLetters}) =>
      GameRegistry(
        rounds: rounds ?? this.rounds,
        playedLetters: playedLetters ?? this.playedLetters,
      );

  int totalFor(String playerId) => rounds
      .expand((round) => round.scores)
      .where((score) => score.playerId == playerId)
      .fold(0, (total, score) => total + score.points);

  int uniqueFor(String playerId) => rounds
      .expand((round) => round.scores)
      .where((score) => score.playerId == playerId)
      .fold(0, (total, score) => total + score.uniqueWords);

  int defencesFor(String playerId) => rounds
      .expand((round) => round.scores)
      .where((score) => score.playerId == playerId)
      .fold(0, (total, score) => total + score.successfulDefences);

  int juryApprovedFor(String playerId) => rounds
      .expand((round) => round.scores)
      .where((score) => score.playerId == playerId)
      .fold(0, (total, score) => total + score.juryApprovedWords);

  Map<String, dynamic> toJson() => {
        'rounds': rounds.map((round) => round.toJson()).toList(),
        'playedLetters': playedLetters,
      };

  factory GameRegistry.fromJson(Map<String, dynamic> json) => GameRegistry(
        rounds: (json['rounds'] as List? ?? const [])
            .map((item) =>
                RoundScore.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        playedLetters:
            List<String>.from(json['playedLetters'] as List? ?? const []),
      );
}
