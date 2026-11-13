import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Pure-Dart AES-256 block cipher implementation following FIPS 197.
class Aes256 {
  static const List<int> _sBox = [
    0x63, 0x7c, 0x77, 0x7b, 0xf2, 0x6b, 0x6f, 0xc5, 0x30, 0x01, 0x67, 0x2b, 0xfe, 0xd7, 0xab, 0x76,
    0xca, 0x82, 0xc9, 0x7d, 0xfa, 0x59, 0x47, 0xf0, 0xad, 0xd4, 0xa2, 0xaf, 0x9c, 0xa4, 0x72, 0xc0,
    0xb7, 0xfd, 0x93, 0x26, 0x36, 0x3f, 0xf7, 0xcc, 0x34, 0xa5, 0xe5, 0xf1, 0x71, 0xd8, 0x31, 0x15,
    0x04, 0xc7, 0x23, 0xc3, 0x18, 0x96, 0x05, 0x9a, 0x07, 0x12, 0x80, 0xe2, 0xeb, 0x27, 0xb2, 0x75,
    0x09, 0x83, 0x2c, 0x1a, 0x1b, 0x6e, 0x5a, 0xa0, 0x52, 0x3b, 0xd6, 0xb3, 0x29, 0xe3, 0x2f, 0x84,
    0x53, 0xd1, 0x00, 0xed, 0x20, 0xfc, 0xb1, 0x5b, 0x6a, 0xcb, 0xbe, 0x39, 0x4a, 0x4c, 0x58, 0xcf,
    0xd0, 0xef, 0xaa, 0xfb, 0x43, 0x4d, 0x33, 0x85, 0x45, 0xf9, 0x02, 0x7f, 0x50, 0x3c, 0x9f, 0xa8,
    0x51, 0xa3, 0x40, 0x8f, 0x92, 0x9d, 0x38, 0xf5, 0xbc, 0xb6, 0xda, 0x21, 0x10, 0xff, 0xf3, 0xd2,
    0xcd, 0x0c, 0x13, 0xec, 0x5f, 0x97, 0x44, 0x17, 0xc4, 0xa7, 0x7e, 0x3d, 0x64, 0x5d, 0x19, 0x73,
    0x60, 0x81, 0x4f, 0xdc, 0x22, 0x2a, 0x90, 0x88, 0x46, 0xee, 0xb8, 0x14, 0xde, 0x5e, 0x0b, 0xdb,
    0xe0, 0x32, 0x3a, 0x0a, 0x49, 0x06, 0x24, 0x5c, 0xc2, 0xd3, 0xac, 0x62, 0x91, 0x95, 0xe4, 0x79,
    0xe7, 0xc8, 0x37, 0x6d, 0x8d, 0xd5, 0x4e, 0xa9, 0x6c, 0x56, 0xf4, 0xea, 0x65, 0x7a, 0xae, 0x08,
    0xba, 0x78, 0x25, 0x2e, 0x1c, 0xa6, 0xb4, 0xc6, 0xe8, 0xdd, 0x74, 0x1f, 0x4b, 0xbd, 0x8b, 0x8a,
    0x70, 0x3e, 0xb5, 0x66, 0x48, 0x03, 0xf6, 0x0e, 0x61, 0x35, 0x57, 0xb9, 0x86, 0xc1, 0x1d, 0x9e,
    0xe1, 0xf8, 0x98, 0x11, 0x69, 0xd9, 0x8e, 0x94, 0x9b, 0x1e, 0x87, 0xe9, 0xce, 0x55, 0x28, 0xdf,
    0x8c, 0xa1, 0x89, 0x0d, 0xbf, 0xe6, 0x42, 0x68, 0x41, 0x99, 0x2d, 0x0f, 0xb0, 0x54, 0xbb, 0x16
  ];

  static const List<int> _rcon = [
    0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36
  ];

  final Uint32List _expandedKey = Uint32List(60); // 15 round keys * 4 words for AES-256

  Aes256(List<int> keyBytes) {
    if (keyBytes.length != 32) {
      throw ArgumentError('AES-256 requires a 32-byte key.');
    }
    _expandKey(keyBytes);
  }

  void _expandKey(List<int> key) {
    for (int i = 0; i < 8; i++) {
      _expandedKey[i] = ((key[4 * i] & 0xFF) << 24) |
          ((key[4 * i + 1] & 0xFF) << 16) |
          ((key[4 * i + 2] & 0xFF) << 8) |
          (key[4 * i + 3] & 0xFF);
    }

    for (int i = 8; i < 60; i++) {
      int temp = _expandedKey[i - 1];
      if (i % 8 == 0) {
        temp = _subWord(_rotWord(temp)) ^ (_rcon[i ~/ 8] << 24);
      } else if (i % 8 == 4) {
        temp = _subWord(temp);
      }
      _expandedKey[i] = _expandedKey[i - 8] ^ temp;
    }
  }

  static int _subWord(int word) {
    return (_sBox[(word >> 24) & 0xFF] << 24) |
        (_sBox[(word >> 16) & 0xFF] << 16) |
        (_sBox[(word >> 8) & 0xFF] << 8) |
        _sBox[word & 0xFF];
  }

  static int _rotWord(int word) {
    return ((word << 8) & 0xFFFFFF00) | ((word >> 24) & 0xFF);
  }

  static int _xtime(int b) {
    return ((b << 1) ^ (((b >> 7) & 1) * 0x1b)) & 0xFF;
  }

  /// Encrypts one 16-byte block in place or into outBlock.
  void encryptBlock(Uint8List inBlock, int inOff, Uint8List outBlock, int outOff) {
    Uint8List state = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      state[i] = inBlock[inOff + i];
    }

    // Round 0
    _addRoundKey(state, 0);

    // Rounds 1 to 13
    for (int round = 1; round < 14; round++) {
      _subBytes(state);
      _shiftRows(state);
      _mixColumns(state);
      _addRoundKey(state, round);
    }

    // Final round 14
    _subBytes(state);
    _shiftRows(state);
    _addRoundKey(state, 14);

    for (int i = 0; i < 16; i++) {
      outBlock[outOff + i] = state[i];
    }
  }

  void _addRoundKey(Uint8List state, int round) {
    int keyOff = round * 4;
    for (int c = 0; c < 4; c++) {
      int k = _expandedKey[keyOff + c];
      state[c * 4 + 0] ^= (k >> 24) & 0xFF;
      state[c * 4 + 1] ^= (k >> 16) & 0xFF;
      state[c * 4 + 2] ^= (k >> 8) & 0xFF;
      state[c * 4 + 3] ^= k & 0xFF;
    }
  }

  void _subBytes(Uint8List state) {
    for (int i = 0; i < 16; i++) {
      state[i] = _sBox[state[i]];
    }
  }

  void _shiftRows(Uint8List s) {
    int t;
    // Row 1
    t = s[1]; s[1] = s[5]; s[5] = s[9]; s[9] = s[13]; s[13] = t;
    // Row 2
    t = s[2]; s[2] = s[10]; s[10] = t;
    t = s[6]; s[6] = s[14]; s[14] = t;
    // Row 3
    t = s[15]; s[15] = s[11]; s[11] = s[7]; s[7] = s[3]; s[3] = t;
  }

  void _mixColumns(Uint8List s) {
    for (int c = 0; c < 4; c++) {
      int idx = c * 4;
      int a0 = s[idx], a1 = s[idx + 1], a2 = s[idx + 2], a3 = s[idx + 3];
      int h0 = _xtime(a0), h1 = _xtime(a1), h2 = _xtime(a2), h3 = _xtime(a3);
      s[idx + 0] = h0 ^ a1 ^ h1 ^ a2 ^ a3;
      s[idx + 1] = a0 ^ h1 ^ a2 ^ h2 ^ a3;
      s[idx + 2] = a0 ^ a1 ^ h2 ^ a3 ^ h3;
      s[idx + 3] = a0 ^ h0 ^ a1 ^ a2 ^ h3;
    }
  }
}

/// Authenticated AES-256-CTR with Encrypt-then-MAC (HMAC-SHA256).
class AuthenticatedAesCipher {
  static const String magicHeader = 'SVASHIELD_ENC_V1'; // 16 bytes
  static const int ivLength = 16;
  static const int macLength = 32;
  static const int headerLength = 16 + ivLength + macLength; // 64 bytes

  /// Encrypts plaintext bytes using authenticated AES-256-CTR.
  static Uint8List encrypt({
    required Uint8List plaintext,
    required List<int> masterKey, // 32 bytes
  }) {
    if (masterKey.length != 32) {
      throw ArgumentError('Master key must be 32 bytes (256-bit).');
    }

    // Derive encKey and macKey using SHA256 domain separation
    final encKey = sha256.convert([...masterKey, ...utf8.encode('AES_ENC_KEY')]).bytes;
    final macKey = sha256.convert([...masterKey, ...utf8.encode('HMAC_MAC_KEY')]).bytes;

    // Generate random 16-byte IV
    final rng = Random.secure();
    final iv = Uint8List(ivLength);
    for (int i = 0; i < ivLength; i++) {
      iv[i] = rng.nextInt(256);
    }

    // AES-256 CTR encryption
    final aes = Aes256(encKey);
    final ciphertext = Uint8List(plaintext.length);
    final counterBlock = Uint8List(16);
    counterBlock.setRange(0, 16, iv);
    final keystream = Uint8List(16);

    int offset = 0;
    while (offset < plaintext.length) {
      aes.encryptBlock(counterBlock, 0, keystream, 0);
      int bytesInBlock = min(16, plaintext.length - offset);
      for (int i = 0; i < bytesInBlock; i++) {
        ciphertext[offset + i] = plaintext[offset + i] ^ keystream[i];
      }
      offset += bytesInBlock;
      // Increment 128-bit counter
      for (int j = 15; j >= 0; j--) {
        counterBlock[j] = (counterBlock[j] + 1) & 0xFF;
        if (counterBlock[j] != 0) break;
      }
    }

    // Compute HMAC-SHA256 over [Magic + IV + Ciphertext]
    final magicBytes = utf8.encode(magicHeader);
    final hmac = Hmac(sha256, macKey);
    final macDigest = hmac.convert([...magicBytes, ...iv, ...ciphertext]).bytes;

    // Assemble final output: [Magic (16B)] + [IV (16B)] + [MAC (32B)] + [Ciphertext]
    final result = Uint8List(headerLength + ciphertext.length);
    result.setRange(0, 16, magicBytes);
    result.setRange(16, 32, iv);
    result.setRange(32, 64, macDigest);
    result.setRange(64, result.length, ciphertext);

    return result;
  }

  /// Decrypts ciphertext bytes, verifying authenticity tag first.
  /// If the file does not contain the encryption header, it returns the raw bytes (legacy fallback).
  static Uint8List decrypt({
    required Uint8List data,
    required List<int> masterKey,
  }) {
    if (data.length < headerLength) {
      return data; // Legacy / unencrypted
    }

    final magicBytes = utf8.encode(magicHeader);
    bool matchesMagic = true;
    for (int i = 0; i < 16; i++) {
      if (data[i] != magicBytes[i]) {
        matchesMagic = false;
        break;
      }
    }

    if (!matchesMagic) {
      return data; // Legacy unencrypted file, preserve intact!
    }

    if (masterKey.length != 32) {
      throw ArgumentError('Master key must be 32 bytes (256-bit).');
    }

    final encKey = sha256.convert([...masterKey, ...utf8.encode('AES_ENC_KEY')]).bytes;
    final macKey = sha256.convert([...masterKey, ...utf8.encode('HMAC_MAC_KEY')]).bytes;

    final iv = Uint8List.sublistView(data, 16, 32);
    final storedMac = Uint8List.sublistView(data, 32, 64);
    final ciphertext = Uint8List.sublistView(data, 64);

    // Verify HMAC-SHA256
    final hmac = Hmac(sha256, macKey);
    final computedMac = hmac.convert([...magicBytes, ...iv, ...ciphertext]).bytes;

    // Constant-time comparison
    int diff = 0;
    for (int i = 0; i < 32; i++) {
      diff |= storedMac[i] ^ computedMac[i];
    }
    if (diff != 0) {
      throw StateError('SecurityException: Authentication tag verification failed. File corrupted or tampered.');
    }

    // Decrypt AES-256 CTR
    final aes = Aes256(encKey);
    final plaintext = Uint8List(ciphertext.length);
    final counterBlock = Uint8List(16);
    counterBlock.setRange(0, 16, iv);
    final keystream = Uint8List(16);

    int offset = 0;
    while (offset < ciphertext.length) {
      aes.encryptBlock(counterBlock, 0, keystream, 0);
      int bytesInBlock = min(16, ciphertext.length - offset);
      for (int i = 0; i < bytesInBlock; i++) {
        plaintext[offset + i] = ciphertext[offset + i] ^ keystream[i];
      }
      offset += bytesInBlock;
      for (int j = 15; j >= 0; j--) {
        counterBlock[j] = (counterBlock[j] + 1) & 0xFF;
        if (counterBlock[j] != 0) break;
      }
    }

    return plaintext;
  }
}
