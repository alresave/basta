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

  Stream<GameMessage> get messages => _messages.stream;
  Stream<SocketConnectionState> get connection => _connection.stream;
  int get port => _server!.port;

  Future<void> startHost({void Function(WebSocket socket)? onPeer}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _connection.add(SocketConnectionState.connected);
    _server!.transform(WebSocketTransformer()).listen((socket) {
      _peers.add(socket);
      onPeer?.call(socket);
      socket.listen(
        (raw) => _messages.add(GameMessage.decode(raw as String)),
        onDone: () {
          _peers.remove(socket);
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
    _client!.stream.listen(
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

  Future<void> dispose() async {
    await _client?.sink.close();
    for (final peer in _peers) {
      await peer.close();
    }
    await _server?.close(force: true);
    await _messages.close();
    await _connection.close();
  }
}
