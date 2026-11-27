import '../models/staff_user_model.dart';
import 'api_client.dart';

/// Typed REST service for Admin user management endpoints (`/api/users`).
class StaffUserService {
  final ApiClient _apiClient;

  const StaffUserService(this._apiClient);

  /// `GET /api/users` (Admin only) — returns all staff users ordered by ID.
  Future<List<StaffUserModel>> fetchUsers() async {
    final envelope = await _apiClient.get('/users');
    final data = envelope['data'];
    final List<dynamic> rawUsers;
    if (data is Map<String, dynamic> && data['users'] is List) {
      rawUsers = data['users'] as List<dynamic>;
    } else if (data is List) {
      rawUsers = data;
    } else {
      rawUsers = const [];
    }

    return rawUsers
        .whereType<Map<String, dynamic>>()
        .map(StaffUserModel.fromJson)
        .toList(growable: false);
  }

  /// `PATCH /api/users/:id/status` (Admin only) — activates or deactivates a
  /// staff account with server-side last-admin self-lockout protection.
  Future<StaffUserUpdateResult> updateUserStatus(
    int userId, {
    required bool isActive,
  }) async {
    final envelope = await _apiClient.patch(
      '/users/$userId/status',
      body: {'is_active': isActive},
    );
    return StaffUserUpdateResult.fromJson(
      (envelope['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  /// `PATCH /api/users/:id/role` (Admin only) — switches a staff account's role
  /// between `'admin'` and `'pharmacist'` with last-admin protection.
  Future<StaffUserUpdateResult> updateUserRole(
    int userId, {
    required String role,
  }) async {
    final envelope = await _apiClient.patch(
      '/users/$userId/role',
      body: {'role': role},
    );
    return StaffUserUpdateResult.fromJson(
      (envelope['data'] as Map<String, dynamic>?) ?? const {},
    );
  }
}
