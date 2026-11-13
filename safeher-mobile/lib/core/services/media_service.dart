import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'authenticated_aes_cipher.dart';

class MediaService {
  static final AudioRecorder _audioRecorder = AudioRecorder();
  static final ImagePicker _imagePicker = ImagePicker();
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _keyStorageKey = 'svashield_evidence_master_key_v1';
  static List<int>? _cachedMasterKey;

  static Future<List<int>> getMasterKey() async {
    if (_cachedMasterKey != null) return _cachedMasterKey!;
    final storedBase64 = await _secureStorage.read(key: _keyStorageKey);
    if (storedBase64 != null) {
      _cachedMasterKey = base64Decode(storedBase64);
      return _cachedMasterKey!;
    }
    // Generate fresh 256-bit key
    final rng = Random.secure();
    final freshKey = List<int>.generate(32, (_) => rng.nextInt(256));
    await _secureStorage.write(key: _keyStorageKey, value: base64Encode(freshKey));
    _cachedMasterKey = freshKey;
    return freshKey;
  }

  static Future<Directory> _getEvidenceDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final evidenceDir = Directory('${appDir.path}/evidence');
    if (!await evidenceDir.exists()) {
      await evidenceDir.create(recursive: true);
    }
    return evidenceDir;
  }

  // --- Audio Recording ---

  static Future<bool> hasAudioPermission() async {
    try {
      return await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint('Error checking audio permission: $e');
      return false;
    }
  }

  static String? _currentAudioTempPath;

  static Future<String?> startAudioRecording() async {
    try {
      final hasPerm = await _audioRecorder.hasPermission();
      if (!hasPerm) return null;

      final tempDir = await getTemporaryDirectory();
      final tempFilePath = '${tempDir.path}/raw_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      _currentAudioTempPath = tempFilePath;

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: tempFilePath,
      );
      return tempFilePath;
    } catch (e) {
      debugPrint('Error starting audio recording: $e');
      return null;
    }
  }

  static Future<String?> stopAudioRecording() async {
    try {
      final rawPath = await _audioRecorder.stop() ?? _currentAudioTempPath;
      _currentAudioTempPath = null;
      if (rawPath == null) return null;

      final rawFile = File(rawPath);
      if (!await rawFile.exists()) return null;

      // Encrypt audio before saving to permanent evidence directory
      final plaintext = await rawFile.readAsBytes();
      final masterKey = await getMasterKey();
      final encryptedBytes = AuthenticatedAesCipher.encrypt(
        plaintext: plaintext,
        masterKey: masterKey,
      );

      final dir = await _getEvidenceDirectory();
      final targetPath = '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await File(targetPath).writeAsBytes(encryptedBytes);

      // Clean up raw unencrypted audio temp file immediately
      try {
        await rawFile.delete();
      } catch (_) {}

      return targetPath;
    } catch (e) {
      debugPrint('Error stopping and encrypting audio recording: $e');
      return null;
    }
  }

  static Future<bool> isAudioRecording() async {
    try {
      return await _audioRecorder.isRecording();
    } catch (e) {
      return false;
    }
  }

  // --- Photo Capture & Selection ---

  static Future<String?> pickPhoto({ImageSource source = ImageSource.camera}) async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (photo == null) return null;

      final rawFile = File(photo.path);
      final plaintext = await rawFile.readAsBytes();
      final masterKey = await getMasterKey();
      final encryptedBytes = AuthenticatedAesCipher.encrypt(
        plaintext: plaintext,
        masterKey: masterKey,
      );

      final dir = await _getEvidenceDirectory();
      final targetPath = '${dir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(targetPath).writeAsBytes(encryptedBytes);

      // Clean up raw unencrypted camera temp file immediately
      try {
        await rawFile.delete();
      } catch (_) {}

      return targetPath;
    } catch (e) {
      debugPrint('Error capturing/selecting and encrypting photo: $e');
      return null;
    }
  }

  static Future<String?> capturePhoto() => pickPhoto(source: ImageSource.camera);

  static Future<String?> pickPhotoFromGallery() => pickPhoto(source: ImageSource.gallery);

  // --- Video Recording ---

  static Future<String?> recordVideo({Duration maxDuration = const Duration(minutes: 5)}) async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
        maxDuration: maxDuration,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (video == null) return null;

      final rawFile = File(video.path);
      final plaintext = await rawFile.readAsBytes();
      final masterKey = await getMasterKey();
      final encryptedBytes = AuthenticatedAesCipher.encrypt(
        plaintext: plaintext,
        masterKey: masterKey,
      );

      final dir = await _getEvidenceDirectory();
      final targetPath = '${dir.path}/video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      await File(targetPath).writeAsBytes(encryptedBytes);

      // Clean up raw camera temp file immediately
      try {
        await rawFile.delete();
      } catch (_) {}

      return targetPath;
    } catch (e) {
      debugPrint('Error recording and encrypting video: $e');
      return null;
    }
  }

  // --- Decryption for Playback & Preview ---

  /// Decrypts an encrypted evidence file into memory bytes.
  /// If the file is unencrypted (legacy), returns raw bytes.
  static Future<Uint8List?> decryptEvidenceBytes(String filePath) async {
    try {
      final file = File(filePath);
      if (!await file.exists()) return null;

      final rawData = await file.readAsBytes();
      final masterKey = await getMasterKey();
      return AuthenticatedAesCipher.decrypt(data: rawData, masterKey: masterKey);
    } catch (e) {
      debugPrint('Error decrypting evidence file bytes: $e');
      return null;
    }
  }

  /// Creates a temporary short-lived plaintext file in cache for audio/video playback.
  static Future<File?> getDecryptedTempFile(String filePath) async {
    try {
      final decryptedBytes = await decryptEvidenceBytes(filePath);
      if (decryptedBytes == null) return null;

      final tempDir = await getTemporaryDirectory();
      final ext = filePath.split('.').last;
      final tempFile = File('${tempDir.path}/preview_${DateTime.now().millisecondsSinceEpoch}.$ext');
      await tempFile.writeAsBytes(decryptedBytes);
      return tempFile;
    } catch (e) {
      debugPrint('Error creating decrypted temp file for preview: $e');
      return null;
    }
  }

  // --- Secure Local Deletion ---

  static Future<bool> deleteEvidenceFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting evidence file: $e');
      return false;
    }
  }

  /// Permanently deletes all encrypted evidence files and destroys the master encryption key.
  static Future<void> clearAllEvidence() async {
    try {
      final dir = await _getEvidenceDirectory();
      if (await dir.exists()) {
        final entities = dir.listSync();
        for (final entity in entities) {
          if (entity is File) {
            await entity.delete();
          }
        }
      }
      await _secureStorage.delete(key: _keyStorageKey);
      _cachedMasterKey = null;
    } catch (e) {
      debugPrint('Error clearing all evidence: $e');
    }
  }

  static void dispose() {
    _audioRecorder.dispose();
  }
}
