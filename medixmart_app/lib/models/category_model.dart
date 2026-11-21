/// Domain model for a medicine category (`GET /api/categories`).
class CategoryModel {
  final int id;
  final String name;
  final String? description;
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;
    final rawCreatedAt = json['created_at'] as String?;

    return CategoryModel(
      id: id,
      name: (json['name'] as String? ?? '').trim(),
      description: _nullableTrimmed(json['description'] as String?),
      createdAt: rawCreatedAt != null ? DateTime.tryParse(rawCreatedAt) : null,
    );
  }

  static String? _nullableTrimmed(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
