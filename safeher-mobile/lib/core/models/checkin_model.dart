class CheckInModel {
  final int? id;
  final int? serverId;
  final int intervalMinutes;
  final DateTime scheduledTime;
  final String status; // SCHEDULED, CONFIRMED_SAFE, MISSED, ESCALATED
  final String note;
  final DateTime createdAt;

  CheckInModel({
    this.id,
    this.serverId,
    required this.intervalMinutes,
    required this.scheduledTime,
    this.status = 'SCHEDULED',
    this.note = '',
    required this.createdAt,
  });

  bool get isScheduled => status == 'SCHEDULED';
  bool get isConfirmedSafe => status == 'CONFIRMED_SAFE';
  bool get isMissed => status == 'MISSED';
  bool get isEscalated => status == 'ESCALATED';

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(scheduledTime)) return Duration.zero;
    return scheduledTime.difference(now);
  }

  factory CheckInModel.fromJson(Map<String, dynamic> json) {
    return CheckInModel(
      id: json['id'] as int?,
      serverId: json['serverId'] as int?,
      intervalMinutes: json['intervalMinutes'] as int? ?? 30,
      scheduledTime: json['scheduledTime'] != null
          ? DateTime.parse(json['scheduledTime'] as String)
          : DateTime.now()
              .add(Duration(minutes: json['intervalMinutes'] as int? ?? 30)),
      status: json['status'] as String? ?? 'SCHEDULED',
      note: json['note'] as String? ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (serverId != null) 'serverId': serverId,
      'intervalMinutes': intervalMinutes,
      'scheduledTime': scheduledTime.toIso8601String(),
      'status': status,
      'note': note,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  CheckInModel copyWith({
    int? id,
    int? serverId,
    int? intervalMinutes,
    DateTime? scheduledTime,
    String? status,
    String? note,
    DateTime? createdAt,
  }) {
    return CheckInModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      intervalMinutes: intervalMinutes ?? this.intervalMinutes,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
