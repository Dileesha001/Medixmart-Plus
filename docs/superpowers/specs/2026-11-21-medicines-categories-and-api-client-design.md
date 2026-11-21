# Design Document: Shared `ApiClient` & Medicines / Categories Screen

**Date:** 2026-11-21  
**Author:** Member 2 (Frontend & UI/UX Lead)  
**Target Area:** `medixmart_app/` (Flutter client for Windows desktop & Android mobile/tablet)  
**Design System Source:** Figma `Medixmart Plus — Design System` (`vySUExa6s7c0fKEDAcOPZs`)  
**Backend Baseline:** `upstream/dev` @ `64dc9e2` (`GET/POST /api/categories`, `GET/POST/PUT/PATCH /api/medicines`)

---

## 1. Intent & Why

Medixmart Plus follows a critical path of **Login → Medicines → Batches → Transactional Sales → Alerts**. Authentication (`LoginScreen`, `AuthGate`, `AuthProvider`) and the responsive `AdminDashboardScreen` shell are already merged, and all eight `/api/categories` and `/api/medicines` REST endpoints are live and verified on the backend.

This design covers two coupled deliverables:
1. A reusable, authenticated **`ApiClient`** (plus rich `ApiException`) that standardizes Bearer token attachment, timeouts, JSON envelope decoding, field-level validation errors, and global 401 session revocation for every upcoming Flutter feature.
2. The **Medicines & Categories Screen** (Approach A: single-screen catalog with inline category filtering and quick-add category modal), wired into the existing persistent sidebar/drawer shell.

Building both now unblocks Member 3 (Inventory/Batches), Member 4 (POS & Receive Stock, which reuse `ApiClient`, `MedicineModel`, and `MedicineProvider`), and Member 6 (QA), while replacing the current snackbar placeholder on the Dashboard's **Medicines** nav item and **Add Medicine** button.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- Provide a single shared `ApiClient` (`lib/services/api_client.dart`) and `ApiException` (`lib/models/api_exception.dart`) built on `package:http` and the existing `TokenStorage` abstraction (`'medixmart_jwt_token'`).
- Automatically handle session termination (`AUTH_EXPIRED_TOKEN`, `AUTH_SESSION_REVOKED`, `AUTH_INVALID_TOKEN`, `AUTH_MISSING_TOKEN`, and `403 AUTH_ACCOUNT_DISABLED`—explicitly excluding `401 AUTH_INVALID_CREDENTIALS` and `403 AUTH_FORBIDDEN_ROLE`) by clearing stored credentials and notifying `AuthProvider` so `AuthGate` immediately returns the user to `LoginScreen` with a clear message.
- Deliver a responsive **Medicines & Categories** screen matching the Medixmart Plus Figma Design System (`MmColors`, `MmTypography`, `MmSpacing`, `MmRadius`, `Input Field` `7:70`, `Data Table Row` `10:107`, `POS Search Bar`, `MmButton`, `StatusBadge`).
- Support live backend operations:
  - Search medicines (debounced, matching name, generic name, or brand).
  - Filter by category (`All Categories` or any category from `GET /api/categories`) and by active status (`Active`, `Inactive`, `All`).
  - Sort by `Name`, `Selling Price`, `Reorder Level`, or `Newest` (ascending/descending).
  - Paginate through large catalogs using backend pagination metadata.
  - **Admin-only mutations:** Create Medicine, Edit Medicine, Safe Soft-Deactivate Medicine (with confirmation dialog), Reactivate Inactive Medicine (via `PUT /api/medicines/:id` with `is_active: true`), and Create Category (from toolbar or inline inside the Add/Edit Medicine dialog).
- Enforce role-based UI visibility: hide Admin mutation controls for `pharmacist` users while preserving read/search/filter access and server-side RBAC enforcement.
- Provide reusable UI building blocks (`MmInputField`, loading/empty/error-retry states, confirmation dialog) that other team members can adopt directly.
- Keep all existing unit/widget tests (`admin_dashboard_screen_test.dart`, `login_auth_flow_test.dart`) passing without regression.

### Non-Goals
- **No backend edits** in this task (use the existing, verified endpoints as implemented).
- **No batch stock receipt, supplier management, or FEFO batch table** (owned by Members 3 & 4; `batches` API is not yet built).
- **No category editing or deletion** (the backend currently exposes `GET /api/categories`, `GET /api/categories/:id`, and `POST /api/categories` only).
- **No refactoring of Dashboard KPI/chart mock data** into live alert/report endpoints (separate task).
- **No change-password screen or admin user-management screen** (separate tasks).

### Anti-Goals
- **Never fake `available_stock` numbers.** `GET /api/medicines` does not currently return batch stock totals; displaying placeholder/zero stock would mislead pharmacy staff.
- **Never break existing tests or create duplicate `ApiException` classes.** `auth_service.dart` must remain compatible with existing tests and share the single `ApiException` type.
- **Never allow duplicate form submissions** when a create/update/deactivate request is already in flight.
- **Never wipe user form input on a validation or network failure**—preserve entered values and surface field-specific or banner errors inline so staff can correct and resubmit.

---

## 3. Constraints & Verified Backend Contracts

Inspection of the live backend revealed critical differences between `docs/api/flutter-integration-guide.md` and the actual Express implementation. This design follows the **actual backend code** (with defensive parsing where helpful):

### 3.1 Authentication & Token Storage
- Existing `AuthProvider` stores JWTs in `TokenStorage` under key **`'medixmart_jwt_token'`** (not `'auth_token'`).
- `ApiClient` must accept `TokenStorage` (defaulting to `SecureTokenStorage`) and read `'medixmart_jwt_token'`, plus accept an `onSessionRevoked` callback (`void Function(String? message)?`) wired to `AuthProvider.handleSessionRevoked(String? reason)`.
- `AuthProvider.handleSessionRevoked` clears stored token, resets `_token`/`_user`, sets `_status = AuthStatus.unauthenticated`, stores a clear user-facing `_errorMessage` (e.g., *"Your session expired. Please sign in again."*), and notifies listeners so `AuthGate` transitions cleanly to `LoginScreen`.
- `AuthProvider.logout()` and `handleSessionRevoked()` must ensure any cached `MedicineProvider` data is cleared (or reloaded fresh on next authenticated session) so stale data never leaks across accounts.

### 3.2 Categories Endpoints (`medixmart-backend/src/controllers/category.controller.js`)
- `GET /api/categories` (Admin & Pharmacist)
  - Response `200`: `{ "success": true, "data": [{ "id", "name", "description", "created_at" }], "meta": { "total": N, "timestamp": "..." } }`
- `POST /api/categories` (Admin only)
  - Request: `{ "name": "Antibiotics", "description": "Optional text" }`
  - Response `201`: `{ "success": true, "data": { "id", "name", "description", "created_at" }, "meta": { ... } }`
  - Errors: `400 VALIDATION_ERROR` (with `error.details`), `409 DUPLICATE_ENTRY`, `403 AUTH_FORBIDDEN_ROLE`.

### 3.3 Medicines Endpoints (`medixmart-backend/src/controllers/medicine.controller.js` & `src/utils/response.js`)
- `GET /api/medicines` (Admin & Pharmacist)
  - Query parameters (exact backend names):
    - `search` (optional string — matches `name`, `generic_name`, or `brand` via `ILIKE`)
    - `category_id` (optional int)
    - `is_active` (optional: `'true'`, `'false'`, or `'all'` — backend defaults to `TRUE` when omitted; passing `'all'` omits the `is_active` SQL filter and returns both active and inactive rows)
    - `page` (default `1`)
    - `limit` (default `20`, max `100`)
    - `sortBy` (**camelCase**, whitelisted: `name`, `selling_price`, `reorder_level`, `created_at`, `id`)
    - `sortOrder` (**camelCase**: `asc`, `desc`)
  - Response `200`:
    ```json
    {
      "success": true,
      "data": [
        {
          "id": 5,
          "category_id": 1,
          "category_name": "Analgesics",
          "name": "Panadol ActiFast",
          "generic_name": "Paracetamol",
          "brand": "GSK",
          "dosage_form": "Tablet",
          "strength": "500mg",
          "selling_price": "25.00",
          "cost_price": "18.50",
          "reorder_level": 20,
          "is_active": true,
          "created_at": "2026-11-19T06:00:00.000Z",
          "updated_at": "2026-11-19T06:00:00.000Z"
        }
      ],
      "meta": {
        "page": 1,
        "limit": 20,
        "totalRecords": 142,
        "totalPages": 8,
        "hasNextPage": true,
        "hasPrevPage": false,
        "timestamp": "..."
      }
    }
    ```
  - **Numeric parsing rule:** PostgreSQL `NUMERIC(10, 2)` fields (`selling_price`, `cost_price`) arrive as strings (`"25.00"`). `MedicineModel.fromJson` must parse both `num` and `String` safely.
  - **Pagination parsing rule:** Read flat `meta['totalRecords']`, `meta['totalPages']`, `meta['hasNextPage']`, `meta['hasPrevPage']` first, with fallback to nested `meta['pagination']` if a future endpoint uses the nested shape.
  - **Forward-compatible stock field:** `MedicineModel` includes an optional `int? availableStock` parsed from `available_stock` / `total_stock` if present; omitted from UI columns while `null` so no fake numbers are shown.
- `POST /api/medicines` (Admin only)
  - Required: `name`, `category_id`, `selling_price` (`>= 0`).
  - Optional: `generic_name`, `brand`, `dosage_form` (default `'Tablet'`), `strength`, `cost_price` (default `0.00`, `>= 0`), `reorder_level` (default `10`, integer `>= 0`).
  - Unique constraint: `(name, strength)` → `409 DUPLICATE_ENTRY`.
  - Returns `201` with created row (note: `INSERT ... RETURNING *` does not include `category_name`; provider refreshes list or resolves `category_name` from loaded categories).
- `PUT /api/medicines/:id` (Admin only)
  - Accepts any subset of medicine fields including `is_active` (enables both editing details and reactivating an inactive medicine).
  - Returns `200` with updated row.
- `PATCH /api/medicines/:id/deactivate` (Admin only)
  - Sets `is_active = FALSE` without deleting foreign-key references.
  - Returns `200`: `{ "success": true, "data": { "medicine": { "id", "name", "is_active", "updated_at" }, "message": "..." } }`.

### 3.4 Monetary & Formatting Conventions
- Currency display: `Rs. #,##0.00` (matching existing `AdminDashboardDefaults`, e.g., `Rs. 25.00`, `Rs. 1,250.00`), rendered in `MmTypography.codeMono` inside tables.
- Platform support: Windows desktop (`>= 1024px` permanent sidebar, `>= 900px` data table) and Android/compact viewports (`< 1024px` drawer navigation, `< 900px` stacked medicine cards), zero horizontal overflow at `1440x900`, `862x692`, and `390x844`.

---

## 4. Approaches Considered

| Approach | Summary | Trade-offs | Decision |
| :--- | :--- | :--- | :--- |
| **A. Single-Screen Medicines Catalog + Inline Category Controls** | Persistent sidebar shell swaps main body to `MedicinesScreen`. Category dropdown/filter lives in toolbar, paired with a **Categories** modal (list + Add Category) and an inline **+ New Category** trigger inside the Add/Edit Medicine dialog. | Fastest workflow for staff (no tab-hopping); aligns cleanly with current `GET`/`POST`-only categories API. Category descriptions/dates are inside the Categories modal rather than a dedicated full-page table. | **Selected** |
| **B. Two-Tab Screen (Medicines \| Categories)** | Same persistent sidebar shell, but top segmented tabs switch between a Medicines table and a full Categories table. | Gives category descriptions/timestamps full-page space, but adds extra tab-switching overhead when managing medicines and categories together. | Not selected |
| **C. Separate `Navigator.push` Screen** | Leave `AdminDashboardScreen` untouched and push `MedicinesScreen` as an independent route. | Avoids touching dashboard shell code, but breaks persistent desktop sidebar UX, causes navigation flicker, and duplicates sidebar/drawer wiring for every future module. | Rejected |

---

## 5. Detailed Design

### 5.1 File Map

**New files:**
- `medixmart_app/lib/models/api_exception.dart` — `ApiErrorDetail`, `ApiException` (with `isSessionRevoked`, `isForbidden`, `isDuplicate`, `isValidation`, `fieldError(String field)` helper).
- `medixmart_app/lib/models/category_model.dart` — immutable `CategoryModel` (`id`, `name`, `description`, `createdAt`).
- `medixmart_app/lib/models/medicine_model.dart` — immutable `MedicineModel` + `MedicineInput` request payload DTO.
- `medixmart_app/lib/models/paginated_response.dart` — generic `PaginationMeta` & `PaginatedResponse<T>`.
- `medixmart_app/lib/services/api_client.dart` — shared authenticated HTTP client (`get`, `post`, `put`, `patch`, `delete`).
- `medixmart_app/lib/services/medicine_service.dart` — typed REST calls for `/api/categories` and `/api/medicines`.
- `medixmart_app/lib/providers/medicine_provider.dart` — `ChangeNotifier` managing categories, paginated medicines, filters, sort, debounced search, mutations, and error states.
- `medixmart_app/lib/widgets/mm_input_field.dart` — Figma `7:70` input component (`MmInputField`, `MmInputSize.medium/large`, Default/Focused/Error/Disabled states with brand/danger focus rings).
- `medixmart_app/lib/widgets/mm_feedback_states.dart` — `MmLoadingView`, `MmEmptyState`, `MmErrorState` (with retry button), and `showMmConfirmDialog`.
- `medixmart_app/lib/screens/medicines/medicines_screen.dart` — responsive Medicines & Categories screen.
- `medixmart_app/lib/screens/medicines/medicine_form_dialog.dart` — Add/Edit Medicine modal with inline "+ New Category" shortcut and server error mapping.
- `medixmart_app/lib/screens/medicines/category_modal.dart` — Categories directory + Add Category modal.
- `medixmart_app/test/unit/api_client_and_models_test.dart` — unit tests for `ApiClient`, `ApiException`, `MedicineModel`, `CategoryModel`, `PaginationMeta`, and `MedicineProvider`.
- `medixmart_app/test/widget/medicines_screen_test.dart` — widget tests covering desktop/tablet/mobile layouts, RBAC (Admin vs Pharmacist), search/filter/sort/pagination, Add/Edit/Deactivate/Reactivate Medicine, Add Category, error/retry, and 401 session revocation.

**Modified files:**
- `medixmart_app/lib/services/auth_service.dart` — `export '../models/api_exception.dart';` and remove duplicate local `ApiException` class (keeping existing constructor compatibility via default `details = const []`).
- `medixmart_app/lib/providers/auth_provider.dart` — add `static const String tokenStorageKey = 'medixmart_jwt_token';`, expose `handleSessionRevoked([String? reason])`, and keep all existing public methods/signatures intact.
- `medixmart_app/lib/screens/dashboard/admin_dashboard_screen.dart` — switch main content area based on `DashboardProvider.selectedNavId`:
  - `'dashboard'` → `_DashboardMainArea` (preserves all existing layout & tests; additionally hides the Watchlist **Add Medicine** button when `authUser?.isPharmacist == true` per Member 2 Task 35 — leaving `authUser == null` in standalone dashboard tests unaffected)
  - `'medicines'` → `MedicinesScreen` (receiving `showMenuButton`, `onOpenDrawer`, and optional `openCreateOnMount` flag when launched from the Dashboard's **Add Medicine** button by an Admin)
  - Other unbuilt nav items (`pos_checkout`, `receive_batches`, `alerts`, `customers`, `reports`) → stay on current view and show snackbar indicating the module is not yet enabled (preventing dead-end screens).
- `medixmart_app/lib/main.dart` — register `ApiClient`, `MedicineService`, and `MedicineProvider` in `MultiProvider` (keeping optional constructor overrides on `MedixmartApp` for tests; wire `ApiClient.onSessionRevoked` to `AuthProvider.handleSessionRevoked`; clear/reset `MedicineProvider` on unauthenticated transition).

---

### 5.2 Shared `ApiClient` Behavior

- **Base URL:** Reads `ApiConfig.baseUrl` dynamically on every request (so runtime custom LAN host changes on `LoginScreen` apply immediately).
- **Headers:** Always sets `Content-Type: application/json` and `Accept: application/json`; attaches `Authorization: Bearer <token>` from `TokenStorage.read(AuthProvider.tokenStorageKey)` when `requiresAuth: true`.
- **Timeouts & Network Errors:** Every method (`get`, `post`, `put`, `patch`, `delete`) applies `.timeout(ApiConfig.receiveTimeout)` and normalizes:
  - `SocketException` / `http.ClientException` → `ApiException(code: 'NETWORK_ERROR', statusCode: 0, message: 'Unable to reach pharmacy server. Verify server status and LAN/Wi-Fi connection.')`
  - `TimeoutException` → `ApiException(code: 'REQUEST_TIMEOUT', statusCode: 408, message: 'Server request timed out. Please try again.')`
  - Non-JSON / malformed body → `ApiException(code: 'INVALID_RESPONSE', statusCode: response.statusCode, ...)`
- **Session Revocation Handling (Explicit Error-Code Allowlist):** For authenticated requests (`requiresAuth: true`), `ApiException.isSessionRevoked` matches ONLY the explicit set of session-terminating backend codes:
  - `401 AUTH_MISSING_TOKEN`
  - `401 AUTH_INVALID_TOKEN`
  - `401 AUTH_EXPIRED_TOKEN`
  - `401 AUTH_SESSION_REVOKED`
  - `403 AUTH_ACCOUNT_DISABLED` (matches `medixmart-backend/src/middleware/auth.js`, which rejects disabled active users with `403 AUTH_ACCOUNT_DISABLED` before checking `token_version` so disabled sessions terminate immediately)
  - **Explicitly excluded:** `401 AUTH_INVALID_CREDENTIALS` (returned by protected `PUT /api/auth/change-password` on wrong current password — must NOT log the user out) and `403 AUTH_FORBIDDEN_ROLE` (must remain a permission error without revoking the session).
  - When `requiresAuth: true` and `exception.isSessionRevoked` is true, `ApiClient` deletes `'medixmart_jwt_token'` from `TokenStorage`, invokes `onSessionRevoked?.call(exception.message)`, and throws `exception`.
- **Clean HTTP client disposal:** Supports injected `http.Client` for deterministic unit/widget testing.

---

### 5.3 `MedicineProvider` State & Flows

- **Status enum (`MedicineStatusFilter`):** `active` (`'true'`), `inactive` (`'false'`), `all` (`'all'`). Defaults to `active`.
- **Sort options (`MedicineSortField`):** `name` (default), `selling_price`, `reorder_level`, `created_at` + ascending/descending toggle.
- **Initialization (`ensureLoaded()`):** Loads categories and page 1 of medicines in parallel on first visit; avoids redundant refetches on widget rebuilds while allowing explicit `refresh()`.
- **Search debouncing:** `setSearchQuery(String)` debounces API calls (~350ms), resets `page = 1`, and uses a monotonic request counter (`_requestSeq`) so out-of-order responses from slower earlier queries are ignored.
- **Filter/Sort/Page changes:** Reset `page = 1` on filter/sort changes; clamp page bounds (`1..totalPages`).
- **Mutations (with in-flight guard `_isMutating`):**
  - `createCategory(name, description)` → calls `POST /api/categories`, inserts/sorts into `_categories` (or reloads categories), returns the newly created `CategoryModel` so the Add/Edit Medicine dialog can auto-select it immediately.
  - `createMedicine(input)` → calls `POST /api/medicines`, refreshes current page so joined `category_name` and pagination totals stay exact.
  - `updateMedicine(id, input)` → calls `PUT /api/medicines/:id`, refreshes current page.
  - `deactivateMedicine(id)` → calls `PATCH /api/medicines/:id/deactivate`, refreshes current page (if last item on page `> 1` disappeared under Active filter, automatically steps back one page).
  - `reactivateMedicine(id)` → calls `PUT /api/medicines/:id` with `{'is_active': true}`, refreshes current page.
- **Mutation errors:** Re-throws `ApiException` to the calling dialog/handler so form dialogs display exact server errors without erasing the list view behind the dialog.

---

### 5.4 Responsive Medicines & Categories UI

- **Header bar** (matches `_DashboardMainArea` header container: white surface, bottom `1px` `borderDefault` divider):
  - Left: drawer hamburger button (`Key('dashboard_menu_button')`) when `< 1024px`, `Medicines` title (`headingH2`), and subtle count pill (e.g., `142 items`).
  - Right (stacks cleanly below title when `< 760px`): `PosSearchBar` (`Search name, generic, or brand...`), refresh icon button, secondary `MmButton` (`Categories` — visible to both Admin and Pharmacist so Pharmacists can inspect category descriptions read-only, matching `GET /api/categories`), and for **Admin only**: primary `MmButton` (`Add Medicine`, `iconPlusMd`).
- **Filter toolbar** (responsive `Wrap` so controls never overflow on mobile/tablet):
  - Category dropdown (`All Categories` + loaded categories).
  - Active status segmented pill selector (`Active` | `Inactive` | `All`).
  - Sort dropdown (`Name A–Z`, `Name Z–A`, `Price: Low–High`, `Price: High–Low`, `Reorder Level`, `Newest`).
  - Active filter clear button (`Reset filters`) when any search/filter is active.
- **Main catalog surface** (white rounded `12px` card with `1px` `borderDefault` and `MmElevation.xs`):
  - **Loading state:** `MmLoadingView` on initial load; slim linear progress bar along top of card during filter/page refreshes so existing rows don't flash away.
  - **Error state:** `MmErrorState` showing the `ApiException.message` and a **Retry** `MmButton`.
  - **Empty state:** Distinguishes between *"No medicines in catalog yet"* (with Admin **+ Add Medicine** CTA) and *"No medicines match your search/filters"* (with **Clear Filters** CTA).
  - **Desktop table (`>= 900px`, styled after Figma `10:107`):**
    - Horizontal scroll fallback below `960px` min width if needed.
    - Columns: `MEDICINE` (bold name + muted `generic_name · brand` subtitle), `CATEGORY`, `FORM & STRENGTH` (`dosage_form · strength`), `PRICE (LKR)` (`Rs. XX.XX` selling in `codeMono` + muted cost subtitle), `REORDER` (integer units), `STATUS` (`StatusBadge`: green `Active` or danger `Inactive`), and for Admin only: `ACTIONS` (`Edit` icon button, `Deactivate` or `Reactivate` icon button).
    - Inactive rows rendered with subtle muted background (`bgSubtle`) so they are visually distinct without relying solely on color.
  - **Mobile/Tablet cards (`< 900px`):**
    - Clean stacked cards displaying medicine title, generic/brand subtitle, category pill, status badge, key-value metrics row (Form/Strength, Selling Price, Cost Price, Reorder Level), and Admin action footer buttons (`Edit`, `Deactivate`/`Reactivate`).
  - **Pagination footer:** Displays `"Showing X–Y of Z medicines"` and `Previous` / `Page P of T` / `Next` buttons disabled at bounds.
- **Modals:**
  - **Add / Edit Medicine Dialog (`medicine_form_dialog.dart`):**
    - Constrained width (`maxWidth: 560`), scrollable for small screens/keyboards.
    - Fields using `MmInputField` (`7:70`): Medicine Name\*, Category dropdown\* (with inline `+ New` button opening Quick Add Category and auto-selecting the result), Generic Name, Brand, Dosage Form (dropdown with common pharmacy forms + custom input option or standard choices: `Tablet`, `Capsule`, `Syrup`, `Suspension`, `Injection`, `Cream`, `Ointment`, `Drops`, `Inhaler`, `Powder`, `Other`), Strength (e.g. `500mg`), Selling Price (LKR)\*, Cost Price (LKR), Reorder Level\*.
    - Client validation: required Name & Category, numeric non-negative Selling Price & Cost Price, non-negative integer Reorder Level.
    - Server error display: maps `ApiException.details` to matching fields and displays top-level `409 DUPLICATE_ENTRY` / general errors in a danger banner inside the dialog without clearing inputs.
    - Submit button shows loading indicator and blocks duplicate submissions while request is pending.
  - **Categories Modal (`category_modal.dart`):**
    - Shows searchable/scrollable list of existing categories (name + description) and (for Admin) an inline **Add Category** form (`name`*, optional `description`), handling `409 DUPLICATE_ENTRY` cleanly and refreshing `MedicineProvider.categories` immediately on save.
  - **Safe Deactivate Confirmation Dialog:**
    - Explains clearly: *"Deactivating '<Name>' hides it from active POS search while preserving all historical sales and batch records."* with Cancel and Danger Confirm buttons.

---

## 6. What's Left to the Builder

- Exact Material icons for table row actions (e.g., `Icons.edit_outlined`, `Icons.block_outlined` / `Icons.restore_rounded`, `Icons.refresh_rounded`) where no dedicated SVG exists in `AppAssets`.
- Exact debounce interval (`350ms` recommended) and subtle hover/transition animations.
- Exact currency formatting helper implementation (e.g., pure-Dart formatter in `lib/utils/formatters.dart` so no new `intl` dependency is required in `pubspec.yaml`).
- Exact widget keys used to make widget tests readable and resilient (`Key('medicines_add_button')`, `Key('medicines_category_button')`, etc.).
