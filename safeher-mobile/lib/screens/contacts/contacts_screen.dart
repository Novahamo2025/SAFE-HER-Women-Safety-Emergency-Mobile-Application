import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/contact_model.dart';
import '../../core/providers/contact_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/empty_state_widget.dart';
import '../../widgets/safe_button.dart';
import '../../widgets/safe_card.dart';
import '../../widgets/status_badge.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  void _showAddEditContactDialog(BuildContext context, [ContactModel? contact]) {
    final nameCtrl = TextEditingController(text: contact?.contactName ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');
    String relationship = contact?.relationship ?? 'Family';
    int priority = contact?.priority ?? 1;
    bool notifySms = contact?.notifySms ?? true;
    bool notifyPush = contact?.notifyPush ?? true;

    final relationships = ['Family', 'Parent', 'Spouse', 'Sibling', 'Friend', 'Colleague', 'Neighbor'];
    final formKey = GlobalKey<FormState>();

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
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        contact != null ? 'Edit Trusted Contact' : 'Add Trusted Contact',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name
                  const Text('Contact Full Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Papa, Sarah',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter name' : null,
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  const Text('Phone Number (with country code)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      hintText: '+91 98765 43210',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (val) => (val == null || val.trim().length < 10) ? 'Enter valid phone number' : null,
                  ),
                  const SizedBox(height: 16),

                  // Relationship Picker
                  const Text('Relationship', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: relationships.map((rel) {
                      final isSelected = relationship == rel;
                      return ChoiceChip(
                        label: Text(rel),
                        selected: isSelected,
                        selectedColor: AppTheme.brandPrimaryLight,
                        labelStyle: TextStyle(
                          color: isSelected ? AppTheme.brandPrimaryDark : AppTheme.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12.5,
                        ),
                        onSelected: (selected) {
                          if (selected) setSheetState(() => relationship = rel);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Priority Selector
                  Row(
                    children: [
                      const Text('Alert Priority:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: priority,
                        items: [1, 2, 3, 4, 5].map((p) {
                          return DropdownMenuItem<int>(
                            value: p,
                            child: Text('Priority $p ${p == 1 ? "(Primary)" : ""}'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => priority = val);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Notification Options
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send Instant SMS Alert', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Direct carrier message with Google Maps GPS link', style: TextStyle(fontSize: 12)),
                    value: notifySms,
                    activeColor: AppTheme.brandPrimary,
                    onChanged: (val) => setSheetState(() => notifySms = val),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Send Push Notification', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('High-priority alert when app is installed', style: TextStyle(fontSize: 12)),
                    value: notifyPush,
                    activeColor: AppTheme.brandPrimary,
                    onChanged: (val) => setSheetState(() => notifyPush = val),
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  SafeButton(
                    text: contact != null ? 'Save Changes' : 'Add Contact',
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final provider = context.read<ContactProvider>();

                      if (contact != null) {
                        await provider.updateContact(
                          ContactModel(
                            id: contact.id,
                            contactName: nameCtrl.text.trim(),
                            phone: phoneCtrl.text.trim(),
                            relationship: relationship,
                            priority: priority,
                            notifySms: notifySms,
                            notifyPush: notifyPush,
                            isVerified: true,
                          ),
                        );
                      } else {
                        await provider.addContact(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          relationship: relationship,
                          priority: priority,
                          notifySms: notifySms,
                          notifyPush: notifyPush,
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(contact != null ? 'Contact updated.' : 'Trusted contact added.'),
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
      ),
    );
  }

  void _confirmDeleteContact(BuildContext context, ContactModel contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Trusted Contact?'),
        content: Text(
          'Are you sure you want to remove ${contact.contactName} from your emergency alerts network? They will no longer receive your SOS or live location.',
          style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.emergencyRed),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ContactProvider>().deleteContact(contact.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${contact.contactName} removed from trusted contacts.')),
                );
              }
            },
            child: const Text('Remove Contact'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactProvider = context.watch<ContactProvider>();
    final contacts = contactProvider.contacts;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Trusted Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => contactProvider.loadContacts(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Add Contact', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddEditContactDialog(context),
      ),
      body: contactProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contacts.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.people_outline,
                  title: 'No Trusted Contacts Yet',
                  description: 'Add people you trust so Svasheild can immediately notify them and stream your live GPS location during an emergency.',
                  buttonText: 'Add First Contact',
                  onButtonPressed: () => _showAddEditContactDialog(context),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Privacy & Notification summary strip
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.brandPrimaryLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.brandPrimary.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.shield_outlined, color: AppTheme.brandPrimary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '${contacts.length} emergency contacts ready. Priority 1 contacts receive immediate native SMS.',
                                style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      ...contacts.map((contact) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: SafeCard(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.brandPrimaryLight,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Text(
                                        contact.contactName.isNotEmpty
                                            ? contact.contactName[0].toUpperCase()
                                            : 'C',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.brandPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  contact.contactName,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              if (contact.isVerified)
                                                const Icon(Icons.verified, color: AppTheme.brandPrimary, size: 16),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            contact.phone,
                                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _showAddEditContactDialog(context, contact);
                                        } else if (action == 'delete') {
                                          _confirmDeleteContact(context, contact);
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Edit Contact')),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Remove Contact', style: TextStyle(color: AppTheme.emergencyRed)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        StatusBadge(
                                          label: 'Priority ${contact.priority}',
                                          type: contact.priority == 1 ? StatusBadgeType.error : StatusBadgeType.neutral,
                                        ),
                                        if (contact.relationship != null) ...[
                                          const SizedBox(width: 6),
                                          StatusBadge(
                                            label: contact.relationship!,
                                            type: StatusBadgeType.info,
                                          ),
                                        ],
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        if (contact.notifySms)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.sms_outlined, size: 16, color: AppTheme.brandPrimary),
                                          ),
                                        if (contact.notifyPush)
                                          const Padding(
                                            padding: EdgeInsets.only(left: 6),
                                            child: Icon(Icons.notifications_active_outlined, size: 16, color: AppTheme.safeGreen),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 60), // Room for FAB
                    ],
                  ),
                ),
    );
  }
}
