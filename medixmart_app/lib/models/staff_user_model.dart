import 'user_model.dart';

/// Filter options for the Staff Accounts status segmented control.
enum StaffStatusFilter { all, active, disabled }

/// Immutable representation of a pharmacy staff account returned by
/// `GET /api/users`, `PATCH /api/users/:id/status`, and `PATCH /api/users/:id/role`.
class StaffUserModel {
  final int id;
  final String username;
  final String role; // 'admin' or 'pharmacist'
  final bool isActive;
  final int tokenVersion;
  final DateTime? passwordChangedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StaffUserModel({
    required this.id,
    required this.username,
    required this.role,
    required this.isActive,
    this.tokenVersion = 1,
    this.passwordChangedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isPharmacist => role.toLowerCase() == 'pharmacist';
  String get roleLabel => isAdmin ? 'Admin' : 'Pharmacist';

  String get initials {
    final cleaned = username.trim();
    if (cleaned.isEmpty) return '??';
    final parts = cleaned
        .split(RegExp(r'[\s._-]+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return cleaned.length >= 2
        ? cleaned.substring(0, 2).toUpperCase()
        : cleaned.toUpperCase();
  }

  static DateTime? _parseDate(Object? raw) {
    if (raw is String && raw.trim().isNotEmpty) {
      return DateTime.tryParse(raw.trim());
    }
    return null;
  }

  static int _parseInt(Object? raw, {int fallback = 0}) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
    return fallback;
  }

  factory StaffUserModel.fromJson(Map<String, dynamic> json) {
    return StaffUserModel(
      id: _parseInt(json['id']),
      username: (json['username'] as String? ?? '').trim(),
      role: (json['role'] as String? ?? 'pharmacist').toLowerCase(),
      isActive: json['is_active'] as bool? ?? true,
      tokenVersion: _parseInt(json['token_version'], fallback: 1),
      passwordChangedAt: _parseDate(json['password_changed_at']),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
    );
  }

  StaffUserModel copyWith({
    int? id,
    String? username,
    String? role,
    bool? isActive,
    int? tokenVersion,
    DateTime? passwordChangedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffUserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      tokenVersion: tokenVersion ?? this.tokenVersion,
      passwordChangedAt: passwordChangedAt ?? this.passwordChangedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Response payload returned by `PUT /api/auth/change-password`.
class ChangePasswordResult {
  final String message;
  final String token;
  final UserModel user;
  final String expiresIn;

  const ChangePasswordResult({
    required this.message,
    required this.token,
    required this.user,
    required this.expiresIn,
  });

  factory ChangePasswordResult.fromJson(Map<String, dynamic> json) {
    return ChangePasswordResult(
      message: json['message'] as String? ??
          'Password changed successfully. Prior sessions have been invalidated.',
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      expiresIn: json['expiresIn'] as String? ?? '8h',
    );
  }
}

/// Response payload returned by `PATCH /api/users/:id/status` and
/// `PATCH /api/users/:id/role`.
class StaffUserUpdateResult {
  final String message;
  final StaffUserModel user;

  const StaffUserUpdateResult({
    required this.message,
    required this.user,
  });

  factory StaffUserUpdateResult.fromJson(Map<String, dynamic> json) {
    return StaffUserUpdateResult(
      message: json['message'] as String? ?? 'User updated successfully.',
      user: StaffUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
