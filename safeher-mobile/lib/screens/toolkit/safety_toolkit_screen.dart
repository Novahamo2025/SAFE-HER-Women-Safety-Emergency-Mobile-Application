import 'package:flutter/material.dart';
import 'package:torch_light/torch_light.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';

class SafetyToolkitScreen extends StatefulWidget {
  const SafetyToolkitScreen({super.key});

  @override
  State<SafetyToolkitScreen> createState() => _SafetyToolkitScreenState();
}

class _SafetyToolkitScreenState extends State<SafetyToolkitScreen> {
  bool _isFlashlightOn = false;
  bool _isSirenPlaying = false;

  Future<void> _toggleFlashlight() async {
    try {
      if (_isFlashlightOn) {
        await TorchLight.disableTorch();
        setState(() => _isFlashlightOn = false);
      } else {
        await TorchLight.enableTorch();
        setState(() => _isFlashlightOn = true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flashlight control unavailable on this device')),
      );
    }
  }

  void _toggleSiren() {
    setState(() {
      _isSirenPlaying = !_isSirenPlaying;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSirenPlaying ? 'High-decibel deterrent siren activated!' : 'Siren stopped.'),
        backgroundColor: _isSirenPlaying ? AppTheme.emergencyRed : AppTheme.safeGreen,
      ),
    );
  }

  Future<void> _callHelpline(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  void dispose() {
    if (_isFlashlightOn) {
      TorchLight.disableTorch().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Toolkit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Instant Tools',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                // Flashlight Toggle
                Expanded(
                  child: InkWell(
                    onTap: _toggleFlashlight,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _isFlashlightOn ? Colors.amber.shade100 : Colors.white,
                        border: Border.all(
                          color: _isFlashlightOn ? Colors.amber : Colors.grey.shade200,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _isFlashlightOn ? Icons.flash_on : Icons.flash_off,
                            size: 40,
                            color: _isFlashlightOn ? Colors.amber.shade800 : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isFlashlightOn ? 'FLASHLIGHT ON' : 'Flashlight',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isFlashlightOn ? Colors.amber.shade900 : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Loud Siren Toggle
                Expanded(
                  child: InkWell(
                    onTap: _toggleSiren,
                    borderRadius: BorderRadius.circular(16),
                    child: Ink(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _isSirenPlaying ? Colors.red.shade100 : Colors.white,
                        border: Border.all(
                          color: _isSirenPlaying ? AppTheme.emergencyRed : Colors.grey.shade200,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _isSirenPlaying ? Icons.volume_up : Icons.volume_off,
                            size: 40,
                            color: _isSirenPlaying ? AppTheme.emergencyRed : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isSirenPlaying ? 'SIREN PLAYING' : 'Loud Siren',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _isSirenPlaying ? AppTheme.emergencyRed : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            const Text(
              'Emergency Helplines (India)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 12),

            _buildHelplineTile('112', 'National Emergency Unified Hotline', 'Police, Fire, Ambulance'),
            _buildHelplineTile('1091', 'Women Helpline (Domestic & Public)', 'Dedicated round-the-clock support'),
            _buildHelplineTile('181', 'Women in Distress Helpline', 'National Commission for Women'),
            _buildHelplineTile('1098', 'Childline Helpline', 'Children emergency & protection'),
          ],
        ),
      ),
    );
  }

  Widget _buildHelplineTile(String number, String title, String subtitle) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.emergencyRed.withOpacity(0.1),
          child: const Icon(Icons.phone, color: AppTheme.emergencyRed),
        ),
        title: Text('$title ($number)', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.emergencyRed,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          onPressed: () => _callHelpline(number),
          child: const Text('CALL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
