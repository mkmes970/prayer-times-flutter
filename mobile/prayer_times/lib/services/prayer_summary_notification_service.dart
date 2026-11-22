import 'dart:convert';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';

class PrayerSummaryNotificationService {
  PrayerSummaryNotificationService({MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('com.example.prayertimes/device');

  final MethodChannel _channel;

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> requestPermission() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>(
          'requestPrayerSummaryPermission',
        ) ??
        false;
  }

  Future<bool> notificationsAllowed() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>(
          'arePrayerSummaryNotificationsAllowed',
        ) ??
        false;
  }

  Future<bool> synchronize(Map<String, Object?> payload) async {
    if (!isSupported) return true;
    return await _channel.invokeMethod<bool>(
          'syncPrayerSummary',
          jsonEncode(payload),
        ) ??
        false;
  }
}
