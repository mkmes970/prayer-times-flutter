import 'package:flutter/material.dart';

/// Only shown while the dashboard has no selected timetable.
class RegionSelectionNotice extends StatelessWidget {
  const RegionSelectionNotice({
    required this.visible,
    this.fontSize = 24,
    super.key,
  });

  final bool visible;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'اختر المنطقة من الإعدادات',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(
            color: const Color(0xFFD50000),
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
            shadows: const [
              Shadow(color: Color(0xB3FF1744), blurRadius: 8),
              Shadow(color: Color(0x66FF1744), blurRadius: 18),
            ],
          ),
        ),
      ),
    );
  }
}
