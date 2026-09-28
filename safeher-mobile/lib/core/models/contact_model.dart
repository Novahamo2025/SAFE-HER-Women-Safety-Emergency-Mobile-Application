class ContactModel {
  final int id;
  final String contactName;
  final String phone;
  final String? relationship;
  final int priority;
  final bool notifySms;
  final bool notifyPush;
  final bool isVerified;

  ContactModel({
    required this.id,
    required this.contactName,
    required this.phone,
    this.relationship,
    required this.priority,
    this.notifySms = true,
    this.notifyPush = true,
    this.isVerified = false,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as int,
      contactName: json['contactName'] as String,
      phone: json['phone'] as String,
      relationship: json['relationship'] as String?,
      priority: json['priority'] as int? ?? 1,
      notifySms: json['notifySms'] as bool? ?? true,
      notifyPush: json['notifyPush'] as bool? ?? true,
      isVerified: json['isVerified'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contactName': contactName,
      'phone': phone,
      'relationship': relationship,
      'priority': priority,
      'notifySms': notifySms,
      'notifyPush': notifyPush,
    };
  }
}
