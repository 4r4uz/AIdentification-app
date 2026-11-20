class SpeciesModel {
  final int id;
  final String nameCommon;
  final String? nameScientific;
  final String? description;
  final String? imageUrl;
  final String? habitat;

  SpeciesModel({
    required this.id,
    required this.nameCommon,
    this.nameScientific,
    this.description,
    this.imageUrl,
    this.habitat,
  });

  factory SpeciesModel.fromJson(Map<String, dynamic> json) {
    return SpeciesModel(
      id: ((json['id'] ?? json['species_id']) as num).toInt(),
      nameCommon:
          (json['name_common'] ?? json['species_name']) as String? ??
          'Especie desconocida',
      nameScientific: (json['name_scientific'] ?? json['scientific_name']) as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      habitat: json['habitat'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_common': nameCommon,
      'name_scientific': nameScientific,
      'description': description,
      'image_url': imageUrl,
      'habitat': habitat,
    };
  }
}