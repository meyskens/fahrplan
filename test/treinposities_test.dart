import 'package:fahrplan/utils/treinposities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TreinPosities', () {
    test('Treinposiities parses /20250310/452', () async {
      final date = DateTime(2025, 3, 10);
      final tpData = await Treinposities.getRealtime(date, "ES452");

      expect(tpData, isNotNull);
    });
  });
}
