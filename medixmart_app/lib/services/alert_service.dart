import '../models/alert_model.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';

/// REST client for `/api/alerts` endpoints.
class AlertService {
  final ApiClient _apiClient;

  const AlertService(this._apiClient);

  Future<PaginatedResponse<AlertModel>> fetchAlerts({
    bool isResolved = false,
    AlertType? alertType,
    AlertSeverity? severity,
    int page = 1,
    int limit = 20,
  }) async {
    final body = await _apiClient.get(
      '/alerts',
      queryParameters: {
        'is_resolved': isResolved.toString(),
        if (alertType != null) 'alert_type': alertType.queryValue,
        if (severity != null) 'severity': severity.queryValue,
        'page': page,
        'limit': limit,
      },
    );

    final rawList = body['data'] as List<dynamic>? ?? const [];
    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(AlertModel.fromJson)
        .toList(growable: false);
    final pagination = PaginationMeta.fromMetaJson(
      body['meta'] as Map<String, dynamic>?,
      itemCount: items.length,
      defaultLimit: limit,
    );

    return PaginatedResponse<AlertModel>(
      items: items,
      pagination: pagination,
    );
  }

  Future<AlertSummary> fetchSummary() async {
    final body = await _apiClient.get('/alerts/summary');
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return AlertSummary.fromJson(data);
  }

  Future<void> resolveAlert(int id) async {
    await _apiClient.patch('/alerts/$id/resolve');
  }

  Future<ExpiryCheckResult> runExpiryCheck({int? monthsAhead}) async {
    final body = await _apiClient.post(
      '/alerts/generate-expiry',
      body: monthsAhead != null
          ? {'months_ahead': monthsAhead}
          : const <String, dynamic>{},
    );
    final data = body['data'] as Map<String, dynamic>? ?? const {};
    return ExpiryCheckResult.fromJson(data);
  }
}
