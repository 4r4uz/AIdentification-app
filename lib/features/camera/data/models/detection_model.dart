class DetectionModel {
  final int id;
  final String userId;
  final int? speciesId;
  final String imagePath;
  final double? confidence;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  DetectionModel({
    required this.id,
    required this.userId,
    this.speciesId,
    required this.imagePath,
    this.confidence,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory DetectionModel.fromJson(Map<String, dynamic> json) {
    return DetectionModel(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      speciesId: json['species_id'] as int?,
      imagePath: json['image_path'] as String,
      confidence: (json['confidence'] as num?)?.toDouble(),
      latitude: (json['location_lat'] as num?)?.toDouble(),
      longitude: (json['location_lng'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'species_id': speciesId,
      'image_path': imagePath,
      'confidence': confidence,
      'location_lat': latitude,
      'location_lng': longitude,
      'created_at': createdAt.toIso8601String(),
    };
  }
}