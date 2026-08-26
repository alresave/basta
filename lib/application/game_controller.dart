import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../data/network/local_discovery_service.dart';
import '../data/network/socket_service.dart';
import '../data/protocol/game_message.dart';
import '../data/validation/word_validation_service.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import '../domain/models/round_data.dart';
import '../domain/models/word_challenge.dart';

class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController(
      {required String nickname, WordValidationService? wordValidationService})
      : _me = Player(id: const Uuid().v4(), nickname: nickname),
        _wordValidationService =
            wordValidationService ?? WordValidationService();

  final Player _me;
  final _socket = SocketService();
  final _discovery = LocalDiscoveryService();
  final _alphabet = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ'.split('');
  final WordValidationService _wordValidationService;
  StreamSubscription<GameMessage>? _messages;
  Timer? _countdown;
  Timer? _juryTimer;
  String? _activeCategory;
  bool _isHost = false;
  GameState? state;
  WordChallenge? activeChallenge;
  final Map<String, bool> _juryVotes = {};

  bool get inputsEnabled =>
      state?.phase == GamePhase.answering ||
      state?.phase == GamePhase.bastaCountdown;
  String get playerId => _me.id;

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
    // Los clientes necesitan el RoundData antes de recibir la letra.
    _publishState();
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
    if (!_isHost) {
      _socket.sendToHost(
        GameMessage(
            event: GameEvent.triggerBasta, payload: {'playerId': _me.id}),
      );
      return;
    }
    _startBastaAsHost();
  }

  void _startBastaAsHost() {
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

  /// La validación y resolución final de la impugnación pertenece al Host.
  void challengeWord({
    required String playerId,
    required String category,
    required String word,
  }) {
    final message = GameMessage(
      event: GameEvent.challengeWord,
      payload: {'playerId': playerId, 'category': category, 'word': word},
    );
    if (_isHost) {
      _handleHostMessage(message);
    } else {
      _socket.sendToHost(message);
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
      case GameEvent.triggerBasta:
        _startBastaAsHost();
      case GameEvent.invalidateCurrentCategory:
        _invalidate(
          message.payload['playerId'] as String,
          message.payload['category'] as String,
        );
      case GameEvent.challengeWord:
        _startChallenge(
          playerId: message.payload['playerId'] as String,
          category: message.payload['category'] as String,
          word: message.payload['word'] as String,
        );
      case GameEvent.juryVote:
        _recordJuryVote(
          message.payload['challengeId'] as String,
          message.payload['playerId'] as String,
          message.payload['valid'] as bool,
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
      case GameEvent.challengeChecking:
      case GameEvent.juryVoteStarted:
      case GameEvent.challengeResolved:
        activeChallenge = WordChallenge.fromJson(
            message.payload['challenge'] as Map<String, dynamic>);
      default:
        break;
    }
    notifyListeners();
  }

  Future<void> _startChallenge({
    required String playerId,
    required String category,
    required String word,
  }) async {
    if (activeChallenge != null &&
        activeChallenge!.status != ChallengeStatus.resolved) {
      return;
    }
    final challenge = WordChallenge(
      id: const Uuid().v4(),
      playerId: playerId,
      category: category,
      word: word,
      status: ChallengeStatus.checking,
    );
    activeChallenge = challenge;
    _broadcast(GameEvent.challengeChecking, {'challenge': challenge.toJson()});

    final result = await _wordValidationService.validate(word);
    if (activeChallenge?.id != challenge.id) return;
    if (result.exists) {
      _resolveChallenge(challenge.copyWith(
        status: ChallengeStatus.resolved,
        valid: true,
        definition: result.definition,
      ));
      return;
    }
    final juryChallenge = challenge.copyWith(
      status: ChallengeStatus.juryVoting,
      deadlineEpochMs: DateTime.now().millisecondsSinceEpoch + 5000,
    );
    activeChallenge = juryChallenge;
    _juryVotes.clear();
    _broadcast(
        GameEvent.juryVoteStarted, {'challenge': juryChallenge.toJson()});
    _juryTimer?.cancel();
    _juryTimer =
        Timer(const Duration(seconds: 5), () => _closeJury(juryChallenge));
  }

  void voteOnChallenge(bool valid) {
    final challenge = activeChallenge;
    if (challenge == null || challenge.status != ChallengeStatus.juryVoting) {
      return;
    }
    final message = GameMessage(
      event: GameEvent.juryVote,
      payload: {
        'challengeId': challenge.id,
        'playerId': _me.id,
        'valid': valid
      },
    );
    if (_isHost) {
      _recordJuryVote(challenge.id, _me.id, valid);
    } else {
      _socket.sendToHost(message);
    }
  }

  void dismissChallenge() {
    activeChallenge = null;
    notifyListeners();
  }

  void _recordJuryVote(String challengeId, String playerId, bool valid) {
    if (activeChallenge?.id != challengeId ||
        activeChallenge?.status != ChallengeStatus.juryVoting) {
      return;
    }
    // Un voto por jugador; el último mensaje no puede alterar el primero.
    _juryVotes.putIfAbsent(playerId, () => valid);
  }

  void _closeJury(WordChallenge challenge) {
    if (activeChallenge?.id != challenge.id) return;
    final validVotes = _juryVotes.values.where((vote) => vote).length;
    final invalidVotes = _juryVotes.length - validVotes;
    // Un empate (incluido cero votos) no confirma la palabra.
    _resolveChallenge(challenge.copyWith(
      status: ChallengeStatus.resolved,
      valid: validVotes > invalidVotes,
    ));
  }

  void _resolveChallenge(WordChallenge challenge) {
    activeChallenge = challenge;
    if (challenge.valid == false) {
      _invalidate(challenge.playerId, challenge.category);
    } else {
      _validate(challenge.playerId, challenge.category);
    }
    _publishState();
    _broadcast(GameEvent.challengeResolved, {'challenge': challenge.toJson()});
  }

  void _validate(String playerId, String category) {
    final old = state!.currentRound!;
    final valid = Map<String, Set<String>>.from(old.validCategoriesByPlayer);
    valid[playerId] = {...?valid[playerId], category};
    state = state!.copyWith(
      currentRound: old.copyWith(validCategoriesByPlayer: valid),
    );
  }

  void _beginBastaCountdown({int? seconds}) {
    var remaining = seconds ?? state!.config.bastaSeconds;
    state = state!.copyWith(
      phase: GamePhase.bastaCountdown,
      secondsRemaining: remaining,
    );
    notifyListeners();
    _countdown?.cancel();
    _juryTimer?.cancel();
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
    _publishState();
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
