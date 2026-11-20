import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_assets.dart';
import '../config/app_theme.dart';
import '../models/dashboard_models.dart';

/// Dashboard summary card for Today Sales, Low Stock count, Expiring Within
/// 7 Months count, and Outstanding Customer Credit (`9:43`).
class KpiSummaryCard extends StatelessWidget {
  final KpiMetricType metric;
  final String title;
  final String value;
  final String subtitle;
  final VoidCallback? onTap;

  const KpiSummaryCard({
    super.key,
    this.metric = KpiMetricType.todaySales,
    this.title = 'Outstanding Credit',
    this.value = 'Rs. 19,400.00',
    this.subtitle = '6 active customer accounts',
    this.onTap,
  });

  factory KpiSummaryCard.fromData(KpiCardData data, {VoidCallback? onTap}) {
    return KpiSummaryCard(
      metric: data.metric,
      title: data.title,
      value: data.value,
      subtitle: data.subtitle,
      onTap: onTap,
    );
  }

  Color get _iconBoxColor {
    switch (metric) {
      case KpiMetricType.todaySales:
        return MmColors.bgBrandSubtle;
      case KpiMetricType.lowStock:
        return MmColors.bgWarningSubtle;
      case KpiMetricType.expiring7M:
        return MmColors.bgDangerSubtle;
      case KpiMetricType.creditDue:
        return MmColors.bgInfoSubtle;
    }
  }

  String get _iconAsset {
    switch (metric) {
      case KpiMetricType.todaySales:
        return AppAssets.iconCart;
      case KpiMetricType.lowStock:
        return AppAssets.iconAlertTriangle;
      case KpiMetricType.expiring7M:
        return AppAssets.iconClock;
      case KpiMetricType.creditDue:
        return AppAssets.iconCreditCard;
    }
  }

  Color get _subtitleColor {
    switch (metric) {
      case KpiMetricType.todaySales:
        return MmColors.textBrand;
      case KpiMetricType.lowStock:
        return MmColors.textWarning;
      case KpiMetricType.expiring7M:
        return MmColors.textDanger;
      case KpiMetricType.creditDue:
        return MmColors.textInfo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MmRadius.lg),
        child: Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      style: MmTypography.labelMedium.copyWith(
                        color: MmColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: MmSpacing.sm),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _iconBoxColor,
                      borderRadius: BorderRadius.circular(MmRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: SvgPicture.asset(
                        _iconAsset,
                        width: 18,
                        height: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: MmSpacing.md),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: MmTypography.headingH1,
                ),
              ),
              const SizedBox(height: MmSpacing.md),
              Text(
                subtitle,
                style: MmTypography.bodySmall.copyWith(
                  color: _subtitleColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
