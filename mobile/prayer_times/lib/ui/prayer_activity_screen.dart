import 'package:flutter/material.dart';

import '../state/prayer_controller.dart';
import 'post_prayer_adhkar.dart';

const _activityBeige = Color(0xFFF4E7C5);
const _activityInk = Color(0xFF173E2B);
const _phoneReminder = Color(0xFFC62828);

class PrayerActivityScreen extends StatelessWidget {
  const PrayerActivityScreen({
    required this.status,
    required this.now,
    super.key,
  });

  final PrayerScreenStatus status;
  final DateTime now;

  bool get _isBlack =>
      status.phase == PrayerScreenPhase.prayerBlackout ||
      status.phase == PrayerScreenPhase.fridayBlackout;

  bool get _isAdhanAnnouncement =>
      status.phase == PrayerScreenPhase.fridayKhutbah;

  @override
  Widget build(BuildContext context) {
    if (status.phase == PrayerScreenPhase.ramadanTaraweeh ||
        status.phase == PrayerScreenPhase.ramadanQiyam) {
      return _BlackPrayerScreen(title: status.label, now: now);
    }
    if (status.phase == PrayerScreenPhase.prayerBlackout) {
      return _BlackPrayerScreen(title: 'الصلاة قائمة', now: now);
    }
    if (status.phase == PrayerScreenPhase.postPrayerDhikr) {
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Container(
            margin: const EdgeInsets.all(16),
            child: PostPrayerAdhkar(status: status, now: now),
          ),
        ),
      );
    }
    final countdown = status.phase == PrayerScreenPhase.adhanCountdown ||
        status.phase == PrayerScreenPhase.iqamaCountdown;
    final showPhone = status.phase == PrayerScreenPhase.iqamaCountdown ||
        (status.phase == PrayerScreenPhase.adhanCountdown &&
            status.prayerId == 'dhuhr' &&
            status.endsAt.weekday == DateTime.friday);
    if (countdown || status.phase == PrayerScreenPhase.adhanAnnouncement) {
      final microseconds = status.remainingAt(now).inMicroseconds;
      final seconds = (microseconds / Duration.microsecondsPerSecond).ceil();
      return PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: const Color(0xFFFFF5DF),
          body: SafeArea(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          status.label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: _activityInk,
                            fontWeight: FontWeight.w700,
                            fontSize:
                                (constraints.maxHeight * (countdown ? .1 : .17))
                                    .clamp(22.0, 76.0)
                                    .toDouble(),
                          ),
                        ),
                      ),
                      if (countdown) ...[
                        const SizedBox(height: 12),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ExcludeSemantics(
                              child: Text(
                                '$seconds',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  color: _activityInk,
                                  fontWeight: FontWeight.w800,
                                  fontSize: (constraints.maxHeight *
                                          (showPhone ? .32 : .55))
                                      .clamp(72.0, 280.0)
                                      .toDouble(),
                                  height: 1.1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (showPhone) ...[
                        Text('يرجى إغلاق الهاتف',
                            style: TextStyle(
                                color: _phoneReminder,
                                fontSize: constraints.maxHeight * .08)),
                        Image.asset('assets/images/no-phone.png',
                            height: constraints.maxHeight * .2,
                            width: constraints.maxHeight * .2),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    final black = _isBlack;
    final background = black ? Colors.black : _activityBeige;
    final remaining = status.remainingAt(now);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final iconSize =
                  (constraints.maxHeight * 0.18).clamp(56.0, 150.0).toDouble();
              final titleSize =
                  (constraints.maxHeight * 0.085).clamp(30.0, 72.0).toDouble();
              return Stack(
                fit: StackFit.expand,
                children: [
                  if (black)
                    Positioned(
                      top: 18,
                      left: 12,
                      right: 12,
                      child: Text(
                        _format12HourClock(now),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: _phoneReminder,
                          fontSize: (constraints.maxHeight * 0.055)
                              .clamp(22.0, 44.0)
                              .toDouble(),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.4,
                        ),
                      ),
                    ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isAdhanAnnouncement)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Text(
                              status.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _activityInk,
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        if (black) ...[
                          Text(
                            status.phase == PrayerScreenPhase.fridayBlackout
                                ? 'استمع للخطبة بارك الله فيك'
                                : 'يرجى إغلاق الهاتف',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _phoneReminder,
                              fontSize: status.phase ==
                                      PrayerScreenPhase.fridayBlackout
                                  ? (constraints.maxHeight * .12)
                                      .clamp(36.0, 88.0)
                                      .toDouble()
                                  : titleSize,
                            ),
                          ),
                          const SizedBox(height: 18),
                        ],
                        if (black)
                          Semantics(
                            label: 'تذكير بإغلاق الهاتف',
                            child: black
                                ? Image.asset(
                                    'assets/images/no-phone.png',
                                    width: iconSize,
                                    height: iconSize,
                                    fit: BoxFit.contain,
                                  )
                                : Icon(
                                    Icons.phonelink_off,
                                    size: iconSize,
                                    color: _phoneReminder,
                                  ),
                          ),
                      ],
                    ),
                  ),
                  if (status.phase == PrayerScreenPhase.postPrayerDhikr)
                    Positioned(
                      left: 12,
                      right: 12,
                      bottom: 12,
                      child: Text(
                        'العودة إلى الواجهة الرئيسية بعد ${_formatRemaining(remaining)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: _activityInk,
                          fontSize: 16,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BlackPrayerScreen extends StatelessWidget {
  const _BlackPrayerScreen({required this.title, required this.now});

  final String title;
  final DateTime now;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final height = constraints.maxHeight;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: double.infinity,
                          height: (height * .14).clamp(36.0, 72.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _format12HourClock(now),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: (height * .065).clamp(30.0, 46.0),
                                fontWeight: FontWeight.w400,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: double.infinity,
                          height: (height * .25).clamp(64.0, 120.0),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: (height * .1).clamp(42.0, 60.0),
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SizedBox(
                          width: (height * .22).clamp(64.0, 112.0),
                          height: (height * .22).clamp(64.0, 112.0),
                          child: Image.asset(
                            'assets/images/no-phone.png',
                            key: const ValueKey('prayer-no-phone'),
                            fit: BoxFit.contain,
                            semanticLabel: 'إغلاق الهاتف',
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
}

String _format12HourClock(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final second = value.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String _formatRemaining(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${value.inHours.toString().padLeft(2, '0')}:$minutes:$seconds';
}
