import 'package:flutter/material.dart';
import '../config/app_assets.dart';
import '../config/app_theme.dart';

/// Semantic tones for [StatusBadge] and [AlertFeedItem].
enum StatusTone {
  inStock('In Stock'),
  lowStock('Low Stock'),
  expiring7M('Expiring 7M'),
  expired('Expired');

  final String defaultLabel;
  const StatusTone(this.defaultLabel);
}

/// KPI metric variants for [KpiSummaryCard].
enum KpiMetricType {
  todaySales('Today Sales'),
  lowStock('Low Stock'),
  expiring7M('Expiring 7M'),
  creditDue('Credit Due');

  final String figmaName;
  const KpiMetricType(this.figmaName);
}

/// Data model for a sidebar navigation item (`10:48`).
class SidebarNavItemData {
  final String id;
  final String label;
  final String iconAsset;
  final int? badgeCount;

  const SidebarNavItemData({
    required this.id,
    required this.label,
    required this.iconAsset,
    this.badgeCount,
  });
}

/// Data model for a KPI summary card (`9:43`).
class KpiCardData {
  final KpiMetricType metric;
  final String title;
  final String value;
  final String subtitle;

  const KpiCardData({
    required this.metric,
    required this.title,
    required this.value,
    required this.subtitle,
  });
}

/// Data model for a 7-day daily sales bar column (`44:80`).
class DailySalesBarData {
  final String dayLabel;
  final String formattedAmount;
  final double fillHeight;

  const DailySalesBarData({
    required this.dayLabel,
    required this.formattedAmount,
    required this.fillHeight,
  });
}

/// Data model for an alert feed item (`44:121`).
class AlertItemData {
  final String title;
  final String meta;
  final StatusTone tone;
  final String? badgeLabel;

  const AlertItemData({
    required this.title,
    required this.meta,
    required this.tone,
    this.badgeLabel,
  });
}

/// Row background variant for [InventoryWatchlistRow] (`10:107`).
enum WatchlistRowSurface {
  dangerSubtle(MmColors.bgDangerSubtle),
  surface(MmColors.bgSurface),
  brandSubtle(MmColors.bgBrandSubtle);

  final Color backgroundColor;
  const WatchlistRowSurface(this.backgroundColor);
}

/// Data model for an Inventory Watchlist table row (`10:107`).
class InventoryWatchlistItemData {
  final String medicineName;
  final String category;
  final String earliestBatchFefo;
  final String totalStock;
  final String unitPrice;
  final StatusTone statusTone;
  final String statusLabel;
  final WatchlistRowSurface rowSurface;

  const InventoryWatchlistItemData({
    required this.medicineName,
    required this.category,
    required this.earliestBatchFefo,
    required this.totalStock,
    required this.unitPrice,
    required this.statusTone,
    required this.statusLabel,
    required this.rowSurface,
  });
}

/// Default reference dataset matching Figma node `46:355` ("Admin Dashboard").
abstract final class AdminDashboardDefaults {
  static const String headerTitle = 'Dashboard';
  static const String headerDate = 'Wed, 18 Nov 2026';
  static const String searchPlaceholder = 'Search medicines or batches...';
  static const String last7DaysTotal = 'Rs. 284,600.00 total';
  static const String recentAlertsActionLabel = 'View all (20)';

  static const String adminInitials = 'DR';
  static const String adminName = 'Ravindu Bandara';
  static const String adminRole = 'Administrator';

  static const List<SidebarNavItemData> navItems = [
    SidebarNavItemData(
      id: 'dashboard',
      label: 'Dashboard',
      iconAsset: AppAssets.navDashboard,
    ),
    SidebarNavItemData(
      id: 'checkout',
      label: 'Checkout',
      iconAsset: AppAssets.navCheckout,
    ),
    SidebarNavItemData(
      id: 'medicines',
      label: 'Medicines',
      iconAsset: AppAssets.navMedicines,
    ),
    SidebarNavItemData(
      id: 'receive_batches',
      label: 'Receive Batches',
      iconAsset: AppAssets.navReceiveBatches,
    ),
    SidebarNavItemData(
      id: 'alerts',
      label: 'Alerts',
      iconAsset: AppAssets.navAlerts,
      badgeCount: 12,
    ),
    SidebarNavItemData(
      id: 'customers',
      label: 'Customers',
      iconAsset: AppAssets.navCustomers,
    ),
    SidebarNavItemData(
      id: 'reports',
      label: 'Reports',
      iconAsset: AppAssets.navReports,
    ),
  ];

  static const List<KpiCardData> kpiCards = [
    KpiCardData(
      metric: KpiMetricType.todaySales,
      title: "Today's Sales",
      value: 'Rs. 48,750.00',
      subtitle: '34 bills completed today',
    ),
    KpiCardData(
      metric: KpiMetricType.lowStock,
      title: 'Low Stock',
      value: '08 Items',
      subtitle: 'At or below reorder level',
    ),
    KpiCardData(
      metric: KpiMetricType.expiring7M,
      title: 'Expiring ≤ 7 Months',
      value: '12 Batches',
      subtitle: 'Eligible for supplier return',
    ),
    KpiCardData(
      metric: KpiMetricType.creditDue,
      title: 'Outstanding Credit',
      value: 'Rs. 19,400.00',
      subtitle: '6 active customer accounts',
    ),
  ];

  static const List<DailySalesBarData> dailySalesBars = [
    DailySalesBarData(
      dayLabel: 'Thu',
      formattedAmount: '34.2k',
      fillHeight: 64,
    ),
    DailySalesBarData(
      dayLabel: 'Fri',
      formattedAmount: '41.8k',
      fillHeight: 82,
    ),
    DailySalesBarData(
      dayLabel: 'Sat',
      formattedAmount: '52.4k',
      fillHeight: 112,
    ),
    DailySalesBarData(
      dayLabel: 'Sun',
      formattedAmount: '38.9k',
      fillHeight: 74,
    ),
    DailySalesBarData(
      dayLabel: 'Mon',
      formattedAmount: '29.6k',
      fillHeight: 52,
    ),
    DailySalesBarData(
      dayLabel: 'Tue',
      formattedAmount: '38.9k',
      fillHeight: 76,
    ),
    DailySalesBarData(
      dayLabel: 'Today',
      formattedAmount: '48.8k',
      fillHeight: 100,
    ),
  ];

  static const List<AlertItemData> recentAlerts = [
    AlertItemData(
      title: 'Amoxicillin 250mg Cap',
      meta: '04 Packs left · Reorder at 15',
      tone: StatusTone.lowStock,
      badgeLabel: 'Low Stock',
    ),
    AlertItemData(
      title: 'Losartan Potassium 50mg',
      meta: 'Batch #B-061 · Exp 2027-04',
      tone: StatusTone.expiring7M,
      badgeLabel: 'Expiring 7M',
    ),
    AlertItemData(
      title: 'Cetirizine 10mg Tab',
      meta: 'Batch #B-014 · Exp 2026-09',
      tone: StatusTone.expired,
      badgeLabel: 'Expired',
    ),
  ];

  static const List<InventoryWatchlistItemData> watchlistItems = [
    InventoryWatchlistItemData(
      medicineName: 'Amoxicillin 250mg Cap',
      category: 'Antibiotics',
      earliestBatchFefo: 'B-2026-088 · 2027-03',
      totalStock: '04 Packs',
      unitPrice: 'Rs. 450.00',
      statusTone: StatusTone.lowStock,
      statusLabel: 'Low Stock',
      rowSurface: WatchlistRowSurface.dangerSubtle,
    ),
    InventoryWatchlistItemData(
      medicineName: 'Paracetamol BP 500mg',
      category: 'Analgesics',
      earliestBatchFefo: 'B-2026-102 · 2027-08',
      totalStock: '140 Packs',
      unitPrice: 'Rs. 120.00',
      statusTone: StatusTone.inStock,
      statusLabel: 'In Stock',
      rowSurface: WatchlistRowSurface.surface,
    ),
    InventoryWatchlistItemData(
      medicineName: 'Metformin HCl 500mg',
      category: 'Antidiabetic',
      earliestBatchFefo: 'B-2026-119 · 2027-11',
      totalStock: '85 Packs',
      unitPrice: 'Rs. 210.00',
      statusTone: StatusTone.inStock,
      statusLabel: 'In Stock',
      rowSurface: WatchlistRowSurface.brandSubtle,
    ),
  ];
}
