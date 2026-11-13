import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/contact_provider.dart';
import '../../core/providers/emergency_provider.dart';
import '../../core/providers/journey_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/status_badge.dart';
import '../emergency/sos_active_screen.dart';

class SafeWalkScreen extends StatefulWidget {
  const SafeWalkScreen({super.key});

  @override
  State<SafeWalkScreen> createState() => _SafeWalkScreenState();
}

class _SafeWalkScreenState extends State<SafeWalkScreen> {
  final TextEditingController _destController = TextEditingController();
  int _estimatedMinutes = 20;

  final List<String> _presets = [
    'Home',
    'Hostel',
    'Metro Station',
    'Office / Work',
    'Bus Terminal'
  ];

  @override
  void dispose() {
    _destController.dispose();
    super.dispose();
  }

  void _startJourney() {
    final dest = _destController.text.trim();
    if (dest.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your journey destination.'),
          backgroundColor: AppTheme.warningAmber,
        ),
      );
      return;
    }

    context.read<JourneyProvider>().startJourney(
          destination: dest,
          durationMinutes: _estimatedMinutes,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text('Safe Walk active towards $dest for $_estimatedMinutes mins'),
        backgroundColor: AppTheme.safeGreen,
      ),
    );
  }

  void _showAddCheckpointDialog() {
    final checkpointCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Route Checkpoint'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add a landmark or transit note to your monitored journey:',
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: checkpointCtrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Boarded Metro Blue Line, crossed bridge',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (checkpointCtrl.text.isNotEmpty) {
                context
                    .read<JourneyProvider>()
                    .addCheckpoint(checkpointCtrl.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Add Checkpoint'),
          ),
        ],
      ),
    );
  }

  void _showArrivalSafetyModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppTheme.surfaceWhite,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.warningLightAmber,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.alarm_on,
                  color: AppTheme.warningAmber, size: 36),
            ),
            const SizedBox(height: 16),
            Text(
              'Have You Reached Safely?',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryFor(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'Your estimated arrival time has reached. Please confirm your safety to prevent escalating alerts to your trusted contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.5,
                  color: AppTheme.textSecondaryFor(context),
                  height: 1.4),
            ),
            const SizedBox(height: 24),
            SafeButton(
              text: 'YES, I AM SAFE',
              icon: Icons.check_circle_outline,
              type: SafeButtonType.primary,
              onPressed: () {
                context.read<JourneyProvider>().completeJourneySafely();
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Safe Walk completed. Glad you reached safely!'),
                    backgroundColor: AppTheme.safeGreen,
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SafeButton(
              text: 'NEED HELP / TRIGGER SOS',
              icon: Icons.emergency,
              type: SafeButtonType.danger,
              onPressed: () async {
                Navigator.pop(ctx);
                final contacts = context.read<ContactProvider>().contacts;
                final emergency = context.read<EmergencyProvider>();
                await emergency.triggerEmergency(
                    contacts: contacts, userName: 'SafeHer User');
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SosActiveScreen(
                          latitude: emergency.latitude,
                          longitude: emergency.longitude),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final journeyProvider = context.watch<JourneyProvider>();
    final activeJourney = journeyProvider.activeJourney;

    // Check if safety prompt is needed
    if (journeyProvider.shouldPromptSafetyArrival) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        journeyProvider.dismissArrivalPrompt();
        _showArrivalSafetyModal();
      });
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Safe Walk / Journey'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (activeJourney != null && activeJourney.isActive) ...[
              // Active Journey Card
              SafeCard(
                borderColor: isDark
                    ? const Color(0xFF334155)
                    : AppTheme.brandPrimary.withValues(alpha: 0.3),
                backgroundColor: isDark
                    ? const Color(0xFF1E293B)
                    : AppTheme.brandPrimaryLight.withValues(alpha: 0.3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const StatusBadge(
                          label: 'JOURNEY MONITORED',
                          type: StatusBadgeType.info,
                          showDot: true,
                        ),
                        Text(
                          'ETA ${activeJourney.expectedArrival.hour.toString().padLeft(2, '0')}:${activeJourney.expectedArrival.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.textPrimaryDark
                                  : AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF4F46E5)
                                : AppTheme.brandPrimary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.directions_walk,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Heading Towards',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondary)),
                              Text(
                                activeJourney.destination,
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark
                                        ? AppTheme.textPrimaryDark
                                        : AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: activeJourney.progressPercentage,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? const Color(0xFF334155)
                            : Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(isDark
                            ? const Color(0xFF818CF8)
                            : AppTheme.brandPrimary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Started at ${activeJourney.startedAt.hour.toString().padLeft(2, '0')}:${activeJourney.startedAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppTheme.textTertiaryDark
                                  : AppTheme.textTertiary),
                        ),
                        Text(
                          '${activeJourney.remainingDuration.inMinutes} mins remaining',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF818CF8)
                                  : AppTheme.brandPrimary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Checkpoints list
                    Text('Journey Timeline & Checkpoints:',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    ...activeJourney.checkpoints.map((cp) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 14, color: AppTheme.safeGreen),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(cp,
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          color: isDark
                                              ? AppTheme.textSecondaryDark
                                              : AppTheme.textSecondary))),
                            ],
                          ),
                        )),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.add_location_alt_outlined,
                                size: 18),
                            label: const Text('Add Checkpoint',
                                style: TextStyle(fontSize: 13)),
                            onPressed: _showAddCheckpointDialog,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.safeGreen),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('I Have Arrived',
                                style: TextStyle(fontSize: 13)),
                            onPressed: () =>
                                journeyProvider.completeJourneySafely(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () => journeyProvider.cancelJourney(),
                        child: const Text('Cancel Safe Walk',
                            style: TextStyle(
                                color: AppTheme.emergencyRed, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ] else ...[
              // Start New Journey Card
              SafeCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start a Monitored Journey',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'SvaShield tracks your expected arrival and alerts your trusted contacts if you do not confirm reaching safely within the grace period.',
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondary,
                          height: 1.4),
                    ),
                    const SizedBox(height: 20),

                    // Destination Input
                    Text('Destination',
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _destController,
                      decoration: InputDecoration(
                        hintText: 'e.g. Home, Sector 18 Metro, Hostel',
                        prefixIcon: Icon(Icons.location_on_outlined,
                            color: isDark
                                ? const Color(0xFF818CF8)
                                : AppTheme.brandPrimary),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Quick presets
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _presets.map((preset) {
                        return ActionChip(
                          label: Text(preset,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.textPrimaryDark
                                      : AppTheme.textPrimary)),
                          backgroundColor: isDark
                              ? const Color(0xFF273449)
                              : AppTheme.surfaceMuted,
                          onPressed: () =>
                              setState(() => _destController.text = preset),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Expected Duration Slider
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Estimated Duration',
                            style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppTheme.textPrimaryDark
                                    : AppTheme.textPrimary)),
                        Text(
                          '$_estimatedMinutes minutes',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF818CF8)
                                  : AppTheme.brandPrimary),
                        ),
                      ],
                    ),
                    Slider(
                      value: _estimatedMinutes.toDouble(),
                      min: 5,
                      max: 120,
                      divisions: 23,
                      activeColor: isDark
                          ? const Color(0xFF818CF8)
                          : AppTheme.brandPrimary,
                      onChanged: (val) =>
                          setState(() => _estimatedMinutes = val.toInt()),
                    ),
                    const SizedBox(height: 8),

                    // Grace Period info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : AppTheme.infoLightBlue,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF334155)
                                : AppTheme.infoBlue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.timer_outlined,
                              color: isDark
                                  ? const Color(0xFF60A5FA)
                                  : AppTheme.infoBlue,
                              size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Grace period: You will receive a safety prompt at ETA + 5 minutes before contacts are notified.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    SafeButton(
                      text: 'Start Safe Walk',
                      icon: Icons.navigation_outlined,
                      onPressed: _startJourney,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Past Journeys Summary
            if (journeyProvider.pastJourneys.isNotEmpty) ...[
              Text(
                'Recent Journeys',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimary),
              ),
              const SizedBox(height: 10),
              ...journeyProvider.pastJourneys.take(3).map((pj) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: SafeCard(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: pj.isCompleted
                                ? (isDark
                                    ? const Color(0xFF064E3B)
                                    : AppTheme.safeGreenLight)
                                : (isDark
                                    ? const Color(0xFF334155)
                                    : AppTheme.surfaceMuted),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            pj.isCompleted ? Icons.check : Icons.close,
                            color: pj.isCompleted
                                ? AppTheme.safeGreen
                                : (isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondary),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(pj.destination,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark
                                          ? AppTheme.textPrimaryDark
                                          : AppTheme.textPrimary)),
                              Text(
                                '${pj.startedAt.day}/${pj.startedAt.month} • ${pj.durationMinutes} mins',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: isDark
                                        ? AppTheme.textSecondaryDark
                                        : AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: pj.status,
                          type: pj.isCompleted
                              ? StatusBadgeType.success
                              : StatusBadgeType.neutral,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
