import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Base del modo remoto: salas persistentes e identidad anónima de Supabase.
class RemoteRoomService {
  RemoteRoomService(this._client);

  final SupabaseClient _client;
  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  Future<void> ensureSignedIn() async {
    if (_client.auth.currentSession == null) {
      await _client.auth.signInAnonymously();
    }
  }

  Future<RemoteRoom> createRoom() async {
    await ensureSignedIn();
    final response = await _client.rpc('create_basta_room', params: {
      'room_code': _newCode(),
    }).single();
    return RemoteRoom.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<RemoteRoom> joinRoom(String code) async {
    await ensureSignedIn();
    final response = await _client.rpc('join_basta_room', params: {
      'room_code': code.trim().toUpperCase(),
    }).single();
    return RemoteRoom.fromJson(Map<String, dynamic>.from(response as Map));
  }

  String _newCode() => List.generate(
        6,
        (_) => _alphabet[Random.secure().nextInt(_alphabet.length)],
      ).join();
}

class RemoteRoom {
  const RemoteRoom(
      {required this.id, required this.code, required this.status});

  final String id;
  final String code;
  final String status;

  factory RemoteRoom.fromJson(Map<String, dynamic> json) => RemoteRoom(
        id: json['id'] as String,
        code: json['code'] as String,
        status: json['status'] as String,
      );
}
