class SpeciesFactModel {
  final int id;
  final int speciesId;
  final String fact;
  final int sortOrder;
  final String? sourceUrl;
  final String? speciesName;

  const SpeciesFactModel({
    required this.id,
    required this.speciesId,
    required this.fact,
    required this.sortOrder,
    this.sourceUrl,
    this.speciesName,
  });

  factory SpeciesFactModel.fromJson(Map<String, dynamic> json) {
    final species = json['species'];
    final speciesData = species is Map
        ? Map<String, dynamic>.from(species)
        : <String, dynamic>{};

    return SpeciesFactModel(
      id: (json['id'] as num).toInt(),
      speciesId: (json['species_id'] as num).toInt(),
      fact: json['fact'] as String,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      sourceUrl: json['source_url'] as String?,
      speciesName:
          speciesData['name_common'] as String? ??
          json['species_name'] as String?,
    );
  }
}
