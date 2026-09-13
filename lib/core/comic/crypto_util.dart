import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// AES-ECB decryption with PKCS7 padding (Venera's `Convert.decryptAesEcb`).
Uint8List aesEcbDecrypt(List<int> data, List<int> key) {
  final cipher =
      PaddedBlockCipherImpl(PKCS7Padding(), ECBBlockCipher(AESEngine()));
  cipher.init(
      false,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
          KeyParameter(Uint8List.fromList(key)), null));
  return cipher.process(Uint8List.fromList(data));
}
