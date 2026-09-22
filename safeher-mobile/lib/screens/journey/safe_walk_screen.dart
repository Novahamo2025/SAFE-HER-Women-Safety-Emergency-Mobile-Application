import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class SafeWalkScreen extends StatefulWidget {
  const SafeWalkScreen({super.key});

  @override
  State<SafeWalkScreen> createState() => _SafeWalkScreenState();
}

class _SafeWalkScreenState extends State<SafeWalkScreen> {
  final TextEditingController _destController = TextEditingController();
  int _estimatedMinutes = 20;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safe Walk / Journey'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Where are you heading?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on, color: AppTheme.emergencyRed),
                hintText: 'e.g. Home, Metro Station, College Hostel',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Expected Duration',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$_estimatedMinutes minutes to reach destination',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            Slider(
              value: _estimatedMinutes.toDouble(),
              min: 5,
              max: 120,
              divisions: 23,
              activeColor: AppTheme.emergencyRed,
              label: '$_estimatedMinutes mins',
              onChanged: (val) => setState(() => _estimatedMinutes = val.toInt()),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'If you do not confirm arrival within 5 minutes of your ETA, SafeHer automatically alerts your contacts.',
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('START MONITORED JOURNEY'),
                onPressed: () {
                  if (_destController.text.isNotEmpty) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Safe Walk active towards ${_destController.text}'),
                        backgroundColor: AppTheme.safeGreen,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
