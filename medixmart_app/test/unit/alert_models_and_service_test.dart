import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medixmart_app/models/alert_model.dart';
import 'package:medixmart_app/models/dashboard_models.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/services/alert_service.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/utils/formatters.dart';

class _MemStorage implements TokenStorage {
  final Map<String, String> _map;
  _MemStorage([Map<String, String>? initial])
      : _map = Map<String, String>.from(initial ?? const {});

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String value) async => _map[key] = value;

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

void main() {
  group('Alert Models & Formatters', () {
    test('AlertModel.fromJson parses all 5 types, 3 severities, and fallbacks',
        () {
      final types = <String, AlertType>{
        'expired': AlertType.expired,
        'expiry_warning': AlertType.expiryWarning,
        'low_stock': AlertType.lowStock,
        'credit_overdue': AlertType.creditOverdue,
        'birthday': AlertType.birthday,
      };

      for (final entry in types.entries) {
        final model = AlertModel.fromJson({
          'id': 10,
          'alert_type': entry.key,
          'severity': 'warning',
          'title': 'Sample Title',
          'message': 'Sample Message',
          'reference_table': 'batches',
          'reference_id': 42,
          'is_resolved': false,
          'resolved_at': null,
          'created_at': '2026-11-24T00:30:00.000Z',
        });
        expect(model.alertType, entry.value);
        expect(model.severity, AlertSeverity.warning);
        expect(model.referenceLabel, 'Batch #42');
        expect(model.isResolved, isFalse);
        expect(model.resolvedAt, isNull);
        expect(model.createdAt, isNotNull);
      }

      final unknown = AlertModel.fromJson({
        'id': '11',
        'alert_type': 'custom_type',
        'severity': 'unknown_sev',
        'title': 'Custom Notice',
        'message': 'Details',
        'reference_table': null,
        'reference_id': null,
        'is_resolved': true,
        'resolved_at': '2026-11-24T01:00:00.000Z',
        'created_at': '2026-11-24T00:30:00.000Z',
      });

      expect(unknown.id, 11);
      expect(unknown.alertType, isNull);
      expect(unknown.rawAlertType, 'custom_type');
      expect(unknown.typeLabel, 'custom_type');
      expect(unknown.severity, AlertSeverity.info);
      expect(unknown.referenceLabel, isNull);
      expect(unknown.isResolved, isTrue);
      expect(unknown.resolvedAt, isNotNull);
    });

    test('AlertModel.referenceLabel formats known tables and handles nulls', () {
      AlertModel buildWithRef(String? table, int? id) => AlertModel(
            id: 1,
            alertType: AlertType.lowStock,
            rawAlertType: 'low_stock',
            severity: AlertSeverity.warning,
            title: 'T',
            message: 'M',
            referenceTable: table,
            referenceId: id,
          );

      expect(buildWithRef('batches', 7).referenceLabel, 'Batch #7');
      expect(buildWithRef('medicines', 8).referenceLabel, 'Medicine #8');
      expect(buildWithRef('customers', 9).referenceLabel, 'Customer #9');
      expect(buildWithRef('sales', 10).referenceLabel, 'Sale #10');
      expect(buildWithRef('suppliers', 11).referenceLabel, 'suppliers #11');
      expect(buildWithRef('batches', null).referenceLabel, isNull);
      expect(buildWithRef(null, 5).referenceLabel, isNull);
    });

    test('AlertModel.toDashboardAlertItem maps tones and badge labels', () {
      const expired = AlertModel(
        id: 1,
        alertType: AlertType.expired,
        rawAlertType: 'expired',
        severity: AlertSeverity.danger,
        title: 'Batch B-014 Expired',
        message: 'Expired message',
      );
      const expiring = AlertModel(
        id: 2,
        alertType: AlertType.expiryWarning,
        rawAlertType: 'expiry_warning',
        severity: AlertSeverity.warning,
        title: 'Batch B-061 Near Expiry',
        message: 'Warning message',
      );
      const lowStock = AlertModel(
        id: 3,
        alertType: AlertType.lowStock,
        rawAlertType: 'low_stock',
        severity: AlertSeverity.warning,
        title: 'Amoxicillin Low Stock',
        message: '4 packs left',
      );
      const birthday = AlertModel(
        id: 4,
        alertType: AlertType.birthday,
        rawAlertType: 'birthday',
        severity: AlertSeverity.info,
        title: 'Customer Birthday',
        message: 'Send wishes',
      );

      expect(expired.toDashboardAlertItem().tone, StatusTone.expired);
      expect(expired.toDashboardAlertItem().badgeLabel, 'Expired');
      expect(expiring.toDashboardAlertItem().tone, StatusTone.expiring7M);
      expect(expiring.toDashboardAlertItem().badgeLabel, 'Expiring 7M');
      expect(lowStock.toDashboardAlertItem().tone, StatusTone.lowStock);
      expect(lowStock.toDashboardAlertItem().badgeLabel, 'Low Stock');
      expect(birthday.toDashboardAlertItem().tone, StatusTone.inStock);
      expect(birthday.toDashboardAlertItem().badgeLabel, 'Birthday');
    });

    test('AlertSummary and ExpiryCheckResult parse API payloads safely', () {
      const empty = AlertSummary.empty();
      expect(empty.totalActive, 0);
      expect(empty.lowStockCount, 0);

      final summary = AlertSummary.fromJson({
        'total_active': 12,
        'danger_count': '3',
        'warning_count': 8,
        'info_count': 1,
        'expired_count': 2,
        'expiring_soon_count': 6,
        'low_stock_count': 3,
      });

      expect(summary.totalActive, 12);
      expect(summary.dangerCount, 3);
      expect(summary.warningCount, 8);
      expect(summary.infoCount, 1);
      expect(summary.expiredCount, 2);
      expect(summary.expiringSoonCount, 6);
      expect(summary.lowStockCount, 3);

      final check = ExpiryCheckResult.fromJson({
        'message': 'Expiry alert engine executed successfully.',
        'stats': {
          'expired_alerts_created': 1,
          'warning_alerts_created': 4,
          'alerts_auto_resolved': 2,
        },
      });
      expect(check.expiredAlertsCreated, 1);
      expect(check.warningAlertsCreated, 4);
      expect(check.alertsAutoResolved, 2);
      expect(check.totalChanges, 7);
    });

    test('MmFormatters.twoDigitCount and shortDateTime format values', () {
      expect(MmFormatters.twoDigitCount(0), '00');
      expect(MmFormatters.twoDigitCount(8), '08');
      expect(MmFormatters.twoDigitCount(12), '12');

      final localDt = DateTime(2026, 11, 24, 9, 5);
      expect(MmFormatters.shortDateTime(localDt), '24 Nov 2026, 09:05');
    });
  });

  group('AlertService', () {
    test('fetchAlerts serializes filters and parses paginated response',
        () async {
      Uri? capturedUri;
      String? authHeader;

      final client = ApiClient(
        httpClient: MockClient((request) async {
          capturedUri = request.url;
          authHeader = request.headers['Authorization'];
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 14,
                  'alert_type': 'expiry_warning',
                  'severity': 'warning',
                  'title': 'Batch B-061 Near Expiry (Return Window)',
                  'message': 'Expires in 142 days.',
                  'reference_table': 'batches',
                  'reference_id': 61,
                  'is_resolved': false,
                  'resolved_at': null,
                  'created_at': '2026-11-24T00:30:00.000Z',
                },
              ],
              'meta': {
                'page': 2,
                'limit': 10,
                'totalRecords': 15,
                'totalPages': 2,
                'hasNextPage': false,
                'hasPrevPage': true,
              },
            }),
            200,
          );
        }),
        tokenStorage: _MemStorage({AuthProvider.tokenStorageKey: 'jwt-123'}),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );

      final service = AlertService(client);
      final result = await service.fetchAlerts(
        isResolved: true,
        alertType: AlertType.expiryWarning,
        severity: AlertSeverity.warning,
        page: 2,
        limit: 10,
      );

      expect(authHeader, 'Bearer jwt-123');
      expect(capturedUri?.path, '/api/alerts');
      expect(capturedUri?.queryParameters, {
        'is_resolved': 'true',
        'alert_type': 'expiry_warning',
        'severity': 'warning',
        'page': '2',
        'limit': '10',
      });
      expect(result.items, hasLength(1));
      expect(result.items.first.id, 14);
      expect(result.pagination.page, 2);
      expect(result.pagination.totalRecords, 15);
      expect(result.pagination.hasPrevPage, isTrue);
    });

    test('fetchSummary, resolveAlert, and runExpiryCheck hit exact endpoints',
        () async {
      final calls = <http.Request>[];

      final client = ApiClient(
        httpClient: MockClient((request) async {
          calls.add(request);
          if (request.method == 'GET' && request.url.path == '/api/alerts/summary') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'total_active': 5,
                  'danger_count': 1,
                  'warning_count': 3,
                  'info_count': 1,
                  'expired_count': 1,
                  'expiring_soon_count': 2,
                  'low_stock_count': 1,
                },
              }),
              200,
            );
          }
          if (request.method == 'PATCH' &&
              request.url.path == '/api/alerts/14/resolve') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'message': 'Alert marked as resolved.'},
              }),
              200,
            );
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/alerts/generate-expiry') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'message': 'Expiry alert engine executed successfully.',
                  'stats': {
                    'expired_alerts_created': 2,
                    'warning_alerts_created': 3,
                    'alerts_auto_resolved': 1,
                  },
                },
              }),
              200,
            );
          }
          return http.Response('Not found', 404);
        }),
        tokenStorage: _MemStorage({AuthProvider.tokenStorageKey: 'jwt-123'}),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );

      final service = AlertService(client);
      final summary = await service.fetchSummary();
      expect(summary.totalActive, 5);

      await service.resolveAlert(14);

      final defaultCheck = await service.runExpiryCheck();
      expect(defaultCheck.expiredAlertsCreated, 2);
      expect(defaultCheck.warningAlertsCreated, 3);
      expect(defaultCheck.alertsAutoResolved, 1);

      await service.runExpiryCheck(monthsAhead: 6);

      expect(calls[2].method, 'POST');
      expect(jsonDecode(calls[2].body), <String, dynamic>{});
      expect(jsonDecode(calls[3].body), {'months_ahead': 6});
    });
  });
}
