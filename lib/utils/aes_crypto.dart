import 'package:encrypt/encrypt.dart';

class AESCrypto {
  // 加密方法
  static String encrypt(String iv, String key, String plainText) {
    final keyObj = Key.fromUtf8(key);
    final ivObj = IV.fromUtf8(iv);
    final encrypter = Encrypter(AES(keyObj, mode: AESMode.cbc, padding: 'PKCS7')); // 使用 PKCS7
    final encrypted = encrypter.encrypt(plainText, iv: ivObj);
    return encrypted.base64;
  }

  // 解密方法
  static String decrypt(String iv, String key, String encryptedText) {
    final keyObj = Key.fromUtf8(key);
    final ivObj = IV.fromUtf8(iv);
    final encrypter = Encrypter(AES(keyObj, mode: AESMode.cbc, padding: 'PKCS7')); // 使用 PKCS7
    final decrypted = encrypter.decrypt64(encryptedText, iv: ivObj);
    return decrypted;
  }
}
