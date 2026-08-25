import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../data/network/local_discovery_service.dart';
import '../data/network/socket_service.dart';
import '../data/protocol/game_message.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import '../domain/models/round_data.dart';

class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController({required String nickname})
      : _me = Player(id: const Uuid().v4(), nickname: nickname);

  final Player _me;
  final _socket = SocketService();
  final _discovery = LocalDiscoveryService();
  final _alphabet = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ'.split('');
  StreamSubscription<GameMessage>? _messages;
  Timer? _countdown;
  String? _activeCategory;
  bool _isHost = false;
  GameState? state;

  bool get inputsEnabled =>
      state?.phase == GamePhase.answering ||
      state?.phase == GamePhase.bastaCountdown;

  Future<void> host(GameConfig config) async {
    _isHost = true;
    await _socket.startHost();
    state = GameState(
      roomId: const Uuid().v4().substring(0, 6),
      hostId: _me.id,
      players: [_me.copyWith()],
      config: config,
    );
    _listen();
    await _discovery.advertise(roomId: state!.roomId, port: _socket.port);
    _publishState();
    notifyListeners();
  }

  Future<void> findRooms(void Function(LocalRoom) onRoom) =>
      _discovery.discover(onRoom);

  Future<void> join(LocalRoom room) async {
    await _socket.connect(room.host, room.port);
    _listen();
    _socket.sendToHost(
      GameMessage(event: GameEvent.joinLobby, payload: _me.toJson()),
    );
  }

  void startRound() {
    _assertHost();
    final nextNumber = (state!.currentRound?.number ?? 0) + 1;
    final stopper = state!.players[nextNumber % state!.players.length];
    state = state!.copyWith(
      phase: GamePhase.spinning,
      currentRound: RoundData(
          number: nextNumber, letter: null, stopperPlayerId: stopper.id),
    );
    _broadcast(GameEvent.startLetterSpin, {'stopperPlayerId': stopper.id});
  }

  void stopLetter() {
    _assertHost();
    if (state!.phase != GamePhase.spinning) return;
    final letter = _alphabet[Random.secure().nextInt(_alphabet.length)];
    state = state!.copyWith(
      phase: GamePhase.answering,
      currentRound: state!.currentRound!.copyWith(letter: letter),
    );
    _broadcast(GameEvent.letterStopped, {'letter': letter});
  }

  void triggerBasta() {
    _assertHost();
    if (state!.phase != GamePhase.answering) return;
    _beginBastaCountdown();
    _broadcast(GameEvent.triggerBasta, {'seconds': state!.config.bastaSeconds});
  }

  void setActiveCategory(String? category) => _activeCategory = category;

  void submitAnswers(Map<String, String> answers) {
    if (_isHost) {
      _storeAnswers(_me.id, answers);
    } else {
      _socket.sendToHost(
        GameMessage(
          event: GameEvent.submitAnswers,
          payload: {'playerId': _me.id, 'answers': answers},
        ),
      );
    }
  }

  void _listen() => _messages ??= _socket.messages.listen(_handleMessage);

  void _handleMessage(GameMessage message) {
    if (_isHost) _handleHostMessage(message);
    if (!_isHost) _handleClientMessage(message);
  }

  void _handleHostMessage(GameMessage message) {
    switch (message.event) {
      case GameEvent.joinLobby:
        final player = Player.fromJson(message.payload);
        if (!state!.players.any((p) => p.id == player.id)) {
          state = state!.copyWith(players: [...state!.players, player]);
          _publishState();
        }
      case GameEvent.submitAnswers:
        _storeAnswers(
          message.payload['playerId'] as String,
          Map<String, String>.from(message.payload['answers'] as Map),
        );
      case GameEvent.invalidateCurrentCategory:
        _invalidate(
          message.payload['playerId'] as String,
          message.payload['category'] as String,
        );
      default:
        break;
    }
  }

  void _handleClientMessage(GameMessage message) {
    switch (message.event) {
      case GameEvent.lobbyState:
        state = GameState.fromJson(
          message.payload['state'] as Map<String, dynamic>,
        );
      case GameEvent.startLetterSpin:
        state = state?.copyWith(phase: GamePhase.spinning);
      case GameEvent.letterStopped:
        state = state?.copyWith(
          phase: GamePhase.answering,
          currentRound: state!.currentRound!.copyWith(
            letter: message.payload['letter'] as String,
          ),
        );
      case GameEvent.triggerBasta:
        _beginBastaCountdown(seconds: message.payload['seconds'] as int);
      case GameEvent.freezeInputs:
        _freeze();
      default:
        break;
    }
    notifyListeners();
  }

  void _beginBastaCountdown({int? seconds}) {
    var remaining = seconds ?? state!.config.bastaSeconds;
    state = state!.copyWith(
      phase: GamePhase.bastaCountdown,
      secondsRemaining: remaining,
    );
    notifyListeners();
    _countdown?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      state = state!.copyWith(secondsRemaining: remaining);
      notifyListeners();
      if (remaining <= 0) {
        timer.cancel();
        if (_isHost) {
          _freeze();
          _broadcast(GameEvent.freezeInputs, const {});
        }
      }
    });
  }

  void _freeze() {
    _countdown?.cancel();
    state = state?.copyWith(phase: GamePhase.frozen, secondsRemaining: 0);
    notifyListeners();
  }

  void _storeAnswers(String playerId, Map<String, String> answers) {
    final old = state!.currentRound!;
    state = state!.copyWith(
      currentRound: old.copyWith(
        answersByPlayer: {...old.answersByPlayer, playerId: answers},
      ),
    );
  }

  void _invalidate(String playerId, String category) {
    final old = state!.currentRound!;
    final invalid = Map<String, Set<String>>.from(
      old.invalidCategoriesByPlayer,
    );
    invalid[playerId] = {...?invalid[playerId], category};
    state = state!.copyWith(
      currentRound: old.copyWith(invalidCategoriesByPlayer: invalid),
    );
  }

  void _publishState() =>
      _broadcast(GameEvent.lobbyState, {'state': state!.toJson()});
  void _broadcast(GameEvent event, Map<String, dynamic> payload) {
    _socket.broadcast(GameMessage(event: event, payload: payload));
    notifyListeners();
  }

  void _assertHost() {
    if (!_isHost) throw StateError('Sólo el Host puede cambiar el juego.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        inputsEnabled &&
        _activeCategory != null) {
      final message = GameMessage(
        event: GameEvent.invalidateCurrentCategory,
        payload: {'playerId': _me.id, 'category': _activeCategory},
      );
      if (_isHost) {
        _invalidate(_me.id, _activeCategory!);
      } else {
        _socket.sendToHost(message);
      }
      _activeCategory = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    _messages?.cancel();
    _socket.dispose();
    _discovery.dispose();
    super.dispose();
  }
}
