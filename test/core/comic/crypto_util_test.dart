import 'package:flutter_test/flutter_test.dart';
import 'package:libiko/core/comic/crypto_util.dart';

List<int> _hex(String s) => [
      for (var i = 0; i < s.length; i += 2)
        int.parse(s.substring(i, i + 2), radix: 16)
    ];

void main() {
  test('aesEcbDecrypt decrypts a known AES-256-ECB/PKCS7 vector', () {
    final key = List<int>.generate(32, (i) => i);
    final cipher = _hex(
        'f9decd47c8e1eb0e30883ecb87144c2b2cc90868386a7fd66d3c86b0dd9021f3');
    final plain = aesEcbDecrypt(cipher, key);
    expect(String.fromCharCodes(plain), '{"hello":"world"}');
  });
}
