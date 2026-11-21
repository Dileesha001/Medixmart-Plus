import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:medixmart_app/models/api_exception.dart';
import 'package:medixmart_app/models/category_model.dart';
import 'package:medixmart_app/models/medicine_model.dart';
import 'package:medixmart_app/models/paginated_response.dart';
import 'package:medixmart_app/providers/medicine_provider.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/services/medicine_service.dart';

class _FetchRequest {
  final String? search;
  final int? categoryId;
  final String isActive;
  final int page;
  final int limit;
  final String sortBy;
  final String sortOrder;

  const _FetchRequest({
    this.search,
    this.categoryId,
    required this.isActive,
    required this.page,
    required this.limit,
    required this.sortBy,
    required this.sortOrder,
  });
}

class _FakeMedicineService extends MedicineService {
  _FakeMedicineService() : super(ApiClient());

  int categoryFetchCount = 0;
  final List<_FetchRequest> fetchRequests = [];

  Future<List<CategoryModel>> Function()? onFetchCategories;
  Future<PaginatedResponse<MedicineModel>> Function(_FetchRequest req)?
      onFetchMedicines;
  Future<CategoryModel> Function(String name, String? description)?
      onCreateCategory;
  Future<MedicineModel> Function(MedicineInput input)? onCreateMedicine;
  Future<MedicineModel> Function(int id, MedicineInput input)? onUpdateMedicine;
  Future<void> Function(int id)? onDeactivateMedicine;
  Future<MedicineModel> Function(int id)? onReactivateMedicine;

  @override
  Future<List<CategoryModel>> fetchCategories() async {
    categoryFetchCount++;
    if (onFetchCategories != null) {
      return onFetchCategories!();
    }
    return const [
      CategoryModel(id: 1, name: 'Analgesics', description: 'Pain relief'),
      CategoryModel(id: 2, name: 'Antibiotics', description: 'Rx only'),
    ];
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
    final req = _FetchRequest(
      search: search,
      categoryId: categoryId,
      isActive: isActive,
      page: page,
      limit: limit,
      sortBy: sortBy,
      sortOrder: sortOrder,
    );
    fetchRequests.add(req);
    if (onFetchMedicines != null) {
      return onFetchMedicines!(req);
    }
    return const PaginatedResponse<MedicineModel>(
      items: [
        MedicineModel(
          id: 1,
          categoryId: 1,
          categoryName: 'Analgesics',
          name: 'Panadol',
          sellingPrice: 25,
          costPrice: 18,
          reorderLevel: 20,
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
  Future<CategoryModel> createCategory({
    required String name,
    String? description,
  }) async {
    if (onCreateCategory != null) {
      return onCreateCategory!(name, description);
    }
    return CategoryModel(id: 99, name: name, description: description);
  }

  @override
  Future<MedicineModel> createMedicine(MedicineInput input) async {
    if (onCreateMedicine != null) {
      return onCreateMedicine!(input);
    }
    return MedicineModel(
      id: 10,
      categoryId: input.categoryId,
      name: input.name,
      sellingPrice: input.sellingPrice,
      costPrice: input.costPrice,
      reorderLevel: input.reorderLevel,
    );
  }

  @override
  Future<MedicineModel> updateMedicine(int id, MedicineInput input) async {
    if (onUpdateMedicine != null) {
      return onUpdateMedicine!(id, input);
    }
    return MedicineModel(
      id: id,
      categoryId: input.categoryId,
      name: input.name,
      sellingPrice: input.sellingPrice,
      costPrice: input.costPrice,
      reorderLevel: input.reorderLevel,
    );
  }

  @override
  Future<void> deactivateMedicine(int id) async {
    if (onDeactivateMedicine != null) {
      return onDeactivateMedicine!(id);
    }
  }

  @override
  Future<MedicineModel> reactivateMedicine(int id) async {
    if (onReactivateMedicine != null) {
      return onReactivateMedicine!(id);
    }
    return MedicineModel(
      id: id,
      categoryId: 1,
      name: 'Reactivated',
      sellingPrice: 25,
      isActive: true,
    );
  }
}

void main() {
  group('MedicineProvider', () {
    test('ensureLoaded loads categories and page 1 medicines once and does not refetch on repeated calls',
        () async {
      final service = _FakeMedicineService();
      final provider = MedicineProvider(
        service: service,
        searchDebounce: const Duration(milliseconds: 10),
      );
      addTearDown(provider.dispose);

      await provider.ensureLoaded();
      await provider.ensureLoaded();

      expect(service.categoryFetchCount, 1);
      expect(service.fetchRequests.length, 1);
      expect(provider.hasLoadedOnce, isTrue);
      expect(provider.categories.length, 2);
      expect(provider.medicines.single.name, 'Panadol');
      expect(provider.errorMessage, isNull);
    });

    test('setSearchQuery debounces requests and discards stale out-of-order responses',
        () async {
      final service = _FakeMedicineService();
      final amoCompleter = Completer<PaginatedResponse<MedicineModel>>();
      final paraCompleter = Completer<PaginatedResponse<MedicineModel>>();

      service.onFetchMedicines = (req) {
        if (req.search == 'amo') return amoCompleter.future;
        if (req.search == 'para') return paraCompleter.future;
        return Future.value(
          const PaginatedResponse(items: [], pagination: PaginationMeta.empty()),
        );
      };

      final provider = MedicineProvider(
        service: service,
        searchDebounce: const Duration(milliseconds: 15),
      );
      addTearDown(provider.dispose);

      provider.setSearchQuery('amo');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(service.fetchRequests.length, 1);
      expect(service.fetchRequests.last.search, 'amo');

      provider.setSearchQuery('para');
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(service.fetchRequests.length, 2);
      expect(service.fetchRequests.last.search, 'para');

      // Newer response ("para") arrives first.
      paraCompleter.complete(
        const PaginatedResponse(
          items: [
            MedicineModel(
              id: 2,
              categoryId: 1,
              name: 'Paracetamol',
              sellingPrice: 20,
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
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.medicines.single.name, 'Paracetamol');

      // Stale response ("amo") arrives late and must be discarded.
      amoCompleter.complete(
        const PaginatedResponse(
          items: [
            MedicineModel(
              id: 1,
              categoryId: 2,
              name: 'Amoxicillin',
              sellingPrice: 40,
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
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(provider.medicines.single.name, 'Paracetamol');
    });

    test('category filter, status filter, sort change, and clearFilters reset page to 1 and query backend with exact parameters',
        () async {
      final service = _FakeMedicineService();
      service.onFetchMedicines = (req) async {
        return PaginatedResponse(
          items: const [
            MedicineModel(
              id: 1,
              categoryId: 2,
              name: 'Amoxil',
              sellingPrice: 50,
            ),
          ],
          pagination: PaginationMeta(
            page: req.page,
            limit: req.limit,
            totalRecords: 40,
            totalPages: 2,
            hasNextPage: req.page < 2,
            hasPrevPage: req.page > 1,
          ),
        );
      };

      final provider = MedicineProvider(
        service: service,
        searchDebounce: const Duration(milliseconds: 10),
      );
      addTearDown(provider.dispose);

      await provider.ensureLoaded();
      await provider.goToPage(2);
      expect(service.fetchRequests.last.page, 2);

      await provider.setCategoryFilter(2);
      expect(service.fetchRequests.last.page, 1);
      expect(service.fetchRequests.last.categoryId, 2);
      expect(provider.hasActiveFilters, isTrue);

      await provider.setStatusFilter(MedicineStatusFilter.inactive);
      expect(service.fetchRequests.last.page, 1);
      expect(service.fetchRequests.last.isActive, 'false');

      await provider.setSort(MedicineSortField.sellingPrice, ascending: false);
      expect(service.fetchRequests.last.sortBy, 'selling_price');
      expect(service.fetchRequests.last.sortOrder, 'desc');

      await provider.clearFilters();
      expect(service.fetchRequests.last.categoryId, isNull);
      expect(service.fetchRequests.last.isActive, 'true');
      expect(service.fetchRequests.last.search, isNull);
      expect(provider.hasActiveFilters, isFalse);
    });

    test('deactivateMedicine on sole item of page 2 under Active filter steps back to page 1 and reloads',
        () async {
      final service = _FakeMedicineService();
      var deactivated = false;
      service.onDeactivateMedicine = (_) async {
        deactivated = true;
      };
      service.onFetchMedicines = (req) async {
        if (!deactivated && req.page == 2) {
          return const PaginatedResponse(
            items: [
              MedicineModel(
                id: 21,
                categoryId: 1,
                name: 'Last Item Page 2',
                sellingPrice: 10,
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
        return PaginatedResponse(
          items: const [
            MedicineModel(
              id: 1,
              categoryId: 1,
              name: 'Item Page 1',
              sellingPrice: 10,
            ),
          ],
          pagination: PaginationMeta(
            page: 1,
            limit: 20,
            totalRecords: deactivated ? 20 : 21,
            totalPages: deactivated ? 1 : 2,
            hasNextPage: !deactivated,
            hasPrevPage: false,
          ),
        );
      };

      final provider = MedicineProvider(service: service);
      addTearDown(provider.dispose);

      await provider.ensureLoaded();
      await provider.goToPage(2);
      expect(provider.pagination.page, 2);
      expect(provider.medicines.single.id, 21);

      await provider.deactivateMedicine(21);

      expect(provider.pagination.page, 1);
      expect(provider.medicines.single.id, 1);
      expect(service.fetchRequests.last.page, 1);
    });

    test('createCategory updates sorted categories list and returns created CategoryModel',
        () async {
      final service = _FakeMedicineService();
      service.onCreateCategory = (name, desc) async =>
          CategoryModel(id: 3, name: name, description: desc);

      final provider = MedicineProvider(service: service);
      addTearDown(provider.dispose);

      await provider.ensureLoaded();
      final created = await provider.createCategory(
        name: 'Allergy',
        description: 'Antihistamines',
      );

      expect(created.id, 3);
      expect(
        provider.categories.map((c) => c.name).toList(),
        ['Allergy', 'Analgesics', 'Antibiotics'],
      );
    });

    test('isMutating blocks overlapping duplicate create calls and rethrows ApiException without erasing medicines list',
        () async {
      final service = _FakeMedicineService();
      final pendingCreate = Completer<MedicineModel>();
      var createCalls = 0;
      service.onCreateMedicine = (input) {
        createCalls++;
        if (createCalls == 1) return pendingCreate.future;
        return Future.error(
          const ApiException(
            code: 'DUPLICATE_ENTRY',
            message: 'Medicine already exists.',
            statusCode: 409,
          ),
        );
      };

      final provider = MedicineProvider(service: service);
      addTearDown(provider.dispose);
      await provider.ensureLoaded();
      expect(provider.medicines.single.name, 'Panadol');

      const input = MedicineInput(
        categoryId: 1,
        name: 'Panadol',
        sellingPrice: 25,
      );

      final firstFuture = provider.createMedicine(input);
      expect(provider.isMutating, isTrue);

      // Overlapping call while first mutation is in flight must be rejected.
      await expectLater(
        provider.createMedicine(input),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'MUTATION_IN_PROGRESS'),
        ),
      );
      expect(createCalls, 1);

      pendingCreate.completeError(
        const ApiException(
          code: 'DUPLICATE_ENTRY',
          message: 'Duplicate medicine.',
          statusCode: 409,
        ),
      );

      await expectLater(
        firstFuture,
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'DUPLICATE_ENTRY'),
        ),
      );
      expect(provider.isMutating, isFalse);
      // Existing list stays intact behind dialog.
      expect(provider.medicines.single.name, 'Panadol');
    });

    test('reset cancels pending debounce and clears cached medicines, categories, filters, and errorMessage',
        () async {
      final service = _FakeMedicineService();
      final provider = MedicineProvider(
        service: service,
        searchDebounce: const Duration(milliseconds: 50),
      );
      addTearDown(provider.dispose);

      await provider.ensureLoaded();
      await provider.setCategoryFilter(1);
      final callsBeforeReset = service.fetchRequests.length;

      provider.setSearchQuery('pending-query');
      provider.reset();

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(service.fetchRequests.length, callsBeforeReset);
      expect(provider.hasLoadedOnce, isFalse);
      expect(provider.medicines, isEmpty);
      expect(provider.categories, isEmpty);
      expect(provider.selectedCategoryId, isNull);
      expect(provider.searchQuery, isEmpty);
      expect(provider.statusFilter, MedicineStatusFilter.active);
      expect(provider.errorMessage, isNull);
    });
  });
}
