import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/dashboard_models.dart';
import 'status_badge.dart';

/// Column width proportions matching the Figma 920px `Data Table Row` (`10:49` & `10:107`).
abstract final class _WatchlistColFlex {
  static const int medicineName = 220;
  static const int category = 130;
  static const int earliestBatch = 190;
  static const int totalStock = 110;
  static const int unitPrice = 110;
  static const int status = 130;
}

/// Standardized table header row (`10:49`) for the Inventory Watchlist table.
class DataTableHeaderRow extends StatelessWidget {
  const DataTableHeaderRow({super.key});

  @override
  Widget build(BuildContext context) {
    final headerStyle = MmTypography.labelSmall.copyWith(
      color: MmColors.textSecondary,
    );

    return Container(
      height: 52,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: MmSpacing.lg),
      decoration: BoxDecoration(
        color: MmColors.bgSubtle,
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: _WatchlistColFlex.medicineName,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'MEDICINE NAME',
                style: headerStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _WatchlistColFlex.category,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CATEGORY',
                style: headerStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _WatchlistColFlex.earliestBatch,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'EARLIEST BATCH (FEFO)',
                style: headerStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _WatchlistColFlex.totalStock,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'TOTAL STOCK',
                style: headerStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _WatchlistColFlex.unitPrice,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'UNIT PRICE',
                style: headerStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: MmSpacing.sm),
          Expanded(
            flex: _WatchlistColFlex.status,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'STATUS',
                style: headerStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Standardized responsive data table row for Medicine Inventory, Batch
/// Tracking, Supplier Returns, and Customer Credit (`10:107`).
class InventoryWatchlistRow extends StatelessWidget {
  final InventoryWatchlistItemData item;
  final VoidCallback? onTap;

  const InventoryWatchlistRow({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 52,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: MmSpacing.lg),
          decoration: BoxDecoration(
            color: item.rowSurface.backgroundColor,
            border: Border.all(
              color: MmColors.borderDefault,
              width: MmElevation.strokeThin,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: _WatchlistColFlex.medicineName,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.medicineName,
                    style: MmTypography.bodyMedium.copyWith(
                      color: MmColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                flex: _WatchlistColFlex.category,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.category,
                    style: MmTypography.bodyMedium.copyWith(
                      color: MmColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                flex: _WatchlistColFlex.earliestBatch,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.earliestBatchFefo,
                    style: MmTypography.codeMono.copyWith(
                      color: MmColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                flex: _WatchlistColFlex.totalStock,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.totalStock,
                    style: MmTypography.bodyMedium.copyWith(
                      color: MmColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                flex: _WatchlistColFlex.unitPrice,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    item.unitPrice,
                    style: MmTypography.codeMono.copyWith(
                      color: MmColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: MmSpacing.sm),
              Expanded(
                flex: _WatchlistColFlex.status,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(
                    label: item.statusLabel,
                    tone: item.statusTone,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
