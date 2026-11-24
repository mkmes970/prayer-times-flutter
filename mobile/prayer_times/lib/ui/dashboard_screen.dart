import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/friday_hadith_window.dart';
import '../models/prayer_schedule.dart';
import '../models/morning_adhkar.dart';
import '../services/date_format.dart';
import '../services/countdown_format.dart';
import '../services/hijri_date.dart';
import '../state/prayer_controller.dart';
import 'dua_ticker.dart';
import 'region_selection_notice.dart';
import 'hadith_panel.dart';
import 'prayer_activity_screen.dart';
import 'prayer_period_theme.dart';
import 'settings_screen.dart';
import 'theme_catalog.dart';
import 'ramadan_screen.dart';
import 'mosque_heading.dart';
import '../models/dashboard_font_levels.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.controller,
    this.previewTheme,
    super.key,
  });

  final PrayerController controller;
  final DashboardTheme? previewTheme;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _hadithBoundaryKey = GlobalKey();
  bool _hadithVisible = false;
  bool _ramadanPromptOpen = false;
  String? _dismissedRamadanPrompt;
  DateTime? _ramadanPromptDismissedAt;

  void _offerRamadanChoice(DateTime now, PrayerScreenStatus? activity) {
    if (widget.previewTheme != null ||
        _ramadanPromptOpen ||
        activity?.phase != PrayerScreenPhase.ramadanWelcome ||
        !controller.needsRamadanChoice ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final hijri = controller.hijriDateAt(now);
    final key = '${controller.selectedRegionId}:${hijri.year}';
    if (_dismissedRamadanPrompt == key) return;
    _ramadanPromptOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        if (!controller.needsRamadanChoice ||
            ModalRoute.of(context)?.isCurrent == false) {
          return;
        }
        await Navigator.of(context).push<bool>(MaterialPageRoute(
            builder: (_) => RamadanScreen(controller: controller)));
        _dismissedRamadanPrompt = key;
        _ramadanPromptDismissedAt = controller.now;
      } finally {
        _ramadanPromptOpen = false;
      }
    });
  }

  void _onHadithVisibilityChanged(bool visible) {
    if (mounted && _hadithVisible != visible) {
      setState(() => _hadithVisible = visible);
    }
  }

  PrayerController get controller => widget.controller;

  // Retain the current author block while the prayer screen hides the strip.
  late final _duaRotation = loadDuaRotation();

  Future<void> _openSettings(BuildContext context) async {
    if (controller.settings.hasPin) {
      final pin = await _askForPin(context);
      if (pin == null || !controller.verifyPin(pin)) {
        if (pin != null && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('رمز PIN غير صحيح.')));
        }
        return;
      }
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SettingsScreen(controller: controller),
      ),
    );
  }

  Future<String?> _askForPin(BuildContext context) async {
    final field = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('رمز إدارة الإعدادات'),
        content: TextField(
          controller: field,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(labelText: 'رمز PIN'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, field.text),
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([controller.clock, controller]),
      builder: (context, _) {
        final now = controller.now;
        final preview = widget.previewTheme != null;
        final hijri = controller.hijriDateAt(now);
        final ramadanKey = '${controller.selectedRegionId}:${hijri.year}';
        final dismissed = _dismissedRamadanPrompt == ramadanKey;
        final activity = preview
            ? null
            : controller.activePrayerScreen(
                now,
                ramadanWelcomeDismissed: dismissed,
                ramadanWelcomeDismissedAt:
                    dismissed ? _ramadanPromptDismissedAt : null,
              );
        _offerRamadanChoice(now, activity);
        final design = widget.previewTheme ??
            themeForPeriod(
              prayerPeriodAt(now, controller.selectedRegion?.timesFor(now)),
              controller.settings,
            );
        final palette = design.palette.copyWith(
          ink: controller.dashboardTextColor == null
              ? design.palette.ink
              : Color(controller.dashboardTextColor!),
        );
        // Keep independent hadith/dua playback mounted beneath opaque alerts.
        // Transient prayer alerts must not restart the numbered collection.
        final dashboard = Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (design.backgroundAsset != null)
                Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      design.backgroundAsset!,
                      fit: BoxFit.fill,
                      excludeFromSemantics: true,
                    ),
                    CustomPaint(
                      painter: _MosquePainter(
                        palette,
                        decorationsOnly: true,
                      ),
                    ),
                  ],
                )
              else
                _MosqueBackdrop(palette: palette),
              SizedBox.expand(
                child: LayoutBuilder(builder: (context, screenConstraints) {
                  final displayHeight = screenConstraints.maxWidth > 0
                      ? (1024 *
                              screenConstraints.maxHeight /
                              screenConstraints.maxWidth)
                          .clamp(420.0, 576.0)
                          .toDouble()
                      : 576.0;
                  return FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: 1024,
                      height: displayHeight,
                      child: MediaQuery(
                        data: MediaQuery.of(context)
                            .copyWith(size: Size(1024, displayHeight)),
                        child: Column(
                          children: [
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final landscape = constraints.maxWidth >
                                      constraints.maxHeight;
                                  return Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      landscape ? 22 : 14,
                                      preview ? 58 : (landscape ? 18 : 14),
                                      landscape ? 22 : 14,
                                      0,
                                    ),
                                    child: Stack(
                                      children: [
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(top: 10),
                                          child: _DashboardContent(
                                            controller: controller,
                                            now: now,
                                            landscape: landscape,
                                            width: constraints.maxWidth,
                                            palette: palette,
                                            showHadith: !preview,
                                            hadithBoundaryKey:
                                                _hadithBoundaryKey,
                                            onHadithVisibilityChanged:
                                                _onHadithVisibilityChanged,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 4),
                            DuaTicker(
                              palette: palette,
                              rotation: _duaRotation,
                              textColor: controller.dashboardTextColor == null
                                  ? null
                                  : Color(controller.dashboardTextColor!),
                              scrollingEnabled:
                                  controller.settings.tickerScrollingEnabled,
                              speed: controller.settings.tickerSpeed,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            ExcludeFocus(
              excluding: activity != null,
              child: ExcludeSemantics(
                excluding: activity != null,
                child: dashboard,
              ),
            ),
            if (activity != null)
              Positioned.fill(
                child: PrayerActivityScreen(status: activity, now: now),
              ),
            Positioned.fill(
              child: LayoutBuilder(builder: (context, constraints) {
                final displayHeight = constraints.maxWidth > 0
                    ? (1024 * constraints.maxHeight / constraints.maxWidth)
                        .clamp(420.0, 576.0)
                        .toDouble()
                    : 576.0;
                return FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: 1024,
                    height: displayHeight,
                    child: Stack(
                      children: [
                        if (!preview)
                          Positioned(
                            left: 22,
                            top: 18,
                            child: _SettingsButton(
                              onPressed: () => _openSettings(context),
                              palette: palette,
                            ),
                          ),
                        if (preview)
                          Positioned(
                            right: 16,
                            top: 12,
                            child: Material(
                              color: palette.ribbon,
                              shape: const CircleBorder(),
                              child: IconButton(
                                tooltip: 'الرجوع من المعاينة',
                                color: palette.softGold,
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({required this.onPressed, required this.palette});

  final VoidCallback onPressed;
  final PrayerPeriodPalette palette;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'إعدادات التطبيق',
      child: Material(
        color: palette.ribbon,
        shape: CircleBorder(
          side: BorderSide(color: palette.accent, width: 1.5),
        ),
        child: IconButton(
          autofocus: true,
          visualDensity: VisualDensity.compact,
          onPressed: onPressed,
          icon: Icon(Icons.settings_outlined, color: palette.accent, size: 18),
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          tooltip: 'إعدادات التطبيق',
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.controller,
    required this.now,
    required this.landscape,
    required this.width,
    required this.palette,
    required this.hadithBoundaryKey,
    required this.onHadithVisibilityChanged,
    this.showHadith = true,
  });

  final PrayerController controller;
  final DateTime now;
  final bool landscape;
  final double width;
  final PrayerPeriodPalette palette;
  final GlobalKey hadithBoundaryKey;
  final ValueChanged<bool> onHadithVisibilityChanged;
  final bool showHadith;

  @override
  Widget build(BuildContext context) {
    if (landscape && width > 650) {
      return Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 35,
            child: _PrayerList(
              controller: controller,
              now: now,
              compact: true,
              palette: palette,
              hadithBoundaryKey: hadithBoundaryKey,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 65,
            child: _MainInformation(
              controller: controller,
              now: now,
              compact: true,
              showCountdown: true,
              showHadith: showHadith,
              palette: palette,
              hadithBoundaryKey: hadithBoundaryKey,
              onHadithVisibilityChanged: onHadithVisibilityChanged,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _MainInformation(
          controller: controller,
          now: now,
          compact: false,
          showCountdown: false,
          showHadith: showHadith,
          palette: palette,
          onHadithVisibilityChanged: onHadithVisibilityChanged,
        ),
        const SizedBox(height: 8),
        Expanded(
          child: _PrayerList(
            controller: controller,
            now: now,
            compact: false,
            palette: palette,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: _CountdownStrip(
            controller: controller,
            now: now,
            scale: 1,
            compact: false,
          ),
        ),
      ],
    );
  }
}

class _MainInformation extends StatelessWidget {
  const _MainInformation({
    required this.controller,
    required this.now,
    required this.compact,
    required this.showCountdown,
    required this.palette,
    this.hadithBoundaryKey,
    required this.onHadithVisibilityChanged,
    this.showHadith = true,
  });

  final PrayerController controller;
  final DateTime now;
  final bool compact;
  final bool showCountdown;
  final PrayerPeriodPalette palette;
  final GlobalKey? hadithBoundaryKey;
  final ValueChanged<bool> onHadithVisibilityChanged;
  final bool showHadith;

  @override
  Widget build(BuildContext context) {
    final pine = palette.ink;
    final scale = DashboardFontLevels.nameRatio(controller.settings.fontScale);
    final clockScale =
        DashboardFontLevels.clockRatio(controller.settings.clockScale);
    final hijri = controller.hijriDateAt(now);
    final gregorianParts = formatGregorianDate(now).split('/');
    final mq = MediaQuery.sizeOf(context);
    final prayerNameSize =
        compact ? math.min(mq.width * 0.032, mq.height * 0.066) : 30.0;
    final clockSize = prayerNameSize * clockScale;
    final labelSize = prayerNameSize;
    final dateScale = clockSize / (compact ? 30.5 : 28.5);

    // This group takes its natural height and stays anchored above the timer.
    // Increasing its font size consumes space upward, never below the Hijri date.
    final information = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        RegionSelectionNotice(
          visible: controller.selectedRegion == null,
          fontSize: (compact ? 22.0 : 26.0),
        ),
        if (controller.selectedRegion != null &&
            _needsBaghdadNotice(controller, now))
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Text(
              'تحقق من ضبط المنطقة الزمنية على Asia/Baghdad',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: palette.ink,
                fontSize: 12.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        Text(
          _formatClock(
            now,
            seconds: true,
            use24Hour: controller.settings.use24HourClock,
          ),
          textDirection: TextDirection.ltr,
          style: TextStyle(
            color: pine,
            fontSize: clockSize,
            fontWeight: FontWeight.w800,
            height: 1.05,
            letterSpacing: 1.5,
            shadows: const [],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _weekdayName(now.weekday),
          style: TextStyle(
            color: pine,
            fontWeight: FontWeight.bold,
            fontSize: labelSize * clockScale,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        _GregorianDateLabel(
          parts: gregorianParts,
          compact: compact,
          scale: dateScale,
          palette: palette,
        ),
        if (controller.settings.showHijriDate) const SizedBox(height: 6),
        if (controller.settings.showHijriDate)
          _HijriDateLabel(
            date: hijri,
            compact: compact,
            scale: dateScale,
            palette: palette,
          ),
      ],
    );
    final maghribTime = controller.selectedRegion?.timesFor(now)?['maghrib'];
    final maghribParts = maghribTime?.split(':');
    final maghribAt = maghribParts == null
        ? null
        : DateTime(now.year, now.month, now.day, int.parse(maghribParts[0]),
            int.parse(maghribParts[1]));
    final eveningEnd = maghribAt?.subtract(const Duration(minutes: 5));
    final todayTimes = controller.selectedRegion?.timesFor(now);
    DateTime? timeAt(String key) {
      final parts = todayTimes?[key]?.split(':');
      return parts == null
          ? null
          : DateTime(now.year, now.month, now.day, int.parse(parts[0]),
              int.parse(parts[1]));
    }

    final fajrAt = timeAt('fajrSecond');
    final sunriseAt = timeAt('sunrise');
    final fajrWait = controller.settings.iqamaMinutes['fajrSecond'];
    final morningStart = morningStartsAt(
        fajrAt,
        fajrWait,
        controller.settings.prayerDurationMinutes['fajrSecond'] ?? 0,
        controller.settings.postPrayerDhikrMinutes ?? 0);
    final morningEnd = sunriseAt;
    final fridayMode = isFridayHadithWindow(now,
        morningEndsAt: sunriseAt, dhuhrAt: timeAt('dhuhr'));
    final informationPanel = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final headingSize = prayerNameSize * scale;
          return Column(
            children: [
              Expanded(
                child: ClipRect(
                  key: const ValueKey('dashboard-mosque-area'),
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: 0,
                    maxHeight: double.infinity,
                    minWidth: constraints.maxWidth,
                    maxWidth: constraints.maxWidth,
                    child: MosqueHeading(
                      settings: controller.settings,
                      fitLines: false,
                      style: TextStyle(
                        color: pine,
                        fontSize: headingSize,
                        fontWeight: FontWeight.bold,
                        height: 1.05,
                        shadows: const [],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                key: const ValueKey('dashboard-clock-calendars'),
                width: constraints.maxWidth,
                child: information,
              ),
            ],
          );
        },
      ),
    );
    final panel = !showHadith
        ? informationPanel
        : HadithPanel(
            now: now,
            adhanBlocked: controller.activePrayerScreen(now) != null,
            morningStartsAt: morningStart,
            morningEndsAt: morningEnd,
            adhanTimes: [
              for (final day in [now, now.add(const Duration(days: 1))])
                for (final entry
                    in (controller.selectedRegion?.timesFor(day)?.values ??
                            <String, String>{})
                        .entries)
                  if (entry.key != 'sunrise')
                    DateTime(
                        day.year,
                        day.month,
                        day.day,
                        int.parse(entry.value.split(':')[0]),
                        int.parse(entry.value.split(':')[1])),
            ],
            eveningMaghribAt: maghribAt,
            eveningEndsAt: eveningEnd,
            enabled: controller.settings.hadithEnabled,
            fridayMode: fridayMode,
            ramadanMode: controller.hijriDateAt(now).month == 9,
            rightBoundaryKey: hadithBoundaryKey,
            onVisibilityChanged: onHadithVisibilityChanged,
            child: informationPanel,
          );
    if (!showCountdown) {
      return SizedBox(height: 240, child: panel);
    }
    return Column(
      children: [
        Expanded(child: panel),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: _CountdownStrip(
            controller: controller,
            now: now,
            scale: 1,
            compact: compact,
          ),
        ),
      ],
    );
  }
}

class _HijriDateLabel extends StatelessWidget {
  const _HijriDateLabel({
    required this.date,
    required this.compact,
    required this.scale,
    required this.palette,
  });

  final HijriDate date;
  final bool compact;
  final double scale;
  final PrayerPeriodPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = _dateStyle(compact, scale, palette);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          Text('${date.day}', style: style, textDirection: TextDirection.ltr),
          Text('/', style: style, textDirection: TextDirection.ltr),
          Text(
            '${hijriMonthNames[date.month - 1]} (${date.month})',
            style: style,
            textDirection: TextDirection.rtl,
          ),
          Text('/', style: style, textDirection: TextDirection.ltr),
          Text('${date.year}', style: style, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

class _GregorianDateLabel extends StatelessWidget {
  const _GregorianDateLabel({
    required this.parts,
    required this.compact,
    required this.scale,
    required this.palette,
  });

  final List<String> parts;
  final bool compact;
  final double scale;
  final PrayerPeriodPalette palette;

  @override
  Widget build(BuildContext context) {
    final style = _dateStyle(compact, scale, palette);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: TextDirection.rtl,
        children: [
          Text(parts[0], style: style, textDirection: TextDirection.ltr),
          Text('/', style: style, textDirection: TextDirection.ltr),
          Text(parts[1], style: style, textDirection: TextDirection.ltr),
          Text('/', style: style, textDirection: TextDirection.ltr),
          Text(parts[2], style: style, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

TextStyle _dateStyle(bool compact, double scale, PrayerPeriodPalette palette) =>
    TextStyle(
      color: palette.ink,
      fontSize: (compact ? 30.5 : 28.5) * scale,
      fontWeight: FontWeight.w700,
      height: 1.05,
    );

class _CountdownStrip extends StatelessWidget {
  const _CountdownStrip({
    required this.controller,
    required this.now,
    required this.scale,
    required this.compact,
  });

  final PrayerController controller;
  final DateTime now;
  final double scale;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = controller.countdownStatus(now);
    final title = status.kind == DashboardStatusKind.iqama
        ? 'الوقت المتبقي للإقامة'
        : status.kind == DashboardStatusKind.nextEvent
            ? 'باقي لأذان ${status.label}'
            : 'باقي للأذان';
    final value = status.target == null
        ? '--:--:--'
        : formatCountdownDuration(status.remainingAt(now)!);
    return _CountdownCard(
      title: title,
      value: value,
      compact: compact,
      scale: scale,
      textColor: controller.dashboardTextColor,
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.title,
    required this.value,
    required this.compact,
    required this.scale,
    this.textColor,
  });

  final String title;
  final String value;
  final bool compact;
  final double scale;
  final int? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        minHeight: compact ? MediaQuery.sizeOf(context).height * 0.16 : 72,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF123D30),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220D301F),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            flex: 4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor == null ? Colors.white : Color(textColor!),
                  fontSize: (compact ? 28.0 : 26.0) * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Container(
            width: 1.5,
            height: compact ? MediaQuery.sizeOf(context).height * 0.10 : 42,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.white.withValues(alpha: .5),
          ),
          Expanded(
            flex: 6,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: textColor == null ? Colors.white : Color(textColor!),
                  fontWeight: FontWeight.w800,
                  fontSize: (compact ? 50.0 : 42.0) * scale,
                  height: 1.08,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerList extends StatelessWidget {
  const _PrayerList({
    required this.controller,
    required this.now,
    required this.compact,
    required this.palette,
    this.hadithBoundaryKey,
  });

  final PrayerController controller;
  final DateTime now;
  final bool compact;
  final PrayerPeriodPalette palette;
  final GlobalKey? hadithBoundaryKey;

  @override
  Widget build(BuildContext context) {
    final times = controller.selectedRegion?.timesFor(now);
    const scale = 1.0;
    return Column(
      children: [
        for (final slot in prayerSlots)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _PrayerRow(
                slot: slot,
                time: times?[slot.id],
                active: controller.highlightedPrayerId(now) == slot.id,
                compact: compact,
                scale: scale,
                use24Hour: controller.settings.use24HourClock,
                palette: palette,
                hadithBoundaryKey:
                    slot.id == prayerSlots.first.id ? hadithBoundaryKey : null,
              ),
            ),
          ),
      ],
    );
  }
}

class _PrayerRow extends StatelessWidget {
  const _PrayerRow({
    required this.slot,
    required this.time,
    required this.active,
    required this.compact,
    required this.scale,
    required this.use24Hour,
    required this.palette,
    this.hadithBoundaryKey,
  });

  final PrayerSlot slot;
  final String? time;
  final bool active;
  final bool compact;
  final double scale;
  final bool use24Hour;
  final PrayerPeriodPalette palette;
  final GlobalKey? hadithBoundaryKey;

  @override
  Widget build(BuildContext context) {
    final pine = palette.ink;
    final height = compact ? 42.0 : 51.0;
    final displaySize = MediaQuery.sizeOf(context);
    final boxHeight = compact ? displaySize.height * 0.08 : 42.0;
    final nameSize = compact
        ? math.min(displaySize.width * 0.032, displaySize.height * 0.066)
        : 30.0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      height: height,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
      decoration: BoxDecoration(
        color: active ? palette.rowSurface : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: active ? Border.all(color: palette.accent, width: 1.5) : null,
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                slot.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: pine,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w700,
                  fontSize: nameSize * scale,
                  height: 1,
                  shadows: [Shadow(color: palette.card, blurRadius: 3)],
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 7 : 10),
          Container(
            width: compact ? 97 : 94,
            height: boxHeight,
            alignment: Alignment.center,
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 12,
              vertical: compact ? 4 : 6,
            ),
            decoration: BoxDecoration(
              color: palette.ribbon,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: active
                    ? palette.accent
                    : palette.accent.withValues(alpha: 0.65),
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                time == null ? '--:--' : _formatPrayerTime(time!, use24Hour),
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: const Color(0xFFFFF5DE),
                  fontSize: (compact
                          ? math.min(displaySize.width * 0.029,
                              displaySize.height * 0.061)
                          : 28.0) *
                      scale,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                ),
              ),
            ),
          ),
          SizedBox(width: compact ? 5 : 9),
          Container(
            key: hadithBoundaryKey,
            width: compact ? 38 : 37,
            height: boxHeight,
            decoration: BoxDecoration(
              color: palette.ribbon,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.accent, width: 1),
            ),
            child: Icon(
              _iconFor(slot.id),
              color: palette.accent,
              size: compact ? 19 : 22,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(String id) => switch (id) {
      'fajrFirst' => Icons.nightlight_outlined,
      'fajrSecond' => Icons.nightlight_round,
      'sunrise' => Icons.wb_twilight,
      'dhuhr' => Icons.wb_sunny_outlined,
      'asr' => Icons.cloud_outlined,
      'maghrib' => Icons.wb_twilight,
      _ => Icons.nights_stay_outlined,
    };

class _MosqueBackdrop extends StatelessWidget {
  const _MosqueBackdrop({required this.palette});

  final PrayerPeriodPalette palette;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MosquePainter(palette),
      child: const SizedBox.expand(),
    );
  }
}

class _MosquePainter extends CustomPainter {
  _MosquePainter(
    this.palette, {
    this.decorationsOnly = false,
  });

  final PrayerPeriodPalette palette;
  final bool decorationsOnly;

  @override
  void paint(Canvas canvas, Size size) {
    if (decorationsOnly) {
      _drawCelestialLight(canvas, size);
      return;
    }
    final rect = Offset.zero & size;
    final sky = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [palette.skyTop, palette.skyMiddle, palette.skyBottom],
        stops: const [0, 0.58, 1],
      ).createShader(rect);
    canvas.drawRect(rect, sky);

    _drawCelestialLight(canvas, size);

    // A quiet two-depth skyline gives the domes a deliberate central rhythm,
    // while keeping their translucent shapes well below the prayer readout.
    final scale = math.min(size.width, size.height * 2);
    final distantPaint = Paint()
      ..color = palette.mosque.withValues(alpha: palette.night ? 0.15 : 0.13);
    final mosquePaint = Paint()
      ..color = palette.mosque.withValues(alpha: palette.night ? 0.32 : 0.20);
    final detailPaint = Paint()
      ..color = palette.mosque.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = math.max(0.8, scale * 0.0018);
    final rearGround = size.height * 0.91;
    final groundY = size.height * 0.94;

    // Distant low roofline and small domes soften the horizon without forming
    // a repeated row of identical arches.
    canvas.drawRect(
      Rect.fromLTRB(0, rearGround, size.width, size.height),
      distantPaint,
    );
    _drawDome(
      canvas,
      Offset(size.width * 0.20, rearGround),
      scale * 0.105,
      distantPaint,
      detailPaint: detailPaint,
      detail: false,
    );
    _drawDome(
      canvas,
      Offset(size.width * 0.80, rearGround),
      scale * 0.105,
      distantPaint,
      detailPaint: detailPaint,
      detail: false,
    );
    _drawMinaret(
      canvas,
      Offset(size.width * 0.075, rearGround),
      math.min(size.height * 0.20, scale * 0.18),
      distantPaint,
      detailPaint: detailPaint,
    );
    _drawMinaret(
      canvas,
      Offset(size.width * 0.925, rearGround),
      math.min(size.height * 0.20, scale * 0.18),
      distantPaint,
      detailPaint: detailPaint,
    );

    // The central prayer hall anchors a compact, overlapping dome cluster:
    // one broad crown, paired shoulders and two low outer caps.
    final hall = Path()
      ..moveTo(size.width * 0.12, groundY)
      ..lineTo(size.width * 0.12, groundY - scale * 0.045)
      ..quadraticBezierTo(
        size.width * 0.20,
        groundY - scale * 0.055,
        size.width * 0.28,
        groundY - scale * 0.045,
      )
      ..lineTo(size.width * 0.28, groundY - scale * 0.030)
      ..lineTo(size.width * 0.72, groundY - scale * 0.030)
      ..lineTo(size.width * 0.72, groundY - scale * 0.045)
      ..quadraticBezierTo(
        size.width * 0.80,
        groundY - scale * 0.055,
        size.width * 0.88,
        groundY - scale * 0.045,
      )
      ..lineTo(size.width * 0.88, groundY)
      ..close();
    canvas.drawPath(hall, mosquePaint);

    final roofline = Paint()
      ..color = palette.mosque.withValues(alpha: 0.18)
      ..strokeWidth = math.max(1, scale * 0.003)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.12, groundY - scale * 0.045),
      Offset(size.width * 0.88, groundY - scale * 0.045),
      roofline,
    );

    _drawMinaret(
      canvas,
      Offset(size.width * 0.12, groundY),
      math.min(size.height * 0.29, scale * 0.28),
      mosquePaint,
      detailPaint: detailPaint,
    );
    _drawMinaret(
      canvas,
      Offset(size.width * 0.88, groundY),
      math.min(size.height * 0.29, scale * 0.28),
      mosquePaint,
      detailPaint: detailPaint,
    );
    _drawMinaret(
      canvas,
      Offset(size.width * 0.30, groundY - scale * 0.045),
      math.min(size.height * 0.18, scale * 0.17),
      mosquePaint,
      detailPaint: detailPaint,
    );
    _drawMinaret(
      canvas,
      Offset(size.width * 0.70, groundY - scale * 0.045),
      math.min(size.height * 0.18, scale * 0.17),
      mosquePaint,
      detailPaint: detailPaint,
    );

    _drawDome(
      canvas,
      Offset(size.width * 0.23, groundY - scale * 0.035),
      scale * 0.12,
      mosquePaint,
      detailPaint: detailPaint,
    );
    _drawDome(
      canvas,
      Offset(size.width * 0.38, groundY - scale * 0.035),
      scale * 0.155,
      mosquePaint,
      detailPaint: detailPaint,
    );
    _drawDome(
      canvas,
      Offset(size.width * 0.50, groundY - scale * 0.035),
      scale * 0.205,
      mosquePaint,
      detailPaint: detailPaint,
    );
    _drawDome(
      canvas,
      Offset(size.width * 0.62, groundY - scale * 0.035),
      scale * 0.155,
      mosquePaint,
      detailPaint: detailPaint,
    );
    _drawDome(
      canvas,
      Offset(size.width * 0.77, groundY - scale * 0.035),
      scale * 0.12,
      mosquePaint,
      detailPaint: detailPaint,
    );
  }

  void _drawCelestialLight(Canvas canvas, Size size) {
    final period = palette.period;
    final isMoon = period == PrayerPeriod.fajr || period == PrayerPeriod.isha;
    final center = switch (period) {
      PrayerPeriod.fajr => Offset(size.width * 0.56, size.height * 0.18),
      PrayerPeriod.sunrise => Offset(size.width * 0.57, size.height * 0.69),
      PrayerPeriod.dhuhr => Offset(size.width * 0.52, size.height * 0.28),
      PrayerPeriod.asr => Offset(size.width * 0.55, size.height * 0.47),
      PrayerPeriod.maghrib => Offset(size.width * 0.55, size.height * 0.52),
      PrayerPeriod.isha => Offset(size.width * 0.56, size.height * 0.18),
    };
    final radius = isMoon
        ? math.min(size.width * 0.045, size.height * 0.105)
        : math.min(size.width * 0.048, size.height * 0.115);
    final haloRadius = radius * (period == PrayerPeriod.dhuhr ? 3.8 : 3.1);
    final haloRect = Rect.fromCircle(center: center, radius: haloRadius);
    final halo = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.softGold.withValues(alpha: isMoon ? 0.30 : 0.45),
          palette.softGold.withValues(alpha: isMoon ? 0.10 : 0.16),
          palette.softGold.withValues(alpha: 0),
        ],
        stops: const [0, 0.42, 1],
      ).createShader(haloRect);
    canvas.drawCircle(center, haloRadius, halo);

    if (isMoon) {
      final moon = Paint()
        ..color = const Color(0xFFFFF0C5).withValues(alpha: 0.96);
      canvas.drawCircle(center, radius, moon);
      canvas.drawCircle(
        center.translate(radius * 0.44, -radius * 0.22),
        radius * 0.84,
        Paint()..color = palette.skyTop,
      );
    } else if (period != PrayerPeriod.dhuhr) {
      final sun = Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFFFFF2C5), palette.softGold],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, sun);
    }
  }

  void _drawDome(
    Canvas canvas,
    Offset base,
    double width,
    Paint paint, {
    required Paint detailPaint,
    bool detail = true,
  }) {
    final rise = width * 0.48;
    final crownY = base.dy - rise;
    final dome = Path()
      ..moveTo(base.dx - width / 2, base.dy)
      ..cubicTo(
        base.dx - width * 0.48,
        base.dy - rise * 0.56,
        base.dx - width * 0.25,
        crownY + rise * 0.10,
        base.dx,
        crownY,
      )
      ..cubicTo(
        base.dx + width * 0.25,
        crownY + rise * 0.10,
        base.dx + width * 0.48,
        base.dy - rise * 0.56,
        base.dx + width / 2,
        base.dy,
      )
      ..close();
    canvas.drawPath(dome, paint);
    canvas.drawRect(
      Rect.fromLTWH(
        base.dx - width / 2,
        base.dy - width * 0.045,
        width,
        width * 0.045,
      ),
      paint,
    );
    if (detail) {
      // Faint ribs and a fine finial catch the light only at close range.
      for (final fraction in [-0.25, 0.25]) {
        final x = base.dx + width * fraction;
        final rib = Path()
          ..moveTo(x, base.dy - width * 0.045)
          ..quadraticBezierTo(
            base.dx + fraction * width * 0.80,
            base.dy - rise * 0.48,
            base.dx,
            crownY + rise * 0.10,
          );
        canvas.drawPath(rib, detailPaint);
      }
      canvas.drawLine(
        Offset(base.dx, crownY),
        Offset(base.dx, crownY - width * 0.10),
        detailPaint,
      );
      canvas.drawCircle(
        Offset(base.dx, crownY - width * 0.11),
        math.max(0.8, width * 0.012),
        Paint()..color = detailPaint.color,
      );
    }
  }

  void _drawMinaret(
    Canvas canvas,
    Offset base,
    double height,
    Paint paint, {
    required Paint detailPaint,
  }) {
    final width = height * 0.105;
    final shaft = Path()
      ..moveTo(base.dx - width * 0.34, base.dy)
      ..lineTo(base.dx - width * 0.28, base.dy - height * 0.72)
      ..lineTo(base.dx - width * 0.12, base.dy - height * 0.82)
      ..lineTo(base.dx, base.dy - height)
      ..lineTo(base.dx + width * 0.12, base.dy - height * 0.82)
      ..lineTo(base.dx + width * 0.28, base.dy - height * 0.72)
      ..lineTo(base.dx + width * 0.34, base.dy)
      ..close();
    canvas.drawPath(shaft, paint);
    final cap = Path()
      ..moveTo(base.dx - width * 0.26, base.dy - height * 0.94)
      ..quadraticBezierTo(
        base.dx,
        base.dy - height * 1.06,
        base.dx + width * 0.26,
        base.dy - height * 0.94,
      )
      ..close();
    canvas.drawPath(cap, paint);
    for (final level in [0.70, 0.48]) {
      final galleryY = base.dy - height * level;
      canvas.drawLine(
        Offset(base.dx - width * 0.55, galleryY),
        Offset(base.dx + width * 0.55, galleryY),
        detailPaint,
      );
    }
    canvas.drawLine(
      Offset(base.dx, base.dy - height * 0.78),
      Offset(base.dx, base.dy - height * 0.94),
      detailPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _MosquePainter oldDelegate) =>
      oldDelegate.palette != palette ||
      oldDelegate.decorationsOnly != decorationsOnly;
}

bool _needsBaghdadNotice(PrayerController controller, DateTime now) {
  final zone = controller.deviceTimeZoneId;
  if (zone != null) return zone != 'Asia/Baghdad';
  return now.timeZoneOffset.inMinutes != 180;
}

String _formatClock(
  DateTime value, {
  required bool seconds,
  required bool use24Hour,
}) {
  final hour =
      use24Hour ? value.hour : (value.hour % 12 == 0 ? 12 : value.hour % 12);
  final hourText = use24Hour ? hour.toString().padLeft(2, '0') : '$hour';
  final base = '$hourText:${value.minute.toString().padLeft(2, '0')}';
  if (!seconds) return base;
  return '$base:${value.second.toString().padLeft(2, '0')}';
}

String _formatPrayerTime(String value, bool use24Hour) {
  if (use24Hour) return value;
  final parts = value.split(':');
  final hour = int.parse(parts.first);
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${parts.last.padLeft(2, '0')}';
}

String _weekdayName(int weekday) => const [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ][weekday - 1];
