import 'package:encrypt/encrypt.dart';

final key = Key.fromUtf8('49165020314169912084475981059484');
final iv = IV.fromUtf8('4916502031416991');
final encrypter = Encrypter(AES(key));

String encryptText(String text) {
  final encrypted = encrypter.encrypt(text, iv: iv);
  return encrypted.base64;
}

String decryptText(String text) {
  if (text.isEmpty) {
    return "";
  } else {
    final encrypted = Encrypted.fromBase64(text);
    final decrypted = encrypter.decrypt(encrypted, iv: iv);
    return decrypted;
  }
}
