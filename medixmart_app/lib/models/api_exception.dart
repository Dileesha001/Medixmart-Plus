/// Field-level validation error entry returned in `error.details`.
class ApiErrorDetail {
  final String field;
  final String message;

  const ApiErrorDetail({
    required this.field,
    required this.message,
  });

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

/// Standardized REST API exception matching Medixmart Plus error envelopes.
class ApiException implements Exception {
  /// Explicit allowlist of backend error codes that terminate an active session.
  ///
  /// Explicitly excludes `AUTH_INVALID_CREDENTIALS` (used by protected
  /// `PUT /api/auth/change-password` on wrong current password) and
  /// `AUTH_FORBIDDEN_ROLE` (authorization denial for valid sessions).
  static const Set<String> sessionRevokingCodes = {
    'AUTH_MISSING_TOKEN',
    'AUTH_INVALID_TOKEN',
    'AUTH_EXPIRED_TOKEN',
    'AUTH_SESSION_REVOKED',
    'AUTH_ACCOUNT_DISABLED',
  };

  final String code;
  final String message;
  final int statusCode;
  final List<ApiErrorDetail> details;

  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details = const [],
  });

  factory ApiException.fromJson(Map<String, dynamic> json, int statusCode) {
    final error = (json['error'] as Map<String, dynamic>?) ?? const {};
    final rawDetails = error['details'];
    final parsedDetails = <ApiErrorDetail>[];
    if (rawDetails is List) {
      for (final item in rawDetails) {
        if (item is Map<String, dynamic>) {
          parsedDetails.add(ApiErrorDetail.fromJson(item));
        }
      }
    }

    return ApiException(
      code: error['code'] as String? ?? 'UNKNOWN_ERROR',
      message: error['message'] as String? ?? 'An unexpected error occurred.',
      statusCode: statusCode,
      details: List.unmodifiable(parsedDetails),
    );
  }

  bool get isSessionRevoked => sessionRevokingCodes.contains(code);
  bool get isForbidden => statusCode == 403;
  bool get isDuplicate => statusCode == 409 || code == 'DUPLICATE_ENTRY';
  bool get isValidation => statusCode == 400 || code == 'VALIDATION_ERROR';

  /// Returns the first validation error message matching [field], if any.
  String? fieldError(String field) {
    final target = field.toLowerCase();
    for (final detail in details) {
      if (detail.field.toLowerCase() == target && detail.message.isNotEmpty) {
        return detail.message;
      }
    }
    return null;
  }

  @override
  String toString() => message;
}
