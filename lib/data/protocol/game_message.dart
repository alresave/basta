import 'dart:convert';

enum GameEvent {
  joinLobby,
  lobbyState,
  startLetterSpin,
  letterStopped,
  triggerBasta,
  freezeInputs,
  submitAnswers,
  invalidateCurrentCategory,
  challengeWord,
  error,
}

extension GameEventWireFormat on GameEvent {
  String get wireName => switch (this) {
        GameEvent.joinLobby => 'JOIN_LOBBY',
        GameEvent.lobbyState => 'LOBBY_STATE',
        GameEvent.startLetterSpin => 'START_LETTER_SPIN',
        GameEvent.letterStopped => 'LETTER_STOPPED',
        GameEvent.triggerBasta => 'TRIGGER_BASTA',
        GameEvent.freezeInputs => 'FREEZE_INPUTS',
        GameEvent.submitAnswers => 'SUBMIT_ANSWERS',
        GameEvent.invalidateCurrentCategory => 'INVALIDATE_CURRENT_CATEGORY',
        GameEvent.challengeWord => 'CHALLENGE_WORD',
        GameEvent.error => 'ERROR',
      };

  static GameEvent fromWireName(String value) => GameEvent.values.firstWhere(
        (event) => event.wireName == value,
        orElse: () => throw FormatException('Evento desconocido: $value'),
      );
}

class GameMessage {
  const GameMessage({required this.event, this.payload = const {}});

  final GameEvent event;
  final Map<String, dynamic> payload;

  String encode() => jsonEncode({'event': event.wireName, 'payload': payload});

  factory GameMessage.decode(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return GameMessage(
      event: GameEventWireFormat.fromWireName(json['event'] as String),
      payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    );
  }
}
