import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_assets.dart';
import '../config/app_theme.dart';
import '../models/dashboard_models.dart';
import 'status_badge.dart';

/// Clean, minimalist alert item used in the dashboard alerts card (`44:121`).
class AlertFeedItem extends StatelessWidget {
  final String title;
  final String meta;
  final StatusTone tone;
  final String? badgeLabel;
  final VoidCallback? onTap;

  const AlertFeedItem({
    super.key,
    this.title = 'Amoxicillin 250mg Cap',
    this.meta = '04 Packs left · Reorder at 15',
    this.tone = StatusTone.lowStock,
    this.badgeLabel,
    this.onTap,
  });

  factory AlertFeedItem.fromData(AlertItemData data, {VoidCallback? onTap}) {
    return AlertFeedItem(
      title: data.title,
      meta: data.meta,
      tone: data.tone,
      badgeLabel: data.badgeLabel,
      onTap: onTap,
    );
  }

  Color get _iconBoxColor {
    switch (tone) {
      case StatusTone.expired:
        return MmColors.bgDangerSubtle;
      case StatusTone.expiring7M:
        return MmColors.bgInfoSubtle;
      case StatusTone.lowStock:
      case StatusTone.inStock:
        return MmColors.bgWarningSubtle;
    }
  }

  String get _iconAsset {
    switch (tone) {
      case StatusTone.expired:
        return AppAssets.iconAlertTriangle;
      case StatusTone.expiring7M:
        return AppAssets.iconClock;
      case StatusTone.lowStock:
      case StatusTone.inStock:
        return AppAssets.iconPackage;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MmRadius.md),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: MmSpacing.md,
            vertical: MmSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: MmColors.bgSubtle,
            borderRadius: BorderRadius.circular(MmRadius.md),
            border: Border.all(
              color: MmColors.borderDefault,
              width: MmElevation.strokeThin,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _iconBoxColor,
                        borderRadius: BorderRadius.circular(MmRadius.sm),
                      ),
                      alignment: Alignment.center,
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: SvgPicture.asset(
                          _iconAsset,
                          width: 16,
                          height: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: MmSpacing.sm),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: MmTypography.labelMedium.copyWith(
                              color: MmColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: MmSpacing.xxs),
                          Text(
                            meta,
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
              const SizedBox(width: MmSpacing.sm),
              StatusBadge(
                label: badgeLabel ?? tone.defaultLabel,
                tone: tone,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
