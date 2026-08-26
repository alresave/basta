import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Resultado de una consulta de diccionario. Una respuesta no encontrada y un
/// fallo de red se tratan igual en el juego: ambos pasan al jurado.
class WordValidationResult {
  const WordValidationResult.valid(
      {required this.definition, required this.source})
      : exists = true;

  const WordValidationResult.unconfirmed({this.source})
      : exists = false,
        definition = null;

  final bool exists;
  final String? definition;
  final String? source;
}

/// Diccionario offline-first para el Host.
///
/// [localDictionary] puede cargarse desde un JSON/SQLite embebido al crear el
/// servicio. Se deja un vocabulario básico para que la app funcione sin assets.
class WordValidationService {
  WordValidationService({
    Map<String, String>? localDictionary,
    HttpClient? httpClient,
    this.endpoint = 'https://api.dictionaryapi.dev/api/v2/entries/es',
  })  : _dictionary = {
          ..._builtInDictionary,
          ...(localDictionary ?? const <String, String>{}).map(
              (word, definition) => MapEntry(_normalize(word), definition)),
        },
        _httpClient = httpClient ?? HttpClient();

  static const _builtInDictionary = <String, String>{
    'animal': 'Ser vivo que pertenece al reino animal.',
    'arbol': 'Planta de tronco leñoso que se ramifica a cierta altura.',
    'azul': 'Color semejante al del cielo sin nubes.',
    'casa': 'Edificio para habitar.',
    'camion': 'Vehículo destinado al transporte de carga.',
    'gato': 'Mamífero felino doméstico.',
    'mexico': 'País de América del Norte.',
    'perro': 'Mamífero doméstico de la familia de los cánidos.',
    'sol': 'Estrella alrededor de la que gira la Tierra.',
  };

  final Map<String, String> _dictionary;
  final HttpClient _httpClient;
  final String endpoint;
  Future<void>? _assetLoad;

  Future<WordValidationResult> validate(String word) async {
    await _loadEmbeddedDictionary();
    final normalized = _normalize(word);
    if (normalized.isEmpty) return const WordValidationResult.unconfirmed();
    final local = _dictionary[normalized];
    if (local != null) {
      return WordValidationResult.valid(definition: local, source: 'local');
    }

    try {
      final uri = Uri.parse('$endpoint/${Uri.encodeComponent(normalized)}');
      final request =
          await _httpClient.getUrl(uri).timeout(const Duration(seconds: 3));
      final response =
          await request.close().timeout(const Duration(seconds: 3));
      if (response.statusCode != HttpStatus.ok) {
        return const WordValidationResult.unconfirmed(source: 'remote');
      }
      final raw = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(raw);
      final definition = _definitionFrom(decoded);
      return definition == null
          ? const WordValidationResult.unconfirmed(source: 'remote')
          : WordValidationResult.valid(
              definition: definition, source: 'remote');
    } catch (_) {
      return const WordValidationResult.unconfirmed(source: 'remote');
    }
  }

  Future<void> _loadEmbeddedDictionary() => _assetLoad ??= () async {
        try {
          final raw = await rootBundle.loadString('assets/dictionary_es.json');
          final entries = Map<String, dynamic>.from(jsonDecode(raw) as Map);
          _dictionary.addAll(entries.map(
            (word, definition) =>
                MapEntry(_normalize(word), definition as String),
          ));
        } catch (_) {
          // El diccionario básico mantiene la validación offline si un host
          // integra el servicio sin el bundle Flutter (por ejemplo, en tests).
        }
      }();

  static String? _definitionFrom(dynamic decoded) {
    if (decoded is! List || decoded.isEmpty || decoded.first is! Map) {
      return null;
    }
    final meanings = decoded.first['meanings'];
    if (meanings is! List || meanings.isEmpty || meanings.first is! Map) {
      return null;
    }
    final definitions = meanings.first['definitions'];
    if (definitions is! List ||
        definitions.isEmpty ||
        definitions.first is! Map) {
      return null;
    }
    final definition = definitions.first['definition'];
    return definition is String && definition.trim().isNotEmpty
        ? definition.trim()
        : null;
  }

  static String _normalize(String value) {
    const accented = 'áéíóúüñ';
    const plain = 'aeiouun';
    var result = value.trim().toLowerCase();
    for (var index = 0; index < accented.length; index++) {
      result = result.replaceAll(accented[index], plain[index]);
    }
    return result;
  }
}
