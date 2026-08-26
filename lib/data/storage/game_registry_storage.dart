import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/game_registry.dart';

class GameRegistryStorage {
  static const _keyPrefix = 'basta_registry_';

  Future<void> save(String roomId, GameRegistry registry) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
        _keyPrefix + roomId, jsonEncode(registry.toJson()));
  }

  Future<GameRegistry?> load(String roomId) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_keyPrefix + roomId);
    if (raw == null) return null;
    return GameRegistry.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map));
  }
}
