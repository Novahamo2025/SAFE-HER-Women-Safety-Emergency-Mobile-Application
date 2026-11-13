import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/emergency_provider.dart';
import '../../core/providers/toolkit_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/security_pin_dialog.dart';
import '../../widgets/status_badge.dart';

class SosActiveScreen extends StatefulWidget {
  final double latitude;
  final double longitude;

  const SosActiveScreen({
    super.key,
    required this.latitude,
    required this.longitude,
  });

  @override
  State<SosActiveScreen> createState() => _SosActiveScreenState();
}

class _SosActiveScreenState extends State<SosActiveScreen> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  late Animation<double> _blinkAnimation;
  Timer? _ticker;
  int _secondsActive = 0;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _blinkAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _secondsActive++);
    });
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _ticker?.cancel();
    super.dispose();
  }

  String _formatDuration(int totalSeconds) {
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  Future<void> _handleEndEmergency() async {
    final enteredPin = await SecurityPinDialog.show(
      context,
      title: 'End Emergency SOS',
      message: 'Enter your 4-digit security PIN to confirm you are safe and stop live location sharing:',
      actionButtonText: 'I am Safe (End SOS)',
    );

    if (enteredPin != null && enteredPin.isNotEmpty && mounted) {
      final emergencyProvider = context.read<EmergencyProvider>();
      final success = await emergencyProvider.endEmergency(pin: enteredPin);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(); // Return to dashboard
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Emergency resolved safely. Live location sharing stopped.'),
              backgroundColor: AppTheme.safeGreen,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(emergencyProvider.errorMessage ?? 'Cancellation failed. Incorrect PIN or network error.'),
              backgroundColor: AppTheme.emergencyRed,
            ),
          );
        }
      }
    }
  }

  void _showQuickNoteDialog() {
    final noteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Emergency Incident Note'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a brief note about what is happening. This is saved securely to your emergency record:',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. In an auto rickshaw, driver taking detour near market...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (noteCtrl.text.isNotEmpty) {
                context.read<ToolkitProvider>().addIncident(
                  title: 'SOS Emergency Note',
                  description: noteCtrl.text.trim(),
                  latitude: widget.latitude,
                  longitude: widget.longitude,
                );
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Note securely logged to emergency record.')),
              );
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emergency = context.watch<EmergencyProvider>();
    final toolkit = context.watch<ToolkitProvider>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _handleEndEmergency();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.surfaceWhite,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppTheme.emergencyDarkRed,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'EMERGENCY SOS ACTIVE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _formatDuration(_secondsActive),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            // High Visibility Alert Strip
            AnimatedBuilder(
              animation: _blinkAnimation,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  color: AppTheme.emergencyRed.withValues(alpha: _blinkAnimation.value),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sensors, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Live GPS & Alerts Broadcast Active',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                    ],
                  ),
                );
              },
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Location & Radar Card
                    SafeCard(
                      borderColor: AppTheme.emergencyRed.withValues(alpha: 0.3),
                      backgroundColor: AppTheme.emergencyLightRed.withValues(alpha: 0.4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  color: AppTheme.emergencyRed,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.my_location, color: Colors.white, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Live Location Stream',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    Text(
                                      'Accuracy: ±${emergency.accuracy.toStringAsFixed(1)}m • Updated now',
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              const StatusBadge(
                                label: 'STREAMING',
                                type: StatusBadgeType.error,
                                showDot: true,
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LATITUDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textTertiary)),
                                    Text(
                                      emergency.latitude.toStringAsFixed(5),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: AppTheme.borderLight),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LONGITUDE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.textTertiary)),
                                    Text(
                                      emergency.longitude.toStringAsFixed(5),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: AppTheme.borderLight),
                                const Icon(Icons.map_outlined, color: AppTheme.brandPrimary, size: 24),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Location sharing is temporary and active only during this emergency.',
                            style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Contact Notification Delivery Status
                    const Text(
                      'Trusted Contacts Notification Status',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),

                    if (emergency.deliveryStatuses.isEmpty)
                      const SafeCard(
                        padding: EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: AppTheme.safeGreen, size: 20),
                            SizedBox(width: 10),
                            Text('Emergency alerts dispatched to your contacts.', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ...emergency.deliveryStatuses.map((delivery) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceWhite,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.safeGreenLight,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check, color: AppTheme.safeGreen, size: 16),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        delivery.contactName,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                      ),
                                      Text(
                                        '${delivery.phone} • ${delivery.channel}',
                                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                StatusBadge(
                                  label: delivery.status,
                                  type: StatusBadgeType.success,
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 20),

                    // Quick Emergency Actions Row
                    const Text(
                      'Emergency Tools',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Siren deterrent button
                        Expanded(
                          child: SafeCard(
                            padding: const EdgeInsets.all(12),
                            backgroundColor: toolkit.isSirenActive ? AppTheme.emergencyLightRed : AppTheme.surfaceWhite,
                            borderColor: toolkit.isSirenActive ? AppTheme.emergencyRed : AppTheme.borderLight,
                            onTap: () => toolkit.toggleSiren(),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  toolkit.isSirenActive ? Icons.volume_up : Icons.volume_mute,
                                  color: toolkit.isSirenActive ? AppTheme.emergencyRed : AppTheme.textPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  toolkit.isSirenActive ? 'SIREN ON' : 'Deterrent Siren',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: toolkit.isSirenActive ? AppTheme.emergencyRed : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Quick Note
                        Expanded(
                          child: SafeCard(
                            padding: const EdgeInsets.all(12),
                            onTap: _showQuickNoteDialog,
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.note_add_outlined, color: AppTheme.brandPrimary, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Record Note',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Large END EMERGENCY button
                    SafeButton(
                      text: 'I AM SAFE — END EMERGENCY',
                      icon: Icons.check_circle_outline,
                      type: SafeButtonType.danger,
                      height: 56,
                      onPressed: _handleEndEmergency,
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Requires your 4-digit security PIN to confirm resolution',
                        style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
