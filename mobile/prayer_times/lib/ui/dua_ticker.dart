import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/dua_rotation.dart';
import '../models/pdf_hadith_catalogue.dart';
import 'continuous_ticker.dart';
import 'prayer_period_theme.dart';

Future<DuaRotation> loadDuaRotation() async {
  final contents = await rootBundle.loadString('assets/data/dua-ticker.json');
  final original = DuaCatalogue.fromJson(jsonDecode(contents));
  final extra = parsePdfHadithCatalogue(
      jsonDecode(
          await rootBundle.loadString('assets/data/pdf-hadiths-600.json')),
      600);
  return DuaRotation(
      DuaCatalogue(
        interval: original.interval,
        groups: [
          ...original.groups,
          for (final entry in extra) DuaGroup([entry['text'] as String]),
        ],
      ),
      shuffleIndividualTexts: true);
}

class DuaTicker extends StatefulWidget {
  const DuaTicker({
    required this.palette,
    required this.rotation,
    this.textColor,
    this.scrollingEnabled = false,
    this.speed = 32,
    super.key,
  });

  final PrayerPeriodPalette palette;
  final Future<DuaRotation> rotation;
  final Color? textColor;
  final bool scrollingEnabled;
  final double speed;

  @override
  State<DuaTicker> createState() => _DuaTickerState();
}

class _DuaTickerState extends State<DuaTicker> {
  DuaRotation? _rotation;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rotation = await widget.rotation;
      if (!mounted) return;
      setState(() => _rotation = rotation);
    } catch (error, stack) {
      debugPrint('تعذّر تحميل نصوص الشريط: $error\n$stack');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.scrollingEnabled) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) => Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsets.symmetric(vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: widget.palette.ribbon,
        ),
        child: _rotation == null
            ? Text(
                _failed ? 'تعذّر تحميل نصوص الشريط' : 'جاري تحميل نصوص الشريط…',
                textDirection: TextDirection.rtl,
                style: TextStyle(
                    color: widget.textColor ?? Colors.white, fontSize: 24))
            : ContinuousTicker(
                rotation: _rotation!,
                fontSize:
                    (constraints.maxWidth / 42).clamp(24.0, 34.0).toDouble(),
                accent: widget.palette.accent,
                textColor: widget.textColor,
                pixelsPerSecond: widget.speed,
              ),
      ),
    );
  }
}
