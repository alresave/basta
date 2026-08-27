import 'player.dart';
import 'round_data.dart';
import 'game_registry.dart';

enum GamePhase { lobby, spinning, answering, bastaCountdown, frozen, finished }

class GameConfig {
  const GameConfig({
    required this.categories,
    required this.totalRounds,
    this.bastaSeconds = 10,
  });

  final List<String> categories;
  final int totalRounds;
  final int bastaSeconds;

  GameConfig copyWith({List<String>? categories, int? totalRounds}) =>
      GameConfig(
        categories: categories ?? this.categories,
        totalRounds: totalRounds ?? this.totalRounds,
        bastaSeconds: bastaSeconds,
      );

  Map<String, dynamic> toJson() => {
        'categories': categories,
        'totalRounds': totalRounds,
        'bastaSeconds': bastaSeconds,
      };

  factory GameConfig.fromJson(Map<String, dynamic> json) => GameConfig(
        categories: List<String>.from(json['categories'] as List),
        totalRounds: json['totalRounds'] as int,
        bastaSeconds: json['bastaSeconds'] as int? ?? 10,
      );
}

class GameState {
  const GameState({
    required this.roomId,
    required this.hostId,
    required this.players,
    required this.config,
    this.phase = GamePhase.lobby,
    this.currentRound,
    this.secondsRemaining = 0,
    this.registry = const GameRegistry(),
  });

  final String roomId;
  final String hostId;
  final List<Player> players;
  final GameConfig config;
  final GamePhase phase;
  final RoundData? currentRound;
  final int secondsRemaining;
  final GameRegistry registry;

  GameState copyWith({
    List<Player>? players,
    GameConfig? config,
    GamePhase? phase,
    RoundData? currentRound,
    int? secondsRemaining,
    GameRegistry? registry,
  }) =>
      GameState(
        roomId: roomId,
        hostId: hostId,
        players: players ?? this.players,
        config: config ?? this.config,
        phase: phase ?? this.phase,
        currentRound: currentRound ?? this.currentRound,
        secondsRemaining: secondsRemaining ?? this.secondsRemaining,
        registry: registry ?? this.registry,
      );

  Map<String, dynamic> toJson() => {
        'roomId': roomId,
        'hostId': hostId,
        'players': players.map((p) => p.toJson()).toList(),
        'config': config.toJson(),
        'phase': phase.name,
        'currentRound': currentRound?.toJson(),
        'secondsRemaining': secondsRemaining,
        'registry': registry.toJson(),
      };

  factory GameState.fromJson(Map<String, dynamic> json) => GameState(
        roomId: json['roomId'] as String,
        hostId: json['hostId'] as String,
        players: (json['players'] as List)
            .map((item) => Player.fromJson(item as Map<String, dynamic>))
            .toList(),
        config: GameConfig.fromJson(json['config'] as Map<String, dynamic>),
        phase: GamePhase.values.byName(json['phase'] as String),
        currentRound: json['currentRound'] == null
            ? null
            : RoundData.fromJson(json['currentRound'] as Map<String, dynamic>),
        secondsRemaining: json['secondsRemaining'] as int? ?? 0,
        registry: json['registry'] == null
            ? const GameRegistry()
            : GameRegistry.fromJson(
                Map<String, dynamic>.from(json['registry'] as Map)),
      );
}
