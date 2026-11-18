import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_theme.dart';

/// Navigation item for the desktop sidebar and tablet drawer with active state
/// and optional unread alert count badge (`10:48`).
class SidebarNavItem extends StatelessWidget {
  final String label;
  final String iconAsset;
  final bool isActive;
  final int? badgeCount;
  final VoidCallback? onTap;

  const SidebarNavItem({
    super.key,
    required this.label,
    required this.iconAsset,
    this.isActive = false,
    this.badgeCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MmRadius.md),
        child: Container(
          height: 44,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: MmSpacing.md),
          decoration: BoxDecoration(
            color: isActive ? MmColors.bgBrandSubtle : MmColors.bgSurface,
            borderRadius: BorderRadius.circular(MmRadius.md),
            border: isActive
                ? Border.all(
                    color: MmColors.borderBrand,
                    width: MmElevation.strokeThin,
                  )
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: SvgPicture.asset(
                      iconAsset,
                      width: 18,
                      height: 18,
                    ),
                  ),
                  const SizedBox(width: MmSpacing.md),
                  Text(
                    label,
                    style: MmTypography.labelLarge.copyWith(
                      color:
                          isActive ? MmColors.textBrand : MmColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (badgeCount != null && badgeCount! > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: MmSpacing.xs,
                    vertical: MmSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: MmColors.bgDanger,
                    borderRadius: BorderRadius.circular(MmRadius.full),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: MmTypography.labelSmall.copyWith(
                      color: MmColors.textOnBrand,
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
