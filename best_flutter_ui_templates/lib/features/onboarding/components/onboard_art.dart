import 'package:flutter/material.dart';

/// Icon-in-circle artwork used in place of the original image assets,
/// styled to match the LifeHub theme.
class OnboardArt extends StatelessWidget {
  const OnboardArt({
    super.key,
    required this.icon,
    required this.color,
    this.size = 220,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.78,
      child: Center(
        child: Container(
          width: size * 0.62,
          height: size * 0.62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.10),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 24,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: size * 0.44,
              height: size * 0.44,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              child: Icon(icon, size: size * 0.24, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
