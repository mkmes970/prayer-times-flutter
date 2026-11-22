import 'dart:io';
import 'package:prayer_times/models/app_settings.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void main() {
  const fresh = AppSettings();
  check(!fresh.hadithEnabled, 'Hadiths disabled by default');
  check(!fresh.adhanEnabled, 'Adhan audio is off by default');
  check(!fresh.prayerSummaryEnabled, 'Prayer summary is off by default');
  check(
    !fresh.prayerSummaryPermissionRequested,
    'Prayer summary permission starts unrequested',
  );
  check(fresh.adhanPrayerEnabled.values.every((enabled) => enabled),
      'All five prayer sounds are unmuted when the master switch is enabled');
  final adhanSettings = AppSettings.fromJson(fresh.copyWith(
    adhanEnabled: true,
    adhanPrayerEnabled: {...fresh.adhanPrayerEnabled, 'asr': false},
  ).toJson());
  check(adhanSettings.adhanEnabled, 'Adhan master switch is persisted');
  check(!adhanSettings.adhanPrayerEnabled['asr']!, 'Prayer mute is persisted');
  check(adhanSettings.adhanPrayerEnabled['isha']!, 'Other prayer remains on');
  check(!AppSettings.fromJson({'timingDefaultsVersion': 1}).hadithEnabled,
      'Older settings default to disabled');
  check(
    !AppSettings.fromJson({'timingDefaultsVersion': 1}).prayerSummaryEnabled,
    'Older settings default to no ongoing notification',
  );
  check(
    AppSettings.fromJson(
      fresh
          .copyWith(
            prayerSummaryEnabled: true,
            prayerSummaryPermissionRequested: true,
          )
          .toJson(),
    ).prayerSummaryEnabled,
    'Prayer summary setting persists',
  );
  check(
    AppSettings.fromJson(
      fresh.copyWith(prayerSummaryPermissionRequested: true).toJson(),
    ).prayerSummaryPermissionRequested,
    'Prayer summary permission request state persists',
  );
  check(
      AppSettings.fromJson(fresh.copyWith(hadithEnabled: true).toJson())
          .hadithEnabled,
      'Hadith toggle saved');
  check(
      !fresh
          .copyWith(hadithEnabled: true)
          .copyWith(hadithEnabled: false)
          .hadithEnabled,
      'Hadith toggle switches off');
  check(!fresh.tickerScrollingEnabled,
      'Ticker scroll is off until administration enables it');
  check(fresh.tickerSpeed == 32, 'Default ticker speed');
  final tickerSettings = AppSettings.fromJson(fresh
      .copyWith(
        tickerScrollingEnabled: true,
        tickerSpeed: 64,
      )
      .toJson());
  check(tickerSettings.tickerScrollingEnabled, 'Ticker scrolling toggle saved');
  check(tickerSettings.tickerSpeed == 64, 'Ticker speed saved');
  check(
      AppSettings.fromJson({
            ...fresh.toJson(),
            'tickerSpeed': 300,
          }).tickerSpeed ==
          80,
      'Ticker speed is kept within its safe range');
  check(fresh.iqamaMinutes['fajrSecond'] == 20, 'Fajr wait');
  check(fresh.iqamaMinutes['dhuhr'] == 15, 'Dhuhr wait');
  check(fresh.iqamaMinutes['asr'] == 15, 'Asr wait');
  check(fresh.iqamaMinutes['maghrib'] == 8, 'Maghrib wait');
  check(fresh.iqamaMinutes['isha'] == 15, 'Isha wait');
  check(fresh.prayerDurationMinutes['fajrSecond'] == 10, 'Fajr length');
  check(fresh.prayerDurationMinutes['dhuhr'] == 8, 'Dhuhr length');
  check(fresh.prayerDurationMinutes['asr'] == 8, 'Asr length');
  check(fresh.prayerDurationMinutes['maghrib'] == 7, 'Maghrib length');
  check(fresh.prayerDurationMinutes['isha'] == 10, 'Isha length');
  check(fresh.postPrayerDhikrMinutes == 8, 'Adhkar');
  check(fresh.fridayKhutbahMinutes == 20, 'Khutbah');
  check(!fresh.dashboardTextColorEnabled,
      'custom dashboard text color off by default');
  check(
    AppSettings.fromJson(
      fresh
          .copyWith(
            dashboardTextColorEnabled: true,
            dashboardTextColor: 0xFFFFEB3B,
          )
          .toJson(),
    ).dashboardTextColorEnabled,
    'custom text color enabled setting persists',
  );
  check(
    AppSettings.fromJson(
          fresh
              .copyWith(
                dashboardTextColorEnabled: true,
                dashboardTextColor: 0xFFFFEB3B,
              )
              .toJson(),
        ).dashboardTextColor ==
        0xFFFFEB3B,
    'custom text color persists',
  );
  final migrated = AppSettings.fromJson({
    'mosqueName': 'مسجد اختبار',
    'iqamaMinutes': {'dhuhr': 2},
  });
  check(migrated.iqamaMinutes['dhuhr'] == 15, 'legacy defaults installed');
  check(migrated.mosqueName == 'مسجد اختبار', 'other settings preserved');
  final custom = migrated.copyWith(
    iqamaMinutes: {'dhuhr': 12},
    prayerDurationMinutes: {},
    clearFridayKhutbahMinutes: true,
  );
  final reloaded = AppSettings.fromJson(custom.toJson());
  check(reloaded.iqamaMinutes['dhuhr'] == 12, 'later staff change preserved');
  check(reloaded.prayerDurationMinutes.isEmpty, 'explicit disabled preserved');
  check(reloaded.fridayKhutbahMinutes == null, 'explicit unset preserved');
  stdout.writeln(
      'Native defaults, admin ticker controls and one-time migration checks passed.');
}
