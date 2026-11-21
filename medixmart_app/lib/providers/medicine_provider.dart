import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/api_exception.dart';
import '../models/category_model.dart';
import '../models/medicine_model.dart';
import '../models/paginated_response.dart';
import '../services/medicine_service.dart';

/// Active-status filter sent to `GET /api/medicines?is_active=...`.
enum MedicineStatusFilter {
  active('true', 'Active'),
  inactive('false', 'Inactive'),
  all('all', 'All');

  final String queryValue;
  final String label;
  const MedicineStatusFilter(this.queryValue, this.label);
}

/// Sort columns supported by `GET /api/medicines?sortBy=...`.
enum MedicineSortField {
  name('name', 'Name'),
  sellingPrice('selling_price', 'Selling Price'),
  reorderLevel('reorder_level', 'Reorder Level'),
  createdAt('created_at', 'Newest');

  final String queryValue;
  final String label;
  const MedicineSortField(this.queryValue, this.label);
}

/// Shared state provider for the Medicine & Category catalog.
class MedicineProvider extends ChangeNotifier {
  final MedicineService _service;
  final Duration _searchDebounce;

  static const int defaultPageLimit = 20;

  List<CategoryModel> _categories = const [];
  List<MedicineModel> _medicines = const [];
  PaginationMeta _pagination =
      const PaginationMeta.empty(limit: defaultPageLimit);

  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _isCategoriesLoading = false;
  bool _isMutating = false;
  bool _hasLoadedOnce = false;
  bool _isDisposed = false;
  String? _errorMessage;

  String _searchQuery = '';
  int? _selectedCategoryId;
  MedicineStatusFilter _statusFilter = MedicineStatusFilter.active;
  MedicineSortField _sortField = MedicineSortField.name;
  bool _sortAscending = true;
  int _currentPage = 1;

  int _requestSeq = 0;
  Timer? _searchDebounceTimer;

  MedicineProvider({
    required MedicineService service,
    Duration searchDebounce = const Duration(milliseconds: 350),
  })  : _service = service,
        _searchDebounce = searchDebounce;

  List<CategoryModel> get categories => _categories;
  List<MedicineModel> get medicines => _medicines;
  PaginationMeta get pagination => _pagination;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get isCategoriesLoading => _isCategoriesLoading;
  bool get isMutating => _isMutating;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get errorMessage => _errorMessage;

  String get searchQuery => _searchQuery;
  int? get selectedCategoryId => _selectedCategoryId;
  MedicineStatusFilter get statusFilter => _statusFilter;
  MedicineSortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;

  bool get hasActiveFilters =>
      _searchQuery.trim().isNotEmpty ||
      _selectedCategoryId != null ||
      _statusFilter != MedicineStatusFilter.active;

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Loads categories and page 1 medicines once on initial screen mount.
  Future<void> ensureLoaded() async {
    if (_hasLoadedOnce || _isLoading) return;
    await Future.wait([
      loadCategories(),
      _fetchMedicines(page: 1),
    ]);
  }

  /// Reloads categories and the current medicines page from the server.
  Future<void> refresh() async {
    await Future.wait([
      loadCategories(),
      _fetchMedicines(page: _currentPage),
    ]);
  }

  Future<void> loadCategories() async {
    _isCategoriesLoading = true;
    _safeNotify();
    try {
      final fetched = await _service.fetchCategories();
      final sorted = List<CategoryModel>.from(fetched)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _categories = List.unmodifiable(sorted);
    } catch (_) {
      // Categories failure is surfaced if medicines also fail or on explicit retry.
    } finally {
      _isCategoriesLoading = false;
      _safeNotify();
    }
  }

  /// Updates search query with debounce and resets pagination to page 1.
  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _currentPage = 1;
    _searchDebounceTimer?.cancel();
    _safeNotify();

    _searchDebounceTimer = Timer(_searchDebounce, () {
      _fetchMedicines(page: 1);
    });
  }

  Future<void> setCategoryFilter(int? categoryId) async {
    if (_selectedCategoryId == categoryId) return;
    _selectedCategoryId = categoryId;
    _currentPage = 1;
    await _fetchMedicines(page: 1);
  }

  Future<void> setStatusFilter(MedicineStatusFilter filter) async {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    _currentPage = 1;
    await _fetchMedicines(page: 1);
  }

  Future<void> setSort(
    MedicineSortField field, {
    required bool ascending,
  }) async {
    if (_sortField == field && _sortAscending == ascending) return;
    _sortField = field;
    _sortAscending = ascending;
    _currentPage = 1;
    await _fetchMedicines(page: 1);
  }

  Future<void> clearFilters() async {
    _searchDebounceTimer?.cancel();
    _searchQuery = '';
    _selectedCategoryId = null;
    _statusFilter = MedicineStatusFilter.active;
    _sortField = MedicineSortField.name;
    _sortAscending = true;
    _currentPage = 1;
    await _fetchMedicines(page: 1);
  }

  Future<void> goToPage(int page) async {
    final target = page.clamp(1, _pagination.totalPages);
    if (target == _currentPage && _hasLoadedOnce) return;
    _currentPage = target;
    await _fetchMedicines(page: target);
  }

  Future<void> _fetchMedicines({required int page}) async {
    final seq = ++_requestSeq;
    final showFullLoader =
        !_hasLoadedOnce || (_medicines.isEmpty && _errorMessage != null);

    if (showFullLoader) {
      _isLoading = true;
    } else {
      _isRefreshing = true;
    }
    _errorMessage = null;
    _safeNotify();

    try {
      final response = await _service.fetchMedicines(
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        categoryId: _selectedCategoryId,
        isActive: _statusFilter.queryValue,
        page: page,
        limit: defaultPageLimit,
        sortBy: _sortField.queryValue,
        sortOrder: _sortAscending ? 'asc' : 'desc',
      );

      if (seq != _requestSeq || _isDisposed) return;

      _medicines = List.unmodifiable(response.items);
      _pagination = response.pagination;
      _currentPage = response.pagination.page;
      _hasLoadedOnce = true;
      _errorMessage = null;
    } on ApiException catch (e) {
      if (seq != _requestSeq || _isDisposed) return;
      _errorMessage = e.message;
    } catch (_) {
      if (seq != _requestSeq || _isDisposed) return;
      _errorMessage =
          'Unable to load medicines. Please verify server connection and retry.';
    } finally {
      if (seq == _requestSeq && !_isDisposed) {
        _isLoading = false;
        _isRefreshing = false;
        _safeNotify();
      }
    }
  }

  Future<T> _runMutation<T>(Future<T> Function() action) async {
    if (_isMutating) {
      throw const ApiException(
        code: 'MUTATION_IN_PROGRESS',
        message: 'Another save operation is already in progress.',
        statusCode: 409,
      );
    }

    _isMutating = true;
    _safeNotify();
    try {
      return await action();
    } finally {
      _isMutating = false;
      _safeNotify();
    }
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? description,
  }) {
    return _runMutation(() async {
      final created = await _service.createCategory(
        name: name,
        description: description,
      );
      final updated = [
        ..._categories.where((c) => c.id != created.id),
        created,
      ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      _categories = List.unmodifiable(updated);
      _safeNotify();
      return created;
    });
  }

  Future<MedicineModel> createMedicine(MedicineInput input) {
    return _runMutation(() async {
      final created = await _service.createMedicine(input);
      await _fetchMedicines(page: _currentPage);
      return created;
    });
  }

  Future<MedicineModel> updateMedicine(int id, MedicineInput input) {
    return _runMutation(() async {
      final updated = await _service.updateMedicine(id, input);
      await _fetchMedicines(page: _currentPage);
      return updated;
    });
  }

  Future<void> deactivateMedicine(int id) {
    return _runMutation(() async {
      await _service.deactivateMedicine(id);
      final shouldStepBack = _statusFilter == MedicineStatusFilter.active &&
          _medicines.length == 1 &&
          _currentPage > 1;
      final targetPage = shouldStepBack ? _currentPage - 1 : _currentPage;
      _currentPage = targetPage;
      await _fetchMedicines(page: targetPage);
    });
  }

  Future<MedicineModel> reactivateMedicine(int id) {
    return _runMutation(() async {
      final updated = await _service.reactivateMedicine(id);
      final shouldStepBack = _statusFilter == MedicineStatusFilter.inactive &&
          _medicines.length == 1 &&
          _currentPage > 1;
      final targetPage = shouldStepBack ? _currentPage - 1 : _currentPage;
      _currentPage = targetPage;
      await _fetchMedicines(page: targetPage);
      return updated;
    });
  }

  /// Clears all cached catalog data, pending searches, and filters on logout.
  void reset() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = null;
    _requestSeq++;

    final hadState = _hasLoadedOnce ||
        _medicines.isNotEmpty ||
        _categories.isNotEmpty ||
        _searchQuery.isNotEmpty ||
        _selectedCategoryId != null ||
        _statusFilter != MedicineStatusFilter.active ||
        _sortField != MedicineSortField.name ||
        !_sortAscending ||
        _currentPage != 1 ||
        _errorMessage != null ||
        _isLoading ||
        _isRefreshing;

    _categories = const [];
    _medicines = const [];
    _pagination = const PaginationMeta.empty(limit: defaultPageLimit);
    _isLoading = false;
    _isRefreshing = false;
    _isCategoriesLoading = false;
    _hasLoadedOnce = false;
    _errorMessage = null;
    _searchQuery = '';
    _selectedCategoryId = null;
    _statusFilter = MedicineStatusFilter.active;
    _sortField = MedicineSortField.name;
    _sortAscending = true;
    _currentPage = 1;

    if (hadState) {
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _searchDebounceTimer?.cancel();
    super.dispose();
  }
}
