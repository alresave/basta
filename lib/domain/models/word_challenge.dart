enum ChallengeStatus { checking, juryVoting, resolved }

class WordChallenge {
  const WordChallenge({
    required this.id,
    required this.playerId,
    required this.category,
    required this.word,
    required this.status,
    this.definition,
    this.valid,
    this.deadlineEpochMs,
  });

  final String id;
  final String playerId;
  final String category;
  final String word;
  final ChallengeStatus status;
  final String? definition;
  final bool? valid;
  final int? deadlineEpochMs;

  WordChallenge copyWith({
    ChallengeStatus? status,
    String? definition,
    bool? valid,
    int? deadlineEpochMs,
  }) =>
      WordChallenge(
        id: id,
        playerId: playerId,
        category: category,
        word: word,
        status: status ?? this.status,
        definition: definition ?? this.definition,
        valid: valid ?? this.valid,
        deadlineEpochMs: deadlineEpochMs ?? this.deadlineEpochMs,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'playerId': playerId,
        'category': category,
        'word': word,
        'status': status.name,
        'definition': definition,
        'valid': valid,
        'deadlineEpochMs': deadlineEpochMs,
      };

  factory WordChallenge.fromJson(Map<String, dynamic> json) => WordChallenge(
        id: json['id'] as String,
        playerId: json['playerId'] as String,
        category: json['category'] as String,
        word: json['word'] as String,
        status: ChallengeStatus.values.byName(json['status'] as String),
        definition: json['definition'] as String?,
        valid: json['valid'] as bool?,
        deadlineEpochMs: json['deadlineEpochMs'] as int?,
      );
}
