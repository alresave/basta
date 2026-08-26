class RoundData {
  const RoundData({
    required this.number,
    required this.letter,
    required this.stopperPlayerId,
    this.answersByPlayer = const {},
    this.invalidCategoriesByPlayer = const {},
    this.validCategoriesByPlayer = const {},
  });

  final int number;
  final String? letter;
  final String stopperPlayerId;
  final Map<String, Map<String, String>> answersByPlayer;
  final Map<String, Set<String>> invalidCategoriesByPlayer;

  /// Casillas confirmadas por el Tribunal; cada una vale 100 puntos.
  final Map<String, Set<String>> validCategoriesByPlayer;

  RoundData copyWith({
    String? letter,
    Map<String, Map<String, String>>? answersByPlayer,
    Map<String, Set<String>>? invalidCategoriesByPlayer,
    Map<String, Set<String>>? validCategoriesByPlayer,
  }) =>
      RoundData(
        number: number,
        letter: letter ?? this.letter,
        stopperPlayerId: stopperPlayerId,
        answersByPlayer: answersByPlayer ?? this.answersByPlayer,
        invalidCategoriesByPlayer:
            invalidCategoriesByPlayer ?? this.invalidCategoriesByPlayer,
        validCategoriesByPlayer:
            validCategoriesByPlayer ?? this.validCategoriesByPlayer,
      );

  Map<String, dynamic> toJson() => {
        'number': number,
        'letter': letter,
        'stopperPlayerId': stopperPlayerId,
        'answersByPlayer': answersByPlayer,
        'invalidCategoriesByPlayer': invalidCategoriesByPlayer.map(
          (playerId, categories) => MapEntry(playerId, categories.toList()),
        ),
        'validCategoriesByPlayer': validCategoriesByPlayer.map(
          (playerId, categories) => MapEntry(playerId, categories.toList()),
        ),
      };

  factory RoundData.fromJson(Map<String, dynamic> json) => RoundData(
        number: json['number'] as int,
        letter: json['letter'] as String?,
        stopperPlayerId: json['stopperPlayerId'] as String,
        answersByPlayer: (json['answersByPlayer'] as Map? ?? {}).map(
          (key, value) => MapEntry(
            key as String,
            (value as Map).map(
              (category, answer) =>
                  MapEntry(category as String, answer as String),
            ),
          ),
        ),
        invalidCategoriesByPlayer:
            (json['invalidCategoriesByPlayer'] as Map? ?? {}).map(
          (key, value) =>
              MapEntry(key as String, Set<String>.from(value as List)),
        ),
        validCategoriesByPlayer:
            (json['validCategoriesByPlayer'] as Map? ?? {}).map(
          (key, value) =>
              MapEntry(key as String, Set<String>.from(value as List)),
        ),
      );
}
