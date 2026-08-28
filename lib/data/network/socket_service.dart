import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/game_message.dart';

enum SocketConnectionState { connected, disconnected, reconnecting }

/// Transporte puro: no contiene reglas del juego. El Host es autoritativo.
class SocketService {
  HttpServer? _server;
  WebSocketChannel? _client;
  final _messages = StreamController<GameMessage>.broadcast();
  final _connection = StreamController<SocketConnectionState>.broadcast();
  final _peers = <WebSocket>{};
  final _playerSockets = <String, WebSocket>{};
  StreamSubscription<dynamic>? _clientSubscription;

  Stream<GameMessage> get messages => _messages.stream;
  Stream<SocketConnectionState> get connection => _connection.stream;
  int get port => _server!.port;

  Future<void> startHost({void Function(WebSocket socket)? onPeer}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _connection.add(SocketConnectionState.connected);
    _server!.transform(WebSocketTransformer()).listen((socket) {
      _peers.add(socket);
      onPeer?.call(socket);
      String? authenticatedPlayerId;
      socket.listen(
        (raw) {
          // A socket must introduce itself before it can issue game actions.
          // Subsequent messages may only claim that same player identity.
          try {
            final message = GameMessage.decode(raw as String);
            if (authenticatedPlayerId == null) {
              if (message.event != GameEvent.joinLobby) return;
              final id = message.payload['id'];
              if (id is! String || id.isEmpty) return;
              authenticatedPlayerId = id;
              _playerSockets[id] = socket;
            } else if (message.event == GameEvent.joinLobby) {
              if (message.payload['id'] != authenticatedPlayerId) return;
            } else {
              final claimedId =
                  message.payload['actorId'] ?? message.payload['playerId'];
              if (claimedId != authenticatedPlayerId) return;
            }
            _messages.add(message);
          } on FormatException {
            // Ignore malformed or unauthenticated network traffic.
          }
        },
        onDone: () {
          _peers.remove(socket);
          _playerSockets.removeWhere((_, peer) => identical(peer, socket));
          if (_peers.isEmpty) {
            _connection.add(SocketConnectionState.disconnected);
          }
        },
        onError: (_, __) => _connection.add(SocketConnectionState.disconnected),
      );
    });
  }

  Future<void> connect(String host, int port) async {
    _client = IOWebSocketChannel.connect(Uri.parse('ws://$host:$port'));
    await _client!.ready;
    _connection.add(SocketConnectionState.connected);
    await _clientSubscription?.cancel();
    _clientSubscription = _client!.stream.listen(
      (raw) => _messages.add(GameMessage.decode(raw as String)),
      onDone: () => _connection.add(SocketConnectionState.disconnected),
      onError: (_, __) => _connection.add(SocketConnectionState.disconnected),
    );
  }

  Future<void> reconnect(String host, int port) async {
    _connection.add(SocketConnectionState.reconnecting);
    await _client?.sink.close();
    await connect(host, port);
  }

  void sendToHost(GameMessage message) => _client?.sink.add(message.encode());

  void broadcast(GameMessage message) {
    final payload = message.encode();
    for (final peer in _peers) {
      peer.add(payload);
    }
  }

  /// Sends a snapshot only to a player that has completed the local handshake.
  void sendToPlayer(String playerId, GameMessage message) =>
      _playerSockets[playerId]?.add(message.encode());

  Future<void> dispose() async {
    await _client?.sink.close();
    await _clientSubscription?.cancel();
    for (final peer in _peers) {
      await peer.close();
    }
    await _server?.close(force: true);
    await _messages.close();
    await _connection.close();
  }
}
