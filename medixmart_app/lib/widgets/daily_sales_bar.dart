import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import '../models/dashboard_models.dart';

/// Minimalist daily sales bar column for 7-day dashboard revenue chart (`44:80`).
class DailySalesBar extends StatelessWidget {
  final String dayLabel;
  final String formattedAmount;
  final double fillHeight;
  final double trackHeight;
  final double? width;

  const DailySalesBar({
    super.key,
    required this.dayLabel,
    required this.formattedAmount,
    required this.fillHeight,
    this.trackHeight = 128.0,
    this.width,
  });

  factory DailySalesBar.fromData(
    DailySalesBarData data, {
    double? width,
  }) {
    return DailySalesBar(
      dayLabel: data.dayLabel,
      formattedAmount: data.formattedAmount,
      fillHeight: data.fillHeight,
      width: width,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double slotWidth;
        if (width != null) {
          slotWidth = width!;
        } else if (constraints.maxWidth.isFinite) {
          slotWidth = constraints.maxWidth.clamp(28.0, 64.0);
        } else {
          slotWidth = 64.0;
        }
        final barWidth = (slotWidth * 0.5625).clamp(16.0, 36.0);

        return SizedBox(
          width: slotWidth,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  formattedAmount,
                  style: MmTypography.codeMono.copyWith(
                    color: MmColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: MmSpacing.xs),
              Container(
                width: barWidth,
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  dayLabel,
                  style: MmTypography.labelSmall.copyWith(
                    color: MmColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
