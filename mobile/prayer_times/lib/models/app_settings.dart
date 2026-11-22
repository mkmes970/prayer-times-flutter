import 'ramadan_schedule.dart';

const defaultIqamaMinutes = <String, int>{
  'fajrSecond': 20,
  'dhuhr': 15,
  'asr': 15,
  'maghrib': 8,
  'isha': 15,
};
const defaultPrayerDurationMinutes = <String, int>{
  'fajrSecond': 10,
  'dhuhr': 8,
  'asr': 8,
  'maghrib': 7,
  'isha': 10,
};
const defaultAdhanPrayerEnabled = <String, bool>{
  'fajrSecond': true,
  'dhuhr': true,
  'asr': true,
  'maghrib': true,
  'isha': true,
};

class AppSettings {
  const AppSettings({
    this.appName = 'مواقيت الصلاة',
    this.mosqueName = '',
    this.iqamaMinutes = defaultIqamaMinutes,
    this.prayerDurationMinutes = defaultPrayerDurationMinutes,
    this.postPrayerDhikrMinutes = 8,
    this.fridayKhutbahMinutes = 20,
    this.showHijriDate = true,
    this.hadithEnabled = false,
    this.adhanEnabled = false,
    this.prayerSummaryEnabled = false,
    this.prayerSummaryPermissionRequested = false,
    this.adhanPrayerEnabled = defaultAdhanPrayerEnabled,
    this.customThemesEnabled = false,
    this.periodThemes = const {},
    this.tickerScrollingEnabled = false,
    this.tickerSpeed = 32,
    this.hijriOffsetDays = 0,
    this.clockOffsetSeconds = 0,
    this.ramadanPlans = const {},
    this.ramadanTaraweehEnabled = false,
    this.ramadanTaraweehMinutes = 35,
    this.ramadanQiyamEnabled = false,
    this.ramadanQiyamStartMinutes = 150,
    this.ramadanQiyamEndMinutes = 210,
    this.hijriManualDay,
    this.hijriManualMonth,
    this.hijriAnchorDate,
    this.use24HourClock = false,
    this.clockScale = 1,
    this.fontScale = 1,
    this.systemFont = false,
    this.accentColor = 0xFF17432E,
    this.dashboardTextColorEnabled = false,
    this.dashboardTextColor = 0xFF17432E,
    this.keepAwake = true,
    this.immersiveMode = true,
    this.autoStartEnabled = false,
    this.pinSalt = '',
    this.pinHash = '',
  });

  final String appName;
  final String mosqueName;
  final Map<String, int> iqamaMinutes;
  final Map<String, int> prayerDurationMinutes;
  final int? postPrayerDhikrMinutes;
  final int? fridayKhutbahMinutes;
  final bool showHijriDate;
  final bool hadithEnabled;
  final bool adhanEnabled;
  final bool prayerSummaryEnabled;
  final bool prayerSummaryPermissionRequested;
  final Map<String, bool> adhanPrayerEnabled;
  final bool customThemesEnabled;
  final Map<String, String> periodThemes;
  final bool tickerScrollingEnabled;
  final double tickerSpeed;
  final int hijriOffsetDays;
  final int clockOffsetSeconds;
  final Map<String, RamadanPlan> ramadanPlans;
  final bool ramadanTaraweehEnabled;
  final int ramadanTaraweehMinutes;
  final bool ramadanQiyamEnabled;
  final int ramadanQiyamStartMinutes;
  final int ramadanQiyamEndMinutes;
  final int? hijriManualDay;
  final int? hijriManualMonth;
  final String? hijriAnchorDate;
  final bool use24HourClock;
  final double clockScale;
  final double fontScale;
  final bool systemFont;
  final int accentColor;
  final bool dashboardTextColorEnabled;
  final int dashboardTextColor;
  final bool keepAwake;
  final bool immersiveMode;
  final bool autoStartEnabled;
  final String pinSalt;
  final String pinHash;

  bool get hasPin => pinSalt.isNotEmpty && pinHash.isNotEmpty;

  AppSettings copyWith({
    String? appName,
    String? mosqueName,
    Map<String, int>? iqamaMinutes,
    Map<String, int>? prayerDurationMinutes,
    int? postPrayerDhikrMinutes,
    int? fridayKhutbahMinutes,
    bool clearPostPrayerDhikrMinutes = false,
    bool clearFridayKhutbahMinutes = false,
    bool? showHijriDate,
    bool? hadithEnabled,
    bool? adhanEnabled,
    bool? prayerSummaryEnabled,
    bool? prayerSummaryPermissionRequested,
    Map<String, bool>? adhanPrayerEnabled,
    bool? customThemesEnabled,
    Map<String, String>? periodThemes,
    bool? tickerScrollingEnabled,
    double? tickerSpeed,
    int? hijriOffsetDays,
    int? clockOffsetSeconds,
    Map<String, RamadanPlan>? ramadanPlans,
    bool? ramadanTaraweehEnabled,
    int? ramadanTaraweehMinutes,
    bool? ramadanQiyamEnabled,
    int? ramadanQiyamStartMinutes,
    int? ramadanQiyamEndMinutes,
    int? hijriManualDay,
    int? hijriManualMonth,
    String? hijriAnchorDate,
    bool clearHijriManualDate = false,
    bool? use24HourClock,
    double? clockScale,
    double? fontScale,
    bool? systemFont,
    int? accentColor,
    bool? dashboardTextColorEnabled,
    int? dashboardTextColor,
    bool? keepAwake,
    bool? immersiveMode,
    bool? autoStartEnabled,
    String? pinSalt,
    String? pinHash,
  }) {
    return AppSettings(
      appName: appName ?? this.appName,
      mosqueName: mosqueName ?? this.mosqueName,
      iqamaMinutes: Map.unmodifiable(iqamaMinutes ?? this.iqamaMinutes),
      prayerDurationMinutes: Map.unmodifiable(
        prayerDurationMinutes ?? this.prayerDurationMinutes,
      ),
      postPrayerDhikrMinutes: clearPostPrayerDhikrMinutes
          ? null
          : postPrayerDhikrMinutes ?? this.postPrayerDhikrMinutes,
      fridayKhutbahMinutes: clearFridayKhutbahMinutes
          ? null
          : fridayKhutbahMinutes ?? this.fridayKhutbahMinutes,
      showHijriDate: showHijriDate ?? this.showHijriDate,
      hadithEnabled: hadithEnabled ?? this.hadithEnabled,
      adhanEnabled: adhanEnabled ?? this.adhanEnabled,
      prayerSummaryEnabled: prayerSummaryEnabled ?? this.prayerSummaryEnabled,
      prayerSummaryPermissionRequested: prayerSummaryPermissionRequested ??
          this.prayerSummaryPermissionRequested,
      adhanPrayerEnabled: Map.unmodifiable(
        adhanPrayerEnabled ?? this.adhanPrayerEnabled,
      ),
      customThemesEnabled: customThemesEnabled ?? this.customThemesEnabled,
      periodThemes: Map.unmodifiable(periodThemes ?? this.periodThemes),
      tickerScrollingEnabled:
          tickerScrollingEnabled ?? this.tickerScrollingEnabled,
      tickerSpeed: tickerSpeed ?? this.tickerSpeed,
      hijriOffsetDays: hijriOffsetDays ?? this.hijriOffsetDays,
      clockOffsetSeconds: clockOffsetSeconds ?? this.clockOffsetSeconds,
      ramadanPlans: Map.unmodifiable(ramadanPlans ?? this.ramadanPlans),
      ramadanTaraweehEnabled:
          ramadanTaraweehEnabled ?? this.ramadanTaraweehEnabled,
      ramadanTaraweehMinutes:
          ramadanTaraweehMinutes ?? this.ramadanTaraweehMinutes,
      ramadanQiyamEnabled: ramadanQiyamEnabled ?? this.ramadanQiyamEnabled,
      ramadanQiyamStartMinutes:
          ramadanQiyamStartMinutes ?? this.ramadanQiyamStartMinutes,
      ramadanQiyamEndMinutes:
          ramadanQiyamEndMinutes ?? this.ramadanQiyamEndMinutes,
      hijriManualDay:
          clearHijriManualDate ? null : hijriManualDay ?? this.hijriManualDay,
      hijriManualMonth: clearHijriManualDate
          ? null
          : hijriManualMonth ?? this.hijriManualMonth,
      hijriAnchorDate:
          clearHijriManualDate ? null : hijriAnchorDate ?? this.hijriAnchorDate,
      use24HourClock: false,
      clockScale: clockScale ?? this.clockScale,
      fontScale: fontScale ?? this.fontScale,
      systemFont: systemFont ?? this.systemFont,
      accentColor: accentColor ?? this.accentColor,
      dashboardTextColorEnabled:
          dashboardTextColorEnabled ?? this.dashboardTextColorEnabled,
      dashboardTextColor: dashboardTextColor ?? this.dashboardTextColor,
      keepAwake: keepAwake ?? this.keepAwake,
      immersiveMode: immersiveMode ?? this.immersiveMode,
      autoStartEnabled: autoStartEnabled ?? this.autoStartEnabled,
      pinSalt: pinSalt ?? this.pinSalt,
      pinHash: pinHash ?? this.pinHash,
    );
  }

  Map<String, Object?> toJson() => {
        'timingDefaultsVersion': 1,
        'appName': appName,
        'mosqueName': mosqueName,
        'iqamaMinutes': iqamaMinutes,
        'prayerDurationMinutes': prayerDurationMinutes,
        'postPrayerDhikrMinutes': postPrayerDhikrMinutes,
        'fridayKhutbahMinutes': fridayKhutbahMinutes,
        'showHijriDate': showHijriDate,
        'hadithEnabled': hadithEnabled,
        'adhanEnabled': adhanEnabled,
        'prayerSummaryEnabled': prayerSummaryEnabled,
        'prayerSummaryPermissionRequested': prayerSummaryPermissionRequested,
        'adhanPrayerEnabled': adhanPrayerEnabled,
        'customThemesEnabled': customThemesEnabled,
        'periodThemes': periodThemes,
        'tickerScrollingEnabled': tickerScrollingEnabled,
        'tickerSpeed': tickerSpeed,
        'hijriOffsetDays': hijriOffsetDays,
        'clockOffsetSeconds': clockOffsetSeconds,
        'ramadanPlans': {
          for (final e in ramadanPlans.entries) e.key: e.value.toJson(),
        },
        'ramadanTaraweehEnabled': ramadanTaraweehEnabled,
        'ramadanTaraweehMinutes': ramadanTaraweehMinutes,
        'ramadanQiyamEnabled': ramadanQiyamEnabled,
        'ramadanQiyamStartMinutes': ramadanQiyamStartMinutes,
        'ramadanQiyamEndMinutes': ramadanQiyamEndMinutes,
        'hijriManualDay': hijriManualDay,
        'hijriManualMonth': hijriManualMonth,
        'hijriAnchorDate': hijriAnchorDate,
        'use24HourClock': false,
        'clockScale': clockScale,
        'fontScale': fontScale,
        'systemFont': systemFont,
        'accentColor': accentColor,
        'dashboardTextColorEnabled': dashboardTextColorEnabled,
        'dashboardTextColor': dashboardTextColor,
        'keepAwake': keepAwake,
        'immersiveMode': immersiveMode,
        'autoStartEnabled': autoStartEnabled,
        'pinSalt': pinSalt,
        'pinHash': pinHash,
      };

  factory AppSettings.fromJson(Object? value) {
    if (value is! Map) return const AppSettings();
    final map = Map<String, Object?>.from(value);
    Map<String, int> durations(String key) {
      final result = <String, int>{};
      final raw = map[key];
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.key is String &&
              entry.value is int &&
              (entry.value as int) >= 0 &&
              (entry.value as int) <= 360) {
            result[entry.key as String] = entry.value as int;
          }
        }
      }
      return Map.unmodifiable(result);
    }

    int integer(String key, int fallback) =>
        map[key] is int ? map[key] as int : fallback;
    int? optionalMinutes(String key) {
      final value = map[key];
      return value is int && value >= 0 && value <= 360 ? value : null;
    }

    double decimal(String key, double fallback) =>
        map[key] is num ? (map[key] as num).toDouble() : fallback;
    bool boolean(String key, bool fallback) =>
        map[key] is bool ? map[key] as bool : fallback;
    String text(String key, String fallback) =>
        map[key] is String ? map[key] as String : fallback;
    // Install the requested timings once, including existing installations.
    // Later staff edits (including intentionally unset timings) stay intact.
    final installTimingDefaults = integer('timingDefaultsVersion', 0) < 1;
    return AppSettings(
      appName: text('appName', 'مواقيت الصلاة'),
      mosqueName: text('mosqueName', ''),
      iqamaMinutes: installTimingDefaults
          ? defaultIqamaMinutes
          : durations('iqamaMinutes'),
      prayerDurationMinutes: installTimingDefaults
          ? defaultPrayerDurationMinutes
          : durations('prayerDurationMinutes'),
      postPrayerDhikrMinutes:
          installTimingDefaults ? 8 : optionalMinutes('postPrayerDhikrMinutes'),
      fridayKhutbahMinutes:
          installTimingDefaults ? 20 : optionalMinutes('fridayKhutbahMinutes'),
      showHijriDate: boolean('showHijriDate', true),
      hadithEnabled: boolean('hadithEnabled', false),
      adhanEnabled: boolean('adhanEnabled', false),
      prayerSummaryEnabled: boolean('prayerSummaryEnabled', false),
      prayerSummaryPermissionRequested:
          boolean('prayerSummaryPermissionRequested', false),
      adhanPrayerEnabled: Map.unmodifiable({
        for (final entry in defaultAdhanPrayerEnabled.entries)
          entry.key: map['adhanPrayerEnabled'] is Map &&
                  (map['adhanPrayerEnabled'] as Map)[entry.key] is bool
              ? (map['adhanPrayerEnabled'] as Map)[entry.key] as bool
              : entry.value,
      }),
      customThemesEnabled: boolean('customThemesEnabled', false),
      periodThemes: Map.unmodifiable({
        if (map['periodThemes'] is Map)
          for (final entry in (map['periodThemes'] as Map).entries)
            if (entry.key is String && entry.value is String)
              entry.key as String: entry.value as String,
      }),
      tickerScrollingEnabled: boolean('tickerScrollingEnabled', false),
      tickerSpeed: decimal('tickerSpeed', 32).clamp(8, 80).toDouble(),
      hijriOffsetDays: integer('hijriOffsetDays', 0).clamp(-3, 3).toInt(),
      clockOffsetSeconds: integer('clockOffsetSeconds', 0),
      ramadanPlans: Map.unmodifiable({
        if (map['ramadanPlans'] is Map)
          for (final e in (map['ramadanPlans'] as Map).entries)
            if (e.key is String) e.key as String: RamadanPlan.fromJson(e.value),
      }),
      ramadanTaraweehEnabled: boolean('ramadanTaraweehEnabled', false),
      ramadanTaraweehMinutes:
          integer('ramadanTaraweehMinutes', 35).clamp(1, 360).toInt(),
      ramadanQiyamEnabled: boolean('ramadanQiyamEnabled', false),
      ramadanQiyamStartMinutes:
          integer('ramadanQiyamStartMinutes', 150).clamp(0, 1439).toInt(),
      ramadanQiyamEndMinutes:
          integer('ramadanQiyamEndMinutes', 210).clamp(0, 1439).toInt(),
      hijriManualDay: map['hijriManualDay'] is int
          ? (map['hijriManualDay'] as int).clamp(1, 30).toInt()
          : null,
      hijriManualMonth: map['hijriManualMonth'] is int
          ? (map['hijriManualMonth'] as int).clamp(1, 12).toInt()
          : null,
      hijriAnchorDate: map['hijriAnchorDate'] is String &&
              (map['hijriAnchorDate'] as String).isNotEmpty
          ? map['hijriAnchorDate'] as String
          : null,
      use24HourClock: false,
      clockScale: decimal('clockScale', 1).clamp(0.8, 1.3).toDouble(),
      fontScale: decimal('fontScale', 1).clamp(0.8, 1.4).toDouble(),
      systemFont: boolean('systemFont', false),
      accentColor: integer('accentColor', 0xFF17432E),
      dashboardTextColorEnabled: boolean('dashboardTextColorEnabled', false),
      dashboardTextColor: integer('dashboardTextColor', 0xFF17432E),
      keepAwake: boolean('keepAwake', true),
      immersiveMode: boolean('immersiveMode', true),
      autoStartEnabled: boolean('autoStartEnabled', false),
      pinSalt: text('pinSalt', ''),
      pinHash: text('pinHash', ''),
    );
  }
}
