# Shared `ApiClient` & Medicines / Categories Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the reusable authenticated `ApiClient` (with global session revocation) and the responsive Medicines & Categories management screen wired into the persistent Medixmart Plus sidebar/drawer shell.

**Architecture:** Extract a single `ApiException`/`ApiClient` networking layer reusing `AuthProvider`'s `TokenStorage` (`'medixmart_jwt_token'`) and `ApiConfig.baseUrl`, expose typed Category/Medicine models and `MedicineService` behind `MedicineProvider`, build Figma-aligned shared widgets (`MmInputField` `7:70` and feedback/confirm primitives), and mount `MedicinesScreen` inside `AdminDashboardScreen`'s persistent shell when `selectedNavId == 'medicines'`.

**Tech Stack:** Flutter (Windows desktop & Android), Dart (`>=3.2.0 <4.0.0`), `provider` (`^6.1.2`), `http` (`^1.2.2`), `flutter_secure_storage` (`^9.2.2`), `flutter_svg`, `google_fonts`, `flutter_test`. No new pub dependencies required.

**Spec:** `docs/superpowers/specs/2026-11-21-medicines-categories-and-api-client-design.md`

## Global Constraints

- **No backend edits and no new `pubspec.yaml` dependencies:** Build purely in `medixmart_app/` against live `upstream/dev` @ `64dc9e2` endpoints using existing packages.
- **Exact backend contract fidelity:** Use `sortBy` and `sortOrder` (camelCase), `is_active` (`'true'`/`'false'`/`'all'`), flat `meta` pagination (`page`, `limit`, `totalRecords`, `totalPages`, `hasNextPage`, `hasPrevPage`, with nested `meta.pagination` fallback), and parse PostgreSQL `NUMERIC(10, 2)` strings (`"25.00"`) and numbers safely.
- **Never fake stock:** `MedicineModel.availableStock` stays `int?` (`null` until backend joins batches); do not render synthetic stock counts.
- **Auth & RBAC integrity:** Store JWT under `'medixmart_jwt_token'` via `TokenStorage`; revoke session ONLY on allowlisted codes (`AUTH_MISSING_TOKEN`, `AUTH_INVALID_TOKEN`, `AUTH_EXPIRED_TOKEN`, `AUTH_SESSION_REVOKED`, `AUTH_ACCOUNT_DISABLED`); hide Admin-only mutation buttons for `pharmacist` while preserving read-only `Categories` access and server-side RBAC.
- **Responsive & Figma fidelity:** Match `MmColors`, `MmTypography`, `MmSpacing`, `MmRadius`, `MmElevation`, Figma `Input Field` (`7:70`), and `Data Table Row` (`10:107`); zero overflow at `1440x900` (desktop), `862x692` (tablet), and `390x844` (mobile).
- **Formatting & tests:** Format LKR currency as `Rs. #,##0.00` in `MmTypography.codeMono`; keep all existing tests (`admin_dashboard_screen_test.dart`, `login_auth_flow_test.dart`) passing alongside new unit and widget tests.

## Review Focus

1. **Out-of-order search responses (network race):** Fast consecutive searches (`"amo"` → `"para"`) where the earlier request resolves later must discard the stale response and keep `"para"` results. *(Pinned in Task 3)*
2. **Deactivating the last medicine on page `N > 1` under the Active filter:** Removing the sole row on page 2 must automatically step back to page 1 and reload instead of stranding the user on an empty page 2. *(Pinned in Task 3)*
3. **Editing a medicine with a non-preset or `null` `dosage_form` (e.g., `"Sachet"`):** Opening `MedicineFormDialog` must dynamically include the existing dosage form in the dropdown items instead of throwing a Flutter dropdown assertion error. *(Pinned in Task 5)*
4. **Logout / account switch stale-cache leakage:** Signing out or revoking a session must reset `MedicineProvider` state (medicines, categories, filters, errors) so switching Admin → Pharmacist never exposes stale rows or prior filters. *(Pinned in Task 6)*
5. **Protected `401 AUTH_INVALID_CREDENTIALS` vs `403 AUTH_ACCOUNT_DISABLED`:** A protected endpoint returning `401 AUTH_INVALID_CREDENTIALS` must NOT clear the token or trigger logout, whereas `403 AUTH_ACCOUNT_DISABLED` MUST clear the token and route back to `LoginScreen` with the server's disabled message. *(Pinned in Tasks 1 & 6)*

---

### Task 1: Shared `ApiException`, `ApiClient`, and `AuthProvider` Session Revocation

**Files:**
- Create: `medixmart_app/lib/models/api_exception.dart`
- Create: `medixmart_app/lib/services/api_client.dart`
- Modify: `medixmart_app/lib/services/auth_service.dart:1-160`
- Modify: `medixmart_app/lib/providers/auth_provider.dart:34-150`
- Test: `medixmart_app/test/unit/api_client_test.dart`

**Interfaces:**
- Consumes: `ApiConfig.baseUrl`, `ApiConfig.receiveTimeout` (`lib/config/api_config.dart`), `TokenStorage`, `SecureTokenStorage` (`lib/providers/auth_provider.dart`).
- Produces:
  - `ApiErrorDetail({required String field, required String message})` + `fromJson(Map<String, dynamic>)`
  - `ApiException({required String code, required String message, required int statusCode, List<ApiErrorDetail> details = const []})` + `fromJson(Map<String, dynamic>, int statusCode)` + getters `isSessionRevoked`, `isForbidden`, `isDuplicate`, `isValidation`, method `String? fieldError(String field)`
  - `AuthService` re-exports `lib/models/api_exception.dart` (preserving existing `auth_service.dart` imports)
  - `AuthProvider.tokenStorageKey` (`'medixmart_jwt_token'`), `TokenStorage get tokenStorage`, and `Future<void> handleSessionRevoked([String? reason])`
  - `ApiClient({http.Client? httpClient, TokenStorage? tokenStorage, String? baseUrlOverride, void Function(String? message)? onSessionRevoked})` with `Future<Map<String, dynamic>> get(String endpoint, {Map<String, dynamic>? queryParameters, bool requiresAuth = true})`, `post`, `put`, `patch`, `delete`, and `void close()`

- [ ] **Step 1: Write failing unit tests in `medixmart_app/test/unit/api_client_test.dart`**

Write tests using `http/testing.dart` (`MockClient`) and an in-memory `TokenStorage`:
- `ApiException.fromJson parses error code, message, details, and fieldError lookup` (asserts `code == 'VALIDATION_ERROR'`, `isValidation == true`, `fieldError('name') == 'Medicine name is required.'`, `isDuplicate == false`)
- `ApiException.isSessionRevoked matches exact allowlist and excludes AUTH_INVALID_CREDENTIALS and AUTH_FORBIDDEN_ROLE` (asserts `true` for `AUTH_MISSING_TOKEN`, `AUTH_INVALID_TOKEN`, `AUTH_EXPIRED_TOKEN`, `AUTH_SESSION_REVOKED`, `AUTH_ACCOUNT_DISABLED`; `false` for `AUTH_INVALID_CREDENTIALS`, `AUTH_FORBIDDEN_ROLE`, `VALIDATION_ERROR`)
- `ApiClient attaches Bearer token from medixmart_jwt_token and omits it when requiresAuth is false`
- `ApiClient normalizes SocketException, TimeoutException, and malformed non-JSON responses into ApiException`
- `ApiClient revokes session, deletes medixmart_jwt_token, and calls onSessionRevoked on 401 AUTH_SESSION_REVOKED and 403 AUTH_ACCOUNT_DISABLED`
- `ApiClient does NOT revoke session on protected 401 AUTH_INVALID_CREDENTIALS or 403 AUTH_FORBIDDEN_ROLE` *(Review Focus #5)*
- `AuthProvider.handleSessionRevoked clears token, sets unauthenticated status, and surfaces reason message`

- [ ] **Step 2: Run unit test to verify it fails**

Run: `flutter test test/unit/api_client_test.dart` (from `medixmart_app/`)
Expected: FAIL (missing `api_exception.dart`, `api_client.dart`, `handleSessionRevoked`).

- [ ] **Step 3: Implement `ApiException` in `medixmart_app/lib/models/api_exception.dart` and re-export from `auth_service.dart`**

Implement `ApiErrorDetail` and `ApiException` with explicit allowlist:
`static const Set<String> sessionRevokingCodes = {'AUTH_MISSING_TOKEN', 'AUTH_INVALID_TOKEN', 'AUTH_EXPIRED_TOKEN', 'AUTH_SESSION_REVOKED', 'AUTH_ACCOUNT_DISABLED'};`
`bool get isSessionRevoked => sessionRevokingCodes.contains(code);`
`bool get isForbidden => statusCode == 403;`
`bool get isDuplicate => statusCode == 409 || code == 'DUPLICATE_ENTRY';`
`bool get isValidation => statusCode == 400 || code == 'VALIDATION_ERROR';`
In `medixmart_app/lib/services/auth_service.dart`, add `export '../models/api_exception.dart';`, import it, and remove the duplicate local `ApiException` class at lines 147–160.

- [ ] **Step 4: Add `tokenStorageKey`, `tokenStorage` getter, and `handleSessionRevoked` to `medixmart_app/lib/providers/auth_provider.dart`**

Expose `static const String tokenStorageKey = 'medixmart_jwt_token';` (replacing private `_tokenKey`) and `TokenStorage get tokenStorage => _storage;` so `ApiClient` shares the exact same `TokenStorage` instance. Implement `Future<void> handleSessionRevoked([String? reason])` which deletes `tokenStorageKey` safely (catching storage errors), clears `_token`, `_user`, `_isRestoringSession`, sets `_status = AuthStatus.unauthenticated`, sets `_errorMessage = (reason != null && reason.trim().isNotEmpty) ? reason : 'Your session has expired. Please sign in again.'`, and calls `notifyListeners()`.

- [ ] **Step 5: Implement `ApiClient` in `medixmart_app/lib/services/api_client.dart`**

Implement `get`, `post`, `put`, `patch`, `delete` using `_httpClient`, `ApiConfig.baseUrl` (or `_baseUrlOverride`), `ApiConfig.receiveTimeout`, JSON envelope validation (`Map<String, dynamic>`), `SocketException`/`http.ClientException` → `NETWORK_ERROR` (`statusCode: 0`), `TimeoutException` → `REQUEST_TIMEOUT` (`statusCode: 408`), non-JSON → `INVALID_RESPONSE`, and on `requiresAuth && exception.isSessionRevoked`: await token deletion from `TokenStorage`, call `onSessionRevoked?.call(exception.message)`, then throw `exception`. Ignore `null` values in `queryParameters` so optional filters serialize cleanly.

- [ ] **Step 6: Run tests to verify pass and no auth regression**

Run: `flutter test test/unit/api_client_test.dart test/widget/login_auth_flow_test.dart` (from `medixmart_app/`)
Expected: All tests PASS.

- [ ] **Step 7: Commit**

```bash
git add medixmart_app/lib/models/api_exception.dart medixmart_app/lib/services/api_client.dart medixmart_app/lib/services/auth_service.dart medixmart_app/lib/providers/auth_provider.dart medixmart_app/test/unit/api_client_test.dart
git commit -m "feat(app): add shared ApiClient, rich ApiException, and session revocation handling"
```

---

### Task 2: Domain Models, Currency Formatter & `MedicineService`

**Files:**
- Create: `medixmart_app/lib/models/category_model.dart`
- Create: `medixmart_app/lib/models/medicine_model.dart`
- Create: `medixmart_app/lib/models/paginated_response.dart`
- Create: `medixmart_app/lib/utils/formatters.dart`
- Create: `medixmart_app/lib/services/medicine_service.dart`
- Test: `medixmart_app/test/unit/medicine_models_and_service_test.dart`

**Interfaces:**
- Consumes: `ApiClient` (`lib/services/api_client.dart`).
- Produces:
  - `CategoryModel({required int id, required String name, String? description, DateTime? createdAt})` + `fromJson`
  - `MedicineModel({required int id, required int categoryId, String? categoryName, required String name, String? genericName, String? brand, required String dosageForm, String? strength, required double sellingPrice, required double costPrice, required int reorderLevel, required bool isActive, int? availableStock, DateTime? createdAt, DateTime? updatedAt})` + `fromJson` + `copyWith`
  - `MedicineInput({required int categoryId, required String name, String? genericName, String? brand, required String dosageForm, String? strength, required double sellingPrice, double costPrice = 0.0, int reorderLevel = 10, bool? isActive})` + `Map<String, dynamic> toJson()`
  - `PaginationMeta({required int page, required int limit, required int totalRecords, required int totalPages, required bool hasNextPage, required bool hasPrevPage})` + `fromMetaJson(Map<String, dynamic>? meta, {required int itemCount})`
  - `PaginatedResponse<T>({required List<T> items, required PaginationMeta pagination})`
  - `MmFormatters.currencyLkr(double amount)` → `'Rs. 1,250.00'` (pure Dart, handles negative/zero/large numbers)
  - `MedicineService(ApiClient apiClient)` with:
    - `Future<List<CategoryModel>> fetchCategories()`
    - `Future<CategoryModel> createCategory({required String name, String? description})`
    - `Future<PaginatedResponse<MedicineModel>> fetchMedicines({String? search, int? categoryId, String isActive = 'true', int page = 1, int limit = 20, String sortBy = 'name', String sortOrder = 'asc'})`
    - `Future<MedicineModel> fetchMedicineById(int id)`
    - `Future<MedicineModel> createMedicine(MedicineInput input)`
    - `Future<MedicineModel> updateMedicine(int id, MedicineInput input)`
    - `Future<void> deactivateMedicine(int id)`
    - `Future<MedicineModel> reactivateMedicine(int id)`

- [ ] **Step 1: Write failing unit tests in `medixmart_app/test/unit/medicine_models_and_service_test.dart`**

Write tests asserting:
- `MedicineModel.fromJson parses PostgreSQL NUMERIC strings and numeric values plus optional available_stock` (asserts `"25.00"` → `25.0`, `18.5` → `18.5`, missing `available_stock` → `null`, present `available_stock: 40` → `40`)
- `PaginationMeta.fromMetaJson parses flat backend meta and falls back to nested meta.pagination` (asserts both `{page: 2, limit: 20, totalRecords: 45, totalPages: 3, hasNextPage: true, hasPrevPage: true}` and `{pagination: {page: 1, limit: 10, total: 12, totalPages: 2, hasNext: true, hasPrev: false}}`)
- `MmFormatters.currencyLkr formats Sri Lankan rupee amounts with thousand separators` (`0` → `'Rs. 0.00'`, `25.5` → `'Rs. 25.50'`, `48750` → `'Rs. 48,750.00'`, `1234567.89` → `'Rs. 1,234,567.89'`)
- `MedicineService.fetchMedicines sends camelCase sortBy/sortOrder, is_active, search, category_id, page, limit and parses PaginatedResponse` (via `MockClient` inspecting `request.url.queryParameters`)
- `MedicineService.createCategory, createMedicine, updateMedicine, deactivateMedicine, and reactivateMedicine hit exact REST paths and HTTP methods` (`POST /api/categories`, `POST /api/medicines`, `PUT /api/medicines/5`, `PATCH /api/medicines/5/deactivate`, `PUT /api/medicines/5` with `{'is_active': true}`)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/medicine_models_and_service_test.dart` (from `medixmart_app/`)
Expected: FAIL (files not created yet).

- [ ] **Step 3: Implement models (`category_model.dart`, `medicine_model.dart`, `paginated_response.dart`) and `MmFormatters` (`lib/utils/formatters.dart`)**

Parse numbers defensively with helper `_parseDouble(dynamic v, {double fallback = 0.0})` and `_parseInt(dynamic v, {int fallback = 0})`. In `MedicineInput.toJson()`, emit trimmed strings (or `null` when empty for optional fields `generic_name`, `brand`, `strength`).

- [ ] **Step 4: Implement `MedicineService` in `medixmart_app/lib/services/medicine_service.dart`**

Delegate all HTTP calls to `ApiClient`. For `fetchMedicines`, only include `search` when non-empty after trim and `category_id` when non-null; always pass `is_active`, `page`, `limit`, `sortBy`, `sortOrder`.

- [ ] **Step 5: Run unit tests to verify pass**

Run: `flutter test test/unit/medicine_models_and_service_test.dart` (from `medixmart_app/`)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add medixmart_app/lib/models/category_model.dart medixmart_app/lib/models/medicine_model.dart medixmart_app/lib/models/paginated_response.dart medixmart_app/lib/utils/formatters.dart medixmart_app/lib/services/medicine_service.dart medixmart_app/test/unit/medicine_models_and_service_test.dart
git commit -m "feat(app): add Category/Medicine models, pagination parser, LKR formatter, and MedicineService"
```

---

### Task 3: `MedicineProvider` State Management

**Files:**
- Create: `medixmart_app/lib/providers/medicine_provider.dart`
- Test: `medixmart_app/test/unit/medicine_provider_test.dart`

**Interfaces:**
- Consumes: `CategoryModel`, `MedicineModel`, `MedicineInput`, `PaginationMeta`, `PaginatedResponse`, `MedicineService`, `ApiException`.
- Produces:
  - `enum MedicineStatusFilter { active('true', 'Active'), inactive('false', 'Inactive'), all('all', 'All') }`
  - `enum MedicineSortField { name('name'), sellingPrice('selling_price'), reorderLevel('reorder_level'), createdAt('created_at') }`
  - `class MedicineProvider extends ChangeNotifier`:
    - Constructor: `MedicineProvider({required MedicineService service, Duration searchDebounce = const Duration(milliseconds: 350)})`
    - Getters: `List<CategoryModel> categories`, `List<MedicineModel> medicines`, `PaginationMeta pagination`, `bool isLoading`, `bool isRefreshing`, `bool isCategoriesLoading`, `bool isMutating`, `bool hasLoadedOnce`, `String? errorMessage`, `String searchQuery`, `int? selectedCategoryId`, `MedicineStatusFilter statusFilter`, `MedicineSortField sortField`, `bool sortAscending`, `bool hasActiveFilters`
    - Methods:
      - `Future<void> ensureLoaded()`
      - `Future<void> refresh()`
      - `void setSearchQuery(String query)` (debounced, resets page to 1)
      - `Future<void> setCategoryFilter(int? categoryId)`
      - `Future<void> setStatusFilter(MedicineStatusFilter filter)`
      - `Future<void> setSort(MedicineSortField field, {required bool ascending})`
      - `Future<void> clearFilters()`
      - `Future<void> goToPage(int page)`
      - `Future<CategoryModel> createCategory({required String name, String? description})`
      - `Future<MedicineModel> createMedicine(MedicineInput input)`
      - `Future<MedicineModel> updateMedicine(int id, MedicineInput input)`
      - `Future<void> deactivateMedicine(int id)`
      - `Future<void> reactivateMedicine(int id)`
      - `void reset()` (cancels debounce timer, clears lists/filters/errors, sets `hasLoadedOnce = false`)

- [ ] **Step 1: Write failing unit tests in `medixmart_app/test/unit/medicine_provider_test.dart`**

Write tests with a fake `MedicineService`:
- `ensureLoaded loads categories and page 1 medicines once and does not refetch on repeated calls`
- `setSearchQuery debounces requests and discards stale out-of-order responses` *(Review Focus #1: trigger `"amo"` returning via `Completer` A, then `"para"` returning immediately via `Completer` B, then complete A afterwards — assert `provider.medicines` keeps `"para"` results)*
- `category filter, status filter, sort change, and clearFilters reset page to 1 and query backend with exact parameters`
- `deactivateMedicine on sole item of page 2 under Active filter steps back to page 1 and reloads` *(Review Focus #2)*
- `createCategory updates sorted categories list and returns created CategoryModel`
- `isMutating blocks overlapping duplicate create/update/deactivate calls and rethrows ApiException without erasing medicines list`
- `reset cancels pending debounce and clears cached medicines, categories, filters, and errorMessage`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/unit/medicine_provider_test.dart` (from `medixmart_app/`)
Expected: FAIL (`medicine_provider.dart` not found).

- [ ] **Step 3: Implement `MedicineProvider` in `medixmart_app/lib/providers/medicine_provider.dart`**

Use monotonic `int _requestSeq = 0;` incremented before every `fetchMedicines` call and checked after `await` so stale responses are ignored. Differentiate initial `isLoading` (when `!_hasLoadedOnce` or `_medicines.isEmpty && _errorMessage != null`) vs `isRefreshing` (subsequent filter/page reloads) so existing table rows stay visible during reloads. Cancel `_searchDebounceTimer` in `reset()` and `dispose()`.

- [ ] **Step 4: Run tests to verify pass**

Run: `flutter test test/unit/medicine_provider_test.dart` (from `medixmart_app/`)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add medixmart_app/lib/providers/medicine_provider.dart medixmart_app/test/unit/medicine_provider_test.dart
git commit -m "feat(app): implement MedicineProvider with debounced search, pagination, and mutations"
```

---

### Task 4: Figma `MmInputField` (`7:70`) & Reusable Feedback / Confirmation Widgets

**Files:**
- Create: `medixmart_app/lib/widgets/mm_input_field.dart`
- Create: `medixmart_app/lib/widgets/mm_feedback_states.dart`
- Test: `medixmart_app/test/widget/mm_shared_widgets_test.dart`

**Interfaces:**
- Consumes: `MmColors`, `MmTypography`, `MmSpacing`, `MmRadius`, `MmElevation` (`lib/config/app_theme.dart`), `MmButton`, `MmButtonVariant`, `MmButtonSize` (`lib/widgets/mm_button.dart`).
- Produces:
  - `enum MmInputSize { medium, large }`
  - `class MmInputField extends StatefulWidget` with parameters: `Key? key`, `Key? fieldKey`, `required String label`, `String? hintText`, `String? helperText`, `String? errorText`, `TextEditingController? controller`, `FocusNode? focusNode`, `Widget? leadingIcon`, `Widget? trailingIcon`, `MmInputSize size = MmInputSize.medium`, `bool enabled = true`, `bool readOnly = false`, `int maxLines = 1`, `TextInputType? keyboardType`, `TextInputAction? textInputAction`, `List<TextInputFormatter>? inputFormatters`, `String? Function(String?)? validator`, `ValueChanged<String>? onChanged`, `ValueChanged<String>? onFieldSubmitted`
  - `class MmLoadingView extends StatelessWidget` (`String message`)
  - `class MmEmptyState extends StatelessWidget` (`IconData icon`, `String title`, `String message`, `String? actionLabel`, `VoidCallback? onAction`)
  - `class MmErrorState extends StatelessWidget` (`String title`, `String message`, `VoidCallback onRetry`)
  - `Future<bool> showMmConfirmDialog(BuildContext context, {required String title, required String message, required String confirmLabel, String cancelLabel = 'Cancel', MmButtonVariant confirmVariant = MmButtonVariant.danger})`

- [ ] **Step 1: Write failing widget tests in `medixmart_app/test/widget/mm_shared_widgets_test.dart`**

Write widget tests asserting:
- `MmInputField renders label, hint, helper text, and swaps to error message on Form validation failure`
- `MmInputField disables text input when enabled is false and applies Figma disabled surface`
- `MmErrorState renders error copy and triggers onRetry when Retry button is tapped`
- `MmEmptyState renders title, message, and optional CTA button`
- `showMmConfirmDialog returns true on Confirm and false on Cancel`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/mm_shared_widgets_test.dart` (from `medixmart_app/`)
Expected: FAIL (widget files not found).

- [ ] **Step 3: Implement `MmInputField` in `medixmart_app/lib/widgets/mm_input_field.dart`**

Match Figma node `7:70` exactly:
- Label in `MmTypography.labelMedium` (`textPrimary` when enabled, `textMuted` when disabled), `6px` gap above input box.
- Input box (`FormField<String>` or `TextFormField` inside animated/focus-listening container): `MmRadius.md` (`8px`), Medium padding `horizontal: 12, vertical: 8`, Large padding `all(12)`.
- Default border `1px` `MmColors.borderDefault`; Focused border `1.5px` `MmColors.borderBrand` + boxShadow `[BoxShadow(color: Color(0x3849944F), spreadRadius: 3), BoxShadow(color: Color(0x0F0F1729), offset: Offset(0, 2), blurRadius: 4)]`; Error border `1.5px` `MmColors.borderDanger` + danger focus ring `[BoxShadow(color: Color(0x38EE4655), spreadRadius: 3), BoxShadow(color: Color(0x0F0F1729), offset: Offset(0, 2), blurRadius: 4)]`; Disabled fill `MmColors.bgSubtle`.
- Helper/error text below box in `MmTypography.bodySmall` (`MmColors.textSecondary` or `MmColors.textDanger`). External `errorText` takes precedence over helper text and triggers error border.

- [ ] **Step 4: Implement `mm_feedback_states.dart` in `medixmart_app/lib/widgets/mm_feedback_states.dart`**

Implement `MmLoadingView`, `MmEmptyState`, `MmErrorState`, and `showMmConfirmDialog` using `MmColors`, `MmTypography`, `MmRadius.lg`, and `MmButton`.

- [ ] **Step 5: Run tests to verify pass**

Run: `flutter test test/widget/mm_shared_widgets_test.dart` (from `medixmart_app/`)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add medixmart_app/lib/widgets/mm_input_field.dart medixmart_app/lib/widgets/mm_feedback_states.dart medixmart_app/test/widget/mm_shared_widgets_test.dart
git commit -m "feat(app): add Figma MmInputField and reusable feedback/confirmation widgets"
```

---

### Task 5: `CategoryModal`, `MedicineFormDialog`, and Responsive `MedicinesScreen`

**Files:**
- Create: `medixmart_app/lib/screens/medicines/category_modal.dart`
- Create: `medixmart_app/lib/screens/medicines/medicine_form_dialog.dart`
- Create: `medixmart_app/lib/screens/medicines/medicines_screen.dart`
- Test: `medixmart_app/test/widget/medicines_screen_test.dart`

**Interfaces:**
- Consumes: `AuthProvider`, `MedicineProvider`, `CategoryModel`, `MedicineModel`, `MedicineInput`, `ApiException`, `MmFormatters`, `AppAssets`, `MmColors`, `MmTypography`, `MmSpacing`, `MmRadius`, `MmElevation`, `MmButton`, `PosSearchBar`, `StatusBadge`, `StatusTone`, `MmInputField`, `MmLoadingView`, `MmEmptyState`, `MmErrorState`, `showMmConfirmDialog`.
- Produces:
  - `Future<CategoryModel?> showCategoryModal(BuildContext context, {required bool canCreate, bool focusCreateForm = false})`
  - `Future<bool> showMedicineFormDialog(BuildContext context, {MedicineModel? initialMedicine})`
  - `class MedicinesScreen extends StatefulWidget` with constructor `const MedicinesScreen({super.key, this.showMenuButton = false, this.onOpenDrawer, this.openCreateOnMount = false, this.onCreateDialogHandled})`
  - Stable test keys: `Key('medicines_search_bar')`, `Key('medicines_categories_button')`, `Key('medicines_add_button')`, `Key('medicines_category_filter')`, `Key('medicines_status_active')`, `Key('medicines_status_inactive')`, `Key('medicines_status_all')`, `Key('medicines_sort_dropdown')`, `Key('medicines_prev_page')`, `Key('medicines_next_page')`, `Key('medicine_edit_<id>')`, `Key('medicine_deactivate_<id>')`, `Key('medicine_reactivate_<id>')`.

- [ ] **Step 1: Write failing widget tests in `medixmart_app/test/widget/medicines_screen_test.dart`**

Write widget tests (wrapping `MedicinesScreen` with `MultiProvider` containing `AuthProvider` and `MedicineProvider` backed by a controllable fake `MedicineService`):
- `MedicinesScreen renders desktop table at 1440x900 with LKR prices, category, form/strength, status badges, and Admin actions`
- `MedicinesScreen renders stacked mobile cards at 390x844 and tablet at 862x692 with zero overflow`
- `MedicinesScreen hides Admin mutations for pharmacist while keeping read-only Categories modal accessible` (asserts `medicines_add_button`, `medicine_edit_*`, `medicine_deactivate_*` are `findsNothing`; tapping `medicines_categories_button` opens category list showing descriptions without the Add Category form)
- `MedicinesScreen search, category filter, active/inactive/all toggle, and pagination trigger MedicineProvider updates`
- `Admin Add Medicine validates required/numeric fields, supports inline + New Category, maps server 409 DUPLICATE_ENTRY without clearing inputs, and saves cleanly`
- `Admin Edit Medicine handles legacy non-preset dosage_form ("Sachet") without dropdown error and submits updates` *(Review Focus #3)*
- `Admin Safe Deactivate requires confirmation dialog and refreshes list; inactive medicine supports Reactivate`
- `MedicinesScreen renders error state with working Retry button when initial fetch fails`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget/medicines_screen_test.dart` (from `medixmart_app/`)
Expected: FAIL (screen files not created yet).

- [ ] **Step 3: Implement `CategoryModal` in `medixmart_app/lib/screens/medicines/category_modal.dart`**

Constrained dialog (`maxWidth: 520`, `maxHeight: 620`):
- Header with title `Medicine Categories` + close button.
- Admin-only (`canCreate == true`) collapsible/inline Add Category form using `MmInputField` (`Category Name *`, optional `Description`), danger inline error banner for `409 DUPLICATE_ENTRY` / validation errors (never clearing typed fields on error), submit disabled while submitting, returns newly created `CategoryModel` when `focusCreateForm: true` or refreshes list in-place and shows confirmation snackbar.
- Searchable list of existing categories displaying `name` (`MmTypography.labelLarge`) and `description` (`MmTypography.bodySmall`, fallback `"No description"`), with empty state when none exist.

- [ ] **Step 4: Implement `MedicineFormDialog` in `medixmart_app/lib/screens/medicines/medicine_form_dialog.dart`**

Constrained scrollable dialog (`maxWidth: 580`):
- Preset dosage forms: `['Tablet', 'Capsule', 'Syrup', 'Suspension', 'Injection', 'Cream', 'Ointment', 'Drops', 'Inhaler', 'Powder', 'Other']`. When editing a medicine whose `dosageForm` is non-empty and not in the presets, append it dynamically to the dropdown items so `DropdownButtonFormField` never asserts.
- Category dropdown populated from `MedicineProvider.categories` paired with an inline `+ New` text/secondary button that opens `showCategoryModal(context, canCreate: true, focusCreateForm: true)` and auto-selects the returned `CategoryModel.id`.
- Client validators: Name non-empty; Category selected; Selling Price valid number `>= 0`; Cost Price optional (default `0.00`) valid number `>= 0`; Reorder Level valid integer `>= 0`.
- Server error mapping: extract `ApiException.fieldError('name')`, `fieldError('category_id')`, `fieldError('selling_price')`, `fieldError('cost_price')`, `fieldError('reorder_level')` into field `errorText`, and render a top danger banner for `409 DUPLICATE_ENTRY` or general errors while keeping all entered inputs intact.
- Prevent duplicate submission with local `_isSubmitting` guard.

- [ ] **Step 5: Implement `MedicinesScreen` in `medixmart_app/lib/screens/medicines/medicines_screen.dart`**

- Trigger `medicineProvider.ensureLoaded()` in `initState` via `addPostFrameCallback`; if `openCreateOnMount` is true and current user is Admin, open `showMedicineFormDialog` once loaded and invoke `onCreateDialogHandled?.call()`.
- Header bar: drawer menu button (`Key('dashboard_menu_button')`) when `showMenuButton`, `Medicines` (`headingH2`) + count pill (`'${pagination.totalRecords} items'`), `PosSearchBar`, refresh icon button, secondary `MmButton('Categories')`, and Admin-only primary `MmButton('Add Medicine', leadingIconAsset: AppAssets.iconPlusMd)`.
- Filter bar (`Wrap`): Category `DropdownButtonFormField` (`All Categories` + categories), Status pill selector (`Active` / `Inactive` / `All`), Sort dropdown (`Name (A–Z)`, `Name (Z–A)`, `Price: Low–High`, `Price: High–Low`, `Reorder Level`, `Newest`), and `Reset filters` text button when `hasActiveFilters`.
- Body (`LayoutBuilder`):
  - `isLoading && medicines.isEmpty` → `MmLoadingView`
  - `errorMessage != null && medicines.isEmpty` → `MmErrorState` with Retry
  - `medicines.isEmpty` → `MmEmptyState` (differentiating empty catalog vs empty filter results)
  - `width >= 900`: horizontal-scroll-safe desktop table (`minWidth: 960`) matching Figma `10:107` (52px header + rows, `MmColors.bgSubtle` surface on inactive rows, `MmFormatters.currencyLkr` in `codeMono`, `StatusBadge(label: 'Active', tone: StatusTone.inStock)` vs `StatusBadge(label: 'Inactive', tone: StatusTone.expired)`, Admin-only `Edit` & `Deactivate`/`Reactivate` icon buttons).
  - `width < 900`: stacked cards showing all key fields cleanly without clipping.
  - Pagination footer showing `"Showing X–Y of Z medicines"` and `Previous` / `Page P of T` / `Next` controls.

- [ ] **Step 6: Run tests to verify pass**

Run: `flutter test test/widget/medicines_screen_test.dart` (from `medixmart_app/`)
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add medixmart_app/lib/screens/medicines/category_modal.dart medixmart_app/lib/screens/medicines/medicine_form_dialog.dart medixmart_app/lib/screens/medicines/medicines_screen.dart medixmart_app/test/widget/medicines_screen_test.dart
git commit -m "feat(app): build responsive Medicines & Categories screen with modals and RBAC"
```

---

### Task 6: Persistent Shell Wiring, App Provider Graph & Full Verification

**Files:**
- Modify: `medixmart_app/lib/screens/dashboard/admin_dashboard_screen.dart:70-150,850-915`
- Modify: `medixmart_app/lib/main.dart:1-47`
- Test: `medixmart_app/test/widget/admin_dashboard_screen_test.dart`
- Test: `medixmart_app/test/widget/medicines_screen_test.dart`

**Interfaces:**
- Consumes: `ApiClient`, `MedicineService`, `MedicineProvider`, `MedicinesScreen`, `AuthProvider.handleSessionRevoked`, `TokenStorage`.
- Produces:
  - `MedixmartApp({super.key, AuthProvider? authProvider, DashboardProvider? dashboardProvider, MedicineProvider? medicineProvider})`
  - `AdminDashboardScreen` swaps main area between `_DashboardMainArea` (`selectedNavId == 'dashboard'`) and `MedicinesScreen` (`selectedNavId == 'medicines'`), hides Watchlist **Add Medicine** button when `authUser?.isPharmacist == true`, and keeps unbuilt nav items showing snackbar feedback without blanking the active view.

- [ ] **Step 1: Write failing integration/shell widget tests**

Add tests to `admin_dashboard_screen_test.dart` and `medicines_screen_test.dart`:
- In `admin_dashboard_screen_test.dart`:
  - `AdminDashboardScreen hides Watchlist Add Medicine button when signed in as pharmacist`
  - `Clicking Medicines in sidebar switches main content to MedicinesScreen inside persistent shell`
- In `medicines_screen_test.dart`:
  - `403 AUTH_ACCOUNT_DISABLED during medicines load revokes session, resets MedicineProvider, and returns AuthGate to LoginScreen with error banner` *(Review Focus #4 & #5)*
  - `Logging out and signing in as pharmacist resets cached MedicineProvider state and hides Admin actions` *(Review Focus #4)*

- [ ] **Step 2: Run tests to verify new assertions fail**

Run: `flutter test test/widget/admin_dashboard_screen_test.dart test/widget/medicines_screen_test.dart` (from `medixmart_app/`)
Expected: New shell/revocation tests FAIL while prior tests pass.

- [ ] **Step 3: Wire `AdminDashboardScreen` in `medixmart_app/lib/screens/dashboard/admin_dashboard_screen.dart`**

- Track `bool _pendingOpenAddMedicine = false;` in `_AdminDashboardScreenState`.
- In `_handleNavTap`: if `item.id == 'dashboard'` or `item.id == 'medicines'`, call `selectNavItem(item.id)`; otherwise show snackbar `"${item.label} module is coming soon."` without leaving the current working view.
- In `onAddMedicine` callback: set `_pendingOpenAddMedicine = true;` and select `'medicines'` (no placeholder snackbar).
- In `_InventoryWatchlistCard`: accept `bool showAddMedicine = true` and render the `Add Medicine` button only when `showAddMedicine` is true (pass `showAddMedicine: authUser?.isPharmacist != true` so standalone dashboard tests where `authUser == null` continue rendering it).
- When `selectedNavId == 'medicines'`, render `MedicinesScreen(showMenuButton: !showPermanentSidebar, onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(), openCreateOnMount: _pendingOpenAddMedicine, onCreateDialogHandled: () => setState(() => _pendingOpenAddMedicine = false))` — ensuring `MedicineProvider` is read from context (and gracefully created or required via `MultiProvider`).

- [ ] **Step 4: Wire shared `ApiClient` & `MedicineProvider` lifecycle in `medixmart_app/lib/main.dart`**

Create `MultiProvider` graph in `MedixmartApp` (adding optional `ApiClient? apiClient` and `MedicineProvider? medicineProvider` constructor params for deterministic tests):
- Provide `AuthProvider` (injected or default).
- Provide `DashboardProvider` (injected or default).
- Provide `ApiClient` (injected or created with `tokenStorage: authProvider.tokenStorage` and `onSessionRevoked: (msg) => authProvider.handleSessionRevoked(msg)`).
- Provide `MedicineService(apiClient)`.
- Wire `ChangeNotifierProxyProvider<AuthProvider, MedicineProvider>` (reusing injected `medicineProvider` if supplied, or creating one with `MedicineService`) so whenever `!authProvider.isAuthenticated`, `medicineProvider.reset()` runs automatically and `DashboardProvider.selectNavItem('dashboard')` resets navigation cleanly on sign-out / account switch.

- [ ] **Step 5: Run full static analysis and full Flutter test suite**

Run from `medixmart_app/`:
1. `flutter analyze` — Expected: `No issues found!`
2. `flutter test` — Expected: All unit & widget tests PASS (0 failures).

- [ ] **Step 6: Commit**

```bash
git add medixmart_app/lib/screens/dashboard/admin_dashboard_screen.dart medixmart_app/lib/main.dart medixmart_app/test/widget/admin_dashboard_screen_test.dart medixmart_app/test/widget/medicines_screen_test.dart
git commit -m "feat(app): wire Medicines screen into persistent shell and global ApiClient lifecycle"
```
