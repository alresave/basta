import 'package:flutter_test/flutter_test.dart';

import 'package:basta_local/data/protocol/game_message.dart';
import 'package:basta_local/domain/models/game_registry.dart';
import 'package:basta_local/domain/models/game_state.dart';
import 'package:basta_local/domain/models/player.dart';
import 'package:basta_local/domain/models/round_data.dart';

void main() {
  const host = Player(id: 'host', nickname: 'Anita', isHost: true);
  const guest = Player(id: 'guest', nickname: 'Beto');

  test('el protocolo conserva evento y carga útil al viajar por la red', () {
    const original = GameMessage(
      event: GameEvent.submitAnswers,
      payload: {
        'playerId': 'guest',
        'answers': {'Nombre': 'Nora'},
      },
    );

    final decoded = GameMessage.decode(original.encode());

    expect(decoded.event, GameEvent.submitAnswers);
    expect(decoded.payload['playerId'], 'guest');
    expect(decoded.payload['answers'], {'Nombre': 'Nora'});
  });

  test('un cliente restaura el estado autoritativo antes de recibir la letra',
      () {
    const spinningState = GameState(
      roomId: 'ABC123',
      hostId: 'host',
      players: [host, guest],
      config: GameConfig(categories: ['Nombre', 'Animal'], totalRounds: 3),
      phase: GamePhase.spinning,
      currentRound: RoundData(
        number: 1,
        letter: null,
        stopperPlayerId: 'guest',
      ),
    );
    final message = GameMessage(
      event: GameEvent.lobbyState,
      payload: {'state': spinningState.toJson()},
    );

    final restored = GameState.fromJson(
      message.payload['state'] as Map<String, dynamic>,
    );
    final answering = restored.copyWith(
      phase: GamePhase.answering,
      currentRound: restored.currentRound!.copyWith(letter: 'Ñ'),
    );

    expect(restored.phase, GamePhase.spinning);
    expect(restored.currentRound!.letter, isNull);
    expect(restored.currentRound!.stopperPlayerId, 'guest');
    expect(answering.currentRound!.letter, 'Ñ');
  });

  test('la sincronización conserva respuestas, impugnaciones y letras usadas',
      () {
    const state = GameState(
      roomId: 'ABC123',
      hostId: 'host',
      players: [host, guest],
      config: GameConfig(categories: ['Nombre'], totalRounds: 3),
      phase: GamePhase.frozen,
      currentRound: RoundData(
        number: 1,
        letter: 'N',
        stopperPlayerId: 'host',
        answersByPlayer: {
          'host': {'Nombre': 'Nora'},
          'guest': {'Nombre': 'Nora'},
        },
        invalidCategoriesByPlayer: {
          'guest': {'Nombre'},
        },
        validCategoriesByPlayer: {
          'host': {'Nombre'},
        },
      ),
      registry: GameRegistry(playedLetters: ['N']),
    );

    final restored = GameState.fromJson(state.toJson());

    expect(restored.currentRound!.answersByPlayer['guest']!['Nombre'], 'Nora');
    expect(restored.currentRound!.invalidCategoriesByPlayer['guest'], {'Nombre'});
    expect(restored.currentRound!.validCategoriesByPlayer['host'], {'Nombre'});
    expect(restored.registry.playedLetters, ['N']);
  });
}
