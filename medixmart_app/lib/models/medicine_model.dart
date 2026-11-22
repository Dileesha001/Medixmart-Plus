/// Domain model for a medicine catalog item (`GET /api/medicines`).
class MedicineModel {
  final int id;
  final int categoryId;
  final String? categoryName;
  final String name;
  final String? genericName;
  final String? brand;
  final String dosageForm;
  final String? strength;
  final double sellingPrice;
  final double costPrice;
  final int reorderLevel;
  final bool isActive;

  /// Optional total available stock across non-expired batches.
  /// Remains `null` until backend batch stock aggregation is joined.
  final int? availableStock;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MedicineModel({
    required this.id,
    required this.categoryId,
    this.categoryName,
    required this.name,
    this.genericName,
    this.brand,
    this.dosageForm = 'Tablet',
    this.strength,
    required this.sellingPrice,
    this.costPrice = 0.0,
    this.reorderLevel = 10,
    this.isActive = true,
    this.availableStock,
    this.createdAt,
    this.updatedAt,
  });

  String get subtitleSummary {
    final parts = <String>[
      if (genericName != null && genericName!.isNotEmpty) genericName!,
      if (brand != null && brand!.isNotEmpty) brand!,
    ];
    return parts.join(' · ');
  }

  String get formAndStrength {
    if (strength != null && strength!.isNotEmpty) {
      return '$dosageForm · $strength';
    }
    return dosageForm;
  }

  factory MedicineModel.fromJson(Map<String, dynamic> json) {
    final rawStock = json['available_stock'] ?? json['total_stock'];
    final rawCreatedAt = json['created_at'] as String?;
    final rawUpdatedAt = json['updated_at'] as String?;

    return MedicineModel(
      id: _parseInt(json['id']),
      categoryId: _parseInt(json['category_id']),
      categoryName: _nullableTrimmed(json['category_name'] as String?),
      name: (json['name'] as String? ?? '').trim(),
      genericName: _nullableTrimmed(json['generic_name'] as String?),
      brand: _nullableTrimmed(json['brand'] as String?),
      dosageForm:
          _nullableTrimmed(json['dosage_form'] as String?) ?? 'Tablet',
      strength: _nullableTrimmed(json['strength'] as String?),
      sellingPrice: _parseDouble(json['selling_price']),
      costPrice: _parseDouble(json['cost_price']),
      reorderLevel: _parseInt(json['reorder_level'], fallback: 10),
      isActive: json['is_active'] is bool ? json['is_active'] as bool : true,
      availableStock: rawStock == null ? null : _parseNullableInt(rawStock),
      createdAt: rawCreatedAt != null ? DateTime.tryParse(rawCreatedAt) : null,
      updatedAt: rawUpdatedAt != null ? DateTime.tryParse(rawUpdatedAt) : null,
    );
  }

  MedicineModel copyWith({
    int? id,
    int? categoryId,
    String? categoryName,
    String? name,
    String? genericName,
    String? brand,
    String? dosageForm,
    String? strength,
    double? sellingPrice,
    double? costPrice,
    int? reorderLevel,
    bool? isActive,
    int? availableStock,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicineModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      name: name ?? this.name,
      genericName: genericName ?? this.genericName,
      brand: brand ?? this.brand,
      dosageForm: dosageForm ?? this.dosageForm,
      strength: strength ?? this.strength,
      sellingPrice: sellingPrice ?? this.sellingPrice,
      costPrice: costPrice ?? this.costPrice,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      isActive: isActive ?? this.isActive,
      availableStock: availableStock ?? this.availableStock,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static double _parseDouble(dynamic value, {double fallback = 0.0}) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim()) ?? fallback;
  }

  static int _parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim()) ?? fallback;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static String? _nullableTrimmed(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Request payload DTO for creating or updating a medicine.
class MedicineInput {
  final int categoryId;
  final String name;
  final String? genericName;
  final String? brand;
  final String dosageForm;
  final String? strength;
  final double sellingPrice;
  final double costPrice;
  final int reorderLevel;
  final bool? isActive;

  const MedicineInput({
    required this.categoryId,
    required this.name,
    this.genericName,
    this.brand,
    this.dosageForm = 'Tablet',
    this.strength,
    required this.sellingPrice,
    this.costPrice = 0.0,
    this.reorderLevel = 10,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    String? cleanOptional(String? value) {
      if (value == null) return null;
      final trimmed = value.trim();
      return trimmed.isEmpty ? null : trimmed;
    }

    return {
      'category_id': categoryId,
      'name': name.trim(),
      'generic_name': cleanOptional(genericName),
      'brand': cleanOptional(brand),
      'dosage_form': dosageForm.trim().isEmpty ? 'Tablet' : dosageForm.trim(),
      'strength': cleanOptional(strength),
      'selling_price': sellingPrice,
      'cost_price': costPrice,
      'reorder_level': reorderLevel,
      if (isActive != null) 'is_active': isActive,
    };
  }
}
