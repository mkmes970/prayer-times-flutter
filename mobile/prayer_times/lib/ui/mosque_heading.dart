import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/english_digits.dart';

/// Each populated field occupies one centered line, without truncation.
class MosqueHeading extends StatelessWidget {
  const MosqueHeading({
    required this.settings,
    required this.style,
    super.key,
  });

  final AppSettings settings;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final nameLines = settings.mosqueNameLines;
    final lines = nameLines.isEmpty ? [settings.appName] : nameLines;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final line in lines)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              englishDigits(line),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              softWrap: false,
              style: style,
            ),
          ),
      ],
    );
  }
}
