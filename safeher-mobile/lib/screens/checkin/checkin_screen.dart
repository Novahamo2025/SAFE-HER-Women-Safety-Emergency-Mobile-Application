import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/checkin_model.dart';
import '../../core/providers/checkin_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/status_badge.dart';

class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  void _showCreateCheckInSheet(BuildContext context) {
    int selectedMinutes = 30;
    final noteCtrl = TextEditingController();

    final intervals = [15, 30, 45, 60, 120];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Schedule Safety Check-In',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryFor(ctx)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'SvaShield will ask you to confirm your safety at the chosen interval. If missed, selected contacts receive a reminder.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryFor(ctx), height: 1.4),
              ),
              const SizedBox(height: 20),

              const Text('Check-In Interval', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: intervals.map((mins) {
                  final isSelected = selectedMinutes == mins;
                  return ChoiceChip(
                    label: Text(mins >= 60 ? '${mins ~/ 60} Hour${mins > 60 ? "s" : ""}' : '$mins Mins'),
                    selected: isSelected,
                    selectedColor: AppTheme.brandPrimaryLight,
                    labelStyle: TextStyle(
                      color: isSelected ? AppTheme.brandPrimaryDark : AppTheme.textSecondaryFor(ctx),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    onSelected: (selected) {
                      if (selected) setSheetState(() => selectedMinutes = mins);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),

              const Text('Activity Note (Optional)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  hintText: 'e.g. Studying at library, late meeting, solo jogging',
                  prefixIcon: Icon(Icons.edit_note_outlined),
                ),
              ),
              const SizedBox(height: 24),

              SafeButton(
                text: 'Activate Check-In Schedule',
                onPressed: () {
                  context.read<CheckInProvider>().createCheckIn(
                    intervalMinutes: selectedMinutes,
                    note: noteCtrl.text.trim(),
                  );
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Safety check-in scheduled for $selectedMinutes mins from now.'),
                      backgroundColor: AppTheme.safeGreen,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMissedCheckInDialog(BuildContext context, CheckInModel checkIn) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber, size: 28),
            SizedBox(width: 8),
            Text('Missed Check-In Alert'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You missed your scheduled check-in. Please confirm you are safe right now:',
              style: TextStyle(fontSize: 13.5, color: AppTheme.textSecondaryFor(ctx)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.warningLightAmber,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'If unresolved in 3 minutes, your emergency contacts will be notified with your last known location.',
                style: TextStyle(fontSize: 12, color: AppTheme.warningAmber, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CheckInProvider>().acknowledgeMissedCheckIn(checkIn.id ?? 1, false);
            },
            child: const Text('Need Help / Escalate', style: TextStyle(color: AppTheme.emergencyRed)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safeGreen),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CheckInProvider>().acknowledgeMissedCheckIn(checkIn.id ?? 1, true);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Confirmed safe! Check-in updated.')),
              );
            },
            child: const Text('I am Safe'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CheckInProvider>();
    final activeCheckIn = provider.nextActiveCheckIn;
    final allCheckIns = provider.checkIns;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Safety Check-In'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_alarm),
        label: const Text('New Check-In', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showCreateCheckInSheet(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Check-In Card
            if (activeCheckIn != null) ...[
              SafeCard(
                borderColor: AppTheme.safeGreen.withValues(alpha: 0.4),
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF064E3B)
                    : AppTheme.safeGreenLight.withValues(alpha: 0.5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const StatusBadge(
                          label: 'ACTIVE CHECK-IN',
                          type: StatusBadgeType.success,
                          showDot: true,
                        ),
                        Text(
                          'Due at ${activeCheckIn.scheduledTime.hour.toString().padLeft(2, '0')}:${activeCheckIn.scheduledTime.minute.toString().padLeft(2, '0')}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.safeGreen,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.timer, color: Colors.white, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeCheckIn.note.isNotEmpty ? activeCheckIn.note : 'Scheduled Check-In',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryFor(context)),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${activeCheckIn.remainingDuration.inMinutes} mins remaining until check-in',
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondaryFor(context)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SafeButton(
                      text: 'I AM SAFE (CONFIRM NOW)',
                      icon: Icons.check_circle,
                      type: SafeButtonType.primary,
                      onPressed: () {
                        provider.confirmCheckInSafe(activeCheckIn.id ?? 1);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Safety confirmed! Your contacts know you are safe.'),
                            backgroundColor: AppTheme.safeGreen,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              SafeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.alarm_add_outlined, color: AppTheme.brandPrimary, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('No Active Check-In Timer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Set a timer to regularly verify your safety', style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryFor(context))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SafeButton(
                      text: 'Schedule a Check-In',
                      type: SafeButtonType.secondary,
                      icon: Icons.add,
                      onPressed: () => _showCreateCheckInSheet(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // History Section
            Text(
              'Check-In History',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimaryFor(context)),
            ),
            const SizedBox(height: 10),

            if (allCheckIns.isEmpty)
              const EmptyStateWidget(
                icon: Icons.alarm_off,
                title: 'No Check-Ins Yet',
                description: 'Schedule periodic check-ins during late study sessions, solo trips, or evening workouts.',
              )
            else
              ...allCheckIns.map((ci) {
                StatusBadgeType badgeType = StatusBadgeType.neutral;
                if (ci.isConfirmedSafe) badgeType = StatusBadgeType.success;
                if (ci.isMissed) badgeType = StatusBadgeType.warning;
                if (ci.isEscalated) badgeType = StatusBadgeType.error;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SafeCard(
                    padding: const EdgeInsets.all(14),
                    onTap: ci.isMissed ? () => _showMissedCheckInDialog(context, ci) : null,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: ci.isConfirmedSafe
                                ? AppTheme.safeGreenLight
                                : (ci.isMissed ? AppTheme.warningLightAmber : AppTheme.surfaceMuted),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            ci.isConfirmedSafe ? Icons.check : (ci.isMissed ? Icons.warning : Icons.schedule),
                            color: ci.isConfirmedSafe
                                ? AppTheme.safeGreen
                                : (ci.isMissed ? AppTheme.warningAmber : AppTheme.textSecondaryFor(context)),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ci.note, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              Text(
                                '${ci.intervalMinutes}m timer • ${ci.scheduledTime.hour.toString().padLeft(2, '0')}:${ci.scheduledTime.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryFor(context)),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: ci.status.replaceAll('_', ' '),
                          type: badgeType,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 60), // Space for FAB
          ],
        ),
      ),
    );
  }
}
