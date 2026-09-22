import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

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

class _SosActiveScreenState extends State<SosActiveScreen> {
  final TextEditingController _pinController = TextEditingController();

  void _showCancelDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Emergency?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your security PIN to confirm you are safe:'),
            const SizedBox(height: 12),
            TextField(
              controller: _pinController,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter 4-6 digit PIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.safeGreen),
            onPressed: () {
              Navigator.pop(ctx); // Close dialog
              Navigator.pop(context); // Return to dashboard
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Emergency marked resolved. Contacts notified.')),
              );
            },
            child: const Text('I am Safe (End SOS)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _showCancelDialog();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: AppTheme.emergencyDarkRed,
          title: const Text(
            'EMERGENCY SOS ACTIVE',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Warning strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: AppTheme.emergencyRed,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.warning, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Streaming live GPS coordinates to contacts',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Coordinates Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.my_location, color: AppTheme.emergencyRed, size: 32),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Current Location', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  'Lat: ${widget.latitude.toStringAsFixed(5)}, Lng: ${widget.longitude.toStringAsFixed(5)}',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Emergency Delivery Status',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 10),

                    // Delivery status list
                    _buildDeliveryItem(
                      name: 'Papa (Priority 1)',
                      phone: '+91 98765 43210',
                      channel: 'Native SMS',
                      status: 'Dispatched',
                      icon: Icons.check_circle,
                      iconColor: AppTheme.safeGreen,
                    ),
                    _buildDeliveryItem(
                      name: 'Mom (Priority 2)',
                      phone: '+91 98765 43211',
                      channel: 'Server Gateway',
                      status: 'Delivered',
                      icon: Icons.check_circle,
                      iconColor: AppTheme.safeGreen,
                    ),
                    _buildDeliveryItem(
                      name: 'Local Emergency Network',
                      phone: 'Helpline 112',
                      channel: 'Direct Alert',
                      status: 'Standing By',
                      icon: Icons.access_time,
                      iconColor: Colors.orange,
                    ),

                    const Spacer(),

                    // End SOS button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.safeGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.lock_open, color: Colors.white),
                        label: const Text(
                          'I AM SAFE • END EMERGENCY',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        onPressed: _showCancelDialog,
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

  Widget _buildDeliveryItem({
    required String name,
    required String phone,
    required String channel,
    required String status,
    required IconData icon,
    required Color iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('$phone • $channel', style: const TextStyle(fontSize: 12)),
        trailing: Text(
          status,
          style: TextStyle(color: iconColor, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }
}
