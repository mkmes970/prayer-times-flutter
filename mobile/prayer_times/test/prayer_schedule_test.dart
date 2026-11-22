import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/models/app_data.dart';
import 'package:prayer_times/models/app_settings.dart';
import 'package:prayer_times/models/prayer_schedule.dart';

void main() {
  test('duration settings retain the configured defaults and 12-hour time', () {
    const settings = AppSettings();

    expect(settings.iqamaMinutes, {
      'fajrSecond': 20, 'dhuhr': 15, 'asr': 15, 'maghrib': 8, 'isha': 15,
    });
    expect(settings.prayerDurationMinutes, {
      'fajrSecond': 10, 'dhuhr': 8, 'asr': 8, 'maghrib': 7, 'isha': 10,
    });
    expect(settings.postPrayerDhikrMinutes, 8);
    expect(settings.fridayKhutbahMinutes, 20);
    expect(settings.use24HourClock, isFalse);
  });

  group('Prayer schedule JSON validation', () {
    test(
      'accepts 12-hour English and Arabic times and exports 12-hour values',
      () {
        final times = PrayerTimes.fromJson({
          'fajrFirst': '4:20 AM',
          'fajrSecond': '4:45 ص',
          'sunrise': '6:05',
          'dhuhr': '12:00',
          'asr': '3:15',
          'maghrib': '5:40 م',
          'isha': '7:05 PM',
        });

        expect(times['fajrFirst'], '04:20');
        expect(times['dhuhr'], '12:00');
        expect(times['asr'], '15:15');
        expect(times['maghrib'], '17:40');
        expect(times.toJson()['asr'], '3:15 PM');
        expect(times.toJson()['fajrSecond'], '4:45 AM');
      },
    );

    test('infers bare 12-hour times in prayer order', () {
      final times = PrayerTimes.fromJson({
        'fajrFirst': '4:35',
        'fajrSecond': '4:50',
        'sunrise': '6:10',
        'dhuhr': '12:00',
        'asr': '3:15',
        'maghrib': '5:39',
        'isha': '6:59',
      });

      expect(times['fajrSecond'], '04:50');
      expect(times['sunrise'], '06:10');
      expect(times['dhuhr'], '12:00');
      expect(times['asr'], '15:15');
      expect(times['maghrib'], '17:39');
      expect(times['isha'], '18:59');
    });

    test('accepts a complete annual schedule and keeps region/year data', () {
      final region = regionFromScheduleFile({
        'format': 'mwaqit-prayer-times',
        'schemaVersion': 1,
        'template': false,
        'region': {'id': 'al-abbasi', 'name': 'ناحية العباسي'},
        'years': [
          {
            'year': 2026,
            'months': [
              {
                'month': 10,
                'days': [
                  {
                    'day': 11,
                    'prayers': {
                      'fajrFirst': '04:20',
                      'fajrSecond': '04:45',
                      'sunrise': '06:05',
                      'dhuhr': '11:55',
                      'asr': '15:15',
                      'maghrib': '17:40',
                      'isha': '19:05',
                    },
                  },
                ],
              },
            ],
          },
        ],
      });

      expect(region.name, 'ناحية العباسي');
      expect(region.timesFor(DateTime(2026, 10, 11))?['fajrSecond'], '04:45');
      expect(region.toJson()['years'], isA<List<Object?>>());
    });

    test(
      'rejects template placeholders instead of treating them as real times',
      () {
        expect(
          () => regionFromScheduleFile({
            'format': 'mwaqit-prayer-times',
            'schemaVersion': 1,
            'template': true,
          }),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('rejects invalid clock times', () {
      expect(
        () => PrayerTimes.fromJson({
          'fajrFirst': '24:00',
          'fajrSecond': '04:45',
          'sunrise': '06:05',
          'dhuhr': '11:55',
          'asr': '15:15',
          'maghrib': '17:40',
          'isha': '19:05',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects prayer times in the wrong daily order', () {
      expect(
        () => PrayerTimes.fromJson({
          'fajrFirst': '04:50',
          'fajrSecond': '04:45',
          'sunrise': '06:05',
          'dhuhr': '11:55',
          'asr': '15:15',
          'maghrib': '17:40',
          'isha': '19:05',
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects dates that do not exist in the named month', () {
      expect(
        () => PrayerRegion.fromJson({
          'id': 'region-a',
          'name': 'المنطقة',
          'years': [
            {
              'year': 2026,
              'months': [
                {
                  'month': 2,
                  'days': [
                    {
                      'day': 30,
                      'prayers': {
                        'fajrFirst': '04:20',
                        'fajrSecond': '04:45',
                        'sunrise': '06:05',
                        'dhuhr': '11:55',
                        'asr': '15:15',
                        'maghrib': '17:40',
                        'isha': '19:05',
                      },
                    },
                  ],
                },
              ],
            },
          ],
        }),
        throwsA(isA<FormatException>()),
      );
    });

    test('round-trips a backup with its selected region and preferences', () {
      final times = PrayerTimes({
        'fajrFirst': '04:20',
        'fajrSecond': '04:45',
        'sunrise': '06:05',
        'dhuhr': '11:55',
        'asr': '15:15',
        'maghrib': '17:40',
        'isha': '19:05',
      });
      final region = PrayerRegion(
        id: 'al-abbasi',
        name: 'ناحية العباسي',
        days: {'2026-10-11': times},
      );
      final backup = AppData(
        regions: {region.id: region},
        selectedRegionId: region.id,
        settings: const AppSettings(),
      );

      final restored = AppData.fromJson(backup.toJson());
      expect(restored.selectedRegionId, 'al-abbasi');
      expect(
        restored.selectedRegion?.timesFor(DateTime(2026, 10, 11))?['isha'],
        '19:05',
      );
    });
  });
}
