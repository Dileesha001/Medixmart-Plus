import 'package:flutter/material.dart';
import '../config/app_theme.dart';
import 'mm_button.dart';

/// Centered loading indicator styled with Medixmart Plus brand tokens.
class MmLoadingView extends StatelessWidget {
  final String message;

  const MmLoadingView({
    super.key,
    this.message = 'Loading...',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MmSpacing.xxl,
          vertical: MmSpacing.xxxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(MmColors.bgBrand),
              ),
            ),
            const SizedBox(height: MmSpacing.md),
            Text(
              message,
              style: MmTypography.bodyMedium.copyWith(
                color: MmColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Reusable empty-list state with optional primary call-to-action.
class MmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const MmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MmSpacing.xxl,
          vertical: MmSpacing.xxxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MmColors.bgSubtle,
                  borderRadius: BorderRadius.circular(MmRadius.lg),
                  border: Border.all(
                    color: MmColors.borderDefault,
                    width: MmElevation.strokeThin,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 24,
                  color: MmColors.textSecondary,
                ),
              ),
              const SizedBox(height: MmSpacing.md),
              Text(
                title,
                style: MmTypography.headingH4,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MmSpacing.xs),
              Text(
                message,
                style: MmTypography.bodyMedium.copyWith(
                  color: MmColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: MmSpacing.lg),
                MmButton(
                  label: actionLabel!,
                  variant: MmButtonVariant.primary,
                  size: MmButtonSize.medium,
                  onPressed: onAction,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable API / network error state with retry action.
class MmErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback onRetry;

  const MmErrorState({
    super.key,
    this.title = 'Something went wrong',
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MmSpacing.xxl,
          vertical: MmSpacing.xxxl,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MmColors.bgDangerSubtle,
                  borderRadius: BorderRadius.circular(MmRadius.lg),
                  border: Border.all(
                    color: MmColors.borderDanger,
                    width: MmElevation.strokeThin,
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 24,
                  color: MmColors.textDanger,
                ),
              ),
              const SizedBox(height: MmSpacing.md),
              Text(
                title,
                style: MmTypography.headingH4,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MmSpacing.xs),
              Text(
                message,
                style: MmTypography.bodyMedium.copyWith(
                  color: MmColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MmSpacing.lg),
              MmButton(
                label: 'Retry',
                variant: MmButtonVariant.secondary,
                size: MmButtonSize.medium,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a Medixmart Plus confirmation dialog and returns `true` if confirmed.
Future<bool> showMmConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  MmButtonVariant confirmVariant = MmButtonVariant.danger,
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: MmColors.bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MmRadius.lg),
          side: const BorderSide(
            color: MmColors.borderDefault,
            width: MmElevation.strokeThin,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(MmSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: MmTypography.headingH3),
                const SizedBox(height: MmSpacing.sm),
                Text(
                  message,
                  style: MmTypography.bodyMedium.copyWith(
                    color: MmColors.textSecondary,
                  ),
                ),
                const SizedBox(height: MmSpacing.xxl),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    MmButton(
                      label: cancelLabel,
                      variant: MmButtonVariant.secondary,
                      size: MmButtonSize.medium,
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                    ),
                    const SizedBox(width: MmSpacing.sm),
                    MmButton(
                      label: confirmLabel,
                      variant: confirmVariant,
                      size: MmButtonSize.medium,
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  return result ?? false;
}
