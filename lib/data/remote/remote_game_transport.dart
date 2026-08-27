import 'dart:async';
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../protocol/game_message.dart';

/// Transporte Realtime para una sala remota. Sólo el Host recibe solicitudes
/// dirigidas a él; los cambios autoritativos llegan a todos los jugadores.
class RemoteGameTransport {
  RemoteGameTransport({
    required SupabaseClient client,
    required this.roomId,
    required this.isHost,
  }) : _client = client;

  final SupabaseClient _client;
  final String roomId;
  final bool isHost;
  final _messages = StreamController<GameMessage>.broadcast();
  late final RealtimeChannel _channel;

  Stream<GameMessage> get messages => _messages.stream;

  Future<void> start() async {
    _channel = _client.channel(
      roomId,
      opts: const RealtimeChannelConfig(private: true),
    )..onBroadcast(
        event: 'game-message',
        callback: (payload) {
          final target = payload['target'] as String? ?? 'all';
          if (target == 'host' && !isHost) return;
          final raw = payload['message'];
          if (raw is Map) {
            _messages.add(GameMessage.decode(jsonEncode(raw)));
          }
        },
      );
    final ready = Completer<void>();
    _channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        ready.complete();
      } else if (!ready.isCompleted &&
          (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut)) {
        ready.completeError(
            error ?? StateError('No se pudo conectar a la sala.'));
      }
    });
    await ready.future.timeout(const Duration(seconds: 10));
  }

  Future<void> sendToHost(GameMessage message) =>
      _send(message, target: 'host');
  Future<void> broadcast(GameMessage message) => _send(message, target: 'all');

  Future<void> _send(GameMessage message, {required String target}) =>
      _channel.sendBroadcastMessage(
        event: 'game-message',
        payload: {'target': target, 'message': jsonDecode(message.encode())},
      );

  Future<void> dispose() async {
    await _client.removeChannel(_channel);
    await _messages.close();
  }
}
