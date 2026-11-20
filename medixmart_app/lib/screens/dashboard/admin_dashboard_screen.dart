import 'dart:math' as math;
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

/// Responsive width breakpoints for the Medixmart Plus Admin Dashboard.
abstract final class _DashboardBreakpoints {
  static const double desktopSidebar = 1024.0;
  static const double kpiFourCol = 1000.0;
  static const double kpiTwoCol = 560.0;
  static const double analyticsSplit = 960.0;
  static const double headerSingleRow = 760.0;
  static const double compactPadding = 760.0;
  static const double tableMinWidth = 960.0;
}

/// Medixmart Plus Admin Dashboard screen (`46:355`).
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
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

  void _handleNavTap(SidebarNavItemData item, {required bool closeDrawer}) {
    context.read<DashboardProvider>().selectNavItem(item.id);
    if (closeDrawer) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final showPermanentSidebar =
            constraints.maxWidth >= _DashboardBreakpoints.desktopSidebar;

        final mainArea = _DashboardMainArea(
          searchController: _searchController,
          showMenuButton: !showPermanentSidebar,
          onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
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
            context.read<DashboardProvider>().selectNavItem('receive_batches');
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
        );

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: MmColors.bgCanvas,
          drawer: showPermanentSidebar
              ? null
              : Drawer(
                  width: 260,
                  backgroundColor: MmColors.bgSurface,
                  shape: const RoundedRectangleBorder(),
                  child: SafeArea(
                    child: _DashboardSidebar(
                      onNavTap: (item) =>
                          _handleNavTap(item, closeDrawer: true),
                    ),
                  ),
                ),
          body: SafeArea(
            child: showPermanentSidebar
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _DashboardSidebar(
                        onNavTap: (item) =>
                            _handleNavTap(item, closeDrawer: false),
                      ),
                      Expanded(child: mainArea),
                    ],
                  )
                : mainArea,
          ),
        );
      },
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
    final workspaceBadge =
        authUser?.isPharmacist == true ? 'PHARMACIST' : 'ADMIN';

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
        crossAxisAlignment: CrossAxisAlignment.start,
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Medixmart Plus',
                        style: MmTypography.headingH4,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: MmSpacing.xxs),
                      Text(
                        workspaceBadge,
                        style: MmTypography.labelSmall.copyWith(
                          color: MmColors.textBrand,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MmSpacing.xl),

          // Scrollable Navigation List (`46:363`)
          Expanded(
            child: SingleChildScrollView(
              child: Column(
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
            ),
          ),
          const SizedBox(height: MmSpacing.md),

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
                Expanded(
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
                const SizedBox(width: MmSpacing.xs),
                IconButton(
                  key: const Key('sidebar_logout_button'),
                  tooltip: 'Sign out',
                  onPressed: () {
                    context.read<AuthProvider?>()?.logout();
                  },
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: MmColors.textSecondary,
                  ),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(32, 32),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
  final bool showMenuButton;
  final VoidCallback onOpenDrawer;
  final VoidCallback onNewSale;
  final VoidCallback onViewAllAlerts;
  final VoidCallback onReceiveBatch;
  final VoidCallback onAddMedicine;

  const _DashboardMainArea({
    required this.searchController,
    required this.showMenuButton,
    required this.onOpenDrawer,
    required this.onNewSale,
    required this.onViewAllAlerts,
    required this.onReceiveBatch,
    required this.onAddMedicine,
  });

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaWidth = constraints.maxWidth;
        final isCompact = areaWidth < _DashboardBreakpoints.compactPadding;
        final horizontalPadding = isCompact ? MmSpacing.lg : MmSpacing.xxxl;
        final bodyContentWidth =
            math.max(0.0, areaWidth - (horizontalPadding * 2));
        final singleRowHeader =
            areaWidth >= _DashboardBreakpoints.headerSingleRow;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header (`46:431`)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
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
              child: singleRowHeader
                  ? _buildSingleRowHeader(dashboardProvider)
                  : _buildStackedHeader(dashboardProvider, areaWidth),
            ),

            // Dashboard Body (`46:447`)
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isCompact ? MmSpacing.lg : MmSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // KPI Grid (`46:448`)
                    _KpiSummaryGrid(
                      cards: dashboardProvider.kpiCards,
                      availableWidth: bodyContentWidth,
                    ),
                    const SizedBox(height: MmSpacing.xl),

                    // Analytics & Alerts Section (`46:486`)
                    if (bodyContentWidth >=
                        _DashboardBreakpoints.analyticsSplit)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _Last7DaysSalesCard(
                              totalLabel: AdminDashboardDefaults.last7DaysTotal,
                              bars: dashboardProvider.dailySalesBars,
                              minHeight: 332,
                            ),
                          ),
                          const SizedBox(width: MmSpacing.lg),
                          SizedBox(
                            width: 400,
                            child: _RecentAlertsCard(
                              actionLabel: AdminDashboardDefaults
                                  .recentAlertsActionLabel,
                              alerts: dashboardProvider.recentAlerts,
                              onViewAll: onViewAllAlerts,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _Last7DaysSalesCard(
                        totalLabel: AdminDashboardDefaults.last7DaysTotal,
                        bars: dashboardProvider.dailySalesBars,
                      ),
                      const SizedBox(height: MmSpacing.xl),
                      _RecentAlertsCard(
                        actionLabel:
                            AdminDashboardDefaults.recentAlertsActionLabel,
                        alerts: dashboardProvider.recentAlerts,
                        onViewAll: onViewAllAlerts,
                      ),
                    ],
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
      },
    );
  }

  Widget _buildMenuIconButton() {
    return Padding(
      padding: const EdgeInsets.only(right: MmSpacing.sm),
      child: IconButton(
        key: const Key('dashboard_menu_button'),
        tooltip: 'Open navigation menu',
        onPressed: onOpenDrawer,
        icon: const Icon(
          Icons.menu_rounded,
          size: 22,
          color: MmColors.iconPrimary,
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  Widget _buildSingleRowHeader(DashboardProvider dashboardProvider) {
    return Row(
      children: [
        if (showMenuButton) _buildMenuIconButton(),
        // Title Group (`46:432`)
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  AdminDashboardDefaults.headerTitle,
                  style: MmTypography.headingH2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MmSpacing.md),
              Flexible(
                child: Text(
                  AdminDashboardDefaults.headerDate,
                  style: MmTypography.bodySmall.copyWith(
                    color: MmColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: MmSpacing.lg),
        // Header Controls (`46:435`)
        Flexible(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: PosSearchBar(
                    width: null,
                    placeholder: AdminDashboardDefaults.searchPlaceholder,
                    controller: searchController,
                    onChanged: dashboardProvider.updateSearchQuery,
                  ),
                ),
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
        ),
      ],
    );
  }

  Widget _buildStackedHeader(
    DashboardProvider dashboardProvider,
    double areaWidth,
  ) {
    final showDateInline = areaWidth >= 480;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (showMenuButton) _buildMenuIconButton(),
            Expanded(
              child: showDateInline
                  ? Row(
                      children: [
                        Flexible(
                          child: Text(
                            AdminDashboardDefaults.headerTitle,
                            style: MmTypography.headingH2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: MmSpacing.md),
                        Flexible(
                          child: Text(
                            AdminDashboardDefaults.headerDate,
                            style: MmTypography.bodySmall.copyWith(
                              color: MmColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          AdminDashboardDefaults.headerTitle,
                          style: MmTypography.headingH3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          AdminDashboardDefaults.headerDate,
                          style: MmTypography.bodySmall.copyWith(
                            color: MmColors.textMuted,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
        const SizedBox(height: MmSpacing.md),
        PosSearchBar(
          width: null,
          placeholder: AdminDashboardDefaults.searchPlaceholder,
          controller: searchController,
          onChanged: dashboardProvider.updateSearchQuery,
        ),
      ],
    );
  }
}

/// Adaptive KPI grid: 4 columns on desktop, 2x2 on tablet, 1 column on mobile.
class _KpiSummaryGrid extends StatelessWidget {
  final List<KpiCardData> cards;
  final double availableWidth;

  const _KpiSummaryGrid({
    required this.cards,
    required this.availableWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (availableWidth >= _DashboardBreakpoints.kpiFourCol) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: MmSpacing.lg),
            Expanded(child: KpiSummaryCard.fromData(cards[i])),
          ],
        ],
      );
    }

    if (availableWidth >= _DashboardBreakpoints.kpiTwoCol) {
      final rows = <Widget>[];
      for (var i = 0; i < cards.length; i += 2) {
        if (i > 0) rows.add(const SizedBox(height: MmSpacing.lg));
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: KpiSummaryCard.fromData(cards[i])),
              const SizedBox(width: MmSpacing.lg),
              Expanded(
                child: i + 1 < cards.length
                    ? KpiSummaryCard.fromData(cards[i + 1])
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: MmSpacing.md),
          KpiSummaryCard.fromData(cards[i]),
        ],
      ],
    );
  }
}

/// Last 7 Days Sales chart card (`46:487`).
class _Last7DaysSalesCard extends StatelessWidget {
  final String totalLabel;
  final List<DailySalesBarData> bars;
  final double? minHeight;

  const _Last7DaysSalesCard({
    required this.totalLabel,
    required this.bars,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints:
          minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header (`46:488`)
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MmSpacing.md,
            runSpacing: MmSpacing.xs,
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
              left: MmSpacing.xs,
              right: MmSpacing.xs,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < bars.length; i++) ...[
                  if (i > 0) const SizedBox(width: MmSpacing.xs),
                  Expanded(
                    child: Center(
                      child: DailySalesBar.fromData(bars[i]),
                    ),
                  ),
                ],
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
              Expanded(
                child: Text(
                  'Recent Alerts',
                  style: MmTypography.headingH3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
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
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MmSpacing.md,
            runSpacing: MmSpacing.sm,
            children: [
              Text(
                'Inventory Watchlist',
                style: MmTypography.headingH3,
              ),
              // Table Actions (`46:583`)
              Wrap(
                spacing: MmSpacing.sm,
                runSpacing: MmSpacing.sm,
                children: [
                  MmButton(
                    label: 'Receive Batch',
                    leadingIconAsset: AppAssets.iconReceiveBatchSm,
                    variant: MmButtonVariant.secondary,
                    size: MmButtonSize.small,
                    onPressed: onReceiveBatch,
                  ),
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
          // Table Rows (`46:595`) with smooth horizontal scroll on narrow screens
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(MmRadius.md),
              border: Border.all(
                color: MmColors.borderDefault,
                width: MmElevation.strokeThin,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: LayoutBuilder(
              builder: (context, tableConstraints) {
                final tableWidth = math.max(
                  tableConstraints.maxWidth,
                  _DashboardBreakpoints.tableMinWidth,
                );
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: tableWidth,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const DataTableHeaderRow(),
                        for (final item in items)
                          InventoryWatchlistRow(item: item),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
