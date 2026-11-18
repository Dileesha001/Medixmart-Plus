import 'package:flutter/foundation.dart';
import '../models/dashboard_models.dart';

/// State provider for the Admin Dashboard (`46:355`).
class DashboardProvider extends ChangeNotifier {
  String _selectedNavId = 'dashboard';
  String _searchQuery = '';

  final List<SidebarNavItemData> _navItems =
      List.unmodifiable(AdminDashboardDefaults.navItems);
  final List<KpiCardData> _kpiCards =
      List.unmodifiable(AdminDashboardDefaults.kpiCards);
  final List<DailySalesBarData> _dailySalesBars =
      List.unmodifiable(AdminDashboardDefaults.dailySalesBars);
  final List<AlertItemData> _recentAlerts =
      List.unmodifiable(AdminDashboardDefaults.recentAlerts);
  final List<InventoryWatchlistItemData> _watchlistItems = List.from(
    AdminDashboardDefaults.watchlistItems,
  );

  String get selectedNavId => _selectedNavId;
  String get searchQuery => _searchQuery;

  List<SidebarNavItemData> get navItems => _navItems;
  List<KpiCardData> get kpiCards => _kpiCards;
  List<DailySalesBarData> get dailySalesBars => _dailySalesBars;
  List<AlertItemData> get recentAlerts => _recentAlerts;

  List<InventoryWatchlistItemData> get filteredWatchlistItems {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return List.unmodifiable(_watchlistItems);
    }
    return _watchlistItems.where((item) {
      return item.medicineName.toLowerCase().contains(query) ||
          item.category.toLowerCase().contains(query) ||
          item.earliestBatchFefo.toLowerCase().contains(query) ||
          item.statusLabel.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  void selectNavItem(String navId) {
    if (_selectedNavId == navId) return;
    _selectedNavId = navId;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void addWatchlistMedicine(InventoryWatchlistItemData newItem) {
    _watchlistItems.add(newItem);
    notifyListeners();
  }
}
