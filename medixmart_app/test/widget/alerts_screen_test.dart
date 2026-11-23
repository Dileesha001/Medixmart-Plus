import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medixmart_app/config/app_theme.dart';
import 'package:medixmart_app/main.dart';
import 'package:medixmart_app/models/alert_model.dart';
import 'package:medixmart_app/models/category_model.dart';
import 'package:medixmart_app/models/medicine_model.dart';
import 'package:medixmart_app/models/paginated_response.dart';
import 'package:medixmart_app/models/user_model.dart';
import 'package:medixmart_app/providers/alert_provider.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/providers/dashboard_provider.dart';
import 'package:medixmart_app/providers/medicine_provider.dart';
import 'package:medixmart_app/screens/alerts/alerts_screen.dart';
import 'package:medixmart_app/services/alert_service.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/services/auth_service.dart';
import 'package:medixmart_app/services/medicine_service.dart';
import 'package:provider/provider.dart';

class _TestTokenStorage implements TokenStorage {
  final Map<String, String> store;
  _TestTokenStorage([Map<String, String>? initial])
      : store = Map<String, String>.from(initial ?? const {});

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;

  @override
  Future<void> delete(String key) async => store.remove(key);
}

class _StubAuthService extends AuthService {
  const _StubAuthService();

  @override
  Future<void> logout(String token) async {}
}

class _StubMedicineService extends MedicineService {
  _StubMedicineService() : super(ApiClient());

  @override
  Future<List<CategoryModel>> fetchCategories() async => const [];

  @override
  Future<PaginatedResponse<MedicineModel>> fetchMedicines({
    String? search,
    int? categoryId,
    String isActive = 'true',
    int page = 1,
    int limit = 20,
    String sortBy = 'name',
    String sortOrder = 'asc',
  }) async =>
      const PaginatedResponse(
        items: [],
        pagination: PaginationMeta.empty(),
      );
}

class _InMemoryAlertService extends AlertService {
  final List<AlertModel> alerts;
  bool failNextFetch = false;
  ExpiryCheckResult nextExpiryResult = const ExpiryCheckResult(
    message: 'Expiry alert engine executed successfully.',
    expiredAlertsCreated: 1,
    warningAlertsCreated: 3,
    alertsAutoResolved: 2,
  );
  int pageSize = 20;

  _InMemoryAlertService({List<AlertModel>? initialAlerts})
      : alerts = List.from(
          initialAlerts ??
              [
                AlertModel(
                  id: 1,
                  alertType: AlertType.expired,
                  rawAlertType: 'expired',
                  severity: AlertSeverity.danger,
                  title: 'Batch B-014 Expired',
                  message:
                      'Batch B-014 of Cetirizine (10mg) expired on 2026-09-30. Immediate quarantine required.',
                  referenceTable: 'batches',
                  referenceId: 14,
                  createdAt: DateTime(2026, 11, 20, 6, 0),
                ),
                AlertModel(
                  id: 2,
                  alertType: AlertType.expiryWarning,
                  rawAlertType: 'expiry_warning',
                  severity: AlertSeverity.warning,
                  title: 'Batch B-061 Near Expiry (Return Window)',
                  message:
                      'Batch B-061 of Losartan Potassium (50mg) expires on 2027-04-15 (142 days remaining). Eligible for vendor return to Cipla Lanka.',
                  referenceTable: 'batches',
                  referenceId: 61,
                  createdAt: DateTime(2026, 11, 22, 6, 0),
                ),
                AlertModel(
                  id: 3,
                  alertType: AlertType.lowStock,
                  rawAlertType: 'low_stock',
                  severity: AlertSeverity.warning,
                  title: 'Amoxicillin 250mg Cap Low Stock',
                  message: '04 Packs remaining. Reorder level is 15 packs.',
                  referenceTable: 'medicines',
                  referenceId: 8,
                  createdAt: DateTime(2026, 11, 23, 14, 15),
                ),
                AlertModel(
                  id: 4,
                  alertType: AlertType.birthday,
                  rawAlertType: 'birthday',
                  severity: AlertSeverity.info,
                  title: 'Customer Birthday Today',
                  message: 'Kamal Perera celebrates a birthday today.',
                  referenceTable: 'customers',
                  referenceId: 12,
                  createdAt: DateTime(2026, 11, 24, 7, 0),
                ),
                AlertModel(
                  id: 5,
                  alertType: AlertType.lowStock,
                  rawAlertType: 'low_stock',
                  severity: AlertSeverity.warning,
                  title: 'Omeprazole 20mg Restocked',
                  message: 'Replenished via batch B-109.',
                  referenceTable: 'medicines',
                  referenceId: 15,
                  isResolved: true,
                  createdAt: DateTime(2026, 11, 18, 9, 0),
                  resolvedAt: DateTime(2026, 11, 19, 11, 30),
                ),
              ],
        ),
        super(ApiClient());

  @override
  Future<AlertSummary> fetchSummary() async {
    final active = alerts.where((a) => !a.isResolved).toList();
    return AlertSummary(
      totalActive: active.length,
      dangerCount:
          active.where((a) => a.severity == AlertSeverity.danger).length,
      warningCount:
          active.where((a) => a.severity == AlertSeverity.warning).length,
      infoCount: active.where((a) => a.severity == AlertSeverity.info).length,
      expiredCount:
          active.where((a) => a.alertType == AlertType.expired).length,
      expiringSoonCount:
          active.where((a) => a.alertType == AlertType.expiryWarning).length,
      lowStockCount:
          active.where((a) => a.alertType == AlertType.lowStock).length,
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
    if (failNextFetch && limit != AlertProvider.dashboardPreviewLimit) {
      failNextFetch = false;
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach pharmacy server.',
        statusCode: 0,
      );
    }

    final filtered = alerts.where((a) {
      if (a.isResolved != isResolved) return false;
      if (alertType != null && a.alertType != alertType) return false;
      if (severity != null && a.severity != severity) return false;
      return true;
    }).toList(growable: false);

    final effectiveLimit = limit == 3 ? 3 : pageSize;
    final total = filtered.length;
    final totalPages = total == 0 ? 1 : (total / effectiveLimit).ceil();
    final start = ((page - 1) * effectiveLimit).clamp(0, total);
    final end = (start + effectiveLimit).clamp(0, total);

    return PaginatedResponse<AlertModel>(
      items: filtered.sublist(start, end),
      pagination: PaginationMeta(
        page: page,
        limit: effectiveLimit,
        totalRecords: total,
        totalPages: totalPages,
        hasNextPage: page < totalPages,
        hasPrevPage: page > 1,
      ),
    );
  }

  @override
  Future<void> resolveAlert(int id) async {
    final idx = alerts.indexWhere((a) => a.id == id);
    if (idx >= 0) {
      final current = alerts[idx];
      alerts[idx] = AlertModel(
        id: current.id,
        alertType: current.alertType,
        rawAlertType: current.rawAlertType,
        severity: current.severity,
        title: current.title,
        message: current.message,
        referenceTable: current.referenceTable,
        referenceId: current.referenceId,
        isResolved: true,
        createdAt: current.createdAt,
        resolvedAt: DateTime(2026, 11, 24, 12, 0),
      );
    }
  }

  @override
  Future<ExpiryCheckResult> runExpiryCheck({int? monthsAhead}) async {
    return nextExpiryResult;
  }
}

const _adminUser = UserModel(
  id: 1,
  username: 'admin',
  role: 'admin',
  fullName: 'Ravindu Bandara',
);

const _pharmacistUser = UserModel(
  id: 2,
  username: 'pharma',
  role: 'pharmacist',
  fullName: 'Saman Silva',
);

Widget _wrapAlertsScreen({
  required AlertService service,
  required UserModel user,
  bool showMenuButton = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          initialStatus: AuthStatus.authenticated,
          initialUser: user,
          initialToken: 'jwt',
        ),
      ),
      ChangeNotifierProvider(
        create: (_) => AlertProvider(service: service),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: AlertsScreen(showMenuButton: showMenuButton),
      ),
    ),
  );
}

void main() {
  testWidgets(
      'AlertsScreen renders responsively at desktop (1440x900), tablet (862x692), and mobile (390x844)',
      (WidgetTester tester) async {
    for (final size in const [
      Size(1440, 900),
      Size(862, 692),
      Size(390, 844),
    ]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final service = _InMemoryAlertService();
      await tester.pumpWidget(
        _wrapAlertsScreen(
          service: service,
          user: _adminUser,
          showMenuButton: size.width < 1024,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Alerts'), findsOneWidget);
      expect(find.text('4 active'), findsOneWidget);
      expect(find.text('Batch B-014 Expired'), findsOneWidget);
      expect(find.text('Customer Birthday Today'), findsOneWidget);
      expect(find.byKey(const Key('alerts_run_expiry_button')), findsOneWidget);
    }
  });

  testWidgets(
      'RBAC hides Run Expiry Check for pharmacist while allowing Resolve',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryAlertService();
    await tester.pumpWidget(
      _wrapAlertsScreen(service: service, user: _pharmacistUser),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('alerts_run_expiry_button')), findsNothing);
    expect(find.byKey(const Key('alert_resolve_1')), findsOneWidget);
  });

  testWidgets(
      'Summary cards, Status (Active/Resolved), Type, Severity, and Reset filters work',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryAlertService();
    await tester.pumpWidget(
      _wrapAlertsScreen(service: service, user: _adminUser),
    );
    await tester.pumpAndSettle();

    // Tap Expired summary card -> filters to expired only
    await tester.tap(find.byKey(const Key('alerts_summary_expired')));
    await tester.pumpAndSettle();
    expect(find.text('Batch B-014 Expired'), findsOneWidget);
    expect(find.text('Amoxicillin 250mg Cap Low Stock'), findsNothing);
    expect(find.byKey(const Key('alerts_clear_filters')), findsOneWidget);

    // Reset filters restores all 4 active alerts
    await tester.tap(find.byKey(const Key('alerts_clear_filters')));
    await tester.pumpAndSettle();
    expect(find.text('Amoxicillin 250mg Cap Low Stock'), findsOneWidget);
    expect(find.text('Customer Birthday Today'), findsOneWidget);

    // Switch to Resolved archive
    await tester.tap(find.byKey(const Key('alerts_status_resolved')));
    await tester.pumpAndSettle();
    expect(find.text('Omeprazole 20mg Restocked'), findsOneWidget);
    expect(find.text('Batch B-014 Expired'), findsNothing);
    expect(find.byKey(const Key('alert_resolve_5')), findsNothing);

    // Switch back to Active and filter via Type & Severity dropdowns
    await tester.tap(find.byKey(const Key('alerts_status_active')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alerts_type_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Low Stock').last);
    await tester.pumpAndSettle();
    expect(find.text('Amoxicillin 250mg Cap Low Stock'), findsOneWidget);
    expect(find.text('Batch B-014 Expired'), findsNothing);

    await tester.tap(find.byKey(const Key('alerts_severity_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Danger').last);
    await tester.pumpAndSettle();
    expect(find.text('No matching alerts'), findsOneWidget);

    await tester.tap(find.text('Clear Filters'));
    await tester.pumpAndSettle();
    expect(find.text('Batch B-014 Expired'), findsOneWidget);
  });

  testWidgets(
      'Resolve flow confirms before resolving and updates active counters',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryAlertService();
    await tester.pumpWidget(
      _wrapAlertsScreen(service: service, user: _adminUser),
    );
    await tester.pumpAndSettle();

    // Cancel leaves alert active
    await tester.tap(find.byKey(const Key('alert_resolve_1')));
    await tester.pumpAndSettle();
    expect(find.text('Resolve Alert'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Batch B-014 Expired'), findsOneWidget);

    // Confirm resolves alert and updates count
    await tester.tap(find.byKey(const Key('alert_resolve_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Resolve').last);
    await tester.pumpAndSettle();

    expect(find.text('Alert marked as resolved.'), findsOneWidget);
    expect(find.text('3 active'), findsOneWidget);
    expect(find.text('Batch B-014 Expired'), findsNothing);
  });

  testWidgets(
      'Admin Run Expiry Check shows stats snackbar and empty-changes message',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryAlertService();
    await tester.pumpWidget(
      _wrapAlertsScreen(service: service, user: _adminUser),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('alerts_run_expiry_button')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Expiry check complete: 1 expired, 3 return-window alerts created, 2 auto-resolved.',
      ),
      findsOneWidget,
    );

    service.nextExpiryResult = const ExpiryCheckResult(
      message: 'Done',
      expiredAlertsCreated: 0,
      warningAlertsCreated: 0,
      alertsAutoResolved: 0,
    );
    await tester.tap(find.byKey(const Key('alerts_run_expiry_button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Expiry check complete — no new alerts.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'Initial error state, inline post-initial retry banner, and empty states render cleanly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryAlertService(initialAlerts: const [])
      ..failNextFetch = true;
    await tester.pumpWidget(
      _wrapAlertsScreen(service: service, user: _adminUser),
    );
    await tester.pumpAndSettle();

    // Initial full error state -> Retry recovers to empty active state
    expect(find.text('Could not load alerts'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('All caught up'), findsOneWidget);

    // Switch to Resolved empty state
    await tester.tap(find.byKey(const Key('alerts_status_resolved')));
    await tester.pumpAndSettle();
    expect(find.text('No resolved alerts yet'), findsOneWidget);

    // Populate alert, reload, then fail subsequent filter change -> inline error banner
    service.alerts.add(
      const AlertModel(
        id: 50,
        alertType: AlertType.lowStock,
        rawAlertType: 'low_stock',
        severity: AlertSeverity.warning,
        title: 'Metformin Low Stock',
        message: '5 packs left',
      ),
    );
    await tester.tap(find.byKey(const Key('alerts_status_active')));
    await tester.pumpAndSettle();
    expect(find.text('Metformin Low Stock'), findsOneWidget);

    service.failNextFetch = true;
    await tester.tap(find.byKey(const Key('alerts_status_resolved')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerts_inline_error_banner')), findsOneWidget);
    expect(find.text('Metformin Low Stock'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alerts_inline_error_retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerts_inline_error_banner')), findsNothing);
  });

  testWidgets('Pagination Next/Previous pages through alerts',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryAlertService()..pageSize = 2;
    await tester.pumpWidget(
      _wrapAlertsScreen(service: service, user: _adminUser),
    );
    await tester.pumpAndSettle();

    expect(find.text('Showing 1–2 of 4 alerts'), findsOneWidget);
    expect(find.text('Page 1 of 2'), findsOneWidget);

    await tester.tap(find.byKey(const Key('alerts_next_page')));
    await tester.pumpAndSettle();
    expect(find.text('Showing 3–4 of 4 alerts'), findsOneWidget);
    expect(find.text('Page 2 of 2'), findsOneWidget);
    expect(find.text('Customer Birthday Today'), findsOneWidget);
  });

  testWidgets(
      'MedixmartApp wires live Dashboard alerts, KPI quick-jump, View all, and resets on logout',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _TestTokenStorage({
      AuthProvider.tokenStorageKey: 'admin-jwt',
    });
    final authProvider = AuthProvider(
      authService: const _StubAuthService(),
      tokenStorage: storage,
      initialStatus: AuthStatus.authenticated,
      initialUser: _adminUser,
      initialToken: 'admin-jwt',
    );
    final apiClient = ApiClient(
      httpClient: MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/alerts/summary') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'total_active': 7,
                'danger_count': 2,
                'warning_count': 5,
                'info_count': 0,
                'expired_count': 2,
                'expiring_soon_count': 3,
                'low_stock_count': 2,
              },
            }),
            200,
          );
        }
        if (request.method == 'GET' && request.url.path == '/api/alerts') {
          final type = request.url.queryParameters['alert_type'];
          final items = type == 'low_stock'
              ? [
                  {
                    'id': 88,
                    'alert_type': 'low_stock',
                    'severity': 'warning',
                    'title': 'Live Low Stock Alert',
                    'message': '02 Packs left · Reorder at 10',
                    'reference_table': 'medicines',
                    'reference_id': 4,
                    'is_resolved': false,
                    'created_at': '2026-11-24T00:00:00.000Z',
                  },
                ]
              : [
                  {
                    'id': 77,
                    'alert_type': 'expired',
                    'severity': 'danger',
                    'title': 'Live Expired Batch Alert',
                    'message': 'Batch #LIVE-01 expired yesterday.',
                    'reference_table': 'batches',
                    'reference_id': 9,
                    'is_resolved': false,
                    'created_at': '2026-11-24T00:00:00.000Z',
                  },
                ];
          return http.Response(
            jsonEncode({
              'success': true,
              'data': items,
              'meta': {
                'page': 1,
                'limit': 20,
                'totalRecords': items.length,
                'totalPages': 1,
                'hasNextPage': false,
                'hasPrevPage': false,
              },
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      }),
      tokenStorage: storage,
      baseUrlOverride: 'http://127.0.0.1:3000/api',
    );
    final alertProvider = AlertProvider(service: AlertService(apiClient));
    final medicineProvider = MedicineProvider(service: _StubMedicineService());

    await tester.pumpWidget(
      MedixmartApp(
        authProvider: authProvider,
        dashboardProvider: DashboardProvider(),
        apiClient: apiClient,
        medicineProvider: medicineProvider,
        alertProvider: alertProvider,
      ),
    );
    await tester.pumpAndSettle();

    // Live sidebar badge, KPI counts, and Recent Alerts from API
    expect(find.text('7'), findsOneWidget);
    expect(find.text('02 Items'), findsOneWidget);
    expect(find.text('03 Batches'), findsOneWidget);
    expect(find.text('2 expired · Eligible for return'), findsOneWidget);
    expect(find.text('View all (7)'), findsOneWidget);
    expect(find.text('Live Expired Batch Alert'), findsOneWidget);

    // Tapping Low Stock KPI card navigates to AlertsScreen filtered to low_stock
    await tester.tap(find.text('02 Items'));
    await tester.pumpAndSettle();
    expect(alertProvider.typeFilter, AlertType.lowStock);
    expect(find.text('Live Low Stock Alert'), findsOneWidget);

    // Navigate back to Dashboard and tap View all (7)
    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View all (7)'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('alerts_run_expiry_button')), findsOneWidget);

    // Logging out resets AlertProvider completely
    await tester.tap(find.byKey(const Key('sidebar_logout_button')));
    await tester.pumpAndSettle();
    expect(find.text('Staff Sign In'), findsOneWidget);
    expect(alertProvider.hasLoadedDashboardPreview, isFalse);
    expect(alertProvider.hasLoadedOnce, isFalse);
    expect(alertProvider.summary, isNull);
    expect(alertProvider.alerts, isEmpty);
  });
}
