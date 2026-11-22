import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medixmart_app/config/app_theme.dart';
import 'package:medixmart_app/models/category_model.dart';
import 'package:medixmart_app/models/medicine_model.dart';
import 'package:medixmart_app/models/paginated_response.dart';
import 'package:medixmart_app/models/user_model.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/providers/dashboard_provider.dart';
import 'package:medixmart_app/providers/medicine_provider.dart';
import 'package:medixmart_app/screens/dashboard/admin_dashboard_screen.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/services/medicine_service.dart';
import 'package:provider/provider.dart';

class _StubMedicineService extends MedicineService {
  _StubMedicineService() : super(ApiClient());

  @override
  Future<List<CategoryModel>> fetchCategories() async => const [
        CategoryModel(id: 1, name: 'Analgesics'),
      ];

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
        items: [
          MedicineModel(
            id: 1,
            categoryId: 1,
            categoryName: 'Analgesics',
            name: 'Shell Catalog Panadol',
            sellingPrice: 25,
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

Widget _buildDashboardTestApp({
  AuthProvider? authProvider,
  MedicineProvider? medicineProvider,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => authProvider ?? AuthProvider()),
      ChangeNotifierProvider(create: (_) => DashboardProvider()),
      ChangeNotifierProvider(
        create: (_) =>
            medicineProvider ??
            MedicineProvider(service: _StubMedicineService()),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const AdminDashboardScreen(),
    ),
  );
}

void main() {
  testWidgets(
      'AdminDashboardScreen renders Figma 46:355 desktop layout at 1440x900',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildDashboardTestApp());
    await tester.pumpAndSettle();

    // Permanent sidebar visible, no hamburger menu button
    expect(find.byKey(const Key('dashboard_menu_button')), findsNothing);
    expect(find.text('Medixmart Plus'), findsOneWidget);
    expect(find.text('ADMIN'), findsOneWidget);
    expect(find.text('Ravindu Bandara'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.byKey(const Key('sidebar_logout_button')), findsOneWidget);

    // KPI Cards
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('Rs. 48,750.00'), findsOneWidget);
    expect(find.text('08 Items'), findsOneWidget);
    expect(find.text('12 Batches'), findsOneWidget);
    expect(find.text('Rs. 19,400.00'), findsOneWidget);

    // 7-Day Sales & Alerts
    expect(find.text('Last 7 Days Sales'), findsOneWidget);
    expect(find.text('Rs. 284,600.00 total'), findsOneWidget);
    expect(find.text('Recent Alerts'), findsOneWidget);
    expect(find.text('View all (20)'), findsOneWidget);

    // Inventory Watchlist
    expect(find.text('Inventory Watchlist'), findsOneWidget);
    expect(find.text('Amoxicillin 250mg Cap'), findsNWidgets(2));
    expect(find.text('Paracetamol BP 500mg'), findsOneWidget);
    expect(find.text('Metformin HCl 500mg'), findsOneWidget);
  });

  testWidgets(
      'AdminDashboardScreen adapts cleanly at tablet 862x692 with drawer navigation',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(862, 692);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildDashboardTestApp());
    await tester.pumpAndSettle();

    // Compact shell uses drawer menu button
    expect(find.byKey(const Key('dashboard_menu_button')), findsOneWidget);
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('Last 7 Days Sales'), findsOneWidget);
    expect(find.text('Recent Alerts'), findsOneWidget);
    expect(find.text('Inventory Watchlist'), findsOneWidget);

    // Opening drawer reveals sidebar navigation and logout action
    await tester.tap(find.byKey(const Key('dashboard_menu_button')));
    await tester.pumpAndSettle();

    expect(find.text('Medixmart Plus'), findsOneWidget);
    expect(find.text('Ravindu Bandara'), findsOneWidget);
    expect(find.byKey(const Key('sidebar_logout_button')), findsOneWidget);
  });

  testWidgets(
      'AdminDashboardScreen adapts cleanly at mobile 390x844 with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_buildDashboardTestApp());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard_menu_button')), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('New Sale'), findsOneWidget);
    expect(find.text("Today's Sales"), findsOneWidget);
    expect(find.text('Last 7 Days Sales'), findsOneWidget);
    expect(find.text('Recent Alerts'), findsOneWidget);
    expect(find.text('Inventory Watchlist'), findsOneWidget);
  });

  testWidgets(
      'AdminDashboardScreen hides Watchlist Add Medicine button when signed in as pharmacist',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = AuthProvider(
      initialStatus: AuthStatus.authenticated,
      initialUser: const UserModel(
        id: 2,
        username: 'pharma',
        role: 'pharmacist',
        fullName: 'Saman Silva',
      ),
      initialToken: 'jwt',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(authProvider: authProvider),
    );
    await tester.pumpAndSettle();

    expect(find.text('PHARMACIST'), findsOneWidget);
    expect(find.text('Add Medicine'), findsNothing);
    expect(find.text('Receive Batch'), findsOneWidget);
  });

  testWidgets(
      'Clicking Medicines in sidebar switches main content to MedicinesScreen inside persistent shell',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = AuthProvider(
      initialStatus: AuthStatus.authenticated,
      initialUser: const UserModel(
        id: 1,
        username: 'admin',
        role: 'admin',
        fullName: 'Ravindu Bandara',
      ),
      initialToken: 'jwt',
    );

    await tester.pumpWidget(
      _buildDashboardTestApp(authProvider: authProvider),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Medicines'));
    await tester.pumpAndSettle();

    expect(find.text('Shell Catalog Panadol'), findsOneWidget);
    // Sidebar remains mounted on desktop
    expect(find.text('Medixmart Plus'), findsOneWidget);
    expect(find.byKey(const Key('medicines_add_button')), findsOneWidget);
  });
}
