import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medixmart_app/config/app_theme.dart';
import 'package:medixmart_app/models/api_exception.dart';
import 'package:medixmart_app/models/category_model.dart';
import 'package:medixmart_app/models/medicine_model.dart';
import 'package:medixmart_app/models/paginated_response.dart';
import 'package:medixmart_app/models/user_model.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/providers/medicine_provider.dart';
import 'package:medixmart_app/screens/medicines/medicines_screen.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/services/medicine_service.dart';
import 'package:provider/provider.dart';

class _InMemoryMedicineService extends MedicineService {
  _InMemoryMedicineService({
    List<CategoryModel>? categories,
    List<MedicineModel>? medicines,
  })  : categories = List.from(
          categories ??
              const [
                CategoryModel(
                  id: 1,
                  name: 'Analgesics',
                  description: 'Pain relief medicines',
                ),
                CategoryModel(
                  id: 2,
                  name: 'Antibiotics',
                  description: 'Prescription antibacterial catalog',
                ),
              ],
        ),
        medicines = List.from(
          medicines ??
              const [
                MedicineModel(
                  id: 101,
                  categoryId: 1,
                  categoryName: 'Analgesics',
                  name: 'Panadol ActiFast',
                  genericName: 'Paracetamol',
                  brand: 'GSK',
                  dosageForm: 'Tablet',
                  strength: '500mg',
                  sellingPrice: 25.00,
                  costPrice: 18.50,
                  reorderLevel: 20,
                  isActive: true,
                ),
                MedicineModel(
                  id: 102,
                  categoryId: 2,
                  categoryName: 'Antibiotics',
                  name: 'Amoxil 250',
                  genericName: 'Amoxicillin',
                  brand: 'GSK',
                  dosageForm: 'Capsule',
                  strength: '250mg',
                  sellingPrice: 45.00,
                  costPrice: 32.00,
                  reorderLevel: 15,
                  isActive: true,
                ),
                MedicineModel(
                  id: 103,
                  categoryId: 1,
                  categoryName: 'Analgesics',
                  name: 'Old Pain Relief',
                  genericName: 'Aspirin',
                  brand: 'Legacy',
                  dosageForm: 'Sachet',
                  strength: '300mg',
                  sellingPrice: 15.00,
                  costPrice: 10.00,
                  reorderLevel: 5,
                  isActive: false,
                ),
              ],
        ),
        super(ApiClient());

  final List<CategoryModel> categories;
  final List<MedicineModel> medicines;
  int nextCategoryId = 10;
  int nextMedicineId = 200;

  bool failNextFetch = false;
  bool failNextCreateWithDuplicate = false;
  int pageSizeOverride = 20;

  final List<Map<String, dynamic>> fetchLog = [];
  MedicineInput? lastUpdateInput;

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    return List.unmodifiable(categories);
  }

  @override
  Future<CategoryModel> createCategory({
    required String name,
    String? description,
  }) async {
    if (categories.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      throw const ApiException(
        code: 'DUPLICATE_ENTRY',
        message: 'Category already exists.',
        statusCode: 409,
      );
    }
    final created = CategoryModel(
      id: nextCategoryId++,
      name: name,
      description: description,
    );
    categories.add(created);
    return created;
  }

  @override
  Future<PaginatedResponse<MedicineModel>> fetchMedicines({
    String? search,
    int? categoryId,
    String isActive = 'true',
    int page = 1,
    int limit = 20,
    String sortBy = 'name',
    String sortOrder = 'asc',
  }) async {
    fetchLog.add({
      'search': search,
      'categoryId': categoryId,
      'isActive': isActive,
      'page': page,
      'sortBy': sortBy,
      'sortOrder': sortOrder,
    });

    if (failNextFetch) {
      failNextFetch = false;
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach pharmacy server.',
        statusCode: 0,
      );
    }

    var filtered = medicines.where((m) {
      if (isActive == 'true' && !m.isActive) return false;
      if (isActive == 'false' && m.isActive) return false;
      if (categoryId != null && m.categoryId != categoryId) return false;
      if (search != null && search.trim().isNotEmpty) {
        final q = search.trim().toLowerCase();
        final matches = m.name.toLowerCase().contains(q) ||
            (m.genericName?.toLowerCase().contains(q) ?? false) ||
            (m.brand?.toLowerCase().contains(q) ?? false);
        if (!matches) return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      final cmp = switch (sortBy) {
        'selling_price' => a.sellingPrice.compareTo(b.sellingPrice),
        'reorder_level' => a.reorderLevel.compareTo(b.reorderLevel),
        'created_at' => a.id.compareTo(b.id),
        _ => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      };
      return sortOrder == 'desc' ? -cmp : cmp;
    });

    final effectiveLimit = pageSizeOverride;
    final total = filtered.length;
    final totalPages = (total / effectiveLimit).ceil().clamp(1, 999);
    final safePage = page.clamp(1, totalPages);
    final start = (safePage - 1) * effectiveLimit;
    final end = (start + effectiveLimit).clamp(0, total);
    final slice = start < total ? filtered.sublist(start, end) : <MedicineModel>[];

    return PaginatedResponse(
      items: slice,
      pagination: PaginationMeta(
        page: safePage,
        limit: effectiveLimit,
        totalRecords: total,
        totalPages: totalPages,
        hasNextPage: safePage < totalPages,
        hasPrevPage: safePage > 1,
      ),
    );
  }

  @override
  Future<MedicineModel> createMedicine(MedicineInput input) async {
    if (failNextCreateWithDuplicate) {
      failNextCreateWithDuplicate = false;
      throw const ApiException(
        code: 'DUPLICATE_ENTRY',
        message: 'Medicine with identical name and strength already exists.',
        statusCode: 409,
      );
    }
    final catName = categories
        .firstWhere(
          (c) => c.id == input.categoryId,
          orElse: () => const CategoryModel(id: 0, name: 'General'),
        )
        .name;
    final created = MedicineModel(
      id: nextMedicineId++,
      categoryId: input.categoryId,
      categoryName: catName,
      name: input.name.trim(),
      genericName: input.genericName?.trim(),
      brand: input.brand?.trim(),
      dosageForm: input.dosageForm,
      strength: input.strength?.trim(),
      sellingPrice: input.sellingPrice,
      costPrice: input.costPrice,
      reorderLevel: input.reorderLevel,
      isActive: true,
    );
    medicines.add(created);
    return created;
  }

  @override
  Future<MedicineModel> updateMedicine(int id, MedicineInput input) async {
    lastUpdateInput = input;
    final idx = medicines.indexWhere((m) => m.id == id);
    final catName = categories
        .firstWhere(
          (c) => c.id == input.categoryId,
          orElse: () => const CategoryModel(id: 0, name: 'General'),
        )
        .name;
    final updated = medicines[idx].copyWith(
      categoryId: input.categoryId,
      categoryName: catName,
      name: input.name.trim(),
      genericName: input.genericName?.trim(),
      brand: input.brand?.trim(),
      dosageForm: input.dosageForm,
      strength: input.strength?.trim(),
      sellingPrice: input.sellingPrice,
      costPrice: input.costPrice,
      reorderLevel: input.reorderLevel,
      isActive: input.isActive ?? medicines[idx].isActive,
    );
    medicines[idx] = updated;
    return updated;
  }

  @override
  Future<void> deactivateMedicine(int id) async {
    final idx = medicines.indexWhere((m) => m.id == id);
    if (idx != -1) {
      medicines[idx] = medicines[idx].copyWith(isActive: false);
    }
  }

  @override
  Future<MedicineModel> reactivateMedicine(int id) async {
    final idx = medicines.indexWhere((m) => m.id == id);
    final updated = medicines[idx].copyWith(isActive: true);
    medicines[idx] = updated;
    return updated;
  }
}

Widget _wrapMedicinesScreen({
  required _InMemoryMedicineService service,
  required UserModel user,
  MedicineProvider? provider,
}) {
  final authProvider = AuthProvider(
    initialStatus: AuthStatus.authenticated,
    initialUser: user,
    initialToken: 'jwt',
  );
  final medicineProvider = provider ??
      MedicineProvider(
        service: service,
        searchDebounce: const Duration(milliseconds: 10),
      );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<MedicineProvider>.value(value: medicineProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        body: MedicinesScreen(),
      ),
    ),
  );
}

void main() {
  const adminUser = UserModel(
    id: 1,
    username: 'admin',
    role: 'admin',
    fullName: 'Ravindu Bandara',
  );
  const pharmacistUser = UserModel(
    id: 2,
    username: 'pharma',
    role: 'pharmacist',
    fullName: 'Saman Silva',
  );

  testWidgets(
      'MedicinesScreen renders desktop table at 1440x900 with LKR prices, category, form/strength, status badges, and Admin actions',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService();
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    expect(find.text('Medicines'), findsOneWidget);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.text('Panadol ActiFast'), findsOneWidget);
    expect(find.text('Paracetamol · GSK'), findsOneWidget);
    expect(find.text('Tablet · 500mg'), findsOneWidget);
    expect(find.text('Rs. 25.00'), findsOneWidget);
    expect(find.text('Amoxil 250'), findsOneWidget);
    expect(find.text('Rs. 45.00'), findsOneWidget);

    // Admin actions visible
    expect(find.byKey(const Key('medicines_add_button')), findsOneWidget);
    expect(find.byKey(const Key('medicines_categories_button')), findsOneWidget);
    expect(find.byKey(const Key('medicine_edit_101')), findsOneWidget);
    expect(find.byKey(const Key('medicine_deactivate_101')), findsOneWidget);
  });

  testWidgets(
      'MedicinesScreen renders stacked mobile cards at 390x844 with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService();
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    expect(find.text('Panadol ActiFast'), findsOneWidget);
    expect(find.text('Rs. 25.00'), findsOneWidget);
  });

  testWidgets(
      'MedicinesScreen renders stacked cards cleanly at tablet 862x692 with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(862, 692);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService();
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    expect(find.text('Panadol ActiFast'), findsOneWidget);
    expect(find.text('Rs. 25.00'), findsOneWidget);
  });

  testWidgets(
      'MedicinesScreen hides Admin mutations for pharmacist while keeping read-only Categories modal accessible',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService();
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: pharmacistUser),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('medicines_add_button')), findsNothing);
    expect(find.byKey(const Key('medicine_edit_101')), findsNothing);
    expect(find.byKey(const Key('medicine_deactivate_101')), findsNothing);
    expect(find.byKey(const Key('medicines_categories_button')), findsOneWidget);

    // Pharmacist can open Categories modal read-only and inspect descriptions
    await tester.tap(find.byKey(const Key('medicines_categories_button')));
    await tester.pumpAndSettle();

    expect(find.text('Medicine Categories'), findsOneWidget);
    expect(find.text('Pain relief medicines'), findsOneWidget);
    expect(find.text('Prescription antibacterial catalog'), findsOneWidget);
    expect(find.byKey(const Key('category_name_input')), findsNothing);
  });

  testWidgets(
      'MedicinesScreen search, category filter, active/inactive/all toggle, and pagination trigger MedicineProvider updates',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService()..pageSizeOverride = 1;
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    // Page 1 shows Amoxil 250 (sorted A-Z), next page shows Panadol ActiFast
    expect(find.text('Amoxil 250'), findsOneWidget);
    expect(find.text('Panadol ActiFast'), findsNothing);

    await tester.tap(find.byKey(const Key('medicines_next_page')));
    await tester.pumpAndSettle();
    expect(find.text('Panadol ActiFast'), findsOneWidget);

    // Toggle Inactive filter shows legacy inactive item
    await tester.tap(find.byKey(const Key('medicines_status_inactive')));
    await tester.pumpAndSettle();
    expect(find.text('Old Pain Relief'), findsOneWidget);

    // Toggle All and search for Panadol
    await tester.tap(find.byKey(const Key('medicines_status_all')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('medicines_search_bar')),
        matching: find.byType(TextField),
      ),
      'Panadol',
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.text('Panadol ActiFast'), findsOneWidget);
    expect(find.text('Amoxil 250'), findsNothing);
  });

  testWidgets(
      'Admin Add Medicine validates required/numeric fields, supports inline + New Category, maps server 409 DUPLICATE_ENTRY without clearing inputs, and saves cleanly',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService()
      ..failNextCreateWithDuplicate = true;
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('medicines_add_button')));
    await tester.pumpAndSettle();

    // Submitting empty form shows validation error
    await tester.tap(find.byKey(const Key('medicine_form_submit')));
    await tester.pump();
    expect(find.text('Medicine name is required.'), findsOneWidget);

    // Add a new category inline via + New shortcut
    await tester.tap(find.byKey(const Key('medicine_form_new_category')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('category_name_input')),
      'Vitamins',
    );
    await tester.tap(find.byKey(const Key('category_submit_button')));
    await tester.pumpAndSettle();

    // Fill medicine form fields
    await tester.enterText(
      find.byKey(const Key('medicine_form_name')),
      'Vitamin C 1000mg',
    );
    await tester.enterText(
      find.byKey(const Key('medicine_form_selling_price')),
      '120.50',
    );
    await tester.enterText(
      find.byKey(const Key('medicine_form_cost_price')),
      '85.00',
    );
    await tester.enterText(
      find.byKey(const Key('medicine_form_reorder_level')),
      '25',
    );

    // First submit returns 409 DUPLICATE_ENTRY and preserves entered values
    await tester.tap(find.byKey(const Key('medicine_form_submit')));
    await tester.pumpAndSettle();
    expect(
      find.text('Medicine with identical name and strength already exists.'),
      findsOneWidget,
    );
    expect(find.text('Vitamin C 1000mg'), findsOneWidget);

    // Second submit succeeds and displays new item in catalog
    await tester.tap(find.byKey(const Key('medicine_form_submit')));
    await tester.pumpAndSettle();
    expect(find.text('Vitamin C 1000mg'), findsOneWidget);
    expect(find.text('Vitamins'), findsWidgets);
  });

  testWidgets(
      'Admin Edit Medicine handles legacy non-preset dosage_form ("Sachet") without dropdown error and submits updates',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService();
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    // Switch to Inactive to edit the legacy "Sachet" medicine (id: 103)
    await tester.tap(find.byKey(const Key('medicines_status_inactive')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('medicine_edit_103')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Sachet'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('medicine_form_name')),
      'Aspirin Sachet Updated',
    );
    await tester.tap(find.byKey(const Key('medicine_form_submit')));
    await tester.pumpAndSettle();

    expect(service.lastUpdateInput?.dosageForm, 'Sachet');
    expect(find.text('Aspirin Sachet Updated'), findsOneWidget);
  });

  testWidgets(
      'Admin Safe Deactivate requires confirmation dialog and refreshes list; inactive medicine supports Reactivate',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService();
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    // Deactivate Panadol ActiFast (id: 101)
    await tester.tap(find.byKey(const Key('medicine_deactivate_101')));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Medicine'), findsOneWidget);

    await tester.tap(find.text('Deactivate'));
    await tester.pumpAndSettle();
    expect(find.text('Panadol ActiFast'), findsNothing);

    // Switch to Inactive and Reactivate id 101
    await tester.tap(find.byKey(const Key('medicines_status_inactive')));
    await tester.pumpAndSettle();
    expect(find.text('Panadol ActiFast'), findsOneWidget);

    await tester.tap(find.byKey(const Key('medicine_reactivate_101')));
    await tester.pumpAndSettle();
    expect(find.text('Panadol ActiFast'), findsNothing);

    await tester.tap(find.byKey(const Key('medicines_status_active')));
    await tester.pumpAndSettle();
    expect(find.text('Panadol ActiFast'), findsOneWidget);
  });

  testWidgets(
      'MedicinesScreen renders error state with working Retry button when initial fetch fails',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _InMemoryMedicineService()..failNextFetch = true;
    await tester.pumpWidget(
      _wrapMedicinesScreen(service: service, user: adminUser),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unable to reach pharmacy server.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Panadol ActiFast'), findsOneWidget);
  });
}
