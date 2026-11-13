class EmergencyEventModel {
  final int id;
  final String eventType;
  final String status;
  final String? clientEventUuid;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? cancellationReason;

  EmergencyEventModel({
    required this.id,
    required this.eventType,
    required this.status,
    this.clientEventUuid,
    this.startedAt,
    this.endedAt,
    this.cancellationReason,
  });

  factory EmergencyEventModel.fromJson(Map<String, dynamic> json) {
    return EmergencyEventModel(
      id: json['id'] as int,
      eventType: json['eventType'] as String,
      status: json['status'] as String,
      clientEventUuid: json['clientEventUuid'] as String?,
      startedAt: json['startedAt'] != null ? DateTime.parse(json['startedAt'] as String) : null,
      endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt'] as String) : null,
      cancellationReason: json['cancellationReason'] as String?,
    );
  }

  bool get isActive => status == 'ACTIVE';
  bool get isCancelled => status == 'CANCELLED';
  bool get isResolved => status == 'RESOLVED' || status == 'CANCELLED';

  Map<String, dynamic> toJson() => {
    'id': id,
    'eventType': eventType,
    'status': status,
    if (clientEventUuid != null) 'clientEventUuid': clientEventUuid,
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (endedAt != null) 'endedAt': endedAt!.toIso8601String(),
    if (cancellationReason != null) 'cancellationReason': cancellationReason,
  };
}
