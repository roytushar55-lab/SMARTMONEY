import 'package:flutter_test/flutter_test.dart';
import 'package:smartmoney_admin/core/network/safe_url.dart';

void main() {
  test('accepts https URLs', () {
    expect(
      safeMediaUrl(' https://cdn.example.com/a.png '),
      'https://cdn.example.com/a.png',
    );
  });

  test('rejects http for non-local hosts', () {
    expect(
      safeMediaUrl('http://cdn.example.com/a.png', allowLocalHttp: true),
      isNull,
    );
  });

  test('allows http only for localhost when permitted', () {
    expect(
      safeMediaUrl('http://localhost:5000/a.png', allowLocalHttp: true),
      'http://localhost:5000/a.png',
    );
    expect(
      safeMediaUrl('http://localhost:5000/a.png', allowLocalHttp: false),
      isNull,
    );
  });

  test('rejects dangerous or malformed values', () {
    for (final value in [
      null,
      '',
      '   ',
      'javascript:alert(1)',
      'data:image/png;base64,AAAA',
      'file:///etc/passwd',
      '//cdn.example.com/a.png',
      '/relative/a.png',
      'https://',
      'not a url',
    ]) {
      expect(
        safeMediaUrl(value, allowLocalHttp: true),
        isNull,
        reason: '$value',
      );
    }
  });
}
