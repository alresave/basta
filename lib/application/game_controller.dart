import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import '../data/network/local_discovery_service.dart';
import '../data/protocol/game_message.dart';
import '../data/network/socket_service.dart';
import '../data/remote/remote_game_transport.dart';
import '../data/remote/remote_room_service.dart';
import '../data/storage/game_registry_storage.dart';
import '../data/validation/word_validation_service.dart';
import '../domain/models/game_state.dart';
import '../domain/models/player.dart';
import '../domain/models/round_data.dart';
import '../domain/models/word_challenge.dart';
import 'score_calculator_service.dart';
import 'feedback_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameController extends ChangeNotifier with WidgetsBindingObserver {
  GameController(
      {required String nickname, WordValidationService? wordValidationService})
      : _me = Player(id: const Uuid().v4(), nickname: nickname),
        _wordValidationService =
            wordValidationService ?? WordValidationService();

  final Player _me;
  final _socket = SocketService();
  RemoteGameTransport? _remoteTransport;
  final _discovery = LocalDiscoveryService();
  final _alphabet = 'ABCDEFGHIJKLMNÑOPQRSTUVWXYZ'.split('');
  final WordValidationService _wordValidationService;
  final _feedback = const FeedbackService();
  final _scoreCalculator = const ScoreCalculatorService();
  final _registryStorage = GameRegistryStorage();
  StreamSubscription<GameMessage>? _messages;
  StreamSubscription<SocketConnectionState>? _connection;
  Timer? _countdown;
  Timer? _juryTimer;
  String? _activeCategory;
  bool _isHost = false;
  GameState? state;
  WordChallenge? activeChallenge;
  final Map<String, bool> _juryVotes = {};
  final List<WordChallenge> _roundChallenges = [];
  bool _finishingReview = false;
  String? _hostAddress;
  int? _hostPort;
  String? networkAlert;

  bool get inputsEnabled =>
      state?.phase == GamePhase.answering ||
      state?.phase == GamePhase.bastaCountdown;
  String get playerId => _me.id;
  bool get isHost => _isHost;
  int? get localHostPort => _isHost ? _socket.port : null;

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
    _listenConnection();
    await _discovery.advertise(roomId: state!.roomId, port: _socket.port);
    _publishState();
    notifyListeners();
  }

  Future<void> findRooms(void Function(LocalRoom) onRoom) =>
      _discovery.discover(onRoom);

  Future<void> join(LocalRoom room) async {
    await joinAddress(room.host, room.port);
  }

  /// Respaldo para redes donde mDNS no atraviesa el emulador o el router.
  Future<void> joinAddress(String host, int port) async {
    final address = host.trim();
    if (address.isEmpty || port < 1 || port > 65535) {
      throw ArgumentError('Dirección o puerto inválidos.');
    }
    await _socket.connect(address, port);
    _hostAddress = address;
    _hostPort = port;
    _listen();
    _listenConnection();
    _sendToHost(
      GameMessage(event: GameEvent.joinLobby, payload: _me.toJson()),
    );
  }

  Future<String> hostRemote(GameConfig config) async {
    _isHost = true;
    final room = await RemoteRoomService(Supabase.instance.client).createRoom();
    _remoteTransport = RemoteGameTransport(
      client: Supabase.instance.client,
      roomId: room.id,
      isHost: true,
    );
    await _remoteTransport!.start();
    state = GameState(
      roomId: room.code,
      hostId: _me.id,
      players: [_me.copyWith()],
      config: config,
    );
    _listen();
    _publishState();
    notifyListeners();
    return room.code;
  }

  Future<void> joinRemote(String code) async {
    final room =
        await RemoteRoomService(Supabase.instance.client).joinRoom(code);
    _remoteTransport = RemoteGameTransport(
      client: Supabase.instance.client,
      roomId: room.id,
      isHost: false,
    );
    await _remoteTransport!.start();
    _listen();
    _sendToHost(GameMessage(event: GameEvent.joinLobby, payload: _me.toJson()));
  }

  void startRound() {
    _assertHost();
    if (state!.registry.rounds.length >= state!.config.totalRounds ||
        state!.registry.playedLetters.length >= _alphabet.length) {
      _finishGame();
      return;
    }
    final nextNumber = (state!.currentRound?.number ?? 0) + 1;
    final stopper = state!.players[(nextNumber - 1) % state!.players.length];
    _roundChallenges.clear();
    _feedback.roundBell();
    _feedback.wheelStarted();
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
    if (!_isHost) {
      _sendToHost(GameMessage(
        event: GameEvent.stopLetter,
        payload: {'playerId': _me.id},
      ));
      return;
    }
    _stopLetterAsHost();
  }

  void _stopLetterAsHost() {
    if (state!.phase != GamePhase.spinning) return;
    final available = _alphabet
        .where((letter) => !state!.registry.playedLetters.contains(letter))
        .toList();
    if (available.isEmpty) {
      _finishGame();
      return;
    }
    final letter = available[Random.secure().nextInt(available.length)];
    _feedback.wheelStopped();
    state = state!.copyWith(
      phase: GamePhase.answering,
      currentRound: state!.currentRound!.copyWith(letter: letter),
      registry: state!.registry.copyWith(
        playedLetters: [...state!.registry.playedLetters, letter],
      ),
    );
    _broadcast(GameEvent.letterStopped, {'letter': letter});
  }

  void triggerBasta() {
    _feedback.bastaPressed();
    if (!_isHost) {
      _sendToHost(
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

  void addCategory(String category) {
    _assertHost();
    final value = category.trim();
    if (value.isEmpty ||
        state!.phase != GamePhase.lobby ||
        state!.config.categories
            .any((item) => item.toLowerCase() == value.toLowerCase())) {
      return;
    }
    state = state!.copyWith(
      config: state!.config.copyWith(
        categories: [...state!.config.categories, value],
      ),
    );
    _publishState();
  }

  void removeCategory(String category) {
    _assertHost();
    if (state!.phase != GamePhase.lobby ||
        state!.config.categories.length <= 1) {
      return;
    }
    state = state!.copyWith(
      config: state!.config.copyWith(
        categories:
            state!.config.categories.where((item) => item != category).toList(),
      ),
    );
    _publishState();
  }

  void submitAnswers(Map<String, String> answers) {
    if (_isHost) {
      _storeAnswers(_me.id, answers);
    } else {
      _sendToHost(
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
      payload: {
        'actorId': _me.id,
        'playerId': playerId,
        'category': category,
        'word': word,
      },
    );
    if (_isHost) {
      _handleHostMessage(message);
    } else {
      _sendToHost(message);
    }
  }

  void _listen() => _messages ??=
      (_remoteTransport?.messages ?? _socket.messages).listen(_handleMessage);

  void _sendToHost(GameMessage message) {
    if (_remoteTransport != null) {
      _remoteTransport!.sendToHost(message);
    } else {
      _socket.sendToHost(message);
    }
  }

  void _listenConnection() =>
      _connection ??= _socket.connection.listen((connection) {
        switch (connection) {
          case SocketConnectionState.connected:
            networkAlert = null;
          case SocketConnectionState.reconnecting:
            networkAlert = 'Reconectando a la sala…';
          case SocketConnectionState.disconnected:
            networkAlert = _isHost
                ? 'Se perdió la conexión Wi‑Fi con los jugadores.'
                : 'Se perdió la conexión con el Host.';
        }
        notifyListeners();
      });

  Future<void> reconnect() async {
    if (_isHost || _hostAddress == null || _hostPort == null) return;
    try {
      await _socket.reconnect(_hostAddress!, _hostPort!);
      _sendToHost(
          GameMessage(event: GameEvent.joinLobby, payload: _me.toJson()));
    } catch (_) {
      networkAlert = 'No fue posible reconectar. Revisa la misma red Wi‑Fi.';
      notifyListeners();
    }
  }

  void _handleMessage(GameMessage message) {
    if (_isHost) _handleHostMessage(message);
    if (!_isHost) _handleClientMessage(message);
  }

  void _handleHostMessage(GameMessage message) {
    if (state == null) return;
    switch (message.event) {
      case GameEvent.joinLobby:
        final player = _playerFromPayload(message.payload);
        if (player == null) return;
        if (!state!.players.any((p) => p.id == player.id)) {
          state = state!.copyWith(players: [...state!.players, player]);
          _publishState();
        } else {
          // A returning client receives the authoritative snapshot immediately.
          _socket.sendToPlayer(
            player.id,
            GameMessage(
              event: GameEvent.lobbyState,
              payload: {'state': state!.toJson()},
            ),
          );
        }
      case GameEvent.submitAnswers:
        if (!_isKnownPlayer(message.payload['playerId']) ||
            !inputsEnabled ||
            message.payload['answers'] is! Map) {
          return;
        }
        _storeAnswers(
          message.payload['playerId'] as String,
          Map<String, String>.from(message.payload['answers'] as Map),
        );
      case GameEvent.triggerBasta:
        if (!_isKnownPlayer(message.payload['playerId']) ||
            state!.phase != GamePhase.answering) {
          return;
        }
        _startBastaAsHost();
      case GameEvent.stopLetter:
        if (_isKnownPlayer(message.payload['playerId']) &&
            message.payload['playerId'] ==
                state!.currentRound?.stopperPlayerId) {
          _stopLetterAsHost();
        }
      case GameEvent.invalidateCurrentCategory:
        if (!_isKnownPlayer(message.payload['playerId']) ||
            message.payload['category'] is! String ||
            !state!.config.categories.contains(message.payload['category'])) {
          return;
        }
        _invalidate(
          message.payload['playerId'] as String,
          message.payload['category'] as String,
        );
      case GameEvent.challengeWord:
        if (!_isKnownPlayer(message.payload['actorId']) ||
            !_isKnownPlayer(message.payload['playerId']) ||
            message.payload['category'] is! String ||
            message.payload['word'] is! String) {
          return;
        }
        _startChallenge(
          playerId: message.payload['playerId'] as String,
          category: message.payload['category'] as String,
          word: message.payload['word'] as String,
        );
      case GameEvent.juryVote:
        if (!_isKnownPlayer(message.payload['playerId']) ||
            message.payload['challengeId'] is! String ||
            message.payload['valid'] is! bool) {
          return;
        }
        _recordJuryVote(
          message.payload['challengeId'] as String,
          message.payload['playerId'] as String,
          message.payload['valid'] as bool,
        );
      default:
        break;
    }
  }

  Player? _playerFromPayload(Map<String, dynamic> payload) {
    try {
      final player = Player.fromJson(payload);
      return player.id.trim().isEmpty || player.nickname.trim().isEmpty
          ? null
          : player;
    } on TypeError {
      return null;
    } on FormatException {
      return null;
    }
  }

  bool _isKnownPlayer(Object? id) =>
      id is String && state!.players.any((player) => player.id == id);

  void _handleClientMessage(GameMessage message) {
    switch (message.event) {
      case GameEvent.lobbyState:
        state = GameState.fromJson(
          message.payload['state'] as Map<String, dynamic>,
        );
      case GameEvent.startLetterSpin:
        state = state?.copyWith(phase: GamePhase.spinning);
        _feedback.roundBell();
        _feedback.wheelStarted();
      case GameEvent.letterStopped:
        state = state?.copyWith(
          phase: GamePhase.answering,
          currentRound: state!.currentRound!.copyWith(
            letter: message.payload['letter'] as String,
          ),
        );
        _feedback.wheelStopped();
      case GameEvent.triggerBasta:
        _beginBastaCountdown(seconds: message.payload['seconds'] as int);
      case GameEvent.freezeInputs:
        _freeze();
      case GameEvent.challengeChecking:
        _feedback.judgeGavel();
      case GameEvent.juryVoteStarted:
      case GameEvent.challengeResolved:
        activeChallenge = WordChallenge.fromJson(
            message.payload['challenge'] as Map<String, dynamic>);
        if (message.event == GameEvent.challengeResolved) {
          _feedback.verdict(valid: activeChallenge!.valid == true);
          if (activeChallenge!.valid == true) _feedback.victoryFanfare();
        }
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
    if (_roundChallenges.any(
        (item) => item.playerId == playerId && item.category == category)) {
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
    _feedback.judgeGavel();
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
      _sendToHost(message);
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
      resolvedByJury: true,
    ));
  }

  void _resolveChallenge(WordChallenge challenge) {
    activeChallenge = challenge;
    _feedback.verdict(valid: challenge.valid == true);
    if (challenge.valid == true) _feedback.victoryFanfare();
    _roundChallenges.removeWhere((item) => item.id == challenge.id);
    _roundChallenges.add(challenge);
    if (challenge.valid == false) {
      _invalidate(challenge.playerId, challenge.category);
    } else {
      _validate(challenge.playerId, challenge.category);
    }
    _publishState();
    _broadcast(GameEvent.challengeResolved, {'challenge': challenge.toJson()});
  }

  Future<void> finishReview() async {
    _assertHost();
    final round = state!.currentRound;
    if (_finishingReview || round == null || state!.phase != GamePhase.frozen) {
      return;
    }
    _finishingReview = true;
    final roundScore = _scoreCalculator.calculate(
      round: round,
      state: state!,
      resolvedChallenges: _roundChallenges,
    );
    state = state!.copyWith(
      registry: state!.registry.copyWith(
        rounds: [...state!.registry.rounds, roundScore],
      ),
    );
    try {
      await _registryStorage.save(state!.roomId, state!.registry);
      if (state!.registry.rounds.length >= state!.config.totalRounds ||
          state!.registry.playedLetters.length >= _alphabet.length) {
        _finishGame();
      } else {
        startRound();
      }
    } finally {
      _finishingReview = false;
    }
  }

  void _finishGame() {
    state = state!.copyWith(phase: GamePhase.finished, secondsRemaining: 0);
    _feedback.victoryFanfare();
    _publishState();
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
    _feedback.countdownTick();
    _countdown?.cancel();
    _juryTimer?.cancel();
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      remaining--;
      state = state!.copyWith(secondsRemaining: remaining);
      if (remaining > 0) _feedback.countdownTick();
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
    if (state!.currentRound == null) return;
    final permitted = state!.config.categories.toSet();
    answers.removeWhere((category, _) => !permitted.contains(category));
    final old = state!.currentRound!;
    state = state!.copyWith(
      currentRound: old.copyWith(
        answersByPlayer: {...old.answersByPlayer, playerId: answers},
      ),
    );
    _publishState();
  }

  void _invalidate(String playerId, String category) {
    if (state!.currentRound == null) return;
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
    final message = GameMessage(event: event, payload: payload);
    if (_remoteTransport != null) {
      _remoteTransport!.broadcast(message);
    } else {
      _socket.broadcast(message);
    }
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
        _sendToHost(message);
      }
      _activeCategory = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdown?.cancel();
    _messages?.cancel();
    _connection?.cancel();
    _remoteTransport?.dispose();
    _socket.dispose();
    _discovery.dispose();
    super.dispose();
  }
}
