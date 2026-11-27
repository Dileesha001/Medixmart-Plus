import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:medixmart_app/models/alert_model.dart';
import 'package:medixmart_app/models/api_exception.dart';
import 'package:medixmart_app/models/paginated_response.dart';
import 'package:medixmart_app/providers/alert_provider.dart';
import 'package:medixmart_app/services/alert_service.dart';
import 'package:medixmart_app/services/api_client.dart';

class _FetchRequest {
  final bool isResolved;
  final AlertType? alertType;
  final AlertSeverity? severity;
  final int page;
  final int limit;

  const _FetchRequest({
    required this.isResolved,
    this.alertType,
    this.severity,
    required this.page,
    required this.limit,
  });
}

class _FakeAlertService extends AlertService {
  _FakeAlertService() : super(ApiClient());

  final List<_FetchRequest> fetchRequests = [];
  int summaryFetchCount = 0;

  Future<AlertSummary> Function()? onFetchSummary;
  Future<PaginatedResponse<AlertModel>> Function(_FetchRequest req)?
      onFetchAlerts;
  Future<void> Function(int id)? onResolveAlert;
  Future<ExpiryCheckResult> Function(int? monthsAhead)? onRunExpiryCheck;

  @override
  Future<AlertSummary> fetchSummary() async {
    summaryFetchCount++;
    if (onFetchSummary != null) {
      return onFetchSummary!();
    }
    return const AlertSummary(
      totalActive: 3,
      dangerCount: 1,
      warningCount: 2,
      infoCount: 0,
      expiredCount: 1,
      expiringSoonCount: 1,
      lowStockCount: 1,
    );
  }

  @override
  Future<PaginatedResponse<AlertModel>> fetchAlerts({
    bool isResolved = false,
    AlertType? alertType,
    AlertSeverity? severity,
    int page = 1,
    int limit = 20,
  }) async {
    final req = _FetchRequest(
      isResolved: isResolved,
      alertType: alertType,
      severity: severity,
      page: page,
      limit: limit,
    );
    fetchRequests.add(req);
    if (onFetchAlerts != null) {
      return onFetchAlerts!(req);
    }
    return const PaginatedResponse<AlertModel>(
      items: [
        AlertModel(
          id: 1,
          alertType: AlertType.expired,
          rawAlertType: 'expired',
          severity: AlertSeverity.danger,
          title: 'Batch B-014 Expired',
          message: 'Immediate quarantine required.',
        ),
      ],
      pagination: PaginationMeta(
        page: 1,
        limit: 20,
        totalRecords: 1,
        totalPages: 1,
        hasNextPage: false,
        hasPrevPage: false,
      ),
    );
  }

  @override
  Future<void> resolveAlert(int id) async {
    if (onResolveAlert != null) {
      await onResolveAlert!(id);
    }
  }

  @override
  Future<ExpiryCheckResult> runExpiryCheck({int? monthsAhead}) async {
    if (onRunExpiryCheck != null) {
      return onRunExpiryCheck!(monthsAhead);
    }
    return const ExpiryCheckResult(
      message: 'Expiry alert engine executed successfully.',
      expiredAlertsCreated: 1,
      warningAlertsCreated: 2,
      alertsAutoResolved: 0,
    );
  }
}

void main() {
  group('AlertProvider', () {
    test(
        'ensureDashboardLoaded populates preview separately from AlertsScreen filters',
        () async {
      final service = _FakeAlertService()
        ..onFetchAlerts = (req) async {
          if (req.limit == AlertProvider.dashboardPreviewLimit) {
            return const PaginatedResponse(
              items: [
                AlertModel(
                  id: 1,
                  alertType: AlertType.expired,
                  rawAlertType: 'expired',
                  severity: AlertSeverity.danger,
                  title: 'Active Preview Alert',
                  message: 'Preview body',
                ),
              ],
              pagination: PaginationMeta(
                page: 1,
                limit: 3,
                totalRecords: 1,
                totalPages: 1,
                hasNextPage: false,
                hasPrevPage: false,
              ),
            );
          }
          if (req.isResolved) {
            return const PaginatedResponse(
              items: [
                AlertModel(
                  id: 99,
                  alertType: AlertType.lowStock,
                  rawAlertType: 'low_stock',
                  severity: AlertSeverity.warning,
                  title: 'Resolved Archive Item',
                  message: 'Restocked',
                  isResolved: true,
                ),
              ],
              pagination: PaginationMeta(
                page: 1,
                limit: 20,
                totalRecords: 1,
                totalPages: 1,
                hasNextPage: false,
                hasPrevPage: false,
              ),
            );
          }
          return const PaginatedResponse(
            items: [
              AlertModel(
                id: 1,
                alertType: AlertType.expired,
                rawAlertType: 'expired',
                severity: AlertSeverity.danger,
                title: 'Active Preview Alert',
                message: 'Preview body',
              ),
            ],
            pagination: PaginationMeta(
              page: 1,
              limit: 20,
              totalRecords: 1,
              totalPages: 1,
              hasNextPage: false,
              hasPrevPage: false,
            ),
          );
        };

      final provider = AlertProvider(service: service);
      await provider.ensureDashboardLoaded();

      expect(provider.hasLoadedDashboardPreview, isTrue);
      expect(provider.summary?.totalActive, 3);
      expect(provider.dashboardPreviewAlerts.single.title,
          'Active Preview Alert');

      await provider.ensureLoaded();
      await provider.setShowResolved(true);

      expect(provider.showResolved, isTrue);
      expect(provider.alerts.single.title, 'Resolved Archive Item');
      // Dashboard preview stays intact with active preview items
      expect(provider.dashboardPreviewAlerts.single.title,
          'Active Preview Alert');
    });

    test('ensureDashboardLoaded leaves fallback intact on error', () async {
      final service = _FakeAlertService()
        ..onFetchSummary = () async => throw const ApiException(
              code: 'NETWORK_ERROR',
              message: 'Offline',
              statusCode: 0,
            );
      final provider = AlertProvider(service: service);

      await provider.ensureDashboardLoaded();

      expect(provider.hasLoadedDashboardPreview, isFalse);
      expect(provider.isDashboardLoading, isFalse);
      expect(provider.summary, isNull);
    });

    test('filter transitions reset page to 1 and ignore stale earlier fetches',
        () async {
      final slowInitial = Completer<PaginatedResponse<AlertModel>>();
      final service = _FakeAlertService()
        ..onFetchAlerts = (req) async {
          if (req.alertType == null && req.limit == 20) {
            return slowInitial.future;
          }
          return const PaginatedResponse(
            items: [
              AlertModel(
                id: 7,
                alertType: AlertType.lowStock,
                rawAlertType: 'low_stock',
                severity: AlertSeverity.warning,
                title: 'Newer Filter Result',
                message: 'Stock low',
              ),
            ],
            pagination: PaginationMeta(
              page: 1,
              limit: 20,
              totalRecords: 1,
              totalPages: 1,
              hasNextPage: false,
              hasPrevPage: false,
            ),
          );
        };

      final provider = AlertProvider(service: service);
      final firstLoad = provider.ensureLoaded();
      await provider.setTypeFilter(AlertType.lowStock);

      expect(provider.alerts.single.title, 'Newer Filter Result');

      slowInitial.complete(
        const PaginatedResponse(
          items: [
            AlertModel(
              id: 999,
              alertType: AlertType.expired,
              rawAlertType: 'expired',
              severity: AlertSeverity.danger,
              title: 'Stale Slow Result',
              message: 'Should be discarded',
            ),
          ],
          pagination: PaginationMeta(
            page: 1,
            limit: 20,
            totalRecords: 1,
            totalPages: 1,
            hasNextPage: false,
            hasPrevPage: false,
          ),
        ),
      );
      await firstLoad;

      expect(provider.alerts.single.title, 'Newer Filter Result');

      await provider.setSeverityFilter(AlertSeverity.warning);
      expect(provider.currentPage, 1);
      expect(provider.hasActiveFilters, isTrue);

      await provider.clearFilters();
      expect(provider.hasActiveFilters, isFalse);
      expect(provider.typeFilter, isNull);
      expect(provider.severityFilter, isNull);
      expect(provider.showResolved, isFalse);
    });

    test(
        'resolveAlert steps back from page 2 to page 1 when last active item resolves and prevents duplicate resolve',
        () async {
      final resolveGate = Completer<void>();
      final service = _FakeAlertService()
        ..onFetchAlerts = (req) async {
          if (req.limit == AlertProvider.dashboardPreviewLimit) {
            return const PaginatedResponse(
              items: [],
              pagination: PaginationMeta.empty(limit: 3),
            );
          }
          if (req.page == 2) {
            return const PaginatedResponse(
              items: [
                AlertModel(
                  id: 21,
                  alertType: AlertType.lowStock,
                  rawAlertType: 'low_stock',
                  severity: AlertSeverity.warning,
                  title: 'Last Item On Page 2',
                  message: 'Low',
                ),
              ],
              pagination: PaginationMeta(
                page: 2,
                limit: 20,
                totalRecords: 21,
                totalPages: 2,
                hasNextPage: false,
                hasPrevPage: true,
              ),
            );
          }
          return const PaginatedResponse(
            items: [
              AlertModel(
                id: 1,
                alertType: AlertType.expired,
                rawAlertType: 'expired',
                severity: AlertSeverity.danger,
                title: 'Page 1 Item',
                message: 'Expired',
              ),
            ],
            pagination: PaginationMeta(
              page: 1,
              limit: 20,
              totalRecords: 20,
              totalPages: 2,
              hasNextPage: true,
              hasPrevPage: false,
            ),
          );
        }
        ..onResolveAlert = (_) => resolveGate.future;

      final provider = AlertProvider(service: service);
      await provider.ensureLoaded();
      await provider.goToPage(2);
      expect(provider.currentPage, 2);

      final firstResolve = provider.resolveAlert(21);
      expect(provider.isResolving(21), isTrue);

      await expectLater(
        () => provider.resolveAlert(21),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'MUTATION_IN_PROGRESS',
          ),
        ),
      );

      resolveGate.complete();
      await firstResolve;

      expect(provider.isResolving(21), isFalse);
      expect(provider.currentPage, 1);
      expect(provider.alerts.single.title, 'Page 1 Item');
    });

    test('runExpiryCheck refreshes state, blocks concurrent runs, and reset clears everything',
        () async {
      final checkGate = Completer<ExpiryCheckResult>();
      final service = _FakeAlertService()
        ..onRunExpiryCheck = (_) => checkGate.future;

      final provider = AlertProvider(service: service);
      await provider.ensureLoaded();

      final pendingRun = provider.runExpiryCheck();
      expect(provider.isRunningExpiryCheck, isTrue);

      await expectLater(
        () => provider.runExpiryCheck(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'MUTATION_IN_PROGRESS',
          ),
        ),
      );

      checkGate.complete(
        const ExpiryCheckResult(
          message: 'Done',
          expiredAlertsCreated: 2,
          warningAlertsCreated: 4,
          alertsAutoResolved: 1,
        ),
      );
      final stats = await pendingRun;
      expect(stats.totalChanges, 7);
      expect(provider.isRunningExpiryCheck, isFalse);

      await provider.applyQuickFilter(type: AlertType.expired);
      expect(provider.typeFilter, AlertType.expired);

      provider.reset();
      expect(provider.hasLoadedOnce, isFalse);
      expect(provider.hasLoadedDashboardPreview, isFalse);
      expect(provider.summary, isNull);
      expect(provider.alerts, isEmpty);
      expect(provider.dashboardPreviewAlerts, isEmpty);
      expect(provider.typeFilter, isNull);
      expect(provider.showResolved, isFalse);
    });
  });
}
