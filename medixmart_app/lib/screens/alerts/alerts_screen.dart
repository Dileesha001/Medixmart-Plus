import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../config/app_assets.dart';
import '../../config/app_theme.dart';
import '../../models/alert_model.dart';
import '../../models/api_exception.dart';
import '../../models/dashboard_models.dart';
import '../../providers/alert_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/mm_button.dart';
import '../../widgets/mm_feedback_states.dart';
import '../../widgets/status_badge.dart';

abstract final class _AlertsBreakpoints {
  static const double headerSingleRow = 880.0;
  static const double compactPadding = 760.0;
  static const double desktopLayout = 900.0;
  static const double rowSplit = 720.0;
}

/// Responsive Alerts Center screen (`GET/PATCH/POST /api/alerts`).
///
/// Displays live alert summary counters, server-backed Status/Type/Severity
/// filtering, paginated alert rows/cards, staff Resolve confirmations, and an
/// Admin-only expiry check trigger.
class AlertsScreen extends StatefulWidget {
  final bool showMenuButton;
  final VoidCallback? onOpenDrawer;

  const AlertsScreen({
    super.key,
    this.showMenuButton = false,
    this.onOpenDrawer,
  });

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AlertProvider>().ensureLoaded();
      }
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: MmTypography.bodyMedium.copyWith(
              color: MmColors.textOnBrand,
            ),
          ),
          backgroundColor: isError ? MmColors.bgDanger : MmColors.textPrimary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  Future<void> _handleResolve(AlertModel alert) async {
    final confirmed = await showMmConfirmDialog(
      context,
      title: 'Resolve Alert',
      message:
          "Mark '${alert.title}' as resolved? Resolved alerts move to the Resolved archive.",
      confirmLabel: 'Resolve',
      confirmVariant: MmButtonVariant.primary,
    );
    if (!confirmed || !mounted) return;

    try {
      final provider = context.read<AlertProvider>();
      await provider.resolveAlert(alert.id);
      if (provider.errorMessage != null) {
        _showSnackBar(
          'Alert marked as resolved, but feed refresh failed. Tap Retry to reload.',
          isError: true,
        );
      } else {
        _showSnackBar('Alert marked as resolved.');
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Unable to resolve alert.', isError: true);
    }
  }

  Future<void> _handleRunExpiryCheck() async {
    try {
      final provider = context.read<AlertProvider>();
      final result = await provider.runExpiryCheck();
      if (!mounted) return;
      if (result.totalChanges == 0) {
        _showSnackBar('Expiry check complete — no new alerts.');
      } else {
        _showSnackBar(
          'Expiry check complete: ${result.expiredAlertsCreated} expired, '
          '${result.warningAlertsCreated} return-window alerts created, '
          '${result.alertsAutoResolved} auto-resolved.',
        );
      }
    } on ApiException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Unable to run expiry check.', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final authUser = context.watch<AuthProvider?>()?.user;
    final isAdmin = authUser?.isAdmin ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaWidth = constraints.maxWidth;
        final isCompact = areaWidth < _AlertsBreakpoints.compactPadding;
        final horizontalPadding = isCompact ? MmSpacing.lg : MmSpacing.xxxl;
        final singleRowHeader = areaWidth >= _AlertsBreakpoints.headerSingleRow;
        final bodyContentWidth =
            math.max(0.0, areaWidth - (horizontalPadding * 2));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Header
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
                  ? _buildSingleRowHeader(provider, isAdmin: isAdmin)
                  : _buildStackedHeader(provider, isAdmin: isAdmin),
            ),

            // Scrollable Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isCompact ? MmSpacing.lg : MmSpacing.xxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSummaryStrip(
                      provider: provider,
                      availableWidth: bodyContentWidth,
                    ),
                    const SizedBox(height: MmSpacing.lg),
                    _buildFilterToolbar(provider),
                    const SizedBox(height: MmSpacing.lg),
                    _buildFeedSurface(
                      provider: provider,
                      availableWidth: bodyContentWidth,
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

  Widget _buildMenuButton() {
    return Padding(
      padding: const EdgeInsets.only(right: MmSpacing.sm),
      child: IconButton(
        key: const Key('dashboard_menu_button'),
        tooltip: 'Open navigation menu',
        onPressed: widget.onOpenDrawer,
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

  Widget _buildTitleGroup(AlertProvider provider) {
    final activeCount = provider.summary?.totalActive;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Alerts',
            style: MmTypography.headingH2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (activeCount != null) ...[
          const SizedBox(width: MmSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MmSpacing.sm,
              vertical: MmSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: activeCount > 0
                  ? MmColors.bgWarningSubtle
                  : MmColors.bgSubtle,
              borderRadius: BorderRadius.circular(MmRadius.full),
              border: Border.all(
                color: activeCount > 0
                    ? MmColors.borderWarning
                    : MmColors.borderDefault,
                width: MmElevation.strokeThin,
              ),
            ),
            child: Text(
              '$activeCount active',
              style: MmTypography.labelSmall.copyWith(
                color: activeCount > 0
                    ? MmColors.textWarning
                    : MmColors.textSecondary,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeaderActions(
    AlertProvider provider, {
    required bool isAdmin,
  }) {
    return Wrap(
      spacing: MmSpacing.sm,
      runSpacing: MmSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          key: const Key('alerts_refresh_button'),
          tooltip: 'Refresh alerts',
          onPressed: provider.isLoading || provider.isRefreshing
              ? null
              : () => provider.refresh(),
          icon: const Icon(
            Icons.refresh_rounded,
            size: 20,
            color: MmColors.iconPrimary,
          ),
          style: IconButton.styleFrom(
            minimumSize: const Size(36, 36),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(MmRadius.md),
              side: const BorderSide(
                color: MmColors.borderDefault,
                width: MmElevation.strokeThin,
              ),
            ),
          ),
        ),
        if (isAdmin)
          MmButton(
            key: const Key('alerts_run_expiry_button'),
            label: provider.isRunningExpiryCheck
                ? 'Running Check...'
                : 'Run Expiry Check',
            variant: MmButtonVariant.primary,
            size: MmButtonSize.medium,
            onPressed:
                provider.isRunningExpiryCheck ? null : _handleRunExpiryCheck,
          ),
      ],
    );
  }

  Widget _buildSingleRowHeader(
    AlertProvider provider, {
    required bool isAdmin,
  }) {
    return Row(
      children: [
        if (widget.showMenuButton) _buildMenuButton(),
        Expanded(child: _buildTitleGroup(provider)),
        const SizedBox(width: MmSpacing.md),
        _buildHeaderActions(provider, isAdmin: isAdmin),
      ],
    );
  }

  Widget _buildStackedHeader(
    AlertProvider provider, {
    required bool isAdmin,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (widget.showMenuButton) _buildMenuButton(),
            Expanded(child: _buildTitleGroup(provider)),
          ],
        ),
        const SizedBox(height: MmSpacing.md),
        _buildHeaderActions(provider, isAdmin: isAdmin),
      ],
    );
  }

  Widget _buildSummaryStrip({
    required AlertProvider provider,
    required double availableWidth,
  }) {
    final s = provider.summary ?? const AlertSummary.empty();

    void handleTypeTap(AlertType type) {
      if (!provider.showResolved && provider.typeFilter == type) {
        provider.setTypeFilter(null);
      } else {
        provider.applyQuickFilter(type: type, showResolved: false);
      }
    }

    final cards = [
      _AlertSummaryCard(
        key: const Key('alerts_summary_active'),
        label: 'Active Alerts',
        count: s.totalActive,
        iconAsset: AppAssets.navAlerts,
        iconBgColor: MmColors.bgInfoSubtle,
        accentColor: MmColors.textInfo,
        isSelected: !provider.showResolved &&
            provider.typeFilter == null &&
            provider.severityFilter == null &&
            provider.hasLoadedOnce,
        onTap: () => provider.applyQuickFilter(showResolved: false),
      ),
      _AlertSummaryCard(
        key: const Key('alerts_summary_expired'),
        label: 'Expired',
        count: s.expiredCount,
        iconAsset: AppAssets.iconAlertTriangle,
        iconBgColor: MmColors.bgDangerSubtle,
        accentColor: MmColors.textDanger,
        isSelected:
            !provider.showResolved && provider.typeFilter == AlertType.expired,
        onTap: () => handleTypeTap(AlertType.expired),
      ),
      _AlertSummaryCard(
        key: const Key('alerts_summary_expiring'),
        label: 'Expiring ≤ 7M',
        count: s.expiringSoonCount,
        iconAsset: AppAssets.iconClock,
        iconBgColor: MmColors.bgWarningSubtle,
        accentColor: MmColors.textWarning,
        isSelected: !provider.showResolved &&
            provider.typeFilter == AlertType.expiryWarning,
        onTap: () => handleTypeTap(AlertType.expiryWarning),
      ),
      _AlertSummaryCard(
        key: const Key('alerts_summary_low_stock'),
        label: 'Low Stock',
        count: s.lowStockCount,
        iconAsset: AppAssets.iconPackage,
        iconBgColor: MmColors.bgWarningSubtle,
        accentColor: MmColors.textWarning,
        isSelected:
            !provider.showResolved && provider.typeFilter == AlertType.lowStock,
        onTap: () => handleTypeTap(AlertType.lowStock),
      ),
    ];

    if (availableWidth >= _AlertsBreakpoints.desktopLayout) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: MmSpacing.md),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: MmSpacing.md),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: MmSpacing.md),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: MmSpacing.md),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterToolbar(AlertProvider provider) {
    return Wrap(
      spacing: MmSpacing.md,
      runSpacing: MmSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 2-state Status segmented control: Active | Resolved
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: MmColors.bgSurface,
            borderRadius: BorderRadius.circular(MmRadius.md),
            border: Border.all(
              color: MmColors.borderDefault,
              width: MmElevation.strokeThin,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SegmentPillButton(
                key: const Key('alerts_status_active'),
                label: 'Active',
                isSelected: !provider.showResolved,
                onTap: () => provider.setShowResolved(false),
              ),
              _SegmentPillButton(
                key: const Key('alerts_status_resolved'),
                label: 'Resolved',
                isSelected: provider.showResolved,
                onTap: () => provider.setShowResolved(true),
              ),
            ],
          ),
        ),

        // Type dropdown
        SizedBox(
          width: 195,
          child: InputDecorator(
            decoration: _toolbarDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AlertType?>(
                key: const Key('alerts_type_filter'),
                value: provider.typeFilter,
                isExpanded: true,
                isDense: true,
                items: [
                  DropdownMenuItem<AlertType?>(
                    value: null,
                    child: Text(
                      'All Types',
                      style: MmTypography.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final type in AlertType.values)
                    DropdownMenuItem<AlertType?>(
                      value: type,
                      child: Text(
                        type.label,
                        style: MmTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => provider.setTypeFilter(value),
              ),
            ),
          ),
        ),

        // Severity dropdown
        SizedBox(
          width: 175,
          child: InputDecorator(
            decoration: _toolbarDropdownDecoration(),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<AlertSeverity?>(
                key: const Key('alerts_severity_filter'),
                value: provider.severityFilter,
                isExpanded: true,
                isDense: true,
                items: [
                  DropdownMenuItem<AlertSeverity?>(
                    value: null,
                    child: Text(
                      'All Severities',
                      style: MmTypography.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  for (final severity in AlertSeverity.values)
                    DropdownMenuItem<AlertSeverity?>(
                      value: severity,
                      child: Text(
                        severity.label,
                        style: MmTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => provider.setSeverityFilter(value),
              ),
            ),
          ),
        ),

        if (provider.hasActiveFilters)
          TextButton.icon(
            key: const Key('alerts_clear_filters'),
            onPressed: () => provider.clearFilters(),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text('Reset filters'),
            style: TextButton.styleFrom(
              foregroundColor: MmColors.textSecondary,
              textStyle: MmTypography.labelMedium,
            ),
          ),
      ],
    );
  }

  Widget _buildFeedSurface({
    required AlertProvider provider,
    required double availableWidth,
  }) {
    final hasTypeOrSeverityFilter =
        provider.typeFilter != null || provider.severityFilter != null;

    return Container(
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
        boxShadow: MmElevation.xs,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.isRefreshing)
            const LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: MmColors.bgBrandSubtle,
              valueColor: AlwaysStoppedAnimation<Color>(MmColors.bgBrand),
            ),

          if (provider.errorMessage != null && provider.alerts.isNotEmpty)
            Container(
              key: const Key('alerts_inline_error_banner'),
              padding: const EdgeInsets.symmetric(
                horizontal: MmSpacing.lg,
                vertical: MmSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: MmColors.bgDangerSubtle,
                border: Border(
                  bottom: BorderSide(
                    color: MmColors.borderDanger,
                    width: MmElevation.strokeThin,
                  ),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: MmColors.textDanger,
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  Expanded(
                    child: Text(
                      provider.errorMessage!,
                      style: MmTypography.bodySmall.copyWith(
                        color: MmColors.textDanger,
                      ),
                    ),
                  ),
                  const SizedBox(width: MmSpacing.md),
                  MmButton(
                    key: const Key('alerts_inline_error_retry'),
                    label: 'Retry',
                    variant: MmButtonVariant.secondary,
                    size: MmButtonSize.small,
                    onPressed:
                        provider.isRefreshing ? null : () => provider.refresh(),
                  ),
                ],
              ),
            ),

          if (provider.isLoading && provider.alerts.isEmpty)
            const MmLoadingView(message: 'Loading pharmacy alerts...')
          else if (provider.errorMessage != null && provider.alerts.isEmpty)
            MmErrorState(
              title: 'Could not load alerts',
              message: provider.errorMessage!,
              onRetry: () => provider.refresh(),
            )
          else if (provider.alerts.isEmpty)
            MmEmptyState(
              icon: provider.showResolved
                  ? Icons.inventory_2_outlined
                  : Icons.notifications_none_rounded,
              title: hasTypeOrSeverityFilter
                  ? 'No matching alerts'
                  : (provider.showResolved
                      ? 'No resolved alerts yet'
                      : 'All caught up'),
              message: hasTypeOrSeverityFilter
                  ? 'Adjust or clear your type and severity filters to view alerts.'
                  : (provider.showResolved
                      ? 'Resolved expiry, stock, and customer alerts will appear here.'
                      : 'There are no active stock, expiry, or customer alerts right now.'),
              actionLabel: provider.hasActiveFilters ? 'Clear Filters' : null,
              onAction: provider.hasActiveFilters
                  ? () => provider.clearFilters()
                  : null,
            )
          else ...[
            for (var i = 0; i < provider.alerts.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: MmElevation.strokeThin,
                  color: MmColors.borderDefault,
                ),
              _AlertListItem(
                alert: provider.alerts[i],
                isCompactRow: availableWidth < _AlertsBreakpoints.rowSplit,
                isResolving: provider.isResolving(provider.alerts[i].id),
                onResolve: () => _handleResolve(provider.alerts[i]),
              ),
            ],
            _buildPaginationFooter(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(AlertProvider provider) {
    final p = provider.pagination;
    final start = p.totalRecords == 0 ? 0 : ((p.page - 1) * p.limit) + 1;
    final end = math.min(p.page * p.limit, p.totalRecords);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.lg,
        vertical: MmSpacing.md,
      ),
      decoration: const BoxDecoration(
        color: MmColors.bgSurface,
        border: Border(
          top: BorderSide(
            color: MmColors.borderDefault,
            width: MmElevation.strokeThin,
          ),
        ),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: MmSpacing.md,
        runSpacing: MmSpacing.sm,
        children: [
          Text(
            'Showing $start–$end of ${p.totalRecords} alerts',
            style: MmTypography.bodySmall,
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MmSpacing.sm,
            runSpacing: MmSpacing.xs,
            children: [
              MmButton(
                key: const Key('alerts_prev_page'),
                label: 'Previous',
                variant: MmButtonVariant.secondary,
                size: MmButtonSize.small,
                onPressed: p.hasPrevPage && !provider.isRefreshing
                    ? () => provider.goToPage(p.page - 1)
                    : null,
              ),
              Text(
                'Page ${p.page} of ${p.totalPages}',
                style: MmTypography.labelMedium.copyWith(
                  color: MmColors.textSecondary,
                ),
              ),
              MmButton(
                key: const Key('alerts_next_page'),
                label: 'Next',
                variant: MmButtonVariant.secondary,
                size: MmButtonSize.small,
                onPressed: p.hasNextPage && !provider.isRefreshing
                    ? () => provider.goToPage(p.page + 1)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _toolbarDropdownDecoration() {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(MmRadius.md),
      borderSide: const BorderSide(
        color: MmColors.borderDefault,
        width: MmElevation.strokeThin,
      ),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: MmColors.bgSurface,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.md,
        vertical: 10,
      ),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(MmRadius.md),
        borderSide: const BorderSide(
          color: MmColors.borderBrand,
          width: 1.5,
        ),
      ),
    );
  }
}

class _AlertSummaryCard extends StatelessWidget {
  final String label;
  final int count;
  final String iconAsset;
  final Color iconBgColor;
  final Color accentColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _AlertSummaryCard({
    super.key,
    required this.label,
    required this.count,
    required this.iconAsset,
    required this.iconBgColor,
    required this.accentColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MmColors.bgSurface,
      borderRadius: BorderRadius.circular(MmRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(MmSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MmRadius.lg),
            border: Border.all(
              color: isSelected ? accentColor : MmColors.borderDefault,
              width: isSelected ? 1.5 : MmElevation.strokeThin,
            ),
            boxShadow: MmElevation.xs,
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(MmRadius.md),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: SvgPicture.asset(
                    iconAsset,
                    width: 18,
                    height: 18,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: MmTypography.labelSmall.copyWith(
                        color: MmColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: MmSpacing.xxs),
                    Text(
                      MmFormatters.twoDigitCount(count),
                      style: MmTypography.headingH2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentPillButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentPillButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? MmColors.bgBrandSubtle : Colors.transparent,
      borderRadius: BorderRadius.circular(MmRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MmRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MmSpacing.md,
            vertical: MmSpacing.xs,
          ),
          child: Text(
            label,
            style: MmTypography.labelMedium.copyWith(
              color: isSelected ? MmColors.textBrand : MmColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AlertListItem extends StatelessWidget {
  final AlertModel alert;
  final bool isCompactRow;
  final bool isResolving;
  final VoidCallback onResolve;

  const _AlertListItem({
    required this.alert,
    required this.isCompactRow,
    required this.isResolving,
    required this.onResolve,
  });

  Color get _iconBoxColor {
    if (alert.isResolved) return MmColors.bgSubtle;
    switch (alert.severity) {
      case AlertSeverity.danger:
        return MmColors.bgDangerSubtle;
      case AlertSeverity.warning:
        return MmColors.bgWarningSubtle;
      case AlertSeverity.info:
        return MmColors.bgInfoSubtle;
    }
  }

  Widget _buildIcon() {
    if (alert.alertType == AlertType.birthday) {
      return Icon(
        Icons.cake_outlined,
        size: 18,
        color: alert.isResolved ? MmColors.textSecondary : MmColors.textInfo,
      );
    }
    if (alert.alertType == null && alert.severity == AlertSeverity.info) {
      return Icon(
        Icons.notifications_none_rounded,
        size: 18,
        color: alert.isResolved ? MmColors.textSecondary : MmColors.textInfo,
      );
    }

    final String asset;
    switch (alert.alertType) {
      case AlertType.expired:
        asset = AppAssets.iconAlertTriangle;
        break;
      case AlertType.expiryWarning:
        asset = AppAssets.iconClock;
        break;
      case AlertType.lowStock:
        asset = AppAssets.iconPackage;
        break;
      case AlertType.creditOverdue:
        asset = AppAssets.iconCreditCard;
        break;
      case AlertType.birthday:
      case null:
        asset = alert.severity == AlertSeverity.danger
            ? AppAssets.iconAlertTriangle
            : AppAssets.iconClock;
        break;
    }

    return SizedBox(
      width: 18,
      height: 18,
      child: SvgPicture.asset(
        asset,
        width: 18,
        height: 18,
      ),
    );
  }

  Widget _buildTypeBadge() {
    switch (alert.alertType) {
      case AlertType.expired:
        return StatusBadge(
          label: alert.typeLabel,
          tone: StatusTone.expired,
        );
      case AlertType.expiryWarning:
        return StatusBadge(
          label: alert.typeLabel,
          tone: StatusTone.expiring7M,
        );
      case AlertType.lowStock:
        return StatusBadge(
          label: alert.typeLabel,
          tone: StatusTone.lowStock,
        );
      case AlertType.creditOverdue:
        return StatusBadge(
          label: alert.typeLabel,
          tone: alert.severity == AlertSeverity.danger
              ? StatusTone.expired
              : StatusTone.lowStock,
        );
      case AlertType.birthday:
      case null:
        return _InlineAlertPill(
          label: alert.typeLabel.isEmpty ? alert.severity.label : alert.typeLabel,
          backgroundColor: MmColors.bgInfoSubtle,
          borderColor: MmColors.textInfo.withValues(alpha: 0.35),
          textColor: MmColors.textInfo,
          dotColor: MmColors.textInfo,
        );
    }
  }

  Widget _buildResolveAction() {
    if (alert.isResolved) {
      return const SizedBox.shrink();
    }
    return MmButton(
      key: Key('alert_resolve_${alert.id}'),
      label: isResolving ? 'Resolving...' : 'Resolve',
      variant: MmButtonVariant.secondary,
      size: MmButtonSize.small,
      onPressed: isResolving ? null : onResolve,
    );
  }

  @override
  Widget build(BuildContext context) {
    final refLabel = alert.referenceLabel;

    final metadataChips = Wrap(
      spacing: MmSpacing.sm,
      runSpacing: MmSpacing.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildTypeBadge(),
        if (alert.isResolved)
          const _InlineAlertPill(
            label: 'Resolved',
            backgroundColor: MmColors.bgSubtle,
            borderColor: MmColors.borderDefault,
            textColor: MmColors.textSecondary,
            dotColor: MmColors.textSecondary,
          ),
        if (refLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MmSpacing.sm,
              vertical: MmSpacing.xxs,
            ),
            decoration: BoxDecoration(
              color: MmColors.bgSubtle,
              borderRadius: BorderRadius.circular(MmRadius.sm),
              border: Border.all(
                color: MmColors.borderDefault,
                width: MmElevation.strokeThin,
              ),
            ),
            child: Text(
              refLabel,
              style: MmTypography.labelSmall.copyWith(
                color: MmColors.textSecondary,
              ),
            ),
          ),
        if (alert.createdAt != null)
          Text(
            'Created ${MmFormatters.shortDateTime(alert.createdAt!)}',
            style: MmTypography.bodySmall.copyWith(color: MmColors.textMuted),
          ),
        if (alert.isResolved && alert.resolvedAt != null)
          Text(
            'Resolved ${MmFormatters.shortDateTime(alert.resolvedAt!)}',
            style: MmTypography.bodySmall.copyWith(color: MmColors.textBrand),
          ),
      ],
    );

    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          alert.title,
          style: MmTypography.headingH4.copyWith(
            color: alert.isResolved
                ? MmColors.textSecondary
                : MmColors.textPrimary,
          ),
        ),
        if (alert.message.isNotEmpty) ...[
          const SizedBox(height: MmSpacing.xs),
          Text(
            alert.message,
            style: MmTypography.bodyMedium.copyWith(
              color: MmColors.textSecondary,
            ),
          ),
        ],
        const SizedBox(height: MmSpacing.sm),
        metadataChips,
      ],
    );

    final iconBox = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: _iconBoxColor,
        borderRadius: BorderRadius.circular(MmRadius.md),
      ),
      alignment: Alignment.center,
      child: _buildIcon(),
    );

    return Container(
      key: Key('alert_item_${alert.id}'),
      color: alert.isResolved ? MmColors.bgCanvas : MmColors.bgSurface,
      padding: const EdgeInsets.all(MmSpacing.lg),
      child: isCompactRow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    iconBox,
                    const SizedBox(width: MmSpacing.md),
                    Expanded(child: contentColumn),
                  ],
                ),
                if (!alert.isResolved) ...[
                  const SizedBox(height: MmSpacing.md),
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildResolveAction(),
                  ),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                iconBox,
                const SizedBox(width: MmSpacing.md),
                Expanded(child: contentColumn),
                if (!alert.isResolved) ...[
                  const SizedBox(width: MmSpacing.md),
                  _buildResolveAction(),
                ],
              ],
            ),
    );
  }
}

class _InlineAlertPill extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final Color dotColor;

  const _InlineAlertPill({
    required this.label,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.sm,
        vertical: MmSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(MmRadius.full),
        border: Border.all(
          color: borderColor,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: MmSpacing.xs),
          Flexible(
            child: Text(
              label,
              style: MmTypography.labelSmall.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
