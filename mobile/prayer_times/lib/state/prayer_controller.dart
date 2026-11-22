import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/app_data.dart';
import '../models/app_settings.dart';
import '../models/prayer_schedule.dart';
import '../models/prayer_alert_timing.dart';
import '../models/prayer_highlight.dart';
import '../models/ramadan_schedule.dart';
import '../services/hijri_date.dart';
import '../services/adhan_alarm_service.dart';
import '../services/prayer_summary_notification_service.dart';
import '../services/local_repository.dart';
import '../services/bundled_schedules.dart';

enum DashboardStatusKind { noTodaySchedule, iqama, nextEvent, missingNextDay }

enum PrayerScreenPhase {
  adhanCountdown,
  adhanAnnouncement,
  iqamaCountdown,
  ramadanWelcome,
  prayerBlackout,
  ramadanTaraweeh,
  ramadanQiyam,
  fridayKhutbah,
  fridayBlackout,
  postPrayerDhikr,
}

class PrayerScreenStatus {
  const PrayerScreenStatus({
    required this.phase,
    required this.label,
    required this.prayerId,
    required this.startsAt,
    required this.endsAt,
  });

  final PrayerScreenPhase phase;
  final String label;
  final String prayerId;
  final DateTime startsAt;
  final DateTime endsAt;

  Duration remainingAt(DateTime now) {
    final remaining = endsAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class DashboardStatus {
  const DashboardStatus({
    required this.kind,
    required this.label,
    this.target,
    this.prayerId,
  });

  final DashboardStatusKind kind;
  final String label;
  final DateTime? target;
  final String? prayerId;

  Duration? remainingAt(DateTime now) {
    final value = target?.difference(now);
    if (value == null || value.isNegative) return Duration.zero;
    return value;
  }
}

class PrayerController extends ChangeNotifier {
  PrayerController({
    LocalRepository? repository,
    AdhanAlarmService? adhanAlarmService,
    PrayerSummaryNotificationService? prayerSummaryNotificationService,
    DateTime Function()? deviceNow,
  })  : _repository = repository ?? LocalRepository(),
        _deviceNow = deviceNow ?? DateTime.now,
        _adhanAlarmService = adhanAlarmService ?? AdhanAlarmService(),
        _prayerSummaryNotificationService = prayerSummaryNotificationService ??
            PrayerSummaryNotificationService();

  static const _deviceChannel = MethodChannel('com.example.prayertimes/device');
  final LocalRepository _repository;
  final AdhanAlarmService _adhanAlarmService;
  final PrayerSummaryNotificationService _prayerSummaryNotificationService;
  ValueListenable<String?> get webAdhanStatus => _adhanAlarmService.webStatus;
  Future<void> previewWebAdhan() => _adhanAlarmService.previewWebAudio();
  void stopWebAdhan() => _adhanAlarmService.stopWebAudio();
  final DateTime Function() _deviceNow;

  AppData _data = AppData.empty();
  Timer? _ticker;
  final ValueNotifier<DateTime> clock = ValueNotifier(DateTime.now());
  bool _ready = false;
  bool _loadFailed = false;
  String? _storageError;
  String? _lastActionError;
  String? _adhanAlarmError;
  String? _prayerSummaryError;
  bool _requestingPrayerSummaryPermission = false;
  String? _deviceTimeZoneId;
  bool _ramadanCleanupRunning = false;
  String? _ramadanCleanupAttemptDate;
  int? _previewDashboardTextColor;

  AppSettings get settings => _data.settings;
  int? get previewDashboardTextColor => _previewDashboardTextColor;
  int? get dashboardTextColor =>
      _previewDashboardTextColor ??
      (settings.dashboardTextColorEnabled ? settings.dashboardTextColor : null);

  void previewDashboardLineColor(int? color) {
    if (_previewDashboardTextColor == color) return;
    _previewDashboardTextColor = color;
    notifyListeners();
  }

  Map<String, PrayerRegion> get regions => _data.regions;
  String get selectedRegionId => _data.selectedRegionId;
  PrayerRegion? get selectedRegion {
    final source = _data.selectedRegion;
    return source == null
        ? null
        : regionWithRamadan(
            source, settings.ramadanPlans[selectedRegionId], hijriDateAt);
  }

  RamadanPlan? get currentRamadanPlan {
    final plan = settings.ramadanPlans[selectedRegionId];
    return plan != null && plan.appliesAt(hijriDateAt(now)) ? plan : null;
  }

  bool get needsRamadanChoice =>
      isReady &&
      selectedRegion != null &&
      hijriDateAt(now).month == 9 &&
      currentRamadanPlan == null;
  DateTime get now => clock.value;
  DateTime correctedTime(DateTime deviceTime) =>
      deviceTime.add(Duration(seconds: settings.clockOffsetSeconds));
  bool get isReady => _ready;
  String? get deviceTimeZoneId => _deviceTimeZoneId;
  String? get storageError => _storageError;
  String? get lastActionError => _lastActionError;
  String? get adhanAlarmError => _adhanAlarmError;
  String? get prayerSummaryError => _prayerSummaryError;

  Future<void> initialize() async {
    try {
      _data = await _repository.load();
      _storageError = null;
      _loadFailed = false;
    } catch (error) {
      _storageError = 'تعذر قراءة البيانات المحلية: $error';
      _loadFailed = true;
    }
    clock.value = correctedTime(_deviceNow());
    await _pruneExpiredRamadan();
    _ready = true;
    try {
      _deviceTimeZoneId = await _deviceChannel.invokeMethod<String>(
        'getDeviceTimeZoneId',
      );
    } on PlatformException {
      _deviceTimeZoneId = null;
    } on MissingPluginException {
      _deviceTimeZoneId = null;
    }
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      clock.value = correctedTime(_deviceNow());
      unawaited(_pruneExpiredRamadan());
    });
    await _syncAdhanSchedule(requestPermissions: false);
    final permissionFlowRan = await _requestPrayerSummaryPermissionIfNeeded();
    if (!permissionFlowRan) await _syncPrayerSummaryNotification();
    await _applyDisplaySettings();
    notifyListeners();
  }

  Future<void> refreshPrayerSummaryOnResume() async {
    if (!_ready) return;
    clock.value = correctedTime(_deviceNow());
    final permissionFlowRan = await _requestPrayerSummaryPermissionIfNeeded();
    if (!permissionFlowRan) await _syncPrayerSummaryNotification();
  }

  Future<void> disposeController() async {
    _adhanAlarmService.disposeWebAudio();
    _ticker?.cancel();
    _ticker = null;
    try {
      await WakelockPlus.disable();
    } catch (_) {
      // Unsupported platforms and test hosts may not provide the plugin.
    }
  }

  Future<void> _persist({
    bool allowCorruptStoreReplacement = false,
    bool requestAdhanPermissions = false,
  }) async {
    if (_loadFailed && !allowCorruptStoreReplacement) {
      throw StateError(
        'البيانات المحلية لم تُقرأ بأمان. استعد نسخة احتياطية صالحة قبل حفظ تغييرات جديدة.',
      );
    }
    try {
      await _repository.save(_data);
      _storageError = null;
      _loadFailed = false;
    } catch (error) {
      _storageError = 'تعذر حفظ البيانات على الجهاز: $error';
      notifyListeners();
      rethrow;
    }
    notifyListeners();
    await _syncPrayerSummaryNotification();
    await _syncAdhanSchedule(
      requestPermissions: requestAdhanPermissions,
    );
  }

  Future<void> _applyDisplaySettings() async {
    try {
      await WakelockPlus.toggle(enable: settings.keepAwake);
    } catch (_) {
      // The app remains usable if a device does not expose wakelock support.
    }
    try {
      await SystemChrome.setEnabledSystemUIMode(
        settings.immersiveMode
            ? SystemUiMode.immersiveSticky
            : SystemUiMode.edgeToEdge,
      );
    } catch (_) {
      // System UI modes vary by Android version and device vendor.
    }
  }

  Future<void> updateSettings(AppSettings value) async {
    final displaySettingsChanged = settings.keepAwake != value.keepAwake ||
        settings.immersiveMode != value.immersiveMode;
    final shouldRequestAdhanPermissions = value.adhanEnabled &&
        (settings.adhanEnabled != value.adhanEnabled ||
            !_sameAdhanPrayerSettings(
              settings.adhanPrayerEnabled,
              value.adhanPrayerEnabled,
            ));
    _data = AppData(
      regions: _data.regions,
      selectedRegionId: _data.selectedRegionId,
      settings: value,
    );
    if (!value.dashboardTextColorEnabled) {
      _previewDashboardTextColor = null;
    }
    await _persist(
      requestAdhanPermissions: shouldRequestAdhanPermissions,
    );
    if (displaySettingsChanged) await _applyDisplaySettings();
    await _pruneExpiredRamadan();
  }

  Future<bool> _requestPrayerSummaryPermissionIfNeeded() async {
    if (!_prayerSummaryNotificationService.isSupported ||
        selectedRegion == null ||
        _requestingPrayerSummaryPermission) {
      return false;
    }

    if (settings.prayerSummaryPermissionRequested) {
      try {
        if (!await _prayerSummaryNotificationService.notificationsAllowed()) {
          if (settings.prayerSummaryEnabled) {
            await updateSettings(
              settings.copyWith(prayerSummaryEnabled: false),
            );
          }
          _prayerSummaryError =
              'إشعارات التطبيق غير مسموح بها. اسمح بها من إعدادات Android للتطبيق.';
          notifyListeners();
          return false;
        }
        if (settings.prayerSummaryEnabled) return false;
        await updateSettings(settings.copyWith(prayerSummaryEnabled: true));
        _prayerSummaryError = null;
        notifyListeners();
        return true;
      } catch (error) {
        _prayerSummaryError = 'تعذر التحقق من إذن الإشعارات: $error';
        notifyListeners();
        return false;
      }
    }

    _requestingPrayerSummaryPermission = true;
    var permitted = false;
    String? requestError;
    try {
      permitted = await _prayerSummaryNotificationService.requestPermission();
    } catch (error) {
      requestError = 'تعذر طلب إذن الإشعارات: $error';
    }

    try {
      await updateSettings(settings.copyWith(
        prayerSummaryEnabled: permitted,
        prayerSummaryPermissionRequested: true,
      ));
      _prayerSummaryError = permitted
          ? null
          : requestError ??
              'لم تسمح بالإشعارات. لتفعيلها لاحقًا، افتح إعدادات Android للتطبيق واسمح بالإشعارات.';
    } catch (error) {
      _prayerSummaryError =
          requestError ?? 'تعذر حفظ إعداد إذن الإشعارات: $error';
    } finally {
      _requestingPrayerSummaryPermission = false;
      notifyListeners();
    }
    return true;
  }

  Future<void> _pruneExpiredRamadan() async {
    final date = hijriDateAt(now);
    if (_ramadanCleanupRunning ||
        !settings.ramadanPlans.values.any((plan) => plan.expiredAt(date))) {
      return;
    }
    final attemptDate = '${date.year}-${date.month}-${date.day}';
    if (_ramadanCleanupAttemptDate == attemptDate) return;
    _ramadanCleanupAttemptDate = attemptDate;
    _ramadanCleanupRunning = true;
    final previous = _data;
    final plans = {...settings.ramadanPlans}
      ..removeWhere((_, plan) => plan.expiredAt(date));
    _data = AppData(
        regions: _data.regions,
        selectedRegionId: selectedRegionId,
        settings: settings.copyWith(ramadanPlans: plans));
    try {
      await _persist();
    } catch (_) {
      // Even if storage fails, date-scoped overlays cannot use expired times.
      _data = previous;
      notifyListeners();
    } finally {
      _ramadanCleanupRunning = false;
    }
  }

  Future<void> useExistingRamadanTimes() => _saveRamadanPlan(null);

  Future<void> saveRamadanTimes(Map<int, RamadanDay> days) =>
      _saveRamadanPlan(days);

  Future<void> _saveRamadanPlan(Map<int, RamadanDay>? days) async {
    final hijri = hijriDateAt(now);
    final source = _data.selectedRegion;
    if (hijri.month != 9 || source == null) {
      throw const FormatException(
          'اختر منطقة، وتأكد أن التاريخ الهجري في رمضان.');
    }
    final plan = RamadanPlan(
        year: hijri.year, custom: days != null, days: days ?? const {});
    if (days != null) {
      // Validate against the unchanged sunrise/Asr for each civil date.
      final first = DateTime(now.year, now.month, now.day - hijri.day + 1);
      for (final entry in days.entries) {
        final times = source.timesFor(first.add(Duration(days: entry.key - 1)));
        if (times == null) {
          throw FormatException(
              'لا توجد مواقيت للمنطقة في يوم رمضان ${entry.key}.');
        }
        int minutes(String id) {
          final p = times[id]!.split(':');
          return int.parse(p[0]) * 60 + int.parse(p[1]);
        }

        if (entry.value.fajrSecondMinutes >= minutes('sunrise') ||
            entry.value.maghribMinutes <= minutes('asr')) {
          throw FormatException(
              'راجع اليوم ${entry.key}: الفجر قبل الشروق والمغرب بعد العصر.');
        }
      }
    }
    final previous = _data;
    try {
      await updateSettings(settings.copyWith(ramadanPlans: {
        ...settings.ramadanPlans,
        source.id: plan,
      }));
    } catch (_) {
      _data = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> adjustClockSeconds(int seconds) async {
    if (seconds < -60 || seconds > 60) {
      throw ArgumentError.value(seconds, 'seconds', 'يجب أن يكون بين -60 و60');
    }
    final previous = _data;
    try {
      await updateSettings(settings.copyWith(
        clockOffsetSeconds: settings.clockOffsetSeconds + seconds,
      ));
    } catch (_) {
      _data = previous;
      clock.value = correctedTime(_deviceNow());
      notifyListeners();
      rethrow;
    }
    clock.value = correctedTime(_deviceNow());
    notifyListeners();
  }

  bool _sameAdhanPrayerSettings(
    Map<String, bool> first,
    Map<String, bool> second,
  ) {
    if (first.length != second.length) return false;
    for (final entry in first.entries) {
      if (second[entry.key] != entry.value) return false;
    }
    return true;
  }

  Future<void> _syncAdhanSchedule({required bool requestPermissions}) async {
    try {
      await _adhanAlarmService.synchronize(
        _data,
        requestPermissions: requestPermissions,
        now: _deviceNow(),
      );
      final hasSelectedRegion = selectedRegion != null;
      final hasEnabledPrayer = adhanPrayerSlots.any(
        (slot) => settings.adhanPrayerEnabled[slot.id] ?? true,
      );
      final events = AdhanAlarmSchedule.build(_data, now: _deviceNow());
      _adhanAlarmError = settings.adhanEnabled && !hasSelectedRegion
          ? 'اختر المنطقة من الإعدادات أولًا لتحديد مواقيت الأذان.'
          : settings.adhanEnabled &&
                  hasSelectedRegion &&
                  hasEnabledPrayer &&
                  events.isEmpty
              ? 'لا توجد مواقيت أذان قادمة مسجلة للمنطقة المختارة.'
              : null;
    } on PlatformException catch (error) {
      _adhanAlarmError = switch (error.code) {
        'exact_alarm_permission_required' =>
          'اسمح للتطبيق بالتنبيهات الدقيقة من إعدادات Android ليعمل الأذان والشاشة مغلقة.',
        'schedule_failed' =>
          'تعذر جدولة الأذان على هذا الجهاز: ${error.message ?? error.code}',
        _ => 'تعذر تفعيل تنبيهات الأذان: ${error.message ?? error.code}',
      };
    } on MissingPluginException {
      _adhanAlarmError =
          'نسخة Android الحالية لا تتضمن خدمة تنبيهات الأذان؛ أنشئ APK محدثًا.';
    } catch (error) {
      _adhanAlarmError = 'تعذر تجهيز مواعيد الأذان: $error';
    }
    notifyListeners();
  }

  Future<void> _syncPrayerSummaryNotification() async {
    if (!_prayerSummaryNotificationService.isSupported) {
      _prayerSummaryError = null;
      return;
    }

    final hasRegion = selectedRegion != null;
    final enabled = settings.prayerSummaryEnabled && hasRegion;
    final permissionWasDeclined = settings.prayerSummaryPermissionRequested &&
        !settings.prayerSummaryEnabled;
    _prayerSummaryError = settings.prayerSummaryEnabled && !hasRegion
        ? 'اختر المنطقة من الإعدادات أولًا لعرض مواقيت الإشعارات.'
        : permissionWasDeclined
            ? 'لم تسمح بالإشعارات. لتفعيلها لاحقًا، افتح إعدادات Android للتطبيق واسمح بالإشعارات.'
            : null;
    try {
      final succeeded = await _prayerSummaryNotificationService.synchronize(
        enabled ? _buildPrayerSummaryPayload() : const {'enabled': false},
      );
      if (enabled && !succeeded) {
        _prayerSummaryError =
            'تعذر تحديث إشعار المواقيت. تحقق من سماح Android بإشعارات التطبيق.';
      }
    } on PlatformException catch (error) {
      _prayerSummaryError =
          'تعذر تحديث إشعار المواقيت: ${error.message ?? error.code}';
    } on MissingPluginException {
      _prayerSummaryError =
          'نسخة Android الحالية لا تتضمن إشعار المواقيت؛ أنشئ APK محدثًا.';
    } catch (error) {
      _prayerSummaryError = 'تعذر تجهيز إشعار المواقيت: $error';
    }
    notifyListeners();
  }

  Map<String, Object?> _buildPrayerSummaryPayload() {
    final region = selectedRegion;
    if (region == null) return const {'enabled': false};

    final correctedNow = correctedTime(_deviceNow());
    final today = DateTime(
      correctedNow.year,
      correctedNow.month,
      correctedNow.day,
    );
    final firstDate = today.subtract(const Duration(days: 1));
    final dailySchedules = <Map<String, Object?>>[];
    final todayTimes = region.timesFor(today);
    final todaySchedule = <String, Object?>{
      'date': _notificationDateKey(today),
      if (todayTimes != null)
        'times': {
          for (final slot in prayerSlots)
            if (todayTimes[slot.id] != null)
              slot.id: _notificationTime(todayTimes[slot.id]!),
        },
    };
    final transitions = <DateTime>{};

    for (var offset = 0; offset <= adhanScheduleHorizonDays; offset++) {
      final date = DateTime(
        firstDate.year,
        firstDate.month,
        firstDate.day + offset,
      );
      transitions.add(date);
      final times = region.timesFor(date);
      if (times == null) continue;

      dailySchedules.add({
        'date': _notificationDateKey(date),
        'times': {
          for (final slot in prayerSlots)
            if (times[slot.id] != null)
              slot.id: _notificationTime(times[slot.id]!),
        },
      });

      for (final slot in prayerSlots.where(
        (value) => value.hasIqama || value.id == 'fajrFirst',
      )) {
        final time = times[slot.id];
        if (time == null) continue;
        final adhan = _dateTimeFor(date, time);
        transitions.add(adhan);

        final iqamaMinutes = settings.iqamaMinutes[slot.id];
        final fridayDhuhr =
            slot.id == 'dhuhr' && date.weekday == DateTime.friday;
        if (slot.hasIqama &&
            !fridayDhuhr &&
            iqamaMinutes != null &&
            iqamaMinutes > 0) {
          transitions.add(adhan.add(Duration(minutes: iqamaMinutes)));
        }
      }
    }

    final orderedTransitions = transitions.toList()..sort();
    final states = <Map<String, Object?>>[];
    DashboardStatus? previousStatus;

    for (final transition in orderedTransitions) {
      final status = countdownStatus(
        transition.add(const Duration(milliseconds: 1)),
      );
      final isDayRefresh = transition.hour == 0 &&
          transition.minute == 0 &&
          transition.second == 0;
      final changed = previousStatus == null ||
          previousStatus.kind != status.kind ||
          previousStatus.label != status.label ||
          previousStatus.target != status.target;
      if (isDayRefresh || changed) {
        states.add({
          'at': _notificationDateTime(transition),
          'kind': status.kind.name,
          'label': _notificationStatusLabel(status),
          if (status.target != null)
            'target': _notificationDateTime(status.target!),
        });
      }
      previousStatus = status;
    }

    return {
      'enabled': true,
      'regionName': region.name,
      'clockOffsetSeconds': settings.clockOffsetSeconds,
      'todaySchedule': todaySchedule,
      'dailySchedules': dailySchedules,
      'states': states,
    };
  }

  String _notificationStatusLabel(DashboardStatus status) {
    if (status.kind == DashboardStatusKind.iqama) {
      const prefix = 'إقامة صلاة ';
      final prayer = status.label.startsWith(prefix)
          ? status.label.substring(prefix.length)
          : status.label;
      return 'باقي لإقامة صلاة $prayer';
    }
    if (status.kind == DashboardStatusKind.nextEvent) {
      return 'باقي لأذان ${status.label}';
    }
    return status.label;
  }

  String _notificationDateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  String _notificationDateTime(DateTime date) =>
      '${_notificationDateKey(date)}T'
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}:'
      '${date.second.toString().padLeft(2, '0')}';

  String _notificationTime(String value) =>
      PrayerTimes.formatTime12(value).replaceFirst(
        RegExp(r'\s+(AM|PM)$'),
        '',
      );

  Future<void> setAppAndMosqueName({
    required String appName,
    required String mosqueName,
    String? mosqueNameLine2,
    String? mosqueNameLine3,
  }) async {
    final name = appName.trim();
    await updateSettings(
      settings.copyWith(
        appName: name.isEmpty ? 'مواقيت الصلاة' : name,
        mosqueName: mosqueName.trim(),
        mosqueNameLine2: mosqueNameLine2?.trim(),
        mosqueNameLine3: mosqueNameLine3?.trim(),
      ),
    );
  }

  Future<void> setIqamaDuration(String prayerId, int minutes) async {
    if (minutes < 0 || minutes > 180) {
      throw const FormatException(
        'مدة الإقامة يجب أن تكون بين صفر و180 دقيقة.',
      );
    }
    final durations = {...settings.iqamaMinutes, prayerId: minutes};
    await updateSettings(settings.copyWith(iqamaMinutes: durations));
  }

  Future<void> setIqamaDurations(Map<String, int?> values) async {
    final durations = {...settings.iqamaMinutes};
    for (final entry in values.entries) {
      _validatePrayerDuration(entry.key, entry.value, maximum: 180);
      if (entry.value == null) {
        durations.remove(entry.key);
      } else {
        durations[entry.key] = entry.value!;
      }
    }
    await updateSettings(settings.copyWith(iqamaMinutes: durations));
  }

  Future<void> setPrayerDurations(Map<String, int?> values) async {
    final durations = {...settings.prayerDurationMinutes};
    for (final entry in values.entries) {
      _validatePrayerDuration(entry.key, entry.value, maximum: 360);
      if (entry.value == null) {
        durations.remove(entry.key);
      } else {
        durations[entry.key] = entry.value!;
      }
    }
    await updateSettings(settings.copyWith(prayerDurationMinutes: durations));
  }

  Future<void> setPostPrayerDurations({
    required int? adhkarMinutes,
    required int? fridayKhutbahMinutes,
  }) async {
    for (final value in [adhkarMinutes, fridayKhutbahMinutes]) {
      if (value != null && (value < 0 || value > 360)) {
        throw const FormatException('المدة يجب أن تكون بين صفر و360 دقيقة.');
      }
    }
    await updateSettings(
      settings.copyWith(
        postPrayerDhikrMinutes: adhkarMinutes,
        fridayKhutbahMinutes: fridayKhutbahMinutes,
        clearPostPrayerDhikrMinutes: adhkarMinutes == null,
        clearFridayKhutbahMinutes: fridayKhutbahMinutes == null,
      ),
    );
  }

  Future<void> setRamadanPrayerSettings({
    required bool taraweehEnabled,
    required int taraweehMinutes,
    required bool qiyamEnabled,
    required int qiyamStartMinutes,
    required int qiyamEndMinutes,
  }) async {
    if (taraweehMinutes < 1 || taraweehMinutes > 360) {
      throw const FormatException(
          'مدة التراويح يجب أن تكون بين دقيقة و360 دقيقة.');
    }
    if (qiyamStartMinutes < 0 ||
        qiyamStartMinutes >= 1440 ||
        qiyamEndMinutes < 0 ||
        qiyamEndMinutes >= 1440 ||
        qiyamStartMinutes == qiyamEndMinutes) {
      throw const FormatException('حدد وقتين مختلفين لصلاة القيام.');
    }
    await updateSettings(settings.copyWith(
      ramadanTaraweehEnabled: taraweehEnabled,
      ramadanTaraweehMinutes: taraweehMinutes,
      ramadanQiyamEnabled: qiyamEnabled,
      ramadanQiyamStartMinutes: qiyamStartMinutes,
      ramadanQiyamEndMinutes: qiyamEndMinutes,
    ));
  }

  Future<void> setHijriManualDate({
    required int day,
    required int month,
    required DateTime referenceDate,
  }) async {
    HijriDate.fromGregorianWithManualDate(
      gregorian: referenceDate,
      referenceDate: referenceDate,
      day: day,
      month: month,
    );
    await updateSettings(
      settings.copyWith(
        hijriManualDay: day,
        hijriManualMonth: month,
        hijriAnchorDate: dateKey(referenceDate),
        hijriOffsetDays: 0,
      ),
    );
  }

  Future<void> clearHijriManualDate() async {
    await updateSettings(
      settings.copyWith(clearHijriManualDate: true, hijriOffsetDays: 0),
    );
  }

  HijriDate hijriDateAt(DateTime date) {
    return adjustedHijriDate(date,
        manualDay: settings.hijriManualDay,
        manualMonth: settings.hijriManualMonth,
        anchorDate: settings.hijriAnchorDate,
        offsetDays: settings.hijriOffsetDays);
  }

  void _validatePrayerDuration(
    String prayerId,
    int? minutes, {
    required int maximum,
  }) {
    if (!prayerSlots.any((slot) => slot.id == prayerId && slot.hasIqama)) {
      throw FormatException('الصلاة غير معروفة: $prayerId.');
    }
    if (minutes != null && (minutes < 0 || minutes > maximum)) {
      throw FormatException('المدة يجب أن تكون بين صفر و$maximum دقيقة.');
    }
  }

  Future<void> setPin(String? pin) async {
    if (pin == null || pin.isEmpty) {
      await updateSettings(settings.copyWith(pinSalt: '', pinHash: ''));
      return;
    }
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('رمز PIN يجب أن يتكون من 4 إلى 8 أرقام.');
    }
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final saltHex =
        salt.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    await updateSettings(settings.copyWith(pinSalt: saltHex, pinHash: digest));
  }

  bool verifyPin(String pin) {
    if (!settings.hasPin) return true;
    final salt = <int>[];
    for (var index = 0; index < settings.pinSalt.length; index += 2) {
      salt.add(
        int.parse(settings.pinSalt.substring(index, index + 2), radix: 16),
      );
    }
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    return digest == settings.pinHash;
  }

  Future<void> addRegion(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const FormatException('اكتب اسم المنطقة.');
    if (_data.regions.values.any(
      (region) => region.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      throw const FormatException('يوجد منطقة بهذا الاسم بالفعل.');
    }
    var id = createRegionId(cleanName);
    while (_data.regions.containsKey(id)) {
      id = '$id-${DateTime.now().microsecondsSinceEpoch}';
    }
    _data = AppData(
      regions: {
        ..._data.regions,
        id: PrayerRegion(id: id, name: cleanName, days: const {}),
      },
      selectedRegionId: _data.selectedRegionId,
      settings: settings,
    );
    await _persist();
  }

  Future<void> renameRegion(String id, String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) throw const FormatException('اكتب اسم المنطقة.');
    final region = _data.regions[id];
    if (region == null) throw const FormatException('المنطقة غير موجودة.');
    if (_data.regions.values.any(
      (value) =>
          value.id != id && value.name.toLowerCase() == cleanName.toLowerCase(),
    )) {
      throw const FormatException('يوجد منطقة أخرى بهذا الاسم.');
    }
    _data = AppData(
      regions: {..._data.regions, id: region.renamed(cleanName)},
      selectedRegionId: _data.selectedRegionId,
      settings: settings,
    );
    await _persist();
  }

  Future<void> deleteRegion(String id) async {
    if (_data.regions.length <= 1) {
      throw const FormatException('يجب أن تبقى منطقة واحدة على الأقل.');
    }
    final regions = {..._data.regions}..remove(id);
    final nextId = id == _data.selectedRegionId ? '' : _data.selectedRegionId;
    _data = AppData(
      regions: regions,
      selectedRegionId: nextId,
      settings: settings,
    );
    await _persist();
  }

  Future<void> selectRegion(String id) async {
    if (!_data.regions.containsKey(id)) {
      throw const FormatException('المنطقة غير موجودة.');
    }
    _data = AppData(
      regions: _data.regions,
      selectedRegionId: id,
      settings: settings,
    );
    await _persist();
    await _requestPrayerSummaryPermissionIfNeeded();
  }

  Future<void> saveDay(DateTime date, PrayerTimes times) async {
    final region = selectedRegion;
    if (region == null) throw const FormatException('اختر منطقة أولًا.');
    _data = AppData(
      regions: {..._data.regions, region.id: region.withDay(date, times)},
      selectedRegionId: _data.selectedRegionId,
      settings: settings,
    );
    await _persist();
  }

  Future<bool> importJson({
    required Future<bool> Function() confirmBackupReplacement,
    required Future<bool> Function(String regionName) confirmRegionReplacement,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return false;
      final file = result.files.single;
      final Uint8List? bytes = file.bytes;
      if (bytes == null) {
        throw const FormatException('تعذر قراءة محتوى الملف المحدد.');
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map && decoded['format'] == 'mwaqit-backup') {
        if (!await confirmBackupReplacement()) return false;
        _data = AppData.fromJson(
          decoded,
        ).withAvailableRegions(await loadBundledSchedules());
        await _persist(allowCorruptStoreReplacement: true);
        _lastActionError = null;
        notifyListeners();
        return true;
      }
      final imported = regionFromScheduleFile(decoded);
      if (_data.regions.containsKey(imported.id) &&
          !await confirmRegionReplacement(imported.name)) {
        return false;
      }
      _data = AppData(
        regions: {..._data.regions, imported.id: imported},
        selectedRegionId: _data.regions.containsKey(imported.id)
            ? _data.selectedRegionId
            : imported.id,
        settings: settings,
      );
      await _persist();
      _lastActionError = null;
      notifyListeners();
      return true;
    } on FormatException catch (error) {
      _lastActionError = error.message;
      rethrow;
    } catch (error) {
      _lastActionError = 'فشل استيراد الملف: $error';
      rethrow;
    }
  }

  Future<bool> exportBackup() async {
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(_data.toJson())),
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'حفظ نسخة مواقيت الصلاة',
      fileName: 'mwaqit-backup.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    if (path == null) return false;
    _lastActionError = null;
    notifyListeners();
    return true;
  }

  Future<void> restoreDefaults() async {
    _data = AppData(
      regions: _data.regions,
      selectedRegionId: _data.selectedRegionId,
      settings: const AppSettings(),
    );
    await _persist();
    await _applyDisplaySettings();
  }

  Future<void> setAutoStart(bool enabled) async {
    try {
      await _deviceChannel.invokeMethod<void>('setAutoStartEnabled', enabled);
      _lastActionError = null;
    } on PlatformException catch (error) {
      _lastActionError =
          'لم يتم تفعيل التشغيل التلقائي على هذا الجهاز: ${error.message ?? error.code}';
      notifyListeners();
      rethrow;
    } on MissingPluginException {
      _lastActionError =
          'ميزة التشغيل عند الإقلاع غير مهيأة في ملفات Android بعد.';
      notifyListeners();
      rethrow;
    }
    try {
      await updateSettings(settings.copyWith(autoStartEnabled: enabled));
    } catch (error) {
      try {
        await _deviceChannel.invokeMethod<void>(
          'setAutoStartEnabled',
          !enabled,
        );
      } catch (_) {
        // Keep the visible failure; the system may have blocked rollback too.
      }
      rethrow;
    }
  }

  DashboardStatus? currentIqamaStatus(DateTime now) {
    final region = selectedRegion;
    if (region == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    for (final offset in [0, -1]) {
      final date = DateTime(today.year, today.month, today.day + offset);
      final todayTimes = region.timesFor(date);
      if (todayTimes == null) continue;
      for (final slot in prayerSlots.where((value) => value.hasIqama)) {
        if (slot.id == 'dhuhr' && date.weekday == DateTime.friday) continue;
        final adhan = _dateTimeFor(date, todayTimes[slot.id]!);
        final duration = settings.iqamaMinutes[slot.id];
        if (duration == null) continue;
        final iqamaAt = adhan.add(Duration(minutes: duration));
        if (!now.isBefore(adhan) && now.isBefore(iqamaAt)) {
          return DashboardStatus(
            kind: DashboardStatusKind.iqama,
            label: 'إقامة صلاة ${iqamaPrayerLabel(slot.id, slot.label)}',
            target: iqamaAt,
            prayerId: slot.id,
          );
        }
      }
    }
    return null;
  }

  PrayerScreenStatus? activePrayerScreen(
    DateTime now, {
    bool ramadanWelcomeDismissed = false,
    DateTime? ramadanWelcomeDismissedAt,
  }) {
    final region = selectedRegion;
    if (region == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final events = <PrayerAlertEvent>[];
    // Tomorrow covers an adhan shortly after midnight; yesterday covers an
    // Isha wait that continues into today.
    for (final offset in [-1, 0, 1]) {
      final date = DateTime(today.year, today.month, today.day + offset);
      final times = region.timesFor(date);
      if (times == null) continue;
      for (final slot in prayerSlots.where((value) => value.hasIqama)) {
        events.add(PrayerAlertEvent(
          prayerId: slot.id,
          label: slot.label,
          adhanAt: _dateTimeFor(date, times[slot.id]!),
          iqamaMinutes: settings.iqamaMinutes[slot.id],
        ));
      }
    }
    final alert = activePrayerAlert(now, events);
    if (alert != null) {
      return PrayerScreenStatus(
        phase: switch (alert.kind) {
          PrayerAlertKind.adhanCountdown => PrayerScreenPhase.adhanCountdown,
          PrayerAlertKind.adhanAnnouncement =>
            PrayerScreenPhase.adhanAnnouncement,
          PrayerAlertKind.iqamaCountdown => PrayerScreenPhase.iqamaCountdown,
        },
        label: alert.label,
        prayerId: alert.prayerId,
        startsAt: alert.startsAt,
        endsAt: alert.endsAt,
      );
    }
    final candidates = <PrayerScreenStatus>[];

    void addIfActive({
      required PrayerScreenPhase phase,
      required String label,
      required String prayerId,
      required DateTime start,
      required DateTime end,
    }) {
      if (end.isAfter(start) && !now.isBefore(start) && now.isBefore(end)) {
        candidates.add(
          PrayerScreenStatus(
            phase: phase,
            label: label,
            prayerId: prayerId,
            startsAt: start,
            endsAt: end,
          ),
        );
      }
    }

    final dhikrMinutes = settings.postPrayerDhikrMinutes ?? 0;
    void addDayActivities(DateTime date) {
      final times = region.timesFor(date);
      if (times == null) return;
      final hijriDay = hijriDateAt(date);
      for (final slot in prayerSlots.where((value) => value.hasIqama)) {
        final adhan = _dateTimeFor(date, times[slot.id]!);
        if (slot.id == 'dhuhr' && date.weekday == DateTime.friday) {
          final totalMinutes = settings.fridayKhutbahMinutes ?? 0;
          if (totalMinutes <= 0) continue;
          final khutbahEnd = adhan.add(Duration(minutes: totalMinutes));
          final firstPartMinutes = totalMinutes < 1 ? totalMinutes : 1;
          final introEnd = adhan.add(Duration(minutes: firstPartMinutes));
          addIfActive(
            phase: PrayerScreenPhase.fridayKhutbah,
            label: 'استمع للخطبة',
            prayerId: slot.id,
            start: adhan,
            end: introEnd,
          );
          addIfActive(
            phase: PrayerScreenPhase.fridayBlackout,
            label: slot.label,
            prayerId: slot.id,
            start: introEnd,
            end: khutbahEnd,
          );
          if (dhikrMinutes > 0) {
            addIfActive(
              phase: PrayerScreenPhase.postPrayerDhikr,
              label: 'أذكار الصلاة',
              prayerId: slot.id,
              start: khutbahEnd,
              end: khutbahEnd.add(Duration(minutes: dhikrMinutes)),
            );
          }
          continue;
        }

        final iqamaMinutes = settings.iqamaMinutes[slot.id];
        final prayerMinutes = settings.prayerDurationMinutes[slot.id];
        if (iqamaMinutes == null) {
          continue;
        }
        final prayerStart = adhan.add(Duration(minutes: iqamaMinutes));
        // Never invent a prayer/blackout or dhikr duration for blank settings.
        if (prayerMinutes == null || prayerMinutes <= 0) continue;
        final prayerEnd = prayerStart.add(Duration(minutes: prayerMinutes));
        addIfActive(
          phase: PrayerScreenPhase.prayerBlackout,
          label: slot.label,
          prayerId: slot.id,
          start: prayerStart,
          end: prayerEnd,
        );
        final isFirstRamadanFajr =
            slot.id == 'fajrSecond' && hijriDay.month == 9 && hijriDay.day == 1;
        final greetingNeeded = isFirstRamadanFajr &&
            needsRamadanChoice &&
            !ramadanWelcomeDismissed;
        if (greetingNeeded) {
          addIfActive(
            phase: PrayerScreenPhase.ramadanWelcome,
            label: 'مبارك عليكم شهر رمضان المبارك',
            prayerId: slot.id,
            start: prayerEnd,
            end: prayerEnd.add(const Duration(days: 1)),
          );
        }
        if (dhikrMinutes > 0) {
          final dhikrStart =
              isFirstRamadanFajr && ramadanWelcomeDismissedAt != null
                  ? (ramadanWelcomeDismissedAt.isAfter(prayerEnd)
                      ? ramadanWelcomeDismissedAt
                      : prayerEnd)
                  : prayerEnd;
          addIfActive(
            phase: PrayerScreenPhase.postPrayerDhikr,
            label: 'أذكار الصلاة',
            prayerId: slot.id,
            start: dhikrStart,
            end: dhikrStart.add(Duration(minutes: dhikrMinutes)),
          );
        }
        if (slot.id == 'isha' &&
            settings.ramadanTaraweehEnabled &&
            hijriDay.month == 9) {
          final taraweehStart = prayerEnd.add(Duration(minutes: dhikrMinutes));
          addIfActive(
            phase: PrayerScreenPhase.ramadanTaraweeh,
            label: 'صلاة التراويح',
            prayerId: slot.id,
            start: taraweehStart,
            end: taraweehStart
                .add(Duration(minutes: settings.ramadanTaraweehMinutes)),
          );
        }
      }

      if (settings.ramadanQiyamEnabled) {
        final qiyamStart = DateTime(
          date.year,
          date.month,
          date.day,
          settings.ramadanQiyamStartMinutes ~/ 60,
          settings.ramadanQiyamStartMinutes % 60,
        );
        final startHijri = hijriDateAt(qiyamStart);
        if (startHijri.month == 9 && startHijri.day >= 21) {
          var qiyamEnd = DateTime(
            date.year,
            date.month,
            date.day,
            settings.ramadanQiyamEndMinutes ~/ 60,
            settings.ramadanQiyamEndMinutes % 60,
          );
          if (!qiyamEnd.isAfter(qiyamStart)) {
            qiyamEnd = qiyamEnd.add(const Duration(days: 1));
          }
          addIfActive(
            phase: PrayerScreenPhase.ramadanQiyam,
            label: 'صلاة القيام',
            prayerId: 'ramadanQiyam',
            start: qiyamStart,
            end: qiyamEnd,
          );
        }
      }
    }

    for (final offset in [-1, 0]) {
      addDayActivities(DateTime(today.year, today.month, today.day + offset));
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) {
      final byStart = b.startsAt.compareTo(a.startsAt);
      if (byStart != 0) return byStart;
      if (a.phase == PrayerScreenPhase.ramadanWelcome) return -1;
      if (b.phase == PrayerScreenPhase.ramadanWelcome) return 1;
      return 0;
    });
    return candidates.first;
  }

  DashboardStatus nextPrayerStatus(DateTime now,
      {bool includeFirstAdhan = false}) {
    final region = selectedRegion;
    if (region == null) {
      return const DashboardStatus(
        kind: DashboardStatusKind.noTodaySchedule,
        label: 'لا توجد مواقيت',
      );
    }
    final todayTimes = region.timesFor(now);
    if (todayTimes == null) {
      return DashboardStatus(
        kind: DashboardStatusKind.noTodaySchedule,
        label: 'لا توجد مواقيت ليوم ${dateKey(now)}.',
      );
    }

    final today = DateTime(now.year, now.month, now.day);
    for (final slot in prayerSlots.where(
      (value) =>
          value.hasIqama || (includeFirstAdhan && value.id == 'fajrFirst'),
    )) {
      final event = _dateTimeFor(today, todayTimes[slot.id]!);
      if (event.isAfter(now) || (!includeFirstAdhan && event == now)) {
        return DashboardStatus(
          kind: DashboardStatusKind.nextEvent,
          label: slot.label,
          target: event,
          prayerId: slot.id,
        );
      }
    }

    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowTimes = region.timesFor(tomorrow);
    if (tomorrowTimes == null) {
      return DashboardStatus(
        kind: DashboardStatusKind.missingNextDay,
        label:
            'لا توجد مواقيت مسجلة ليوم ${dateKey(tomorrow)} في ${region.name}.',
      );
    }
    final nextFajrSlot = prayerSlots.firstWhere(
      (slot) => slot.id == (includeFirstAdhan ? 'fajrFirst' : 'fajrSecond'),
    );
    final nextFajr = _dateTimeFor(tomorrow, tomorrowTimes[nextFajrSlot.id]!);
    return DashboardStatus(
      kind: DashboardStatusKind.nextEvent,
      label: nextFajrSlot.label,
      target: nextFajr,
      prayerId: nextFajrSlot.id,
    );
  }

  DashboardStatus dashboardStatus(DateTime now) =>
      currentIqamaStatus(now) ?? nextPrayerStatus(now);

  /// The first Fajr adhan has no iqama: continue directly to second Fajr.
  DashboardStatus countdownStatus(DateTime now) =>
      currentIqamaStatus(now) ?? nextPrayerStatus(now, includeFirstAdhan: true);

  String? highlightedPrayerId(DateTime now) {
    final region = selectedRegion;
    if (region == null) return null;
    final events = <PrayerHighlightEvent>[];
    for (final offset in [-1, 0, 1]) {
      final date = DateTime(now.year, now.month, now.day + offset);
      final times = region.timesFor(date);
      if (times == null) continue;
      for (final slot in prayerSlots.where((slot) => slot.hasIqama)) {
        events.add(PrayerHighlightEvent(
          id: slot.id,
          adhanAt: _dateTimeFor(date, times[slot.id]!),
          waitMinutes: settings.iqamaMinutes[slot.id],
          prayerMinutes: settings.prayerDurationMinutes[slot.id] ?? 0,
          khutbahMinutes: settings.fridayKhutbahMinutes ?? 0,
        ));
      }
    }
    return highlightedPrayer(now, events);
  }

  DateTime _dateTimeFor(DateTime date, String time) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  Future<void> resetActionError() async {
    _lastActionError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    clock.dispose();
    super.dispose();
  }
}
