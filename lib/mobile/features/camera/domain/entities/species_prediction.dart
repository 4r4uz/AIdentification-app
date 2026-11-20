class SpeciesPrediction {
  final String raw;
  final String uuid;
  final String className;
  final String order;
  final String family;
  final String genus;
  final String species;
  final String commonName;

  SpeciesPrediction({
    required this.raw,
    required this.uuid,
    required this.className,
    required this.order,
    required this.family,
    required this.genus,
    required this.species,
    required this.commonName,
  });

  factory SpeciesPrediction.parse(String raw) {
    final parts = raw.split(';');
    final uuid = parts.isNotEmpty ? parts[0].trim() : '';
    final className = parts.length > 1 ? parts[1].trim() : '';
    final order = parts.length > 2 ? parts[2].trim() : '';
    final family = parts.length > 3 ? parts[3].trim() : '';
    final genus = parts.length > 4 ? parts[4].trim() : '';
    final species = parts.length > 5 ? parts[5].trim() : '';
    final commonName = parts.length > 6 ? parts[6].trim() : '';

    return SpeciesPrediction(
      raw: raw,
      uuid: uuid,
      className: className,
      order: order,
      family: family,
      genus: genus,
      species: species,
      commonName: commonName,
    );
  }

  bool get hasUsableClassification =>
      className.isNotEmpty ||
      order.isNotEmpty ||
      family.isNotEmpty ||
      genus.isNotEmpty ||
      species.isNotEmpty;

  int get depth {
    int d = 0;
    if (className.isNotEmpty) d++;
    if (order.isNotEmpty) d++;
    if (family.isNotEmpty) d++;
    if (genus.isNotEmpty) d++;
    if (species.isNotEmpty) d++;
    return d;
  }
}