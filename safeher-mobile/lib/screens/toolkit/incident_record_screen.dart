import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/incident_model.dart';
import '../../core/providers/toolkit_provider.dart';
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Record Incident / Evidence',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        audioTimer?.cancel();
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Consent & Privacy Card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.infoLightBlue,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.infoBlue.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, color: AppTheme.infoBlue, size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Evidence is optional. You control whether it is stored or uploaded. Stored locally with on-device encryption.',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Title
                const Text('Incident Title', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g. Suspicious car, harassment on bus route',
                    prefixIcon: Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),

                // Description
                const Text('Detailed Description / Observation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Describe vehicle numbers, descriptions, locations, exact words, or observations...',
                  ),
                ),
                const SizedBox(height: 16),

                // Audio Evidence Simulator
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: isRecordingAudio ? AppTheme.emergencyRed : AppTheme.brandPrimary,
                        ),
                        icon: Icon(isRecordingAudio ? Icons.stop : Icons.mic),
                        onPressed: () {
                          if (isRecordingAudio) {
                            audioTimer?.cancel();
                            setSheetState(() => isRecordingAudio = false);
                          } else {
                            setSheetState(() {
                              isRecordingAudio = true;
                              audioSeconds = 0;
                            });
                            audioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
                              setSheetState(() => audioSeconds++);
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isRecordingAudio ? 'Recording Audio Evidence...' : 'Record Audio Memo',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                                color: isRecordingAudio ? AppTheme.emergencyRed : AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              isRecordingAudio
                                  ? '${(audioSeconds ~/ 60).toString().padLeft(2, "0")}:${(audioSeconds % 60).toString().padLeft(2, "0")}'
                                  : 'Tap mic icon to record encrypted audio memo',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                SafeButton(
                  text: 'Save Encrypted Evidence',
                  icon: Icons.save_outlined,
                  onPressed: () async {
                    if (descCtrl.text.trim().isEmpty && titleCtrl.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Please enter an incident description or title.')),
                      );
                      return;
                    }

                    audioTimer?.cancel();
                    final pos = await LocationService.getCurrentLocation();

                    if (context.mounted) {
                      await context.read<ToolkitProvider>().addIncident(
                        title: titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : 'Incident Record',
                        description: descCtrl.text.trim(),
                        latitude: pos?.latitude,
                        longitude: pos?.longitude,
                        audioPath: audioSeconds > 0 ? 'encrypted_audio_${DateTime.now().millisecondsSinceEpoch}.m4a' : null,
                      );
                    }

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Incident evidence securely stored locally.'),
                          backgroundColor: AppTheme.safeGreen,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteIncident(BuildContext context, IncidentModel incident) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Incident Evidence?'),
        content: const Text('This will permanently erase this encrypted incident note from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergencyRed),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<ToolkitProvider>().deleteIncident(incident.id);
            },
            child: const Text('Delete Record'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolkit = context.watch<ToolkitProvider>();
    final incidents = toolkit.incidents;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Incident & Evidence Locker'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.note_add),
        label: const Text('New Record', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showNewIncidentSheet(context),
      ),
      body: incidents.isEmpty
          ? EmptyStateWidget(
              icon: Icons.shield_moon_outlined,
              title: 'No Incident Records Yet',
              description: 'Your encrypted notes, photos, and audio recordings will be stored here with privacy protection.',
              buttonText: 'Record First Incident',
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
                      color: AppTheme.safeGreenLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.safeGreen.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.enhanced_encryption, color: AppTheme.safeGreen, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'All records are stored locally with on-device encryption and will never be automatically uploaded without explicit consent.',
                            style: TextStyle(fontSize: 12, color: AppTheme.safeGreenDark, fontWeight: FontWeight.w600),
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
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.emergencyRed),
                                  onPressed: () => _confirmDeleteIncident(context, incident),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              incident.description,
                              style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const StatusBadge(
                                      label: 'ENCRYPTED LOCAL',
                                      type: StatusBadgeType.success,
                                    ),
                                    if (incident.audioPath != null) ...[
                                      const SizedBox(width: 6),
                                      const StatusBadge(label: 'AUDIO MEMO', type: StatusBadgeType.info),
                                    ],
                                  ],
                                ),
                                Text(
                                  '${incident.timestamp.day}/${incident.timestamp.month} ${incident.timestamp.hour.toString().padLeft(2, '0')}:${incident.timestamp.minute.toString().padLeft(2, '0')}',
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
