import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_theme.dart';

enum MmButtonVariant { primary, secondary, danger }

enum MmButtonSize { small, medium, large }

/// Medixmart Plus Button component set (`6:114`).
/// Supports Small/Medium/Large sizes and Primary/Secondary/Danger styles.
class MmButton extends StatelessWidget {
  final String label;
  final String? leadingIconAsset;
  final MmButtonVariant variant;
  final MmButtonSize size;
  final VoidCallback? onPressed;

  const MmButton({
    super.key,
    required this.label,
    this.leadingIconAsset,
    this.variant = MmButtonVariant.primary,
    this.size = MmButtonSize.medium,
    this.onPressed,
  });

  Color get _backgroundColor {
    switch (variant) {
      case MmButtonVariant.primary:
        return MmColors.bgBrand;
      case MmButtonVariant.secondary:
        return MmColors.bgSurface;
      case MmButtonVariant.danger:
        return MmColors.bgDanger;
    }
  }

  Color get _textColor {
    switch (variant) {
      case MmButtonVariant.primary:
      case MmButtonVariant.danger:
        return MmColors.textOnBrand;
      case MmButtonVariant.secondary:
        return MmColors.textPrimary;
    }
  }

  Border? get _border {
    if (variant == MmButtonVariant.secondary) {
      return Border.all(
        color: MmColors.borderDefault,
        width: MmElevation.strokeThin,
      );
    }
    return null;
  }

  EdgeInsetsGeometry get _padding {
    switch (size) {
      case MmButtonSize.small:
        return const EdgeInsets.symmetric(
          horizontal: MmSpacing.md,
          vertical: MmSpacing.xs,
        );
      case MmButtonSize.medium:
        return const EdgeInsets.symmetric(
          horizontal: MmSpacing.lg,
          vertical: MmSpacing.sm,
        );
      case MmButtonSize.large:
        return const EdgeInsets.symmetric(
          horizontal: MmSpacing.xl,
          vertical: MmSpacing.md,
        );
    }
  }

  double get _iconSize {
    switch (size) {
      case MmButtonSize.small:
        return 14.0;
      case MmButtonSize.medium:
        return 16.0;
      case MmButtonSize.large:
        return 18.0;
    }
  }

  double get _gap {
    switch (size) {
      case MmButtonSize.small:
        return MmSpacing.xs;
      case MmButtonSize.medium:
      case MmButtonSize.large:
        return MmSpacing.sm;
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case MmButtonSize.small:
        return MmTypography.labelSmall.copyWith(color: _textColor);
      case MmButtonSize.medium:
        return MmTypography.labelMedium.copyWith(color: _textColor);
      case MmButtonSize.large:
        return MmTypography.labelLarge.copyWith(color: _textColor);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(MmRadius.md),
        child: Container(
          padding: _padding,
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(MmRadius.md),
            border: _border,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (leadingIconAsset != null) ...[
                SizedBox(
                  width: _iconSize,
                  height: _iconSize,
                  child: SvgPicture.asset(
                    leadingIconAsset!,
                    width: _iconSize,
                    height: _iconSize,
                  ),
                ),
                SizedBox(width: _gap),
              ],
              Text(
                label,
                style: _textStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
