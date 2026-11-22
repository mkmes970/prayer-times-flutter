import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/services/prayer_summary_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends the complete nested notification payload as JSON', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.example.prayertimes/device');
    final binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        expect(call.method, 'syncPrayerSummary');
        expect(call.arguments, isA<String>());
        final payload = jsonDecode(call.arguments! as String) as Map;
        expect(payload['regionName'], 'مواقيت الصلاة لمنطقة العباسي');
        expect(
          (payload['todaySchedule'] as Map)['times'],
          containsPair('fajrSecond', '5:11'),
        );
        expect(
          (payload['dailySchedules'] as List).first,
          containsPair('date', '2026-11-06'),
        );
        expect(
          (payload['states'] as List).first,
          containsPair('label', 'باقي لأذان الظهر'),
        );
        return true;
      },
    );
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final service = PrayerSummaryNotificationService(channel: channel);
    final result = await service.synchronize({
      'enabled': true,
      'regionName': 'مواقيت الصلاة لمنطقة العباسي',
      'todaySchedule': {
        'date': '2026-11-06',
        'times': {'fajrSecond': '5:11'},
      },
      'dailySchedules': [
        {
          'date': '2026-11-06',
          'times': {'fajrSecond': '5:11'},
        },
      ],
      'states': [
        {'label': 'باقي لأذان الظهر'},
      ],
    });

    expect(result, isTrue);
  });

  test('checks existing notification permission without prompting again',
      () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    const channel = MethodChannel('com.example.prayertimes/device');
    final binding = TestDefaultBinaryMessengerBinding.instance;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async {
        expect(call.method, 'arePrayerSummaryNotificationsAllowed');
        return true;
      },
    );
    addTearDown(() {
      debugDefaultTargetPlatformOverride = null;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    });

    final service = PrayerSummaryNotificationService(channel: channel);
    expect(await service.notificationsAllowed(), isTrue);
  });
}
