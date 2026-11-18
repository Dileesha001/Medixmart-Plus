import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/app_assets.dart';
import '../config/app_theme.dart';

/// POS and Inventory search bar (`7:87` / `7:71`).
class PosSearchBar extends StatelessWidget {
  final String placeholder;
  final double width;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;

  const PosSearchBar({
    super.key,
    this.placeholder = 'Search medicine by name, category, or scan barcode...',
    this.width = 520.0,
    this.controller,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.only(
        left: MmSpacing.lg,
        right: MmSpacing.md,
        top: MmSpacing.sm,
        bottom: MmSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: MmColors.bgSurface,
        borderRadius: BorderRadius.circular(MmRadius.md),
        border: Border.all(
          color: MmColors.borderDefault,
          width: MmElevation.strokeThin,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: SvgPicture.asset(
              AppAssets.iconSearch,
              width: 18,
              height: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: MmTypography.bodyMedium,
              cursorColor: MmColors.bgBrand,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: MmTypography.bodyMedium.copyWith(
                  color: MmColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
