import 'package:flutter_test/flutter_test.dart';

import 'package:basta_local/data/validation/word_validation_service.dart';

void main() {
  test('consulta el diccionario local antes que la red', () async {
    final service = WordValidationService(localDictionary: {
      'Ñandú': 'Ave corredora sudamericana.',
    });

    final result = await service.validate('  ñandú ');

    expect(result.exists, isTrue);
    expect(result.definition, 'Ave corredora sudamericana.');
    expect(result.source, 'local');
  });
}
