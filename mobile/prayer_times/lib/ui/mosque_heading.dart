import 'package:flutter/material.dart';

import '../models/app_settings.dart';
import '../models/english_digits.dart';

/// Three fixed slots: leaving a field empty never moves the other lines.
class MosqueHeading extends StatelessWidget {
  const MosqueHeading({
    required this.settings,
    required this.style,
    this.fitLines = true,
    super.key,
  });

  final AppSettings settings;
  final TextStyle style;
  final bool fitLines;

  @override
  Widget build(BuildContext context) {
    final lines = [
      settings.mosqueName.trim(),
      settings.mosqueNameLine2.trim(),
      settings.mosqueNameLine3.trim(),
    ];
    if (lines.every((line) => line.isEmpty)) lines[0] = settings.appName;
    return LayoutBuilder(
      builder: (context, constraints) => Column(
        mainAxisSize:
            constraints.hasBoundedHeight ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < lines.length; index++)
            if (constraints.hasBoundedHeight)
              Expanded(child: _slot(lines[index], index))
            else
              SizedBox(
                height: MediaQuery.textScalerOf(context)
                        .scale(style.fontSize ?? 14) *
                    (style.height ?? 1.4),
                child: _slot(lines[index], index),
              ),
        ],
      ),
    );
  }

  Widget _slot(String line, int index) => SizedBox.expand(
        key: ValueKey('mosque-heading-slot-${index + 1}'),
        child: line.isEmpty ? null : _line(line),
      );

  Widget _line(String line) {
    final text = Text(
      englishDigits(line),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
      maxLines: 1,
      softWrap: false,
      style: style,
    );
    return fitLines
        ? FittedBox(fit: BoxFit.scaleDown, child: text)
        : Align(alignment: Alignment.center, child: text);
  }
}
