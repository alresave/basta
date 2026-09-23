import 'package:flutter_test/flutter_test.dart';

import 'package:basta_local/presentation/showcase_screen.dart';

void main() {
  test('normaliza mayúsculas y acentos antes de comparar', () {
    expect(normalizeWord('  ÁRBOL  '), 'arbol');
    expect(
        levenshteinDistance(normalizeWord('CANCION'), normalizeWord('canción')),
        0);
  });

  test('encuentra iguales y evita falsos positivos cortos', () {
    final matches = findRepeatedWords({
      'ana': 'Camión',
      'beto': 'camion',
      'cora': 'sol',
      'dani': 'sal',
    });

    expect(matches, hasLength(1));
    expect(matches.single.playerIds, ['ana', 'beto']);
    expect(matches.single.pointsPerPlayer, 50);
  });

  test(
      'una coincidencia vale 50 puntos para cada jugador, sin importar el grupo',
      () {
    expect(
      findRepeatedWords({'a': 'perro', 'b': 'perro', 'c': 'perro'})
          .single
          .pointsPerPlayer,
      50,
    );
    expect(
      findRepeatedWords(
              {'a': 'perro', 'b': 'perro', 'c': 'perro', 'd': 'perro'})
          .single
          .pointsPerPlayer,
      50,
    );
    expect(
      findRepeatedWords({
        'a': 'perro',
        'b': 'perro',
        'c': 'perro',
        'd': 'perro',
        'e': 'perro',
      }).single.pointsPerPlayer,
      50,
    );
  });
}
