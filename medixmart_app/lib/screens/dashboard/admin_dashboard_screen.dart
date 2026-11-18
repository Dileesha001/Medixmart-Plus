import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_assets.dart';
import '../../config/app_theme.dart';
import '../../models/dashboard_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../widgets/alert_feed_item.dart';
import '../../widgets/brand_emblem.dart';
import '../../widgets/daily_sales_bar.dart';
import '../../widgets/data_table_row.dart';
import '../../widgets/kpi_summary_card.dart';
import '../../widgets/mm_button.dart';
import '../../widgets/pos_search_bar.dart';
import '../../widgets/sidebar_nav_item.dart';

/// Medixmart Plus Admin Dashboard screen (`46:355`).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showWorkflowFeedback(BuildContext context, String actionLabel) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            actionLabel,
            style: MmTypography.bodyMedium.copyWith(
              color: MmColors.textOnBrand,
            ),
          ),
          backgroundColor: MmColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MmColors.bgCanvas,
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardSidebar(
            onNavTap: (item) {
              context.read<DashboardProvider>().selectNavItem(item.id);
            },
          ),
          Expanded(
            child: _DashboardMainArea(
              searchController: _searchController,
              onNewSale: () => _showWorkflowFeedback(
                context,
                'Opening POS Checkout for New Sale...',
              ),
              onViewAllAlerts: () {
                context.read<DashboardProvider>().selectNavItem('alerts');
                _showWorkflowFeedback(
                  context,
                  'Viewing all 20 active stock & expiry alerts.',
                );
              },
              onReceiveBatch: () {
                context
                    .read<DashboardProvider>()
                    .selectNavItem('receive_batches');
                _showWorkflowFeedback(
                  context,
                  'Opening Receive Batch workflow...',
                );
              },
              onAddMedicine: () {
                context.read<DashboardProvider>().selectNavItem('medicines');
                _showWorkflowFeedback(
                  context,
                  'Opening Add Medicine catalog form...',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Left sidebar (`46:356`): Brand header, 7 navigation items, and Admin User footer.
class _DashboardSidebar extends StatelessWidget {
  final ValueChanged<SidebarNavItemData> onNavTap;

  const _DashboardSidebar({
    required this.onNavTap,
  });

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();
    final authUser = context.watch<AuthProvider?>()?.user;

    final userInitials =
        authUser?.initials ?? AdminDashboardDefaults.adminInitials;
    final userName = authUser?.displayName ?? AdminDashboardDefaults.adminName;
    final userRole = authUser?.roleLabel ?? AdminDashboardDefaults.adminRole;

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.lg,
        vertical: MmSpacing.xl,
      ),
      decoration: const BoxDecoration(
        color: MmColors.bgSurface,
        border: Border(
          right: BorderSide(
            color: MmColors.borderDefault,
            width: MmElevation.strokeThin,
          ),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Brand & Navigation (`46:357`)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Brand (`46:358`)
              Padding(
                padding: const EdgeInsets.only(
                  top: MmSpacing.xs,
                  bottom: MmSpacing.sm,
                  left: MmSpacing.xs,
                  right: MmSpacing.xs,
                ),
                child: Row(
                  children: [
                    const BrandEmblem(size: 36),
                    const SizedBox(width: MmSpacing.md),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Medixmart Plus',
                          style: MmTypography.headingH4,
                        ),
                        const SizedBox(height: MmSpacing.xxs),
                        Text(
                          'ADMIN',
                          style: MmTypography.labelSmall.copyWith(
                            color: MmColors.textBrand,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MmSpacing.xl),
              // Navigation List (`46:363`)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0;
                      i < dashboardProvider.navItems.length;
                      i++) ...[
                    if (i > 0) const SizedBox(height: MmSpacing.xs),
                    SidebarNavItem(
                      label: dashboardProvider.navItems[i].label,
                      iconAsset: dashboardProvider.navItems[i].iconAsset,
                      badgeCount: dashboardProvider.navItems[i].badgeCount,
                      isActive: dashboardProvider.selectedNavId ==
                          dashboardProvider.navItems[i].id,
                      onTap: () => onNavTap(dashboardProvider.navItems[i]),
                    ),
                  ],
                ],
              ),
            ],
          ),

          // Admin User (`46:424`)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(
              top: MmSpacing.md,
              left: MmSpacing.xs,
              right: MmSpacing.xs,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: MmColors.borderDefault,
                  width: MmElevation.strokeThin,
                ),
              ),
            ),
            child: Row(
              children: [
                // Avatar (`46:425`)
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: MmColors.bgBrandSubtle,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: MmColors.borderBrand,
                      width: MmElevation.strokeThin,
                    ),
                  ),
                  child: Text(
                    userInitials,
                    style: MmTypography.labelSmall.copyWith(
                      color: MmColors.textBrand,
                    ),
                  ),
                ),
                const SizedBox(width: MmSpacing.sm),
                // User Details (`46:427`)
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userName,
                        style: MmTypography.labelMedium.copyWith(
                          color: MmColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MmSpacing.xxs),
                      Text(
                        userRole,
                        style: MmTypography.bodySmall.copyWith(
                          color: MmColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Main content area (`46:430`): Top Header and scrollable Dashboard Body.
class _DashboardMainArea extends StatelessWidget {
  final TextEditingController searchController;
  final VoidCallback onNewSale;
  final VoidCallback onViewAllAlerts;
  final VoidCallback onReceiveBatch;
  final VoidCallback onAddMedicine;

  const _DashboardMainArea({
    required this.searchController,
    required this.onNewSale,
    required this.onViewAllAlerts,
    required this.onReceiveBatch,
    required this.onAddMedicine,
  });

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Header (`46:431`)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: MmSpacing.xxxl,
            vertical: MmSpacing.lg,
          ),
          decoration: const BoxDecoration(
            color: MmColors.bgSurface,
            border: Border(
              bottom: BorderSide(
                color: MmColors.borderDefault,
                width: MmElevation.strokeThin,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title Group (`46:432`)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AdminDashboardDefaults.headerTitle,
                    style: MmTypography.headingH2,
                  ),
                  const SizedBox(width: MmSpacing.md),
                  Text(
                    AdminDashboardDefaults.headerDate,
                    style: MmTypography.bodySmall.copyWith(
                      color: MmColors.textMuted,
                    ),
                  ),
                ],
              ),
              // Header Controls (`46:435`)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PosSearchBar(
                    width: 320,
                    placeholder: AdminDashboardDefaults.searchPlaceholder,
                    controller: searchController,
                    onChanged: dashboardProvider.updateSearchQuery,
                  ),
                  const SizedBox(width: MmSpacing.md),
                  MmButton(
                    label: 'New Sale',
                    leadingIconAsset: AppAssets.iconPlusMd,
                    variant: MmButtonVariant.primary,
                    size: MmButtonSize.medium,
                    onPressed: onNewSale,
                  ),
                ],
              ),
            ],
          ),
        ),

        // Dashboard Body (`46:447`)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: MmSpacing.xxxl,
              vertical: MmSpacing.xxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // KPI Row (`46:448`)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0;
                        i < dashboardProvider.kpiCards.length;
                        i++) ...[
                      if (i > 0) const SizedBox(width: MmSpacing.lg),
                      Expanded(
                        child: KpiSummaryCard.fromData(
                          dashboardProvider.kpiCards[i],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: MmSpacing.xl),

                // Analytics & Alerts Row (`46:486`)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Last 7 Days Sales Card (`46:487`)
                      Expanded(
                        child: _Last7DaysSalesCard(
                          totalLabel: AdminDashboardDefaults.last7DaysTotal,
                          bars: dashboardProvider.dailySalesBars,
                        ),
                      ),
                      const SizedBox(width: MmSpacing.lg),
                      // Recent Alerts Card (`46:527`)
                      SizedBox(
                        width: 400,
                        child: _RecentAlertsCard(
                          actionLabel:
                              AdminDashboardDefaults.recentAlertsActionLabel,
                          alerts: dashboardProvider.recentAlerts,
                          onViewAll: onViewAllAlerts,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: MmSpacing.xl),

                // Inventory Watchlist Card (`46:580`)
                _InventoryWatchlistCard(
                  items: dashboardProvider.filteredWatchlistItems,
                  onReceiveBatch: onReceiveBatch,
                  onAddMedicine: onAddMedicine,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Last 7 Days Sales chart card (`46:487`).
class _Last7DaysSalesCard extends StatelessWidget {
  final String totalLabel;
  final List<DailySalesBarData> bars;

  const _Last7DaysSalesCard({
    required this.totalLabel,
    required this.bars,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MmSpacing.xl),
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header (`46:488`)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last 7 Days Sales',
                style: MmTypography.headingH3,
              ),
              Text(
                totalLabel,
                style: MmTypography.codeMono.copyWith(
                  color: MmColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.lg),
          // 7-Day Bars (`46:491`)
          Padding(
            padding: const EdgeInsets.only(
              top: MmSpacing.xs,
              left: MmSpacing.sm,
              right: MmSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final bar in bars) DailySalesBar.fromData(bar),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent Alerts card (`46:527`).
class _RecentAlertsCard extends StatelessWidget {
  final String actionLabel;
  final List<AlertItemData> alerts;
  final VoidCallback onViewAll;

  const _RecentAlertsCard({
    required this.actionLabel,
    required this.alerts,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(MmSpacing.xl),
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (`46:528`)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Alerts',
                style: MmTypography.headingH3,
              ),
              InkWell(
                onTap: onViewAll,
                borderRadius: BorderRadius.circular(MmRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MmSpacing.xxs,
                    vertical: MmSpacing.xxs,
                  ),
                  child: Text(
                    actionLabel,
                    style: MmTypography.labelMedium.copyWith(
                      color: MmColors.textBrand,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.md),
          // Alerts List (`46:531`)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < alerts.length; i++) ...[
                if (i > 0) const SizedBox(height: MmSpacing.sm),
                AlertFeedItem.fromData(alerts[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Inventory Watchlist table card (`46:580`).
class _InventoryWatchlistCard extends StatelessWidget {
  final List<InventoryWatchlistItemData> items;
  final VoidCallback onReceiveBatch;
  final VoidCallback onAddMedicine;

  const _InventoryWatchlistCard({
    required this.items,
    required this.onReceiveBatch,
    required this.onAddMedicine,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MmSpacing.xl),
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Table Header (`46:581`)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Inventory Watchlist',
                style: MmTypography.headingH3,
              ),
              // Table Actions (`46:583`)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MmButton(
                    label: 'Receive Batch',
                    leadingIconAsset: AppAssets.iconReceiveBatchSm,
                    variant: MmButtonVariant.secondary,
                    size: MmButtonSize.small,
                    onPressed: onReceiveBatch,
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  MmButton(
                    label: 'Add Medicine',
                    leadingIconAsset: AppAssets.iconPlusSm,
                    variant: MmButtonVariant.primary,
                    size: MmButtonSize.small,
                    onPressed: onAddMedicine,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.md),
          // Table Rows (`46:595`)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(
                color: MmColors.borderDefault,
                width: MmElevation.strokeThin,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const DataTableHeaderRow(),
                for (final item in items) InventoryWatchlistRow(item: item),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
