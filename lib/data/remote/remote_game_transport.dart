import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../protocol/game_message.dart';

enum RemoteConnectionState { connected, reconnecting, disconnected }

class RemotePresence {
  const RemotePresence({required this.playerId, required this.nickname});

  final String playerId;
  final String nickname;
}

/// Transporte Realtime para una sala remota. Sólo el Host recibe solicitudes
/// dirigidas a él; los cambios autoritativos llegan a todos los jugadores.
class RemoteGameTransport {
  RemoteGameTransport({
    required SupabaseClient client,
    required this.roomId,
    required this.isHost,
    required this.playerId,
    required this.nickname,
  }) : _client = client;

  final SupabaseClient _client;
  final String roomId;
  final bool isHost;
  final String playerId;
  final String nickname;
  final _messages = StreamController<GameMessage>.broadcast();
  final _connection = StreamController<RemoteConnectionState>.broadcast();
  final _presence = StreamController<List<RemotePresence>>.broadcast();
  RealtimeChannel? _channel;
  bool _started = false;

  Stream<GameMessage> get messages => _messages.stream;
  Stream<RemoteConnectionState> get connection => _connection.stream;
  Stream<List<RemotePresence>> get presence => _presence.stream;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final channel = _client.channel(
      roomId,
      opts: const RealtimeChannelConfig(private: true),
    )
      ..onBroadcast(
        event: 'game-message',
        callback: (payload) {
          final target = payload['target'] as String? ?? 'all';
          if (target == 'host' && !isHost) return;
          final raw = payload['message'];
          if (raw is Map) {
            _messages.add(GameMessage.decode(jsonEncode(raw)));
          }
        },
      )
      ..onPresenceSync((_) => _emitPresence());
    _channel = channel;
    await _subscribe();
  }

  Future<void> reconnect() async {
    if (!_started) return start();
    _connection.add(RemoteConnectionState.reconnecting);
    await _client.removeChannel(_channel!);
    _channel = null;
    _started = false;
    await start();
  }

  Future<void> _subscribe() async {
    final ready = Completer<void>();
    _channel!.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        _connection.add(RemoteConnectionState.connected);
        _trackPresence();
        if (!ready.isCompleted) ready.complete();
      } else if (!ready.isCompleted &&
          (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut)) {
        _connection.add(RemoteConnectionState.disconnected);
        ready.completeError(
            error ?? StateError('No se pudo conectar a la sala.'));
      } else if (status == RealtimeSubscribeStatus.closed) {
        _connection.add(RemoteConnectionState.disconnected);
      }
    });
    await ready.future.timeout(const Duration(seconds: 10));
  }

  Future<void> _trackPresence() async {
    try {
      await _channel!.track({
        'playerId': playerId,
        'nickname': nickname,
        'isHost': isHost,
        'onlineAt': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {
      // Presence es informativa: no debe impedir recuperar la partida.
    }
  }

  void _emitPresence() {
    final players = <String, RemotePresence>{};
    final channel = _channel;
    if (channel == null) return;
    for (final state in channel.presenceState()) {
      for (final presence in state.presences) {
        final id = presence.payload['playerId'];
        final name = presence.payload['nickname'];
        if (id is String && name is String) {
          players[id] = RemotePresence(playerId: id, nickname: name);
        }
      }
    }
    _presence.add(players.values.toList(growable: false));
  }

  Future<void> sendToHost(GameMessage message) =>
      _send(message, target: 'host');
  Future<void> broadcast(GameMessage message) => _send(message, target: 'all');

  Future<void> _send(GameMessage message, {required String target}) =>
      _channel!.sendBroadcastMessage(
        event: 'game-message',
        payload: {'target': target, 'message': jsonDecode(message.encode())},
      );

  Future<void> dispose() async {
    final channel = _channel;
    if (channel != null) {
      await channel.untrack();
      await _client.removeChannel(channel);
    }
    await _messages.close();
    await _connection.close();
    await _presence.close();
  }
}
