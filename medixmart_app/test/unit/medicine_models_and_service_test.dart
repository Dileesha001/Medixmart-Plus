import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medixmart_app/models/category_model.dart';
import 'package:medixmart_app/models/medicine_model.dart';
import 'package:medixmart_app/models/paginated_response.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/services/medicine_service.dart';
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
  group('Models & Formatters', () {
    test('CategoryModel.fromJson parses category payload', () {
      final cat = CategoryModel.fromJson({
        'id': 3,
        'name': 'Antibiotics',
        'description': 'Prescription antibacterial medicines',
        'created_at': '2026-11-19T06:00:00.000Z',
      });

      expect(cat.id, 3);
      expect(cat.name, 'Antibiotics');
      expect(cat.description, 'Prescription antibacterial medicines');
      expect(cat.createdAt, isNotNull);
    });

    test(
        'MedicineModel.fromJson parses PostgreSQL NUMERIC strings and numeric values plus optional available_stock',
        () {
      final fromStrings = MedicineModel.fromJson({
        'id': 5,
        'category_id': 1,
        'category_name': 'Analgesics',
        'name': 'Panadol ActiFast',
        'generic_name': 'Paracetamol',
        'brand': 'GSK',
        'dosage_form': 'Tablet',
        'strength': '500mg',
        'selling_price': '25.00',
        'cost_price': '18.50',
        'reorder_level': 20,
        'is_active': true,
        'created_at': '2026-11-19T06:00:00.000Z',
        'updated_at': '2026-11-19T06:00:00.000Z',
      });

      expect(fromStrings.sellingPrice, 25.0);
      expect(fromStrings.costPrice, 18.5);
      expect(fromStrings.reorderLevel, 20);
      expect(fromStrings.isActive, isTrue);
      expect(fromStrings.availableStock, isNull);

      final fromNums = MedicineModel.fromJson({
        'id': 6,
        'category_id': 2,
        'name': 'Amoxil',
        'dosage_form': 'Capsule',
        'selling_price': 45,
        'cost_price': 32.25,
        'reorder_level': '15',
        'is_active': false,
        'available_stock': 40,
      });

      expect(fromNums.sellingPrice, 45.0);
      expect(fromNums.costPrice, 32.25);
      expect(fromNums.reorderLevel, 15);
      expect(fromNums.isActive, isFalse);
      expect(fromNums.availableStock, 40);
    });

    test('MedicineInput.toJson trims strings and converts empty optionals to null',
        () {
      const input = MedicineInput(
        categoryId: 2,
        name: '  Amoxil  ',
        genericName: '   ',
        brand: ' GSK ',
        dosageForm: 'Capsule',
        strength: '',
        sellingPrice: 45.5,
        costPrice: 30,
        reorderLevel: 25,
      );

      expect(input.toJson(), {
        'category_id': 2,
        'name': 'Amoxil',
        'generic_name': null,
        'brand': 'GSK',
        'dosage_form': 'Capsule',
        'strength': null,
        'selling_price': 45.5,
        'cost_price': 30.0,
        'reorder_level': 25,
      });
    });

    test(
        'PaginationMeta.fromMetaJson parses flat backend meta and falls back to nested meta.pagination',
        () {
      final flat = PaginationMeta.fromMetaJson(
        {
          'page': 2,
          'limit': 20,
          'totalRecords': 45,
          'totalPages': 3,
          'hasNextPage': true,
          'hasPrevPage': true,
        },
        itemCount: 20,
      );
      expect(flat.page, 2);
      expect(flat.limit, 20);
      expect(flat.totalRecords, 45);
      expect(flat.totalPages, 3);
      expect(flat.hasNextPage, isTrue);
      expect(flat.hasPrevPage, isTrue);

      final nested = PaginationMeta.fromMetaJson(
        {
          'pagination': {
            'page': 1,
            'limit': 10,
            'total': 12,
            'totalPages': 2,
            'hasNext': true,
            'hasPrev': false,
          },
        },
        itemCount: 10,
      );
      expect(nested.page, 1);
      expect(nested.limit, 10);
      expect(nested.totalRecords, 12);
      expect(nested.totalPages, 2);
      expect(nested.hasNextPage, isTrue);
      expect(nested.hasPrevPage, isFalse);
    });

    test('MmFormatters.currencyLkr formats Sri Lankan rupee amounts with thousand separators',
        () {
      expect(MmFormatters.currencyLkr(0), 'Rs. 0.00');
      expect(MmFormatters.currencyLkr(25.5), 'Rs. 25.50');
      expect(MmFormatters.currencyLkr(48750), 'Rs. 48,750.00');
      expect(MmFormatters.currencyLkr(1234567.89), 'Rs. 1,234,567.89');
      expect(MmFormatters.currencyLkr(-1500.5), '-Rs. 1,500.50');
    });
  });

  group('MedicineService', () {
    test(
        'fetchMedicines sends camelCase sortBy/sortOrder, is_active, search, category_id, page, limit and parses PaginatedResponse',
        () async {
      late http.Request captured;
      final apiClient = ApiClient(
        httpClient: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {
                  'id': 5,
                  'category_id': 1,
                  'category_name': 'Analgesics',
                  'name': 'Panadol',
                  'dosage_form': 'Tablet',
                  'strength': '500mg',
                  'selling_price': '25.00',
                  'cost_price': '18.50',
                  'reorder_level': 20,
                  'is_active': true,
                },
              ],
              'meta': {
                'page': 2,
                'limit': 15,
                'totalRecords': 31,
                'totalPages': 3,
                'hasNextPage': true,
                'hasPrevPage': true,
              },
            }),
            200,
          );
        }),
        tokenStorage: _MemStorage({AuthProvider.tokenStorageKey: 'jwt'}),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );

      final service = MedicineService(apiClient);
      final result = await service.fetchMedicines(
        search: '  para ',
        categoryId: 1,
        isActive: 'all',
        page: 2,
        limit: 15,
        sortBy: 'selling_price',
        sortOrder: 'desc',
      );

      expect(captured.method, 'GET');
      expect(captured.url.path, '/api/medicines');
      expect(captured.url.queryParameters, {
        'search': 'para',
        'category_id': '1',
        'is_active': 'all',
        'page': '2',
        'limit': '15',
        'sortBy': 'selling_price',
        'sortOrder': 'desc',
      });
      expect(result.items.length, 1);
      expect(result.items.first.name, 'Panadol');
      expect(result.pagination.totalRecords, 31);
      expect(result.pagination.hasNextPage, isTrue);
    });

    test(
        'fetchCategories, createCategory, createMedicine, updateMedicine, deactivateMedicine, and reactivateMedicine hit exact REST paths and HTTP methods',
        () async {
      final calls = <String>[];
      final apiClient = ApiClient(
        httpClient: MockClient((request) async {
          calls.add('${request.method} ${request.url.path} ${request.body}');
          if (request.method == 'GET' && request.url.path == '/api/categories') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': [
                  {'id': 1, 'name': 'Analgesics', 'description': 'Pain relief'},
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST' && request.url.path == '/api/categories') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {'id': 2, 'name': 'Vitamins', 'description': 'OTC'},
              }),
              201,
            );
          }
          if (request.method == 'PATCH' &&
              request.url.path == '/api/medicines/5/deactivate') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'medicine': {'id': 5, 'name': 'Panadol', 'is_active': false},
                  'message': 'Deactivated',
                },
              }),
              200,
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'id': 5,
                'category_id': 2,
                'name': 'Amoxil',
                'dosage_form': 'Capsule',
                'selling_price': '45.00',
                'cost_price': '30.00',
                'reorder_level': 10,
                'is_active': true,
              },
            }),
            request.method == 'POST' ? 201 : 200,
          );
        }),
        tokenStorage: _MemStorage({AuthProvider.tokenStorageKey: 'jwt'}),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );

      final service = MedicineService(apiClient);
      final cats = await service.fetchCategories();
      expect(cats.single.name, 'Analgesics');

      final newCat =
          await service.createCategory(name: 'Vitamins', description: 'OTC');
      expect(newCat.id, 2);

      const input = MedicineInput(
        categoryId: 2,
        name: 'Amoxil',
        dosageForm: 'Capsule',
        sellingPrice: 45,
        costPrice: 30,
        reorderLevel: 10,
      );
      final created = await service.createMedicine(input);
      expect(created.id, 5);

      final updated = await service.updateMedicine(5, input);
      expect(updated.id, 5);

      await service.deactivateMedicine(5);
      final reactivated = await service.reactivateMedicine(5);
      expect(reactivated.isActive, isTrue);

      expect(calls[0], startsWith('GET /api/categories'));
      expect(calls[1], startsWith('POST /api/categories'));
      expect(calls[2], startsWith('POST /api/medicines '));
      expect(calls[3], startsWith('PUT /api/medicines/5 '));
      expect(calls[4], startsWith('PATCH /api/medicines/5/deactivate'));
      expect(calls[5], 'PUT /api/medicines/5 {"is_active":true}');
    });
  });
}
