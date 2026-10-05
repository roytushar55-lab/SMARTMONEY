import 'package:flutter_test/flutter_test.dart';
import 'package:smart_money_mobile/core/utils/password_rules.dart';

void main() {
  group('hasSpecialCharacter', () {
    test('accepts any non-alphanumeric character', () {
      for (final char in ['!', '_', '-', ' ', '+', '=', '~', '[', '€', '£']) {
        expect(hasSpecialCharacter('Abcdef1$char'), isTrue, reason: char);
      }
    });

    test('rejects letters and digits only, including non-ASCII ones', () {
      expect(hasSpecialCharacter('Abcdef12'), isFalse);
      expect(hasSpecialCharacter('Abcdéf12'), isFalse);
      expect(hasSpecialCharacter(''), isFalse);
    });
  });
}
