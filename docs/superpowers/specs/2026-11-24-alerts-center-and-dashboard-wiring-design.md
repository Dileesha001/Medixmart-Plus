# Design Document: Alerts Center Screen & Live Dashboard Alert Integration

**Date:** 2026-11-24  
**Target Area:** `medixmart_app/` (Flutter client for Windows desktop & Android mobile/tablet)  
**Design System Source:** Figma `Medixmart Plus — Design System` (`MmColors`, `MmTypography`, `MmSpacing`, `MmRadius`, `MmElevation`)  
**Backend Baseline:** `main` @ `65077d1` (`GET /api/alerts`, `GET /api/alerts/summary`, `PATCH /api/alerts/:id/resolve`, `POST /api/alerts/generate-expiry`)

---

## 1. Intent & Why

All four `/api/alerts` endpoints, the idempotent 7-month expiry SQL stored procedure (`generate_expiry_alerts()`), and the daily `06:00` (`Asia/Colombo`) cron + startup catch-up scheduler (`expiryJob.js`) are already live and verified on `main` (PR #15 and PR #17). Meanwhile, Batches/Suppliers, POS Checkout, Customers, and Reports only have database tables so far—no Express routes exist for them yet.

On the Flutter side, `lib/screens/alerts/` is still empty, both the sidebar **Alerts** nav item and the Dashboard's **View all** action display `"Alerts module is coming soon."` snackbars, and `AdminDashboardDefaults` hardcodes alert indicators (`badgeCount: 12`, `08 Items` Low Stock, `12 Batches` Expiring ≤ 7 Months, `View all (20)`, and 3 static `Recent Alerts` rows).

Building `AlertsScreen` and wiring live alert data into `AdminDashboardScreen` delivers a complete, zero-backend-blocker vertical slice that reuses `ApiClient`, `PaginatedResponse`, `AlertFeedItem`, `StatusBadge`, `KpiSummaryCard`, and `MmFeedbackStates`.

---

## 2. Goals, Non-Goals, and Anti-Goals

### Goals
- Add typed alert models (`AlertType`, `AlertSeverity`, `AlertModel`, `AlertSummary`, `ExpiryCheckResult`), `AlertService` (via `ApiClient`), and `AlertProvider` registered in `main.dart` with automatic `reset()` on logout or session revocation.
- Build a responsive **Alerts Center** (`medixmart_app/lib/screens/alerts/alerts_screen.dart`) inside the persistent sidebar/drawer shell featuring:
  - Live 4-card summary strip (`Active Alerts`, `Expired`, `Expiring ≤ 7M`, `Low Stock`) backed by `GET /api/alerts/summary`.
  - Server-backed filtering by **Status** (`Active` / `Resolved`), **Type**, and **Severity**, plus pagination.
  - Per-alert **Resolve** action (`PATCH /api/alerts/:id/resolve`) with confirmation dialog for both `admin` and `pharmacist` users.
  - **Admin-only** `"Run Expiry Check"` action (`POST /api/alerts/generate-expiry`, hidden for `pharmacist` users) surfacing the returned run counts (`expired_alerts_created`, `warning_alerts_created`, `alerts_auto_resolved`).
- Wire live alert counts and top 3 active alerts into the persistent sidebar badge, Dashboard `Low Stock` and `Expiring ≤ 7 Months` KPI cards, and Dashboard `Recent Alerts` card (`View all (N)`), and route sidebar **Alerts**, Dashboard **View all**, and alert KPI card taps to `AlertsScreen`.
- Keep all existing unit and widget tests (including standalone `admin_dashboard_screen_test.dart`) passing without regression.

### Non-Goals
- **No backend edits** (consume the verified `/api/alerts` contracts as implemented).
- **No manual alert creation, editing, or reopen/unresolve flows** (not exposed by the backend).
- **No client-side text search bar** (`GET /api/alerts` does not accept a `search` parameter; avoid misleading page-only filtering).
- **No live wiring of `Today's Sales`, `Outstanding Credit`, `Last 7 Days Sales`, or `Inventory Watchlist`** (those backend routes do not exist yet).
- **No deep-linking from `reference_table`/`reference_id`** to Batch or Customer detail screens (those modules are not built yet).

### Anti-Goals
- **Never break standalone `admin_dashboard_screen_test.dart` tests** that mount `AdminDashboardScreen` with an unauthenticated `AuthProvider` and without an `AlertProvider` in the widget tree.
- **Never offer an `"All"` status filter tab.** `alert.controller.js` parses `is_resolved !== undefined ? is_resolved === 'true' : false`, so only Active (`false`) and Resolved (`true`) lists exist.
- **Never send a null or omitted body to `POST /api/alerts/generate-expiry`.** `alert.controller.js` destructures `const { months_ahead } = req.body;`, so always send `{}` (or `{'months_ahead': n}`).
- **Never reference nonexistent SVG assets in `AppAssets`.** Only `statusDotInStock`, `statusDotWarning`, and `statusDotDanger` exist; render `info`/`birthday` and `resolved` pill dots with standard Flutter widgets.

---

## 3. Verified Backend Contracts

Verified against `medixmart-backend/src/routes/alert.routes.js`, `src/controllers/alert.controller.js`, `src/services/alert.service.js`, `src/utils/response.js`, and `src/sql/04_create_harmonized_core_schema.sql`:

### 3.1 `GET /api/alerts` (Admin & Pharmacist)
- **Query parameters:**
  - `is_resolved`: `'false'` (default) or `'true'`
  - `alert_type` (optional): `'expired' | 'expiry_warning' | 'low_stock' | 'credit_overdue' | 'birthday'`
  - `severity` (optional): `'danger' | 'warning' | 'info'`
  - `page`: positive integer (default `1`)
  - `limit`: positive integer `1..100` (default `20`)
- **Ordering:** Server sorts by severity priority (`danger` → `warning` → `info`) and then `created_at DESC`.
- **Response `200` (standard `paginatedResponse`):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": 14,
        "alert_type": "expiry_warning",
        "severity": "warning",
        "title": "Batch B-061 Near Expiry (Return Window)",
        "message": "Batch B-061 of Losartan Potassium (50mg) expires on 2027-04-15 (142 days remaining). Quantity: 30 units. Eligible for vendor return to Cipla Lanka.",
        "reference_table": "batches",
        "reference_id": 61,
        "is_resolved": false,
        "resolved_at": null,
        "created_at": "2026-11-24T00:30:00.000Z"
      }
    ],
    "meta": {
      "page": 1,
      "limit": 20,
      "totalRecords": 1,
      "totalPages": 1,
      "hasNextPage": false,
      "hasPrevPage": false,
      "timestamp": "2026-11-24T00:30:01.000Z"
    }
  }
  ```

### 3.2 `GET /api/alerts/summary` (Admin & Pharmacist)
- **Response `200`:**
  ```json
  {
    "success": true,
    "data": {
      "total_active": 12,
      "danger_count": 3,
      "warning_count": 8,
      "info_count": 1,
      "expired_count": 2,
      "expiring_soon_count": 6,
      "low_stock_count": 3
    },
    "meta": { "timestamp": "..." }
  }
  ```

### 3.3 `PATCH /api/alerts/:id/resolve` (Admin & Pharmacist)
- **Response `200`:**
  ```json
  {
    "success": true,
    "data": {
      "message": "Alert marked as resolved.",
      "alert": {
        "id": 14,
        "alert_type": "expiry_warning",
        "severity": "warning",
        "title": "Batch B-061 Near Expiry (Return Window)",
        "is_resolved": true,
        "resolved_at": "2026-11-24T01:00:00.000Z"
      }
    },
    "meta": { "timestamp": "..." }
  }
  ```
- **Errors:** `400 VALIDATION_ERROR` (non-integer `:id`), `404 NOT_FOUND` (missing alert ID).

### 3.4 `POST /api/alerts/generate-expiry` (Admin Only)
- **Request body:** `{}` (defaults to server config `7` months) or `{ "months_ahead": 7 }`.
- **Response `200`:**
  ```json
  {
    "success": true,
    "data": {
      "message": "Expiry alert engine executed successfully.",
      "stats": {
        "expired_alerts_created": 1,
        "warning_alerts_created": 4,
        "alerts_auto_resolved": 2
      }
    },
    "meta": { "timestamp": "..." }
  }
  ```
- **Errors:** `403 AUTH_FORBIDDEN_ROLE` (if called by `pharmacist`), `400 VALIDATION_ERROR` (if `months_ahead <= 0` or non-numeric).

---

## 4. Approaches Considered

| Approach | Summary | Trade-offs | Decision |
| :--- | :--- | :--- | :--- |
| **A. Persistent-Shell `AlertsScreen` + Live Dashboard Preview Wiring** | Single `AlertProvider` feeds both `AlertsScreen` inside the sidebar/drawer shell and live counts/top-3 feed on `AdminDashboardScreen`. | Reuses existing shell and design components; keeps Dashboard badges/KPIs consistent with the Alerts Center while preserving standalone test fallbacks. | **Selected** |
| **B. Standalone `AlertsScreen` Only** | Build `AlertsScreen` and link sidebar **Alerts** / **View all** to it, leaving Dashboard badges and KPIs hardcoded. | Slightly smaller diff, but Dashboard still displays stale mock counts (`12`, `08 Items`, `View all (20)`) contradicting live alerts. | Not selected |
| **C. Overlay Drawer / Modal over Dashboard** | Show alerts in a slide-over panel or dialog on top of `AdminDashboardScreen`. | Avoids adding a full screen, but cramps multi-filter triage, resolved history, pagination, and Admin expiry runs on desktop and mobile. | Rejected |

---

## 5. Detailed Design

### 5.1 File Map

**New files:**
- `medixmart_app/lib/models/alert_model.dart` — `AlertType`, `AlertSeverity`, `AlertModel`, `AlertSummary`, and `ExpiryCheckResult`.
- `medixmart_app/lib/services/alert_service.dart` — typed `ApiClient` wrapper for `/api/alerts`, `/api/alerts/summary`, `/api/alerts/:id/resolve`, and `/api/alerts/generate-expiry`.
- `medixmart_app/lib/providers/alert_provider.dart` — `ChangeNotifier` managing separate Dashboard preview state and paginated/filtered Alerts Center state.
- `medixmart_app/lib/screens/alerts/alerts_screen.dart` — responsive Alerts Center view.
- `medixmart_app/test/unit/alert_models_and_service_test.dart` — model parsing and `AlertService` contract tests.
- `medixmart_app/test/unit/alert_provider_test.dart` — provider state, filtering, race-guard, resolve step-back, and reset tests.
- `medixmart_app/test/widget/alerts_screen_test.dart` — responsive layout, RBAC, filtering, resolve confirmation, expiry run, and error/empty-state widget tests.

**Modified files:**
- `medixmart_app/lib/utils/formatters.dart` — add a pure-Dart timestamp formatter (e.g., `shortDateTime` / `relativeDate`) without adding an `intl` dependency.
- `medixmart_app/lib/main.dart` — register `AlertService` and `AlertProvider` in `MultiProvider` (with optional constructor injection on `MedixmartApp` for tests) and call `_alertProvider.reset()` in `_handleAuthStateChanged()` on logout or session revocation.
- `medixmart_app/lib/screens/dashboard/admin_dashboard_screen.dart` — wire `'alerts'` nav selection and `onViewAllAlerts` (plus alert KPI taps) to `AlertsScreen`, optionally read `AlertProvider?`, trigger `ensureDashboardLoaded()` only when authenticated, and render live summary counts and top 3 active alerts when loaded.

---

### 5.2 `AlertProvider` State & Flows

- **Separated Preview vs. List State:** Maintain Dashboard preview fields (`_summary`, `_dashboardPreviewAlerts`, `_hasLoadedDashboardPreview`, `_isDashboardLoading`) separately from Alerts Center list fields (`_alerts`, `_pagination`, `_showResolved`, `_typeFilter`, `_severityFilter`, `_isLoading`, `_isRefreshing`, `_errorMessage`, `_hasLoadedOnce`). Changing filters to **Resolved** or filtering by **Type** in `AlertsScreen` never overwrites the Dashboard's active `Recent Alerts` preview.
- **Dashboard Loading (`ensureDashboardLoaded()`):** Loads `GET /api/alerts/summary` and `GET /api/alerts?is_resolved=false&page=1&limit=3` in parallel. Errors during background Dashboard preview load do not break the Dashboard UI; they keep `hasLoadedDashboardPreview == false` (or expose non-fatal retry via `AlertsScreen`).
- **Alerts Center Loading (`ensureLoaded()` / `refresh()`):** Fetches `GET /api/alerts/summary` and the active filtered page of `GET /api/alerts` in parallel. Uses a monotonic `_requestSeq` plus `_resetEpoch` (mirroring `MedicineProvider`) so stale out-of-order responses or in-flight calls across a logout `reset()` are discarded.
- **Filter & Quick-Jump Actions:**
  - `setShowResolved(bool)` (Active vs Resolved), `setTypeFilter(AlertType?)`, `setSeverityFilter(AlertSeverity?)`, `clearFilters()`, and `goToPage(int)` reset page to `1` on filter changes and clamp page bounds.
  - `applyQuickFilter({AlertType? type, bool showResolved = false})` sets the target filters and loads immediately—used when clicking Dashboard KPI cards (`Low Stock`, `Expiring ≤ 7 Months`) or tapping summary strip cards on `AlertsScreen`.
- **Mutations & Concurrency Guards:**
  - `resolveAlert(int id)`: tracks `_resolvingIds` (`Set<int>`) to block duplicate taps on the same alert, calls `PATCH /api/alerts/:id/resolve`, and refreshes summary, dashboard preview, and current list page. If resolving the last item on `page > 1` while `showResolved == false`, steps back to `page - 1`.
  - `runExpiryCheck({int? monthsAhead})`: guards with `_isRunningExpiryCheck`, sends `{}` (or `{'months_ahead': monthsAhead}`) to `POST /api/alerts/generate-expiry`, returns `ExpiryCheckResult`, and refreshes summary, dashboard preview, and current list page.
  - `reset()`: cancels/invalidates pending sequences via `_resetEpoch++` and restores all preview, list, filter, and loading fields to initial values.

---

### 5.3 Responsive `AlertsScreen` UI & Semantic Badge Mapping

- **Breakpoints (aligned with `MedicinesScreen`):** `headerSingleRow: 880.0`, `compactPadding: 760.0`, `desktopLayout: 900.0`.
- **Header Bar:**
  - Left: drawer hamburger button (`Key('dashboard_menu_button')`) below `1024px`, `Alerts` title (`MmTypography.headingH2`), and active count pill (`N active` when summary is loaded).
  - Right (stacks cleanly on narrow screens): Refresh icon button and **Admin-only** primary `MmButton` (`Run Expiry Check`) hidden when `authUser?.isAdmin != true`. After completion, show a floating snackbar summarizing `X expired, Y return-window alerts created, Z auto-resolved` (or `"Expiry check complete — no new alerts."` when all three counts are `0`).
- **Interactive 4-Card Summary Strip:** Displays `Active Alerts` (`totalActive`), `Expired` (`expiredCount`), `Expiring ≤ 7M` (`expiringSoonCount`), and `Low Stock` (`lowStockCount`) in a 4-column row on desktop (`>= 900px`) and 2×2 grid on tablet/mobile. Tapping a card toggles the matching `AlertType` filter (and `Active Alerts` clears type/severity filters to show active alerts).
- **Filter Toolbar (`Wrap`):**
  - Status segmented pill (`Active` | `Resolved`).
  - Type dropdown (`All Types`, `Expired`, `Expiring ≤ 7M`, `Low Stock`, `Credit Overdue`, `Birthday`).
  - Severity dropdown (`All Severities`, `Danger`, `Warning`, `Info`).
  - `Reset filters` action when any non-default filter is selected.
- **Feed Surface & States:**
  - Initial load: `MmLoadingView`; subsequent filter/page/action refreshes: slim `LinearProgressIndicator` above existing cards/rows so content stays anchored.
  - Error: `MmErrorState` with `Retry` button.
  - Empty: `MmEmptyState` distinguishing *"No active alerts"* (e.g., all stock healthy), *"No resolved alerts yet"*, and *"No alerts match your current filters"* (with `Clear Filters` CTA).
- **Alert Row / Card Content:**
  - Severity icon tile (`danger` → `MmColors.bgDangerSubtle` + `iconAlertTriangle`; `warning` + `expiry_warning` → `MmColors.bgWarningSubtle` + `iconClock`; `warning` + `low_stock` → `MmColors.bgWarningSubtle` + `iconPackage`; `info` → `MmColors.bgInfoSubtle` + Material info/cake icon).
  - Title (`headingH4` / `labelLarge`) and **full untruncated multi-line message** (essential because SQL messages embed batch number, medicine name/strength, expiry date, days remaining, remaining units, and vendor name).
  - Metadata row (`Wrap`):
    - Semantic type/status pill: reuse `StatusBadge` (`StatusTone.expired`, `StatusTone.expiring7M`, `StatusTone.lowStock`), and use an inline themed pill for `credit_overdue` / `birthday` (`MmColors.bgInfoSubtle` / `MmColors.textInfo` with a Flutter dot widget—never referencing missing SVG assets) and a subtle `Resolved` badge (`MmColors.bgSubtle` / `MmColors.textSecondary`) when `isResolved == true`.
    - Optional reference chip when `referenceTable != null && referenceId != null` (e.g., `Batch #61`, `Medicine #5`).
    - Created timestamp (and resolved timestamp when `resolvedAt != null`) via `MmFormatters`.
  - Action: **Resolve** `MmButton` (secondary/small, with loading indicator while ID is in `_resolvingIds`) visible on active alerts for both Admin and Pharmacist, triggering `showMmConfirmDialog` before calling `resolveAlert(id)`.
- **Pagination Footer:** Matches `MedicinesScreen` (`Showing X–Y of Z alerts`, `Previous` / `Page P of T` / `Next`).

---

### 5.4 Dashboard Live Wiring & Backward Compatibility

- **Navigation Wiring in `AdminDashboardScreen`:**
  - `_handleNavTap` handles `'alerts'` alongside `'dashboard'` and `'medicines'`, switching `DashboardProvider.selectNavItem('alerts')`.
  - `onViewAllAlerts` selects `'alerts'` on `DashboardProvider` instead of showing a snackbar.
  - Tapping the `Low Stock` or `Expiring ≤ 7 Months` `KpiSummaryCard` calls `alertProvider?.applyQuickFilter(type: ...)` and switches `DashboardProvider.selectNavItem('alerts')`.
- **Safe Provider Access & Auth Guard:**
  - Read `context.watch<AlertProvider?>()` and `context.watch<AuthProvider?>()` optionally so standalone tests that only provide `AuthProvider` + `DashboardProvider` + `MedicineProvider` continue mounting cleanly.
  - Trigger `alertProvider.ensureDashboardLoaded()` inside a post-frame callback **only** when `authProvider?.isAuthenticated == true` and `!alertProvider.hasLoadedDashboardPreview && !alertProvider.isDashboardLoading`.
- **Live Replacement Rules (only when `alertProvider != null && alertProvider.hasLoadedDashboardPreview`):**
  - **Sidebar `Alerts` badge:** `summary.totalActive > 0 ? summary.totalActive : null` (hides badge when `0`).
  - **`Low Stock` KPI:** value `'<N> Items'` (2-digit padded for `< 10` or plain count consistent with existing style), keeping subtitle `'At or below reorder level'`.
  - **`Expiring ≤ 7 Months` KPI:** value `'<expiringSoonCount> Batches'`; subtitle shows `'<expiredCount> expired · Eligible for return'` when `expiredCount > 0`, otherwise `'Eligible for supplier return'`.
  - **`Recent Alerts` card:** action label `'View all (${summary.totalActive})'`; renders up to 3 active `AlertFeedItem` entries mapped from `dashboardPreviewAlerts` (tapping navigates to `AlertsScreen`), or a compact empty message (*"No active alerts right now."*) when `dashboardPreviewAlerts` is empty.
- **Fallback:** When `alertProvider == null` or `!alertProvider.hasLoadedDashboardPreview` (including unauthenticated standalone widget tests like `admin_dashboard_screen_test.dart`), retain `AdminDashboardDefaults` values (`badgeCount: 12`, `08 Items`, `12 Batches`, `View all (20)`, and the 3 default alert items).

---

### 5.5 Verification Strategy

- **Unit Tests:**
  - `alert_models_and_service_test.dart`: JSON parsing across all 5 `AlertType` and 3 `AlertSeverity` values, nullable `reference_table`/`reference_id`/`resolved_at`, numeric parsing, `AlertService` query parameter serialization (`is_resolved`, `alert_type`, `severity`, `page`, `limit`), and verifying `generateExpiryAlerts()` sends JSON `{}` (or `{'months_ahead': n}`).
  - `alert_provider_test.dart`: `ensureDashboardLoaded()` vs `ensureLoaded()` separation, filter transitions resetting page to `1`, monotonic `_requestSeq` race protection, `resolveAlert()` stepping back a page when resolving the final item on `page > 1`, `runExpiryCheck()` RBAC/stats propagation, and `reset()` clearing state on logout/session revocation.
- **Widget Tests:**
  - `alerts_screen_test.dart`: desktop (`1440x900`), tablet (`862x692`), and mobile (`390x844`) responsive rendering with zero overflow; Admin vs Pharmacist RBAC (`Run Expiry Check` hidden for Pharmacist, `Resolve` available to both); Status/Type/Severity filtering; Resolve confirmation dialog and post-resolve refresh; Run Expiry Check snackbar stats; error/retry & empty states; Dashboard live KPI/badge/`Recent Alerts` wiring.
  - Regression check: run existing `admin_dashboard_screen_test.dart`, `login_auth_flow_test.dart`, `medicines_screen_test.dart`, and unit suites (`flutter analyze` and `flutter test` in `medixmart_app/`).

---

## 6. What's Left to the Builder

- Exact Material icon selections (`Icons.notifications_none_rounded`, `Icons.check_circle_outline_rounded`, `Icons.fact_check_outlined`, `Icons.cake_outlined`, etc.) where no SVG exists in `AppAssets`.
- Exact widget `Key` identifiers (`Key('alerts_run_expiry_button')`, `Key('alerts_status_active')`, `Key('alerts_status_resolved')`, etc.) to keep widget tests readable and deterministic.
- Whether **Run Expiry Check** fires the backend's default 7-month scan immediately on tap or opens a brief confirmation dialog (with optional custom `months_ahead` override defaulting to `7`).
