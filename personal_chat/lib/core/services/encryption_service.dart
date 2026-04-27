import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class EncryptionService {
  static final EncryptionService _instance = EncryptionService._internal();
  factory EncryptionService() => _instance;
  EncryptionService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  encrypt.Key? _encryptionKey;
  bool _isInitialized = false;

  Future<void> initialize(String userId) async {
    if (_isInitialized) return;

    // Try to get existing key or generate new one
    String? storedKey = await _secureStorage.read(
      key: 'encryption_key_$userId',
    );

    if (storedKey != null) {
      _encryptionKey = encrypt.Key.fromBase64(storedKey);
    } else {
      // Generate new key
      final key = encrypt.Key.fromSecureRandom(
        AppConstants.encryptionKeyLength,
      );
      await _secureStorage.write(
        key: 'encryption_key_$userId',
        value: key.base64,
      );
      _encryptionKey = key;
    }

    _isInitialized = true;
  }

  String encryptMessage(String plainText, String senderId, String receiverId) {
    if (_encryptionKey == null) {
      throw Exception('Encryption not initialized');
    }

    // Create IV from sender and receiver IDs
    final ivString = '${senderId}_$receiverId';
    final ivHash = sha256.convert(utf8.encode(ivString));
    final ivBytes = ivHash.bytes.sublist(0, AppConstants.ivLength);
    final iv = encrypt.IV(Uint8List.fromList(ivBytes));

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_encryptionKey!, mode: encrypt.AESMode.cbc),
    );

    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  String decryptMessage(
    String encryptedText,
    String senderId,
    String receiverId,
  ) {
    if (_encryptionKey == null) {
      throw Exception('Encryption not initialized');
    }

    // Create IV from sender and receiver IDs
    final ivString = '${senderId}_$receiverId';
    final ivHash = sha256.convert(utf8.encode(ivString));
    final ivBytes = ivHash.bytes.sublist(0, AppConstants.ivLength);
    final iv = encrypt.IV(Uint8List.fromList(ivBytes));

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_encryptionKey!, mode: encrypt.AESMode.cbc),
    );

    final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
    return decrypted;
  }

  String generateChatKey(String userId1, String userId2) {
    // Sort user IDs to ensure consistent key generation
    final sortedIds = [userId1, userId2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }

  Future<void> clearKeys() async {
    await _secureStorage.deleteAll();
    _encryptionKey = null;
    _isInitialized = false;
  }
}
