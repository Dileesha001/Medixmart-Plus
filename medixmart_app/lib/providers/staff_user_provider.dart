import 'package:flutter/foundation.dart';
import '../models/api_exception.dart';
import '../models/staff_user_model.dart';
import '../services/staff_user_service.dart';

/// State provider for Admin staff user management (`GET/PATCH /api/users`).
class StaffUserProvider extends ChangeNotifier {
  final StaffUserService _service;

  List<StaffUserModel> _users = const [];
  String _searchQuery = '';
  StaffStatusFilter _statusFilter = StaffStatusFilter.all;
  bool _isLoading = false;
  bool _isRefreshing = false;
  bool _hasLoadedOnce = false;
  String? _errorMessage;
  ApiException? _actionError;
  final Set<int> _mutatingUserIds = <int>{};

  int _requestSeq = 0;
  int _resetEpoch = 0;

  StaffUserProvider({required StaffUserService service}) : _service = service;

  List<StaffUserModel> get users => _users;
  String get searchQuery => _searchQuery;
  StaffStatusFilter get statusFilter => _statusFilter;
  bool get isLoading => _isLoading;
  bool get isRefreshing => _isRefreshing;
  bool get hasLoadedOnce => _hasLoadedOnce;
  String? get errorMessage => _errorMessage;
  ApiException? get actionError => _actionError;

  int get totalCount => _users.length;
  int get adminCount => _users.where((u) => u.isAdmin).length;
  int get pharmacistCount => _users.where((u) => u.isPharmacist).length;
  int get activeCount => _users.where((u) => u.isActive).length;
  int get disabledCount => _users.where((u) => !u.isActive).length;

  bool isMutatingUser(int userId) => _mutatingUserIds.contains(userId);

  StaffUserModel? findUserById(int? userId) {
    if (userId == null) return null;
    for (final user in _users) {
      if (user.id == userId) return user;
    }
    return null;
  }

  List<StaffUserModel> get filteredUsers {
    final query = _searchQuery.trim().toLowerCase();
    return _users.where((user) {
      final matchesStatus = switch (_statusFilter) {
        StaffStatusFilter.all => true,
        StaffStatusFilter.active => user.isActive,
        StaffStatusFilter.disabled => !user.isActive,
      };
      if (!matchesStatus) return false;
      if (query.isEmpty) return true;
      return user.username.toLowerCase().contains(query) ||
          user.roleLabel.toLowerCase().contains(query) ||
          '${user.id}'.contains(query);
    }).toList(growable: false);
  }

  Future<void> ensureLoaded() async {
    if (_hasLoadedOnce || _isLoading) return;
    await _loadUsers(initial: true);
  }

  Future<void> refresh() async {
    await _loadUsers(initial: !_hasLoadedOnce);
  }

  Future<void> _loadUsers({required bool initial}) async {
    final seq = ++_requestSeq;
    final epoch = _resetEpoch;

    if (initial) {
      _isLoading = true;
    } else {
      _isRefreshing = true;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final fetched = await _service.fetchUsers();
      if (epoch != _resetEpoch || seq != _requestSeq) return;
      _users = List.unmodifiable(fetched);
      _hasLoadedOnce = true;
      _errorMessage = null;
    } on ApiException catch (e) {
      if (epoch != _resetEpoch || seq != _requestSeq) return;
      _errorMessage = e.message;
    } catch (_) {
      if (epoch != _resetEpoch || seq != _requestSeq) return;
      _errorMessage = 'Unable to load staff accounts. Please try again.';
    } finally {
      if (epoch == _resetEpoch && seq == _requestSeq) {
        _isLoading = false;
        _isRefreshing = false;
        notifyListeners();
      }
    }
  }

  void setSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void setStatusFilter(StaffStatusFilter filter) {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    notifyListeners();
  }

  void clearActionError() {
    if (_actionError == null) return;
    _actionError = null;
    notifyListeners();
  }

  Future<StaffUserUpdateResult?> updateUserStatus(
    int userId, {
    required bool isActive,
  }) async {
    if (_mutatingUserIds.contains(userId)) return null;
    final epoch = _resetEpoch;
    _mutatingUserIds.add(userId);
    _actionError = null;
    notifyListeners();

    try {
      final result = await _service.updateUserStatus(
        userId,
        isActive: isActive,
      );
      if (epoch != _resetEpoch) return null;
      _mergeUpdatedUser(result.user);
      return result;
    } on ApiException catch (e) {
      if (epoch == _resetEpoch) {
        _actionError = e;
      }
      rethrow;
    } finally {
      if (epoch == _resetEpoch) {
        _mutatingUserIds.remove(userId);
        notifyListeners();
      }
    }
  }

  Future<StaffUserUpdateResult?> updateUserRole(
    int userId, {
    required String role,
  }) async {
    if (_mutatingUserIds.contains(userId)) return null;
    final epoch = _resetEpoch;
    _mutatingUserIds.add(userId);
    _actionError = null;
    notifyListeners();

    try {
      final result = await _service.updateUserRole(
        userId,
        role: role,
      );
      if (epoch != _resetEpoch) return null;
      _mergeUpdatedUser(result.user);
      return result;
    } on ApiException catch (e) {
      if (epoch == _resetEpoch) {
        _actionError = e;
      }
      rethrow;
    } finally {
      if (epoch == _resetEpoch) {
        _mutatingUserIds.remove(userId);
        notifyListeners();
      }
    }
  }

  void _mergeUpdatedUser(StaffUserModel updated) {
    final next = <StaffUserModel>[];
    var replaced = false;
    for (final existing in _users) {
      if (existing.id == updated.id) {
        next.add(
          existing.copyWith(
            username: updated.username,
            role: updated.role,
            isActive: updated.isActive,
            tokenVersion: updated.tokenVersion,
            updatedAt: updated.updatedAt,
          ),
        );
        replaced = true;
      } else {
        next.add(existing);
      }
    }
    if (!replaced) {
      next.add(updated);
    }
    _users = List.unmodifiable(next);
  }

  void reset() {
    _resetEpoch++;
    _requestSeq++;
    _users = const [];
    _searchQuery = '';
    _statusFilter = StaffStatusFilter.all;
    _isLoading = false;
    _isRefreshing = false;
    _hasLoadedOnce = false;
    _errorMessage = null;
    _actionError = null;
    _mutatingUserIds.clear();
    notifyListeners();
  }
}
