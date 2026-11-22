import '../models/category_model.dart';
import '../models/medicine_model.dart';
import '../models/paginated_response.dart';
import 'api_client.dart';

/// REST client for `/api/categories` and `/api/medicines`.
class MedicineService {
  final ApiClient _apiClient;

  const MedicineService(this._apiClient);

  Future<List<CategoryModel>> fetchCategories() async {
    final body = await _apiClient.get('/categories');
    final rawList = body['data'] as List<dynamic>? ?? const [];
    return rawList
        .whereType<Map<String, dynamic>>()
        .map(CategoryModel.fromJson)
        .toList(growable: false);
  }

  Future<CategoryModel> createCategory({
    required String name,
    String? description,
  }) async {
    final cleanDesc = description?.trim();
    final body = await _apiClient.post(
      '/categories',
      body: {
        'name': name.trim(),
        if (cleanDesc != null && cleanDesc.isNotEmpty) 'description': cleanDesc,
      },
    );
    return CategoryModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<PaginatedResponse<MedicineModel>> fetchMedicines({
    String? search,
    int? categoryId,
    String isActive = 'true',
    int page = 1,
    int limit = 20,
    String sortBy = 'name',
    String sortOrder = 'asc',
  }) async {
    final trimmedSearch = search?.trim();
    final body = await _apiClient.get(
      '/medicines',
      queryParameters: {
        if (trimmedSearch != null && trimmedSearch.isNotEmpty)
          'search': trimmedSearch,
        if (categoryId != null) 'category_id': categoryId,
        'is_active': isActive,
        'page': page,
        'limit': limit,
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      },
    );

    final rawList = body['data'] as List<dynamic>? ?? const [];
    final items = rawList
        .whereType<Map<String, dynamic>>()
        .map(MedicineModel.fromJson)
        .toList(growable: false);
    final pagination = PaginationMeta.fromMetaJson(
      body['meta'] as Map<String, dynamic>?,
      itemCount: items.length,
      defaultLimit: limit,
    );

    return PaginatedResponse<MedicineModel>(
      items: items,
      pagination: pagination,
    );
  }

  Future<MedicineModel> fetchMedicineById(int id) async {
    final body = await _apiClient.get('/medicines/$id');
    return MedicineModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<MedicineModel> createMedicine(MedicineInput input) async {
    final body = await _apiClient.post('/medicines', body: input.toJson());
    return MedicineModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<MedicineModel> updateMedicine(int id, MedicineInput input) async {
    final body = await _apiClient.put('/medicines/$id', body: input.toJson());
    return MedicineModel.fromJson(body['data'] as Map<String, dynamic>);
  }

  Future<void> deactivateMedicine(int id) async {
    await _apiClient.patch('/medicines/$id/deactivate');
  }

  Future<MedicineModel> reactivateMedicine(int id) async {
    final body = await _apiClient.put(
      '/medicines/$id',
      body: const {'is_active': true},
    );
    return MedicineModel.fromJson(body['data'] as Map<String, dynamic>);
  }
}
