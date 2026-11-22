import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'state/prayer_controller.dart';
import 'ui/dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  final controller = PrayerController();
  await controller.initialize();
  runApp(PrayerTimesApp(controller: controller));
}

class PrayerTimesApp extends StatefulWidget {
  const PrayerTimesApp({required this.controller, super.key});

  final PrayerController controller;

  @override
  State<PrayerTimesApp> createState() => _PrayerTimesAppState();
}

class _PrayerTimesAppState extends State<PrayerTimesApp>
    with WidgetsBindingObserver {
  PrayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(controller.refreshPrayerSummaryOnResume());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final settings = controller.settings;
        final seed = Color(settings.accentColor);
        return MaterialApp(
          title: settings.appName,
          debugShowCheckedModeBanner: false,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar')],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: seed,
              brightness: Brightness.light,
              surface: const Color(0xFFFFF8E8),
            ),
            fontFamily: settings.systemFont ? null : 'Amiri',
            scaffoldBackgroundColor: const Color(0xFFF5E9C8),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF7EAC9),
              foregroundColor: Color(0xFF153C2B),
              centerTitle: true,
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFFFFBF1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          locale: const Locale('ar'),
          builder: (context, child) => LayoutBuilder(
            builder: (context, constraints) {
              // Also cover devices that ignore the OS orientation preference.
              final portrait = constraints.maxHeight > constraints.maxWidth;
              final size = portrait
                  ? Size(constraints.maxHeight, constraints.maxWidth)
                  : Size(constraints.maxWidth, constraints.maxHeight);
              return RotatedBox(
                quarterTurns: portrait ? 1 : 0,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: size),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
          ),
          home: DashboardScreen(controller: controller),
        );
      },
    );
  }
}
