import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/toolkit_provider.dart';
import '../../core/services/media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../widgets/safe_button.dart';

class AmbientAudioSheet extends StatefulWidget {
  const AmbientAudioSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AmbientAudioSheet(),
    );
  }

  @override
  State<AmbientAudioSheet> createState() => _AmbientAudioSheetState();
}

class _AmbientAudioSheetState extends State<AmbientAudioSheet> {
  final _notesController = TextEditingController();

  bool _isRecording = false;
  int _secondsRecorded = 0;
  Timer? _timer;

  String? _savedAudioPath;
  bool _isSaving = false;
  double? _latitude;
  double? _longitude;

  // Playback preview
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _isPlayingPreview = false;

  @override
  void initState() {
    super.initState();
    _previewPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() => _isPlayingPreview = (state == PlayerState.playing));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_isRecording) {
      MediaService.stopAudioRecording();
    }
    _previewPlayer.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPerm = await MediaService.hasAudioPermission();
    if (!hasPerm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Microphone permission is required to record ambient audio evidence.'),
            backgroundColor: AppTheme.warningAmber,
          ),
        );
      }
      return;
    }

    // Stop preview if playing
    await _previewPlayer.stop();

    final path = await MediaService.startAudioRecording();
    if (path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize microphone audio stream.')),
        );
      }
      return;
    }

    setState(() {
      _isRecording = true;
      _secondsRecorded = 0;
      _savedAudioPath = null;
    });

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsRecorded++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    final encryptedPath = await MediaService.stopAudioRecording();
    final pos = await LocationService.getCurrentLocation();

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _savedAudioPath = encryptedPath;
      _latitude = pos?.latitude;
      _longitude = pos?.longitude;
    });
  }

  Future<void> _togglePlaybackPreview() async {
    if (_savedAudioPath == null) return;

    if (_isPlayingPreview) {
      await _previewPlayer.stop();
    } else {
      final tempFile = await MediaService.getDecryptedTempFile(_savedAudioPath!);
      if (tempFile != null) {
        await _previewPlayer.play(DeviceFileSource(tempFile.path));
      }
    }
  }

  Future<void> _handleSave() async {
    if (_savedAudioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please record audio before saving.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await _previewPlayer.stop();

    final notes = _notesController.text.trim();
    final title = 'Surrounding Audio Record (${_secondsRecorded}s)';
    final description = notes.isNotEmpty
        ? notes
        : 'Encrypted surrounding ambient audio evidence captured via Safety Toolkit.';

    if (!mounted) return;
    await context.read<ToolkitProvider>().addIncident(
          title: title,
          description: description,
          audioPath: _savedAudioPath,
          latitude: _latitude,
          longitude: _longitude,
        );

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Audio evidence encrypted with AES-256 and safely stored.'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF312E81) : AppTheme.brandPrimaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.mic_none_rounded,
                        color: isDark ? const Color(0xFF818CF8) : AppTheme.brandPrimary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Surrounding Sound Recorder',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Explicitly record ambient surroundings during unsafe encounters. Stored in encrypted app storage.',
              style: TextStyle(
                fontSize: 12.5,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 20),

            // Live Recording or Status Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: _isRecording
                    ? (isDark ? AppTheme.emergencyDarkRed.withValues(alpha: 0.35) : AppTheme.emergencyLightRed)
                    : (_savedAudioPath != null
                        ? (isDark ? const Color(0xFF064E3B) : AppTheme.safeGreenLight)
                        : (isDark ? AppTheme.surfaceDarkElevated : AppTheme.surfaceMuted)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _isRecording
                      ? AppTheme.emergencyRed
                      : (_savedAudioPath != null ? AppTheme.safeGreen : (isDark ? AppTheme.borderDark : AppTheme.borderLight)),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  if (_isRecording) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: AppTheme.emergencyRed,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'RECORDING AMBIENT SOUND',
                          style: TextStyle(
                            color: AppTheme.emergencyRed,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _formatDuration(_secondsRecorded),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.emergencyRed,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      icon: const Icon(Icons.stop),
                      label: const Text('Stop Recording', style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: _stopRecording,
                    ),
                  ] else if (_savedAudioPath != null) ...[
                    const Icon(Icons.check_circle, size: 36, color: AppTheme.safeGreen),
                    const SizedBox(height: 8),
                    Text(
                      'Recording Ready (${_formatDuration(_secondsRecorded)})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          icon: Icon(_isPlayingPreview ? Icons.stop : Icons.play_arrow),
                          label: Text(_isPlayingPreview ? 'Pause' : 'Play Preview'),
                          onPressed: _togglePlaybackPreview,
                        ),
                        const SizedBox(width: 12),
                        TextButton.icon(
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Re-record'),
                          onPressed: _startRecording,
                        ),
                      ],
                    ),
                  ] else ...[
                    Icon(
                      Icons.mic,
                      size: 40,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Tap to start recording surrounding sound',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    SafeButton(
                      text: 'Start Recording Now',
                      icon: Icons.fiber_manual_record,
                      type: SafeButtonType.primary,
                      onPressed: _startRecording,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Notes input
            Text(
              'Observation / Encounter Notes (Optional)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'e.g. Verbal harassment near bus stop, two individuals on scooter',
              ),
            ),
            const SizedBox(height: 20),

            if (_savedAudioPath != null)
              SafeButton(
                text: 'Save to Encrypted Evidence Locker',
                icon: Icons.shield_rounded,
                isLoading: _isSaving,
                onPressed: _handleSave,
              ),
          ],
        ),
      ),
    );
  }
}
