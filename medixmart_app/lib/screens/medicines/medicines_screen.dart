import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_assets.dart';
import '../../config/app_theme.dart';
import '../../models/api_exception.dart';
import '../../models/dashboard_models.dart';
import '../../models/medicine_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/medicine_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/mm_button.dart';
import '../../widgets/mm_feedback_states.dart';
import '../../widgets/pos_search_bar.dart';
import '../../widgets/status_badge.dart';
import 'category_modal.dart';
import 'medicine_form_dialog.dart';

abstract final class _MedicinesBreakpoints {
  static const double headerSingleRow = 880.0;
  static const double compactPadding = 760.0;
  static const double desktopTable = 900.0;
  static const double tableMinWidth = 960.0;
}

class _SortOption {
  final String id;
  final String label;
  final MedicineSortField field;
  final bool ascending;

  const _SortOption({
    required this.id,
    required this.label,
    required this.field,
    required this.ascending,
  });
}

const List<_SortOption> _kSortOptions = [
  _SortOption(
    id: 'name_asc',
    label: 'Name (A–Z)',
    field: MedicineSortField.name,
    ascending: true,
  ),
  _SortOption(
    id: 'name_desc',
    label: 'Name (Z–A)',
    field: MedicineSortField.name,
    ascending: false,
  ),
  _SortOption(
    id: 'price_asc',
    label: 'Price: Low–High',
    field: MedicineSortField.sellingPrice,
    ascending: true,
  ),
  _SortOption(
    id: 'price_desc',
    label: 'Price: High–Low',
    field: MedicineSortField.sellingPrice,
    ascending: false,
  ),
  _SortOption(
    id: 'reorder_asc',
    label: 'Reorder Level',
    field: MedicineSortField.reorderLevel,
    ascending: true,
  ),
  _SortOption(
    id: 'newest_desc',
    label: 'Newest First',
    field: MedicineSortField.createdAt,
    ascending: false,
  ),
];

/// Responsive Medicines & Categories management screen.
///
/// Renders a desktop data table (`>= 900px`) and stacked mobile cards (`< 900px`),
/// with live search, category/status filters, sorting, pagination, and
/// Admin-only CRUD controls.
class MedicinesScreen extends StatefulWidget {
  final bool showMenuButton;
  final VoidCallback? onOpenDrawer;
  final bool openCreateOnMount;
  final VoidCallback? onCreateDialogHandled;

  const MedicinesScreen({
    super.key,
    this.showMenuButton = false,
    this.onOpenDrawer,
    this.openCreateOnMount = false,
    this.onCreateDialogHandled,
  });

  @override
  State<MedicinesScreen> createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = context.read<MedicineProvider>().searchQuery;
    _searchController = TextEditingController(text: initialQuery);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await context.read<MedicineProvider>().ensureLoaded();
      if (!mounted) return;
      if (widget.openCreateOnMount) {
        _openCreateIfAuthorized();
      }
    });
  }

  @override
  void didUpdateWidget(covariant MedicinesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.openCreateOnMount && !oldWidget.openCreateOnMount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openCreateIfAuthorized();
        }
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openCreateIfAuthorized() {
    widget.onCreateDialogHandled?.call();
    final isAdmin = context.read<AuthProvider?>()?.user?.isAdmin ?? false;
    if (isAdmin) {
      _openMedicineForm();
    }
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

  Future<void> _openCategoriesModal({required bool isAdmin}) async {
    await showCategoryModal(context, canCreate: isAdmin);
  }

  Future<void> _openMedicineForm({MedicineModel? medicine}) async {
    final saved = await showMedicineFormDialog(
      context,
      initialMedicine: medicine,
    );
    if (saved && mounted) {
      _showSnackBar(
        medicine == null
            ? 'Medicine added to catalog.'
            : "Medicine '${medicine.name}' updated.",
      );
    }
  }

  Future<void> _handleDeactivate(MedicineModel medicine) async {
    final confirmed = await showMmConfirmDialog(
      context,
      title: 'Deactivate Medicine',
      message:
          "Deactivating '${medicine.name}' hides it from active POS search while preserving all historical sales and batch records.",
      confirmLabel: 'Deactivate',
      confirmVariant: MmButtonVariant.danger,
    );
    if (!confirmed || !mounted) return;

    try {
      await context.read<MedicineProvider>().deactivateMedicine(medicine.id);
      _showSnackBar("Medicine '${medicine.name}' deactivated.");
    } on ApiException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Unable to deactivate medicine.', isError: true);
    }
  }

  Future<void> _handleReactivate(MedicineModel medicine) async {
    try {
      await context.read<MedicineProvider>().reactivateMedicine(medicine.id);
      _showSnackBar("Medicine '${medicine.name}' reactivated.");
    } on ApiException catch (e) {
      _showSnackBar(e.message, isError: true);
    } catch (_) {
      _showSnackBar('Unable to reactivate medicine.', isError: true);
    }
  }

  String _currentSortOptionId(MedicineProvider provider) {
    for (final opt in _kSortOptions) {
      if (opt.field == provider.sortField &&
          opt.ascending == provider.sortAscending) {
        return opt.id;
      }
    }
    return _kSortOptions.first.id;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MedicineProvider>();
    final authUser = context.watch<AuthProvider?>()?.user;
    final isAdmin = authUser?.isAdmin ?? false;

    return LayoutBuilder(
      builder: (context, constraints) {
        final areaWidth = constraints.maxWidth;
        final isCompact = areaWidth < _MedicinesBreakpoints.compactPadding;
        final horizontalPadding = isCompact ? MmSpacing.lg : MmSpacing.xxxl;
        final singleRowHeader =
            areaWidth >= _MedicinesBreakpoints.headerSingleRow;
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
                    _buildFilterToolbar(provider),
                    const SizedBox(height: MmSpacing.lg),
                    _buildCatalogSurface(
                      provider: provider,
                      isAdmin: isAdmin,
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

  Widget _buildTitleGroup(MedicineProvider provider) {
    final total = provider.pagination.totalRecords;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            'Medicines',
            style: MmTypography.headingH2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: MmSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MmSpacing.sm,
            vertical: MmSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: MmColors.bgSubtle,
            borderRadius: BorderRadius.circular(MmRadius.full),
            border: Border.all(
              color: MmColors.borderDefault,
              width: MmElevation.strokeThin,
            ),
          ),
          child: Text(
            '$total ${total == 1 ? 'item' : 'items'}',
            style: MmTypography.labelSmall.copyWith(
              color: MmColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderActions(MedicineProvider provider, {required bool isAdmin}) {
    return Wrap(
      spacing: MmSpacing.sm,
      runSpacing: MmSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        IconButton(
          key: const Key('medicines_refresh_button'),
          tooltip: 'Refresh catalog',
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
        MmButton(
          key: const Key('medicines_categories_button'),
          label: 'Categories',
          variant: MmButtonVariant.secondary,
          size: MmButtonSize.medium,
          onPressed: () => _openCategoriesModal(isAdmin: isAdmin),
        ),
        if (isAdmin)
          MmButton(
            key: const Key('medicines_add_button'),
            label: 'Add Medicine',
            leadingIconAsset: AppAssets.iconPlusMd,
            variant: MmButtonVariant.primary,
            size: MmButtonSize.medium,
            onPressed: () => _openMedicineForm(),
          ),
      ],
    );
  }

  Widget _buildSingleRowHeader(
    MedicineProvider provider, {
    required bool isAdmin,
  }) {
    return Row(
      children: [
        if (widget.showMenuButton) _buildMenuButton(),
        Expanded(child: _buildTitleGroup(provider)),
        const SizedBox(width: MmSpacing.md),
        Flexible(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: PosSearchBar(
                    key: const Key('medicines_search_bar'),
                    width: double.infinity,
                    placeholder: 'Search name, generic, or brand...',
                    controller: _searchController,
                    onChanged: provider.setSearchQuery,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.md),
              _buildHeaderActions(provider, isAdmin: isAdmin),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStackedHeader(
    MedicineProvider provider, {
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
        PosSearchBar(
          key: const Key('medicines_search_bar'),
          width: double.infinity,
          placeholder: 'Search name, generic, or brand...',
          controller: _searchController,
          onChanged: provider.setSearchQuery,
        ),
        const SizedBox(height: MmSpacing.md),
        _buildHeaderActions(provider, isAdmin: isAdmin),
      ],
    );
  }

  Widget _buildFilterToolbar(MedicineProvider provider) {
    final validSelectedCategoryId = provider.selectedCategoryId != null &&
            provider.categories.any((c) => c.id == provider.selectedCategoryId)
        ? provider.selectedCategoryId
        : null;

    return Wrap(
      spacing: MmSpacing.md,
      runSpacing: MmSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Category dropdown
        SizedBox(
          width: 210,
          child: DropdownButtonFormField<int?>(
            key: const Key('medicines_category_filter'),
            value: validSelectedCategoryId,
            isExpanded: true,
            decoration: _toolbarDropdownDecoration(),
            items: [
              DropdownMenuItem<int?>(
                value: null,
                child: Text(
                  'All Categories',
                  style: MmTypography.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              for (final cat in provider.categories)
                DropdownMenuItem<int?>(
                  value: cat.id,
                  child: Text(
                    cat.name,
                    style: MmTypography.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (value) => provider.setCategoryFilter(value),
          ),
        ),

        // Active / Inactive / All segmented filter
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
              _StatusSegmentButton(
                key: const Key('medicines_status_active'),
                label: 'Active',
                isSelected:
                    provider.statusFilter == MedicineStatusFilter.active,
                onTap: () =>
                    provider.setStatusFilter(MedicineStatusFilter.active),
              ),
              _StatusSegmentButton(
                key: const Key('medicines_status_inactive'),
                label: 'Inactive',
                isSelected:
                    provider.statusFilter == MedicineStatusFilter.inactive,
                onTap: () =>
                    provider.setStatusFilter(MedicineStatusFilter.inactive),
              ),
              _StatusSegmentButton(
                key: const Key('medicines_status_all'),
                label: 'All',
                isSelected: provider.statusFilter == MedicineStatusFilter.all,
                onTap: () => provider.setStatusFilter(MedicineStatusFilter.all),
              ),
            ],
          ),
        ),

        // Sort dropdown
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<String>(
            key: const Key('medicines_sort_dropdown'),
            value: _currentSortOptionId(provider),
            isExpanded: true,
            decoration: _toolbarDropdownDecoration(),
            items: [
              for (final opt in _kSortOptions)
                DropdownMenuItem<String>(
                  value: opt.id,
                  child: Text(
                    opt.label,
                    style: MmTypography.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              final opt = _kSortOptions.firstWhere((o) => o.id == id);
              provider.setSort(opt.field, ascending: opt.ascending);
            },
          ),
        ),

        if (provider.hasActiveFilters)
          TextButton.icon(
            key: const Key('medicines_clear_filters'),
            onPressed: () {
              _searchController.clear();
              provider.clearFilters();
            },
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

  Widget _buildCatalogSurface({
    required MedicineProvider provider,
    required bool isAdmin,
    required double availableWidth,
  }) {
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

          if (provider.isLoading && provider.medicines.isEmpty)
            const MmLoadingView(message: 'Loading medicine catalog...')
          else if (provider.errorMessage != null && provider.medicines.isEmpty)
            MmErrorState(
              title: 'Could not load medicines',
              message: provider.errorMessage!,
              onRetry: () => provider.refresh(),
            )
          else if (provider.medicines.isEmpty)
            MmEmptyState(
              icon: Icons.medication_outlined,
              title: provider.hasActiveFilters
                  ? 'No matching medicines'
                  : 'No medicines in catalog yet',
              message: provider.hasActiveFilters
                  ? 'Adjust your search query, category, or status filter.'
                  : 'Add your first medicine to start building the pharmacy catalog.',
              actionLabel: provider.hasActiveFilters
                  ? 'Clear Filters'
                  : (isAdmin ? 'Add Medicine' : null),
              onAction: provider.hasActiveFilters
                  ? () {
                      _searchController.clear();
                      provider.clearFilters();
                    }
                  : (isAdmin ? () => _openMedicineForm() : null),
            )
          else ...[
            if (availableWidth >= _MedicinesBreakpoints.desktopTable)
              _buildDesktopTable(
                medicines: provider.medicines,
                isAdmin: isAdmin,
              )
            else
              _buildMobileCardList(
                medicines: provider.medicines,
                isAdmin: isAdmin,
              ),
            _buildPaginationFooter(provider),
          ],
        ],
      ),
    );
  }

  Widget _buildDesktopTable({
    required List<MedicineModel> medicines,
    required bool isAdmin,
  }) {
    return LayoutBuilder(
      builder: (context, tableConstraints) {
        final tableWidth = math.max(
          tableConstraints.maxWidth,
          _MedicinesBreakpoints.tableMinWidth,
        );
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MedicineTableHeader(showActions: isAdmin),
                for (final medicine in medicines)
                  _MedicineTableRow(
                    medicine: medicine,
                    showActions: isAdmin,
                    onEdit: () => _openMedicineForm(medicine: medicine),
                    onDeactivate: () => _handleDeactivate(medicine),
                    onReactivate: () => _handleReactivate(medicine),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMobileCardList({
    required List<MedicineModel> medicines,
    required bool isAdmin,
  }) {
    return Padding(
      padding: const EdgeInsets.all(MmSpacing.md),
      child: Column(
        children: [
          for (var i = 0; i < medicines.length; i++) ...[
            if (i > 0) const SizedBox(height: MmSpacing.md),
            _MedicineMobileCard(
              medicine: medicines[i],
              showActions: isAdmin,
              onEdit: () => _openMedicineForm(medicine: medicines[i]),
              onDeactivate: () => _handleDeactivate(medicines[i]),
              onReactivate: () => _handleReactivate(medicines[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(MedicineProvider provider) {
    final p = provider.pagination;
    final start =
        p.totalRecords == 0 ? 0 : ((p.page - 1) * p.limit) + 1;
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
            'Showing $start–$end of ${p.totalRecords} medicines',
            style: MmTypography.bodySmall,
          ),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: MmSpacing.sm,
            runSpacing: MmSpacing.xs,
            children: [
              MmButton(
                key: const Key('medicines_prev_page'),
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
                key: const Key('medicines_next_page'),
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

class _StatusSegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusSegmentButton({
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
            vertical: 6,
          ),
          child: Text(
            label,
            style: MmTypography.labelMedium.copyWith(
              color: isSelected ? MmColors.textBrand : MmColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

abstract final class _CatalogColFlex {
  static const int medicine = 250;
  static const int category = 135;
  static const int formStrength = 145;
  static const int price = 140;
  static const int reorder = 85;
  static const int status = 110;
  static const int actions = 95;
}

class _MedicineTableHeader extends StatelessWidget {
  final bool showActions;

  const _MedicineTableHeader({required this.showActions});

  @override
  Widget build(BuildContext context) {
    final headerStyle = MmTypography.labelSmall.copyWith(
      color: MmColors.textSecondary,
    );

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: MmSpacing.lg),
      decoration: const BoxDecoration(
        color: MmColors.bgSubtle,
        border: Border(
          bottom: BorderSide(
            color: MmColors.borderDefault,
            width: MmElevation.strokeThin,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _CatalogColFlex.medicine,
            child: Text('MEDICINE', style: headerStyle),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _CatalogColFlex.category,
            child: Text('CATEGORY', style: headerStyle),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _CatalogColFlex.formStrength,
            child: Text('FORM & STRENGTH', style: headerStyle),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _CatalogColFlex.price,
            child: Text('PRICE (LKR)', style: headerStyle),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _CatalogColFlex.reorder,
            child: Text('REORDER', style: headerStyle),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _CatalogColFlex.status,
            child: Text('STATUS', style: headerStyle),
          ),
          if (showActions) ...[
            const SizedBox(width: MmSpacing.sm),
            Expanded(
              flex: _CatalogColFlex.actions,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('ACTIONS', style: headerStyle),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MedicineTableRow extends StatelessWidget {
  final MedicineModel medicine;
  final bool showActions;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  const _MedicineTableRow({
    required this.medicine,
    required this.showActions,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final rowBg =
        medicine.isActive ? MmColors.bgSurface : MmColors.bgSubtle;
    final subtitle = medicine.subtitleSummary;

    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.lg,
        vertical: MmSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: rowBg,
        border: const Border(
          bottom: BorderSide(
            color: MmColors.borderDefault,
            width: MmElevation.strokeThin,
          ),
        ),
      ),
      child: Row(
        children: [
          // Medicine name + generic/brand subtitle
          Expanded(
            flex: _CatalogColFlex.medicine,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  medicine.name,
                  style: MmTypography.labelLarge.copyWith(
                    color: medicine.isActive
                        ? MmColors.textPrimary
                        : MmColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: MmTypography.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: MmSpacing.sm),

          // Category
          Expanded(
            flex: _CatalogColFlex.category,
            child: Text(
              medicine.categoryName ?? '—',
              style: MmTypography.bodyMedium.copyWith(
                color: MmColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: MmSpacing.sm),

          // Form & Strength
          Expanded(
            flex: _CatalogColFlex.formStrength,
            child: Text(
              medicine.formAndStrength,
              style: MmTypography.bodyMedium.copyWith(
                color: MmColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: MmSpacing.sm),

          // Price (Selling + muted cost)
          Expanded(
            flex: _CatalogColFlex.price,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  MmFormatters.currencyLkr(medicine.sellingPrice),
                  style: MmTypography.codeMono.copyWith(
                    color: MmColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Cost ${MmFormatters.currencyLkr(medicine.costPrice)}',
                  style: MmTypography.bodySmall.copyWith(
                    color: MmColors.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: MmSpacing.sm),

          // Reorder level
          Expanded(
            flex: _CatalogColFlex.reorder,
            child: Text(
              '${medicine.reorderLevel}',
              style: MmTypography.codeMono.copyWith(
                color: MmColors.textSecondary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: MmSpacing.sm),

          // Status badge
          Expanded(
            flex: _CatalogColFlex.status,
            child: Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: medicine.isActive ? 'Active' : 'Inactive',
                tone: medicine.isActive
                    ? StatusTone.inStock
                    : StatusTone.expired,
              ),
            ),
          ),

          // Admin Actions
          if (showActions) ...[
            const SizedBox(width: MmSpacing.sm),
            Expanded(
              flex: _CatalogColFlex.actions,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    key: Key('medicine_edit_${medicine.id}'),
                    tooltip: 'Edit medicine',
                    onPressed: onEdit,
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 18,
                      color: MmColors.iconPrimary,
                    ),
                    style: IconButton.styleFrom(
                      minimumSize: const Size(32, 32),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: MmSpacing.xs),
                  if (medicine.isActive)
                    IconButton(
                      key: Key('medicine_deactivate_${medicine.id}'),
                      tooltip: 'Deactivate medicine',
                      onPressed: onDeactivate,
                      icon: const Icon(
                        Icons.block_rounded,
                        size: 18,
                        color: MmColors.textDanger,
                      ),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(32, 32),
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )
                  else
                    IconButton(
                      key: Key('medicine_reactivate_${medicine.id}'),
                      tooltip: 'Reactivate medicine',
                      onPressed: onReactivate,
                      icon: const Icon(
                        Icons.restore_rounded,
                        size: 18,
                        color: MmColors.textBrand,
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
        ],
      ),
    );
  }
}

class _MedicineMobileCard extends StatelessWidget {
  final MedicineModel medicine;
  final bool showActions;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;

  const _MedicineMobileCard({
    required this.medicine,
    required this.showActions,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = medicine.subtitleSummary;
    return Container(
      padding: const EdgeInsets.all(MmSpacing.lg),
      decoration: BoxDecoration(
        color: medicine.isActive ? MmColors.bgSurface : MmColors.bgSubtle,
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medicine.name,
                      style: MmTypography.headingH4,
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: MmSpacing.xxs),
                      Text(subtitle, style: MmTypography.bodySmall),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              StatusBadge(
                label: medicine.isActive ? 'Active' : 'Inactive',
                tone: medicine.isActive
                    ? StatusTone.inStock
                    : StatusTone.expired,
              ),
            ],
          ),
          const SizedBox(height: MmSpacing.md),
          Wrap(
            spacing: MmSpacing.lg,
            runSpacing: MmSpacing.sm,
            children: [
              _CardMetric(
                label: 'Category',
                value: medicine.categoryName ?? '—',
              ),
              _CardMetric(
                label: 'Form & Strength',
                value: medicine.formAndStrength,
              ),
              _CardMetric(
                label: 'Selling Price',
                value: MmFormatters.currencyLkr(medicine.sellingPrice),
                isMono: true,
              ),
              _CardMetric(
                label: 'Cost Price',
                value: MmFormatters.currencyLkr(medicine.costPrice),
                isMono: true,
              ),
              _CardMetric(
                label: 'Reorder Level',
                value: '${medicine.reorderLevel}',
                isMono: true,
              ),
            ],
          ),
          if (showActions) ...[
            const SizedBox(height: MmSpacing.md),
            const Divider(height: 1, color: MmColors.borderDefault),
            const SizedBox(height: MmSpacing.sm),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: MmSpacing.sm,
              runSpacing: MmSpacing.sm,
              children: [
                MmButton(
                  key: Key('medicine_edit_${medicine.id}'),
                  label: 'Edit',
                  variant: MmButtonVariant.secondary,
                  size: MmButtonSize.small,
                  onPressed: onEdit,
                ),
                if (medicine.isActive)
                  MmButton(
                    key: Key('medicine_deactivate_${medicine.id}'),
                    label: 'Deactivate',
                    variant: MmButtonVariant.danger,
                    size: MmButtonSize.small,
                    onPressed: onDeactivate,
                  )
                else
                  MmButton(
                    key: Key('medicine_reactivate_${medicine.id}'),
                    label: 'Reactivate',
                    variant: MmButtonVariant.primary,
                    size: MmButtonSize.small,
                    onPressed: onReactivate,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool isMono;

  const _CardMetric({
    required this.label,
    required this.value,
    this.isMono = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MmTypography.labelSmall.copyWith(color: MmColors.textMuted),
        ),
        const SizedBox(height: MmSpacing.xxs),
        Text(
          value,
          style: isMono
              ? MmTypography.codeMono.copyWith(color: MmColors.textPrimary)
              : MmTypography.bodyMedium,
        ),
      ],
    );
  }
}
