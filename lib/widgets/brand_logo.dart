import 'package:flutter/material.dart';

/// The WareWise mark. Falls back to a placeholder icon if the asset hasn't
/// been dropped into assets/images/logo.png yet, so a missing file doesn't
/// crash the app.
class BrandLogo extends StatelessWidget {
  final double size;

  const BrandLogo({super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.inventory_2_rounded,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}
