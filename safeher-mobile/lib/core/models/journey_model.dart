class JourneyModel {
  final int? id;
  final int? serverId;
  final String destination;
  final int durationMinutes;
  final DateTime startedAt;
  final DateTime expectedArrival;
  final String status; // ACTIVE, COMPLETED, CANCELLED, ESCALATED
  final List<String> checkpoints;

  JourneyModel({
    this.id,
    this.serverId,
    required this.destination,
    required this.durationMinutes,
    required this.startedAt,
    required this.expectedArrival,
    this.status = 'ACTIVE',
    this.checkpoints = const [],
  });

  bool get isActive => status == 'ACTIVE';
  bool get isCompleted => status == 'COMPLETED';

  Duration get remainingDuration {
    final now = DateTime.now();
    if (now.isAfter(expectedArrival)) return Duration.zero;
    return expectedArrival.difference(now);
  }

  double get progressPercentage {
    final totalSecs = durationMinutes * 60;
    final elapsedSecs = DateTime.now().difference(startedAt).inSeconds;
    if (totalSecs <= 0) return 1.0;
    return (elapsedSecs / totalSecs).clamp(0.0, 1.0);
  }

  factory JourneyModel.fromJson(Map<String, dynamic> json) {
    return JourneyModel(
      id: json['id'] as int?,
      serverId: json['serverId'] as int?,
      destination: json['destination'] as String? ?? 'Unknown Destination',
      durationMinutes: json['durationMinutes'] as int? ?? 15,
      startedAt: json['startedAt'] != null
          ? DateTime.parse(json['startedAt'] as String)
          : DateTime.now(),
      expectedArrival: json['expectedArrival'] != null
          ? DateTime.parse(json['expectedArrival'] as String)
          : DateTime.now()
              .add(Duration(minutes: json['durationMinutes'] as int? ?? 15)),
      status: json['status'] as String? ?? 'ACTIVE',
      checkpoints: (json['checkpoints'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (serverId != null) 'serverId': serverId,
      'destination': destination,
      'durationMinutes': durationMinutes,
      'startedAt': startedAt.toIso8601String(),
      'expectedArrival': expectedArrival.toIso8601String(),
      'status': status,
      'checkpoints': checkpoints,
    };
  }

  JourneyModel copyWith({
    int? id,
    int? serverId,
    String? destination,
    int? durationMinutes,
    DateTime? startedAt,
    DateTime? expectedArrival,
    String? status,
    List<String>? checkpoints,
  }) {
    return JourneyModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      destination: destination ?? this.destination,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      startedAt: startedAt ?? this.startedAt,
      expectedArrival: expectedArrival ?? this.expectedArrival,
      status: status ?? this.status,
      checkpoints: checkpoints ?? this.checkpoints,
    );
  }
}
