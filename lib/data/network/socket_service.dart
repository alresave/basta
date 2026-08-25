import 'dart:async';
import 'dart:io';

import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../protocol/game_message.dart';

/// Transporte puro: no contiene reglas del juego. El Host es autoritativo.
class SocketService {
  HttpServer? _server;
  WebSocketChannel? _client;
  final _messages = StreamController<GameMessage>.broadcast();
  final _peers = <WebSocket>{};

  Stream<GameMessage> get messages => _messages.stream;
  int get port => _server!.port;

  Future<void> startHost({void Function(WebSocket socket)? onPeer}) async {
    _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _server!.transform(WebSocketTransformer()).listen((socket) {
      _peers.add(socket);
      onPeer?.call(socket);
      socket.listen(
        (raw) => _messages.add(GameMessage.decode(raw as String)),
        onDone: () => _peers.remove(socket),
      );
    });
  }

  Future<void> connect(String host, int port) async {
    _client = IOWebSocketChannel.connect(Uri.parse('ws://$host:$port'));
    await _client!.ready;
    _client!.stream.listen(
      (raw) => _messages.add(GameMessage.decode(raw as String)),
    );
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
  }
}
