import 'package:flutter/material.dart';
import '../config/app_assets.dart';
import '../config/app_theme.dart';

/// Official Medixmart Pharmacy circular brand logo component (`5:6`).
class BrandEmblem extends StatelessWidget {
  final double size;

  const BrandEmblem({
    super.key,
    this.size = 40.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(MmRadius.emblem),
        child: Image.asset(
          AppAssets.brandEmblem,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
