import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/dashboard_models.dart';

/// Minimalist daily sales bar column for 7-day dashboard revenue chart (`44:80`).
class DailySalesBar extends StatelessWidget {
  final String dayLabel;
  final String formattedAmount;
  final double fillHeight;
  final double trackHeight;

  const DailySalesBar({
    super.key,
    required this.dayLabel,
    required this.formattedAmount,
    required this.fillHeight,
    this.trackHeight = 128.0,
  });

  factory DailySalesBar.fromData(DailySalesBarData data) {
    return DailySalesBar(
      dayLabel: data.dayLabel,
      formattedAmount: data.formattedAmount,
      fillHeight: data.fillHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            formattedAmount,
            style: MmTypography.codeMono.copyWith(
              color: MmColors.textMuted,
            ),
          ),
          const SizedBox(height: MmSpacing.xs),
          Container(
            width: 36,
            height: trackHeight,
            decoration: BoxDecoration(
              color: MmColors.bgSubtle,
              borderRadius: BorderRadius.circular(MmRadius.sm),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              height: fillHeight.clamp(0.0, trackHeight),
              decoration: const BoxDecoration(
                color: MmColors.bgBrand,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(MmRadius.sm),
                  topRight: Radius.circular(MmRadius.sm),
                ),
              ),
            ),
          ),
          const SizedBox(height: MmSpacing.xs),
          Text(
            dayLabel,
            style: MmTypography.labelSmall.copyWith(
              color: MmColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
