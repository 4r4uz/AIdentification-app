class SpeciesModel {
  final int id;
  final String nameCommon;
  final String? nameScientific;
  final String? description;
  final String? imageUrl;
  final String rarity;
  final String? habitat;
  final List<String>? funFacts;

  SpeciesModel({
    required this.id,
    required this.nameCommon,
    this.nameScientific,
    this.description,
    this.imageUrl,
    required this.rarity,
    this.habitat,
    this.funFacts,
  });

  factory SpeciesModel.fromJson(Map<String, dynamic> json) {
    return SpeciesModel(
      id: json['id'] as int,
      nameCommon: json['name_common'] as String,
      nameScientific: json['name_scientific'] as String?,
      description: json['description'] as String?,
      imageUrl: json['image_url'] as String?,
      rarity: json['rarity'] as String,
      habitat: json['habitat'] as String?,
      funFacts: json['fun_facts'] != null
          ? List<String>.from(json['fun_facts'] as List)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_common': nameCommon,
      'name_scientific': nameScientific,
      'description': description,
      'image_url': imageUrl,
      'rarity': rarity,
      'habitat': habitat,
      'fun_facts': funFacts,
    };
  }

  String getRarityColorHex() {
    switch (rarity.toLowerCase()) {
      case 'comun':
        return '#9E9E9E';
      case 'raro':
        return '#2196F3';
      case 'epico':
        return '#9C27B0';
      case 'legendario':
        return '#FFC107';
      default:
        return '#9E9E9E';
    }
  }
}