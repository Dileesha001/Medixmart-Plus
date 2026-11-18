import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_assets.dart';
import '../config/app_theme.dart';
import '../models/dashboard_models.dart';

/// Semantic status badge for stock levels, expiry return windows, FEFO batch
/// priority, and customer credit indicators (`8:42`).
class StatusBadge extends StatelessWidget {
  final String? label;
  final bool showDot;
  final StatusTone tone;

  const StatusBadge({
    super.key,
    this.label,
    this.showDot = true,
    this.tone = StatusTone.inStock,
  });

  Color get _backgroundColor {
    switch (tone) {
      case StatusTone.expired:
        return MmColors.bgDangerSubtle;
      case StatusTone.lowStock:
      case StatusTone.expiring7M:
        return MmColors.bgWarningSubtle;
      case StatusTone.inStock:
        return MmColors.bgBrandSubtle;
    }
  }

  Color get _borderColor {
    switch (tone) {
      case StatusTone.expired:
        return MmColors.borderDanger;
      case StatusTone.lowStock:
      case StatusTone.expiring7M:
        return MmColors.borderWarning;
      case StatusTone.inStock:
        return MmColors.borderBrand;
    }
  }

  Color get _textColor {
    switch (tone) {
      case StatusTone.expired:
        return MmColors.textDanger;
      case StatusTone.lowStock:
      case StatusTone.expiring7M:
        return MmColors.textWarning;
      case StatusTone.inStock:
        return MmColors.textBrand;
    }
  }

  String get _dotAsset {
    switch (tone) {
      case StatusTone.expired:
        return AppAssets.statusDotDanger;
      case StatusTone.lowStock:
      case StatusTone.expiring7M:
        return AppAssets.statusDotWarning;
      case StatusTone.inStock:
        return AppAssets.statusDotInStock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = label ?? tone.defaultLabel;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MmSpacing.sm,
        vertical: MmSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(MmRadius.full),
        border: Border.all(
          color: _borderColor,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            SizedBox(
              width: 6,
              height: 6,
              child: SvgPicture.asset(
                _dotAsset,
                width: 6,
                height: 6,
              ),
            ),
            const SizedBox(width: MmSpacing.xs),
          ],
          Text(
            effectiveLabel,
            style: MmTypography.labelSmall.copyWith(color: _textColor),
          ),
        ],
      ),
    );
  }
}
