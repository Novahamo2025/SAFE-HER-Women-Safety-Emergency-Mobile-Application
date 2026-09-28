class IncidentModel {
  final String id;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? audioPath;
  final String? photoPath;
  final double? latitude;
  final double? longitude;
  final bool isEncryptedLocally;
  final bool isUploaded;

  IncidentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.timestamp,
    this.audioPath,
    this.photoPath,
    this.latitude,
    this.longitude,
    this.isEncryptedLocally = true,
    this.isUploaded = false,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Incident Note',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'] as String)
          : DateTime.now(),
      audioPath: json['audioPath'] as String?,
      photoPath: json['photoPath'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      isEncryptedLocally: json['isEncryptedLocally'] as bool? ?? true,
      isUploaded: json['isUploaded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'timestamp': timestamp.toIso8601String(),
      'audioPath': audioPath,
      'photoPath': photoPath,
      'latitude': latitude,
      'longitude': longitude,
      'isEncryptedLocally': isEncryptedLocally,
      'isUploaded': isUploaded,
    };
  }
}
