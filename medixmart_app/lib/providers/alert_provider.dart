import 'package:flutter/foundation.dart';
import '../models/alert_model.dart';
import '../models/api_exception.dart';
import '../models/paginated_response.dart';
import '../services/alert_service.dart';

/// Shared state provider for the Alerts Center and live Dashboard alert widgets.
class AlertProvider extends ChangeNotifier {
  final AlertService _service;

  static const int defaultPageLimit = 20;
  static const int dashboardPreviewLimit = 3;

  // Separated Dashboard preview state so Alerts Center filters never overwrite
  // the Dashboard's active Recent Alerts feed.
  AlertSummary? _summary;
  List<AlertModel> _dashboardPreviewAlerts = const [];
  bool _isDashboardLoading = false;
  bool _hasLoadedDashboardPreview = false;

  // Alerts Center list state
  List<AlertModel> _alerts = const [];
  PaginationMeta _pagination =
      const PaginationMeta.empty(limit: defaultPageLimit);
  bool _showResolved = false;
  AlertType? _typeFilter;
  AlertSeverity? _severityFilter;
  int _currentPage = 1;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;

  // Mutation guards
  final Set<int> _resolvingIds = <int>{};
  bool _isRunningExpiryCheck = false;

  // Concurrency & lifecycle tracking
  int _requestSeq = 0;
  int _dashboardSeq = 0;
  int _resetEpoch = 0;
  bool _isDisposed = false;

  AlertProvider({required AlertService service}) : _service = service;

  AlertSummary? get summary => _summary;
  List<AlertModel> get dashboardPreviewAlerts => _dashboardPreviewAlerts;
  bool get isDashboardLoading => _isDashboardLoading;
  bool get hasLoadedDashboardPreview => _hasLoadedDashboardPreview;

  List<AlertModel> get alerts => _alerts;
  PaginationMeta get pagination => _pagination;
  bool get showResolved => _showResolved;
  AlertType? get typeFilter => _typeFilter;
  AlertSeverity? get severityFilter => _severityFilter;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get errorMessage => _errorMessage;
  bool get isRunningExpiryCheck => _isRunningExpiryCheck;

  bool isResolving(int id) => _resolvingIds.contains(id);

  bool get hasActiveFilters =>
      _showResolved || _typeFilter != null || _severityFilter != null;

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Loads summary counters and top 3 active alerts for the Dashboard once.
  Future<void> ensureDashboardLoaded() async {
    if (_hasLoadedDashboardPreview || _isDashboardLoading) return;
    await _loadDashboardPreview();
  }

  Future<void> _loadDashboardPreview() async {
    final epoch = _resetEpoch;
    final seq = ++_dashboardSeq;
    _isDashboardLoading = true;
    _safeNotify();

    try {
      final results = await Future.wait<dynamic>([
        _service.fetchSummary(),
        _service.fetchAlerts(
          isResolved: false,
          page: 1,
          limit: dashboardPreviewLimit,
        ),
      ]);

      if (epoch != _resetEpoch || seq != _dashboardSeq || _isDisposed) return;

      _summary = results[0] as AlertSummary;
      final previewPage = results[1] as PaginatedResponse<AlertModel>;
      _dashboardPreviewAlerts = List.unmodifiable(previewPage.items);
      _hasLoadedDashboardPreview = true;
    } catch (_) {
      // Keep Dashboard fallback intact if background preview loading fails.
    } finally {
      if (epoch == _resetEpoch && seq == _dashboardSeq && !_isDisposed) {
        _isDashboardLoading = false;
        _safeNotify();
      }
    }
  }

  /// Loads summary and page 1 alerts on initial Alerts Center mount.
  Future<void> ensureLoaded() async {
    if (_hasLoadedOnce || _isLoading) return;
    await Future.wait([
      _loadDashboardPreview(),
      _fetchAlerts(page: 1),
    ]);
  }

  /// Reloads summary, Dashboard preview, and the current Alerts Center page.
  Future<void> refresh() async {
    await Future.wait([
      _loadDashboardPreview(),
      _fetchAlerts(page: _currentPage),
    ]);
  }

  Future<void> setShowResolved(bool value) async {
    if (_showResolved == value) return;
    _showResolved = value;
    _currentPage = 1;
    await _fetchAlerts(page: 1);
  }

  Future<void> setTypeFilter(AlertType? type) async {
    if (_typeFilter == type) return;
    _typeFilter = type;
    _currentPage = 1;
    await _fetchAlerts(page: 1);
  }

  Future<void> setSeverityFilter(AlertSeverity? severity) async {
    if (_severityFilter == severity) return;
    _severityFilter = severity;
    _currentPage = 1;
    await _fetchAlerts(page: 1);
  }

  Future<void> clearFilters() async {
    _showResolved = false;
    _typeFilter = null;
    _severityFilter = null;
    _currentPage = 1;
    await _fetchAlerts(page: 1);
  }

  /// Applies target filters and reloads summary + filtered page (e.g. KPI jump).
  Future<void> applyQuickFilter({
    AlertType? type,
    AlertSeverity? severity,
    bool showResolved = false,
  }) async {
    _showResolved = showResolved;
    _typeFilter = type;
    _severityFilter = severity;
    _currentPage = 1;
    await Future.wait([
      _loadDashboardPreview(),
      _fetchAlerts(page: 1),
    ]);
  }

  Future<void> goToPage(int page) async {
    final target = page.clamp(1, _pagination.totalPages);
    if (target == _currentPage && _hasLoadedOnce) return;
    _currentPage = target;
    await _fetchAlerts(page: target);
  }

  Future<void> _fetchAlerts({
    required int page,
    bool allowClampRetry = true,
  }) async {
    final epoch = _resetEpoch;
    final seq = ++_requestSeq;
    final showFullLoader =
        !_hasLoadedOnce || (_alerts.isEmpty && _errorMessage != null);

    if (showFullLoader) {
      _isLoading = true;
    } else {
      _isRefreshing = true;
    }
    _errorMessage = null;
    _safeNotify();

    try {
      final response = await _service.fetchAlerts(
        isResolved: _showResolved,
        alertType: _typeFilter,
        severity: _severityFilter,
        page: page,
        limit: defaultPageLimit,
      );

      if (epoch != _resetEpoch || seq != _requestSeq || _isDisposed) return;

      if (allowClampRetry &&
          response.items.isEmpty &&
          response.pagination.totalRecords > 0 &&
          response.pagination.page > response.pagination.totalPages) {
        final clampedPage = response.pagination.totalPages;
        _currentPage = clampedPage;
        await _fetchAlerts(page: clampedPage, allowClampRetry: false);
        return;
      }

      _alerts = List.unmodifiable(response.items);
      _pagination = response.pagination;
      _currentPage = response.pagination.page;
      _hasLoadedOnce = true;
      _errorMessage = null;
    } on ApiException catch (e) {
      if (epoch != _resetEpoch || seq != _requestSeq || _isDisposed) return;
      _errorMessage = e.message;
    } catch (_) {
      if (epoch != _resetEpoch || seq != _requestSeq || _isDisposed) return;
      _errorMessage =
          'Unable to load alerts. Please verify server connection and retry.';
    } finally {
      if (epoch == _resetEpoch && seq == _requestSeq && !_isDisposed) {
        _isLoading = false;
        _isRefreshing = false;
        _safeNotify();
      }
    }
  }

  /// Resolves an active alert and refreshes counts + list.
  Future<void> resolveAlert(int id) async {
    if (_resolvingIds.contains(id)) {
      throw const ApiException(
        code: 'MUTATION_IN_PROGRESS',
        message: 'Alert resolution is already in progress.',
        statusCode: 409,
      );
    }

    final epoch = _resetEpoch;
    _resolvingIds.add(id);
    _safeNotify();

    try {
      await _service.resolveAlert(id);
      if (epoch != _resetEpoch || _isDisposed) return;

      final shouldStepBack =
          !_showResolved && _alerts.length == 1 && _currentPage > 1;
      final targetPage = shouldStepBack ? _currentPage - 1 : _currentPage;
      _currentPage = targetPage;

      await Future.wait([
        _loadDashboardPreview(),
        _fetchAlerts(page: targetPage),
      ]);
    } finally {
      if (epoch == _resetEpoch) {
        _resolvingIds.remove(id);
        _safeNotify();
      }
    }
  }

  /// Triggers the Admin-only expiry check engine and refreshes alert state.
  Future<ExpiryCheckResult> runExpiryCheck({int? monthsAhead}) async {
    if (_isRunningExpiryCheck) {
      throw const ApiException(
        code: 'MUTATION_IN_PROGRESS',
        message: 'An expiry check run is already in progress.',
        statusCode: 409,
      );
    }

    final epoch = _resetEpoch;
    _isRunningExpiryCheck = true;
    _safeNotify();

    try {
      final result = await _service.runExpiryCheck(monthsAhead: monthsAhead);
      if (epoch == _resetEpoch && !_isDisposed) {
        await Future.wait([
          _loadDashboardPreview(),
          _fetchAlerts(page: _currentPage),
        ]);
      }
      return result;
    } finally {
      if (epoch == _resetEpoch) {
        _isRunningExpiryCheck = false;
        _safeNotify();
      }
    }
  }

  /// Clears all cached summary, preview, alerts, filters, and pending work.
  void reset() {
    _requestSeq++;
    _dashboardSeq++;
    _resetEpoch++;

    final hadState = _summary != null ||
        _dashboardPreviewAlerts.isNotEmpty ||
        _isDashboardLoading ||
        _hasLoadedDashboardPreview ||
        _alerts.isNotEmpty ||
        _showResolved ||
        _typeFilter != null ||
        _severityFilter != null ||
        _currentPage != 1 ||
        _isLoading ||
        _isRefreshing ||
        _hasLoadedOnce ||
        _errorMessage != null ||
        _resolvingIds.isNotEmpty ||
        _isRunningExpiryCheck;

    _summary = null;
    _dashboardPreviewAlerts = const [];
    _isDashboardLoading = false;
    _hasLoadedDashboardPreview = false;

    _alerts = const [];
    _pagination = const PaginationMeta.empty(limit: defaultPageLimit);
    _showResolved = false;
    _typeFilter = null;
    _severityFilter = null;
    _currentPage = 1;
    _isLoading = false;
    _isRefreshing = false;
    _hasLoadedOnce = false;
    _errorMessage = null;

    _resolvingIds.clear();
    _isRunningExpiryCheck = false;

    if (hadState) {
      _safeNotify();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
