import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final List<Map<String, dynamic>> _contacts = [
    {'name': 'Papa', 'phone': '+91 98765 43210', 'relationship': 'Father', 'priority': 1},
    {'name': 'Mom', 'phone': '+91 98765 43211', 'relationship': 'Mother', 'priority': 2},
    {'name': 'Ananya', 'phone': '+91 98765 43212', 'relationship': 'Sister', 'priority': 3},
  ];

  void _showAddContactDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final relCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add Trusted Contact',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile Number (+91...)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: relCtrl,
              decoration: const InputDecoration(labelText: 'Relationship (e.g. Sister, Friend)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty && phoneCtrl.text.isNotEmpty) {
                    setState(() {
                      _contacts.add({
                        'name': nameCtrl.text,
                        'phone': phoneCtrl.text,
                        'relationship': relCtrl.text,
                        'priority': _contacts.length + 1,
                      });
                    });
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('SAVE TRUSTED CONTACT'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.emergencyRed,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact'),
        onPressed: _showAddContactDialog,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _contacts.length,
        itemBuilder: (context, index) {
          final c = _contacts[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.emergencyRed.withOpacity(0.1),
                child: Text(
                  '${c['priority']}',
                  style: const TextStyle(color: AppTheme.emergencyRed, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(c['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${c['phone']} • ${c['relationship']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.grey),
                onPressed: () {
                  setState(() => _contacts.removeAt(index));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
