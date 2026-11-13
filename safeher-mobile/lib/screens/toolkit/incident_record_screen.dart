import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_provider.dart';
import '../../core/models/incident_model.dart';
import '../../core/providers/toolkit_provider.dart';
import '../../core/services/media_service.dart';
import '../../core/theme/app_theme.dart';
import '../../services/location_service.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/status_badge.dart';

class IncidentRecordScreen extends StatefulWidget {
  const IncidentRecordScreen({super.key});

  @override
  State<IncidentRecordScreen> createState() => _IncidentRecordScreenState();
}

class _IncidentRecordScreenState extends State<IncidentRecordScreen> {
  void _showNewIncidentSheet(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    bool isRecordingAudio = false;
    int audioSeconds = 0;
    Timer? audioTimer;

    String? recordedAudioPath;
    String? capturedPhotoPath;
    String? recordedVideoPath;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
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
                      Text(
                        'Record Safety Evidence',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () async {
                          if (isRecordingAudio) {
                            await MediaService.stopAudioRecording();
                            audioTimer?.cancel();
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Privacy & Security Notice
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDarkElevated : AppTheme.infoLightBlue,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? AppTheme.borderDark : AppTheme.infoBlue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_rounded, color: AppTheme.infoBlue, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Evidence is saved in app-private storage. Deletion requires your account password for safety.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Title Field
                  Text(
                    'Incident Title',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Suspicious vehicle, stalking on route',
                      prefixIcon: Icon(Icons.title_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Description Field
                  Text(
                    'Observations & Details',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Vehicle numbers, physical descriptions, landmarks, or exact words spoken...',
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Safety Media Capture Section
                  Text(
                    'Capture Evidence (Photo, Video, Audio)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Media Action Buttons
                  Row(
                    children: [
                      // Photo Capture Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: capturedPhotoPath != null
                                  ? AppTheme.safeGreen
                                  : (isDark ? AppTheme.borderDark : AppTheme.borderMedium),
                            ),
                            backgroundColor: capturedPhotoPath != null
                                ? (isDark ? const Color(0xFF064E3B) : AppTheme.safeGreenLight)
                                : null,
                          ),
                          icon: Icon(
                            capturedPhotoPath != null ? Icons.check_circle : Icons.camera_alt_outlined,
                            size: 18,
                            color: capturedPhotoPath != null ? AppTheme.safeGreen : null,
                          ),
                          label: Text(
                            capturedPhotoPath != null ? 'Photo Added' : 'Photo',
                            style: TextStyle(
                              fontSize: 12,
                              color: capturedPhotoPath != null ? AppTheme.safeGreen : null,
                            ),
                          ),
                          onPressed: () async {
                            final photoPath = await MediaService.capturePhoto();
                            if (photoPath != null) {
                              setSheetState(() => capturedPhotoPath = photoPath);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Video Record Button
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: recordedVideoPath != null
                                  ? AppTheme.safeGreen
                                  : (isDark ? AppTheme.borderDark : AppTheme.borderMedium),
                            ),
                            backgroundColor: recordedVideoPath != null
                                ? (isDark ? const Color(0xFF064E3B) : AppTheme.safeGreenLight)
                                : null,
                          ),
                          icon: Icon(
                            recordedVideoPath != null ? Icons.check_circle : Icons.videocam_outlined,
                            size: 18,
                            color: recordedVideoPath != null ? AppTheme.safeGreen : null,
                          ),
                          label: Text(
                            recordedVideoPath != null ? 'Video Added' : 'Video',
                            style: TextStyle(
                              fontSize: 12,
                              color: recordedVideoPath != null ? AppTheme.safeGreen : null,
                            ),
                          ),
                          onPressed: () async {
                            final videoPath = await MediaService.recordVideo();
                            if (videoPath != null) {
                              setSheetState(() => recordedVideoPath = videoPath);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Audio Recording Bar
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.surfaceDarkElevated : AppTheme.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRecordingAudio
                            ? AppTheme.emergencyRed
                            : (recordedAudioPath != null
                                ? AppTheme.safeGreen
                                : (isDark ? AppTheme.borderDark : Colors.transparent)),
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton.filled(
                          style: IconButton.styleFrom(
                            backgroundColor: isRecordingAudio
                                ? AppTheme.emergencyRed
                                : (recordedAudioPath != null
                                    ? AppTheme.safeGreen
                                    : AppTheme.brandPrimary),
                          ),
                          icon: Icon(
                            isRecordingAudio
                                ? Icons.stop
                                : (recordedAudioPath != null ? Icons.check : Icons.mic),
                          ),
                          onPressed: () async {
                            if (isRecordingAudio) {
                              audioTimer?.cancel();
                              final path = await MediaService.stopAudioRecording();
                              setSheetState(() {
                                isRecordingAudio = false;
                                if (path != null) recordedAudioPath = path;
                              });
                            } else {
                              final path = await MediaService.startAudioRecording();
                              if (path != null) {
                                setSheetState(() {
                                  isRecordingAudio = true;
                                  audioSeconds = 0;
                                  recordedAudioPath = null;
                                });
                                audioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                                  setSheetState(() => audioSeconds++);
                                });
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Microphone permission required to record audio.'),
                                      backgroundColor: AppTheme.warningAmber,
                                    ),
                                  );
                                }
                              }
                            }
                          },
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRecordingAudio
                                    ? 'Recording Audio Evidence...'
                                    : (recordedAudioPath != null
                                        ? 'Audio Memo Recorded'
                                        : 'Audio Memo'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: isRecordingAudio
                                      ? AppTheme.emergencyRed
                                      : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary),
                                ),
                              ),
                              Text(
                                isRecordingAudio
                                    ? '${(audioSeconds ~/ 60).toString().padLeft(2, "0")}:${(audioSeconds % 60).toString().padLeft(2, "0")} • Tap to stop'
                                    : (recordedAudioPath != null
                                        ? 'Audio ready to be saved securely'
                                        : 'Tap mic icon to record voice memo'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Photo Thumbnail Preview (if captured)
                  if (capturedPhotoPath != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List?>(
                            future: MediaService.decryptEvidenceBytes(capturedPhotoPath!),
                            builder: (ctx, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                width: 60,
                                height: 60,
                                color: AppTheme.surfaceMuted,
                                child: const Icon(Icons.lock, size: 24, color: AppTheme.brandPrimary),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Photo Evidence Attached', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                capturedPhotoPath!.split(Platform.pathSeparator).last,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: AppTheme.emergencyRed, size: 20),
                          onPressed: () {
                            MediaService.deleteEvidenceFile(capturedPhotoPath!);
                            setSheetState(() => capturedPhotoPath = null);
                          },
                        ),
                      ],
                    ),
                  ],

                  // Video Attachment Preview (if recorded)
                  if (recordedVideoPath != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Video Evidence Attached', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(
                                recordedVideoPath!.split(Platform.pathSeparator).last,
                                style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel, color: AppTheme.emergencyRed, size: 20),
                          onPressed: () {
                            MediaService.deleteEvidenceFile(recordedVideoPath!);
                            setSheetState(() => recordedVideoPath = null);
                          },
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 22),

                  // Save Button
                  SafeButton(
                    text: 'Save Encrypted Evidence',
                    icon: Icons.shield_rounded,
                    isLoading: isSaving,
                    onPressed: () async {
                      if (descCtrl.text.trim().isEmpty &&
                          titleCtrl.text.trim().isEmpty &&
                          capturedPhotoPath == null &&
                          recordedAudioPath == null &&
                          recordedVideoPath == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please capture evidence or enter observations.')),
                        );
                        return;
                      }

                      setSheetState(() => isSaving = true);

                      if (isRecordingAudio) {
                        audioTimer?.cancel();
                        final path = await MediaService.stopAudioRecording();
                        if (path != null) recordedAudioPath = path;
                      }

                      final pos = await LocationService.getCurrentLocation();

                      if (context.mounted) {
                        await context.read<ToolkitProvider>().addIncident(
                              title: titleCtrl.text.trim().isNotEmpty
                                  ? titleCtrl.text.trim()
                                  : 'Safety Evidence Note',
                              description: descCtrl.text.trim(),
                              latitude: pos?.latitude,
                              longitude: pos?.longitude,
                              audioPath: recordedAudioPath,
                              photoPath: capturedPhotoPath,
                              videoPath: recordedVideoPath,
                            );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Safety evidence encrypted and securely stored.'),
                            backgroundColor: AppTheme.safeGreen,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- Password-Protected Deletion Dialog ---
  void _confirmDeleteWithPassword(BuildContext context, IncidentModel incident) {
    final passwordCtrl = TextEditingController();
    bool isDeleting = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;

          return AlertDialog(
            backgroundColor: isDark ? AppTheme.surfaceDark : AppTheme.surfaceWhite,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.emergencyLightRed,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.security, color: AppTheme.emergencyRed, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Security Verification',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'To delete "${incident.title}", enter your SvaShield account password:',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Account Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    errorText: errorMsg,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Evidence cannot be recovered once removed.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.emergencyRed,
                  foregroundColor: Colors.white,
                ),
                onPressed: isDeleting
                    ? null
                    : () async {
                        final input = passwordCtrl.text.trim();
                        if (input.isEmpty) {
                          setDialogState(() => errorMsg = 'Account password is required');
                          return;
                        }

                        setDialogState(() {
                          isDeleting = true;
                          errorMsg = null;
                        });

                        final authProvider = context.read<AuthProvider>();
                        final isValid = await authProvider.verifyPassword(input);

                        if (!isValid) {
                          setDialogState(() {
                            isDeleting = false;
                            errorMsg = 'Incorrect password. Verification failed.';
                          });
                          return;
                        }

                        // Verified successfully -> Delete incident and files
                        if (context.mounted) {
                          await context.read<ToolkitProvider>().deleteIncident(incident.id);
                        }

                        if (ctx.mounted) Navigator.pop(ctx);

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Evidence record permanently deleted.'),
                              backgroundColor: AppTheme.safeGreen,
                            ),
                          );
                        }
                      },
                child: isDeleting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify & Delete'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolkit = context.watch<ToolkitProvider>();
    final incidents = toolkit.incidents;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Incident & Evidence Locker'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_outlined),
        label: const Text('Capture Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showNewIncidentSheet(context),
      ),
      body: incidents.isEmpty
          ? EmptyStateWidget(
              icon: Icons.shield_moon_outlined,
              title: 'No Incident Records Yet',
              description: 'Photos, videos, and audio recordings captured here will be safely stored with password-protected deletion.',
              buttonText: 'Capture First Evidence',
              onButtonPressed: () => _showNewIncidentSheet(context),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF064E3B) : AppTheme.safeGreenLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.safeGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.enhanced_encryption, color: AppTheme.safeGreen, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All records are stored in app-private storage. Deletion requires password verification.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white : AppTheme.safeGreenDark,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  ...incidents.map((incident) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SafeCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    incident.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.emergencyRed),
                                  tooltip: 'Password Protected Delete',
                                  onPressed: () => _confirmDeleteWithPassword(context, incident),
                                ),
                              ],
                            ),
                            if (incident.description.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                incident.description,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],

                            // Media indicators
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                const StatusBadge(
                                  label: 'ENCRYPTED',
                                  type: StatusBadgeType.success,
                                ),
                                if (incident.audioPath != null)
                                  const StatusBadge(label: 'AUDIO RECORDING', type: StatusBadgeType.info),
                                if (incident.photoPath != null)
                                  const StatusBadge(label: 'PHOTO CAPTURED', type: StatusBadgeType.info),
                                if (incident.videoPath != null)
                                  const StatusBadge(label: 'VIDEO RECORDING', type: StatusBadgeType.warning),
                              ],
                            ),

                            // Timestamp and location coordinates
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (incident.latitude != null && incident.longitude != null)
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on, size: 13, color: AppTheme.textTertiary),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${incident.latitude!.toStringAsFixed(4)}, ${incident.longitude!.toStringAsFixed(4)}',
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                                      ),
                                    ],
                                  )
                                else
                                  const SizedBox(),
                                Text(
                                  '${incident.timestamp.day}/${incident.timestamp.month}/${incident.timestamp.year} ${incident.timestamp.hour.toString().padLeft(2, '0')}:${incident.timestamp.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 60),
                ],
              ),
            ),
    );
  }
}
