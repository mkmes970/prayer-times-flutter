import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import '../services/adhan_alarm_service.dart';
import 'appearance_screen.dart';
import 'clock_correction_controls.dart';
import 'ramadan_screen.dart';
import 'region_selector.dart';

import '../models/prayer_schedule.dart';
import '../services/hijri_date.dart';
import '../state/prayer_controller.dart';
import 'dashboard_screen.dart';
import 'prayer_period_theme.dart';
import 'theme_catalog.dart';

const _forest = Color(0xFF17432E);
const _brass = Color(0xFFD4A63B);
const _settingsCream = Color(0xFFFFFBF2);
const _defaultDashboardTextColor = 0xFF17432E;
const _dashboardLineColorOptions = <_DashboardLineColorOption>[
  _DashboardLineColorOption('أبيض', 0xFFFFFFFF),
  _DashboardLineColorOption('أصفر', 0xFFFFEB3B),
  _DashboardLineColorOption('ذهبي', 0xFFFFC107),
  _DashboardLineColorOption('برتقالي', 0xFFFF9800),
  _DashboardLineColorOption('أحمر', 0xFFF44336),
  _DashboardLineColorOption('قرمزي', 0xFFE91E63),
  _DashboardLineColorOption('وردي', 0xFFFF80AB),
  _DashboardLineColorOption('بنفسجي', 0xFFBA68C8),
  _DashboardLineColorOption('أرجواني', 0xFF9C27B0),
  _DashboardLineColorOption('نيلي', 0xFF7C4DFF),
  _DashboardLineColorOption('أزرق', 0xFF2196F3),
  _DashboardLineColorOption('سماوي', 0xFF40C4FF),
  _DashboardLineColorOption('فيروزي', 0xFF00BCD4),
  _DashboardLineColorOption('تركوازي', 0xFF00BFA5),
  _DashboardLineColorOption('أخضر', 0xFF4CAF50),
  _DashboardLineColorOption('أخضر فاتح', 0xFF8BC34A),
  _DashboardLineColorOption('ليموني', 0xFFCDDC39),
  _DashboardLineColorOption('عاجي', 0xFFFFF8E1),
  _DashboardLineColorOption('خوخي', 0xFFFFAB91),
  _DashboardLineColorOption('مرجاني', 0xFFFF6E40),
  _DashboardLineColorOption('أزرق داكن', 0xFF1565C0),
  _DashboardLineColorOption('أخضر زمردي', 0xFF00A86B),
  _DashboardLineColorOption('أخضر نعناعي', 0xFF69F0AE),
  _DashboardLineColorOption('بنفسجي فاتح', 0xFFE1BEE7),
  _DashboardLineColorOption('أزرق ثلجي', 0xFFB3E5FC),
  _DashboardLineColorOption('أصفر ليموني', 0xFFF4FF81),
  _DashboardLineColorOption('وردي فاتح', 0xFFF8BBD0),
  _DashboardLineColorOption('نحاسي', 0xFFD7A86E),
  _DashboardLineColorOption('فضي', 0xFFCFD8DC),
  _DashboardLineColorOption('أزرق ملكي', 0xFF536DFE),
  _DashboardLineColorOption('أخضر بحري', 0xFF64FFDA),
  _DashboardLineColorOption('مرجاني فاتح', 0xFFFF8A65),
];

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.controller, super.key});

  final PrayerController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _appName;
  late final TextEditingController _mosqueName;
  late final TextEditingController _mosqueNameLine2;
  late final TextEditingController _mosqueNameLine3;
  late final TextEditingController _regionName;
  late final Map<String, TextEditingController> _iqamaFields;
  late final Map<String, TextEditingController> _prayerDurationFields;
  late final TextEditingController _postPrayerDhikrField;
  late final TextEditingController _fridayKhutbahField;
  late final TextEditingController _ramadanTaraweehMinutesField;
  late bool _ramadanTaraweehEnabled;
  late bool _ramadanQiyamEnabled;
  late TimeOfDay _ramadanQiyamStart;
  late TimeOfDay _ramadanQiyamEnd;
  late String _regionSelectionDraft;
  late int _hijriDay;
  late int _hijriMonth;
  late bool _dashboardLineColorsEnabled;
  late int _dashboardLineColorDraft;
  DateTime _editDate = DateTime.now();
  bool _savingNames = false;
  bool _savingDurations = false;
  bool _savingPrayerTimes = false;
  bool _savingPostPrayer = false;
  bool _savingRamadanPrayers = false;
  bool _savingHijriDate = false;
  bool _savingAdhanSettings = false;
  bool _savingDashboardLineColor = false;

  PrayerController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _editDate = controller.now;
    _appName = TextEditingController(text: controller.settings.appName);
    _mosqueName = TextEditingController(text: controller.settings.mosqueName);
    _mosqueNameLine2 =
        TextEditingController(text: controller.settings.mosqueNameLine2);
    _mosqueNameLine3 =
        TextEditingController(text: controller.settings.mosqueNameLine3);
    _regionName = TextEditingController();
    _regionSelectionDraft = controller.selectedRegionId;
    _postPrayerDhikrField = TextEditingController(
      text: controller.settings.postPrayerDhikrMinutes?.toString() ?? '',
    );
    _fridayKhutbahField = TextEditingController(
      text: controller.settings.fridayKhutbahMinutes?.toString() ?? '',
    );
    _ramadanTaraweehMinutesField = TextEditingController(
      text: controller.settings.ramadanTaraweehMinutes.toString(),
    );
    _ramadanTaraweehEnabled = controller.settings.ramadanTaraweehEnabled;
    _ramadanQiyamEnabled = controller.settings.ramadanQiyamEnabled;
    _ramadanQiyamStart = TimeOfDay(
      hour: controller.settings.ramadanQiyamStartMinutes ~/ 60,
      minute: controller.settings.ramadanQiyamStartMinutes % 60,
    );
    _ramadanQiyamEnd = TimeOfDay(
      hour: controller.settings.ramadanQiyamEndMinutes ~/ 60,
      minute: controller.settings.ramadanQiyamEndMinutes % 60,
    );
    _iqamaFields = {
      for (final slot in prayerSlots.where((item) => item.hasIqama))
        slot.id: TextEditingController(
          text: controller.settings.iqamaMinutes[slot.id]?.toString() ?? '',
        ),
    };
    _prayerDurationFields = {
      for (final slot in prayerSlots.where((item) => item.hasIqama))
        slot.id: TextEditingController(
          text:
              controller.settings.prayerDurationMinutes[slot.id]?.toString() ??
                  '',
        ),
    };
    final hijriNow = controller.hijriDateAt(controller.now);
    _hijriDay = controller.settings.hijriManualDay ?? hijriNow.day;
    _hijriMonth = controller.settings.hijriManualMonth ?? hijriNow.month;
    _dashboardLineColorsEnabled = controller.settings.dashboardTextColorEnabled;
    _dashboardLineColorDraft = controller.settings.dashboardTextColor;
  }

  @override
  void dispose() {
    controller.previewDashboardLineColor(null);
    _appName.dispose();
    _mosqueName.dispose();
    _mosqueNameLine2.dispose();
    _mosqueNameLine3.dispose();
    _regionName.dispose();
    _postPrayerDhikrField.dispose();
    _fridayKhutbahField.dispose();
    _ramadanTaraweehMinutesField.dispose();
    for (final field in _iqamaFields.values) {
      field.dispose();
    }
    for (final field in _prayerDurationFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _setDashboardLineColorsEnabled(bool enabled) async {
    if (enabled) {
      setState(() => _dashboardLineColorsEnabled = true);
      return;
    }
    setState(() {
      _dashboardLineColorsEnabled = false;
      _dashboardLineColorDraft = _defaultDashboardTextColor;
      _savingDashboardLineColor = true;
    });
    controller.previewDashboardLineColor(null);
    try {
      await controller.updateSettings(controller.settings.copyWith(
        dashboardTextColorEnabled: false,
        dashboardTextColor: _defaultDashboardTextColor,
      ));
    } catch (error) {
      if (mounted) {
        setState(() => _dashboardLineColorsEnabled =
            controller.settings.dashboardTextColorEnabled);
        _message('تعذر إيقاف ألوان الخط: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _savingDashboardLineColor = false);
    }
  }

  Future<void> _saveDashboardLineColor() async {
    setState(() => _savingDashboardLineColor = true);
    try {
      await controller.updateSettings(controller.settings.copyWith(
        dashboardTextColorEnabled: true,
        dashboardTextColor: _dashboardLineColorDraft,
      ));
      controller.previewDashboardLineColor(null);
      _message('تم حفظ لون الخط.');
    } catch (error) {
      _message('تعذر حفظ لون الخط: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingDashboardLineColor = false);
    }
  }

  Future<void> _previewDashboardLineColor() async {
    controller.previewDashboardLineColor(_dashboardLineColorDraft);
    final now = controller.now;
    final theme = themeForPeriod(
      prayerPeriodAt(now, controller.selectedRegion?.timesFor(now)),
      controller.settings,
    );
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => DashboardScreen(
          controller: controller,
          previewTheme: theme,
        ),
      ),
    );
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade800 : _forest,
      ),
    );
  }

  Future<void> _setAdhanEnabled(bool enabled) async {
    if (enabled && controller.selectedRegion == null) {
      _message('اختر المنطقة من الإعدادات أولًا.', error: true);
      return;
    }
    setState(() => _savingAdhanSettings = true);
    try {
      if (kIsWeb && enabled) await controller.previewWebAdhan();
      await controller.updateSettings(
        controller.settings.copyWith(adhanEnabled: enabled),
      );
      final issue = controller.adhanAlarmError;
      if (issue != null) {
        _message(issue, error: true);
      } else {
        _message(
            enabled ? 'تم تفعيل تنبيهات الأذان.' : 'تم كتم تنبيهات الأذان.');
      }
    } catch (error) {
      _message('تعذر تحديث تنبيهات الأذان: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingAdhanSettings = false);
    }
  }

  Future<void> _togglePrayerAdhan(String prayerId) async {
    final enabled = controller.settings.adhanPrayerEnabled[prayerId] ?? true;
    final next = {
      ...controller.settings.adhanPrayerEnabled,
      prayerId: !enabled
    };
    setState(() => _savingAdhanSettings = true);
    try {
      await controller.updateSettings(
        controller.settings.copyWith(adhanPrayerEnabled: next),
      );
      final issue = controller.adhanAlarmError;
      if (issue != null) {
        _message(issue, error: true);
      } else {
        final prayer =
            adhanPrayerSlots.firstWhere((slot) => slot.id == prayerId).label;
        _message(
            enabled ? 'تم كتم أذان $prayer.' : 'تم تفعيل صوت أذان $prayer.');
      }
    } catch (error) {
      _message('تعذر تحديث صوت الأذان: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingAdhanSettings = false);
    }
  }

  Future<void> _saveNames() async {
    setState(() => _savingNames = true);
    try {
      await controller.setAppAndMosqueName(
        appName: _appName.text,
        mosqueName: _mosqueName.text,
        mosqueNameLine2: _mosqueNameLine2.text,
        mosqueNameLine3: _mosqueNameLine3.text,
      );
      _message('تم حفظ الاسم.');
    } catch (error) {
      _message('تعذر الحفظ: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingNames = false);
    }
  }

  Future<void> _addRegion() async {
    try {
      await controller.addRegion(_regionName.text);
      _regionName.clear();
      _message('تمت إضافة المنطقة.');
    } catch (error) {
      _message('تعذر إضافة المنطقة: $error', error: true);
    }
  }

  Future<void> _renameRegion() async {
    final region = controller.selectedRegion;
    if (region == null) return;
    final field = TextEditingController(text: region.name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير اسم المنطقة'),
        content: TextField(controller: field, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, field.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    field.dispose();
    if (name == null) return;
    try {
      await controller.renameRegion(region.id, name);
      _message('تم تحديث اسم المنطقة.');
    } catch (error) {
      _message('تعذر تغيير الاسم: $error', error: true);
    }
  }

  Future<void> _deleteRegion() async {
    final region = controller.selectedRegion;
    if (region == null) return;
    final confirmed = await _confirm(
      title: 'حذف المنطقة؟',
      message:
          'سيتم حذف «${region.name}» وكل مواقيتها المحفوظة على هذا الجهاز.',
      confirmLabel: 'حذف المنطقة',
    );
    if (confirmed != true) return;
    try {
      await controller.deleteRegion(region.id);
      if (mounted) {
        setState(() => _regionSelectionDraft = controller.selectedRegionId);
      }
      _message('تم حذف المنطقة.');
    } catch (error) {
      _message('تعذر حذف المنطقة: $error', error: true);
    }
  }

  Future<void> _saveRegionSelection() async {
    try {
      await controller.selectRegion(_regionSelectionDraft);
      _message('تم حفظ المنطقة الحالية.');
    } catch (error) {
      _message('تعذر حفظ المنطقة: $error', error: true);
    }
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'تأكيد',
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(backgroundColor: Colors.red.shade800)
                : null,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _editPrayerTimes() async {
    // Edit source regional times, never copy seasonal overlay into the base.
    final region = controller.regions[controller.selectedRegionId];
    if (region == null) return;
    final existing = region.timesFor(_editDate);
    final values = <String, String>{
      for (final slot in prayerSlots)
        if (existing?[slot.id] != null)
          slot.id: PrayerTimes.formatTime12(existing![slot.id]!),
    };
    final timeFields = <String, TextEditingController>{
      for (final slot in prayerSlots)
        slot.id: TextEditingController(text: values[slot.id] ?? ''),
    };
    final saved = await showDialog<PrayerTimes>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, refreshDialog) => AlertDialog(
          title: Text('مواقيت ${dateKey(_editDate)}'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final slot in prayerSlots)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(slot.label)),
                          SizedBox(
                            width: 120,
                            child: TextField(
                              controller: timeFields[slot.id],
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              keyboardType: TextInputType.datetime,
                              decoration: const InputDecoration(
                                hintText: '4:35 AM',
                                counterText: '',
                                isDense: true,
                              ),
                              maxLength: 8,
                              onChanged: (value) => values[slot.id] = value,
                            ),
                          ),
                          IconButton(
                            tooltip: 'اختيار الوقت',
                            onPressed: () async {
                              final current = timeFields[slot.id]!.text;
                              var initial = const TimeOfDay(hour: 0, minute: 0);
                              try {
                                final minutes = PrayerTimes.parseTimeMinutes(
                                  current,
                                );
                                initial = TimeOfDay(
                                  hour: minutes ~/ 60,
                                  minute: minutes % 60,
                                );
                              } on FormatException {
                                // Use midnight for an empty or incomplete entry.
                              }
                              final picked = await showTimePicker(
                                context: context,
                                initialTime: initial,
                                builder: (context, child) => MediaQuery(
                                  data: MediaQuery.of(
                                    context,
                                  ).copyWith(alwaysUse24HourFormat: false),
                                  child: child!,
                                ),
                              );
                              if (picked == null) return;
                              final hour =
                                  picked.hour % 12 == 0 ? 12 : picked.hour % 12;
                              final period =
                                  picked.period == DayPeriod.am ? 'AM' : 'PM';
                              final value =
                                  '$hour:${picked.minute.toString().padLeft(2, '0')} $period';
                              timeFields[slot.id]!.text = value;
                              values[slot.id] = value;
                              refreshDialog(() {});
                            },
                            icon: const Icon(Icons.schedule),
                          ),
                        ],
                      ),
                    ),
                  const Text(
                    'أدخل الأوقات بنظام 12 ساعة مثل 4:35 AM أو 4:35 م. يمكن إدخال 4:35 بلا لاحقة؛ ويستدل التطبيق على الفترة من ترتيب مواقيت اليوم.',
                    style: TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                for (final slot in prayerSlots) {
                  values[slot.id] = timeFields[slot.id]!.text.trim();
                }
                try {
                  Navigator.pop(dialogContext, PrayerTimes.fromJson(values));
                } on FormatException catch (error) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(error.message)));
                }
              },
              child: const Text('حفظ اليوم'),
            ),
          ],
        ),
      ),
    );
    for (final field in timeFields.values) {
      field.dispose();
    }
    if (saved == null) return;
    try {
      await controller.saveDay(_editDate, saved);
      _message('تم حفظ مواقيت ${dateKey(_editDate)}.');
    } catch (error) {
      _message('تعذر حفظ اليوم: $error', error: true);
    }
  }

  Future<void> _importFile() async {
    try {
      final imported = await controller.importJson(
        confirmBackupReplacement: () => _confirm(
          title: 'استعادة النسخة الاحتياطية؟',
          message:
              'سيؤدي ذلك إلى استبدال جميع المناطق والمواقيت والإعدادات الحالية على هذا الجهاز.',
          confirmLabel: 'استعادة النسخة',
          destructive: true,
        ).then((value) => value ?? false),
        confirmRegionReplacement: (name) => _confirm(
          title: 'استبدال مواقيت المنطقة؟',
          message:
              'توجد منطقة بالمعرّف نفسه. سيتم استبدال جدول «$name» الموجود بالملف المستورد.',
          confirmLabel: 'استبدال الجدول',
          destructive: true,
        ).then((value) => value ?? false),
      );
      if (imported) {
        if (mounted) {
          setState(() => _regionSelectionDraft = controller.selectedRegionId);
        }
        _message('تم استيراد الملف والتحقق من بنيته.');
      }
    } catch (error) {
      _message('لم يتم الاستيراد: $error', error: true);
    }
  }

  Future<void> _exportBackup() async {
    try {
      final saved = await controller.exportBackup();
      if (saved) _message('تم إنشاء ملف النسخة الاحتياطية.');
    } catch (error) {
      _message('تعذر تصدير النسخة: $error', error: true);
    }
  }

  Future<void> _restoreDefaults() async {
    final confirmed = await _confirm(
      title: 'إعادة الإعدادات الافتراضية؟',
      message:
          'ستعود إعدادات الاسم والمظهر والعدادات إلى الافتراضية. ستبقى المناطق ومواقيت الصلاة المحفوظة كما هي.',
      confirmLabel: 'إعادة الضبط',
      destructive: true,
    );
    if (confirmed != true) return;
    await controller.restoreDefaults();
    setState(() {
      _appName.text = controller.settings.appName;
      _mosqueName.text = controller.settings.mosqueName;
      _mosqueNameLine2.text = controller.settings.mosqueNameLine2;
      _mosqueNameLine3.text = controller.settings.mosqueNameLine3;
      for (final field in _iqamaFields.values) {
        field.clear();
      }
      for (final field in _prayerDurationFields.values) {
        field.clear();
      }
      _postPrayerDhikrField.clear();
      _fridayKhutbahField.clear();
      _ramadanTaraweehMinutesField.text = '35';
      _ramadanTaraweehEnabled = false;
      _ramadanQiyamEnabled = false;
      _ramadanQiyamStart = const TimeOfDay(hour: 2, minute: 30);
      _ramadanQiyamEnd = const TimeOfDay(hour: 3, minute: 30);
      final hijri = controller.hijriDateAt(controller.now);
      _hijriDay = hijri.day;
      _hijriMonth = hijri.month;
    });
    _message('تمت إعادة الإعدادات إلى حالتها الافتراضية.');
  }

  Future<void> _managePin() async {
    final pinField = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          controller.settings.hasPin ? 'تغيير رمز PIN' : 'حماية الإعدادات',
        ),
        content: TextField(
          controller: pinField,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 8,
          decoration: const InputDecoration(labelText: 'من 4 إلى 8 أرقام'),
        ),
        actions: [
          if (controller.settings.hasPin)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, '__REMOVE_PIN__'),
              child: const Text('إزالة PIN'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, pinField.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    pinField.dispose();
    if (result == null) return;
    try {
      await controller.setPin(result == '__REMOVE_PIN__' ? null : result);
      _message(
        result == '__REMOVE_PIN__' ? 'تمت إزالة حماية PIN.' : 'تم حفظ PIN.',
      );
    } catch (error) {
      _message('تعذر حفظ PIN: $error', error: true);
    }
  }

  int? _readMinutes(
    TextEditingController field,
    String label, {
    int maximum = 360,
  }) {
    final text = field.text.trim();
    if (text.isEmpty) return null;
    final value = int.tryParse(text);
    if (value == null || value < 0 || value > maximum) {
      throw FormatException(
        '$label: أدخل عددًا صحيحًا بين صفر و$maximum أو اتركه فارغًا.',
      );
    }
    return value;
  }

  Future<void> _saveIqamaDurations() async {
    setState(() => _savingDurations = true);
    try {
      final values = {
        for (final entry in _iqamaFields.entries)
          entry.key: _readMinutes(entry.value, 'مدة الإقامة', maximum: 180),
      };
      await controller.setIqamaDurations(values);
      _message('تم حفظ مدد الإقامة.');
    } catch (error) {
      _message('تعذر حفظ مدد الإقامة: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingDurations = false);
    }
  }

  Future<void> _savePrayerDurations() async {
    setState(() => _savingPrayerTimes = true);
    try {
      final values = {
        for (final entry in _prayerDurationFields.entries)
          entry.key: _readMinutes(entry.value, 'مدة الصلاة'),
      };
      await controller.setPrayerDurations(values);
      _message('تم حفظ مدد الصلاة.');
    } catch (error) {
      _message('تعذر حفظ مدد الصلاة: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingPrayerTimes = false);
    }
  }

  Future<void> _savePostPrayerDurations() async {
    setState(() => _savingPostPrayer = true);
    try {
      await controller.setPostPrayerDurations(
        adhkarMinutes: _readMinutes(_postPrayerDhikrField, 'مدة الأذكار'),
        fridayKhutbahMinutes: _readMinutes(
          _fridayKhutbahField,
          'مدة خطبة الجمعة',
        ),
      );
      _message('تم حفظ مدتي الأذكار والخطبة.');
    } catch (error) {
      _message('تعذر حفظ المدد: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingPostPrayer = false);
    }
  }

  int _minuteOfDay(TimeOfDay time) => time.hour * 60 + time.minute;

  String _ramadanTimeLabel(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'صباحًا' : 'مساءً'}';
  }

  Future<void> _chooseQiyamTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: start ? _ramadanQiyamStart : _ramadanQiyamEnd,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() {
        if (start) {
          _ramadanQiyamStart = picked;
        } else {
          _ramadanQiyamEnd = picked;
        }
      });
    }
  }

  Future<void> _saveRamadanPrayerSettings() async {
    setState(() => _savingRamadanPrayers = true);
    try {
      final minutes = int.tryParse(_ramadanTaraweehMinutesField.text.trim());
      if (minutes == null) {
        throw const FormatException('أدخل مدة صلاة التراويح بالدقائق.');
      }
      await controller.setRamadanPrayerSettings(
        taraweehEnabled: _ramadanTaraweehEnabled,
        taraweehMinutes: minutes,
        qiyamEnabled: _ramadanQiyamEnabled,
        qiyamStartMinutes: _minuteOfDay(_ramadanQiyamStart),
        qiyamEndMinutes: _minuteOfDay(_ramadanQiyamEnd),
      );
      _message('تم حفظ إعدادات التراويح والقيام.');
    } catch (error) {
      _message('تعذر حفظ إعدادات رمضان: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingRamadanPrayers = false);
    }
  }

  Future<void> _saveHijriManualDate() async {
    setState(() => _savingHijriDate = true);
    try {
      final now = controller.now;
      await controller.setHijriManualDate(
        day: _hijriDay,
        month: _hijriMonth,
        referenceDate: DateTime(now.year, now.month, now.day),
      );
      _message('تم حفظ التاريخ الهجري يدويًا.');
    } catch (error) {
      _message('تعذر حفظ التاريخ الهجري: $error', error: true);
    } finally {
      if (mounted) setState(() => _savingHijriDate = false);
    }
  }

  Future<void> _resetHijriManualDate() async {
    try {
      await controller.clearHijriManualDate();
      final calculated = controller.hijriDateAt(controller.now);
      setState(() {
        _hijriDay = calculated.day;
        _hijriMonth = calculated.month;
      });
      _message('عاد التاريخ الهجري إلى الحساب التلقائي.');
    } catch (error) {
      _message('تعذر إعادة التاريخ التلقائي: $error', error: true);
    }
  }

  List<Widget> _durationRows(Map<String, TextEditingController> fields) => [
        for (final slot in prayerSlots.where((item) => item.hasIqama))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(child: Text(slot.label)),
                SizedBox(
                  width: 130,
                  child: TextField(
                    controller: fields[slot.id],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      labelText: 'بالدقائق',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ];

  Widget _minutesField(TextEditingController field, {required String label}) =>
      TextField(
        controller: field,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(labelText: label, suffixText: 'دقيقة'),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final regionSelection =
            controller.regions.containsKey(_regionSelectionDraft)
                ? _regionSelectionDraft
                : controller.regions.containsKey(controller.selectedRegionId)
                    ? controller.selectedRegionId
                    : null;
        final hasPendingRegionSelection = regionSelection != null &&
            regionSelection != controller.selectedRegionId;
        return Scaffold(
          appBar: AppBar(title: Text('إعدادات ${controller.settings.appName}')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_outlined),
                title: const Text('واجهة التطبيق'),
                subtitle: const Text('السمات ومعاينة مظهر كل وقت'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AppearanceScreen(controller: controller),
                  ),
                ),
              ),
              if (controller.storageError != null)
                _WarningPanel(message: controller.storageError!),
              if (controller.lastActionError != null)
                _WarningPanel(message: controller.lastActionError!),
              _section('عرض الأحاديث'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تفعيل الأحاديث'),
                subtitle: const Text(
                    'يتحكم بجميع أحاديث مربع العرض، بما فيها أحاديث قبل الأذان وأذكار الصباح والمساء. الشريط السفلي يعمل في الحالتين.'),
                value: controller.settings.hadithEnabled,
                onChanged: (value) => controller.updateSettings(
                  controller.settings.copyWith(hadithEnabled: value),
                ),
              ),
              if (supportsAdhanAlerts) ...[
                _section('تنبيهات الأذان'),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تفعيل صوت الأذان'),
                  subtitle: Text(
                    kIsWeb
                        ? 'صوت الأذان أثناء فتح التطبيق ونشاطه فقط، بعد السماح بالصوت. لا يُضمن عند قفل الشاشة أو إغلاق التطبيق. التفعيل يشغّل التسجيل للتجربة؛ أبقِ صوت الجهاز مسموعًا.'
                        : 'يشغّل التسجيل المرفق كاملًا عند الصلاة المختارة، حتى مع قفل الشاشة. يحتاج إذن التنبيهات الدقيقة.',
                  ),
                  value: controller.settings.adhanEnabled,
                  onChanged: _savingAdhanSettings ? null : _setAdhanEnabled,
                ),
                if (controller.settings.adhanEnabled) ...[
                  if (kIsWeb) ...[
                    ValueListenableBuilder<String?>(
                      valueListenable: controller.webAdhanStatus,
                      builder: (context, status, _) => Text(
                        status ?? 'الصوت متاح فقط أثناء فتح التطبيق.',
                        style: const TextStyle(color: _forest),
                      ),
                    ),
                    Wrap(
                      spacing: 12,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('تجربة الصوت وتفعيله لهذه الجلسة'),
                          onPressed: () async {
                            try {
                              await controller.previewWebAdhan();
                            } catch (_) {
                              if (mounted) {
                                _message(
                                    'تعذر تشغيل الأذان؛ راجع رسالة حالة الصوت.',
                                    error: true);
                              }
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.stop),
                          label: const Text('إيقاف الصوت الآن'),
                          onPressed: controller.stopWebAdhan,
                        ),
                      ],
                    ),
                  ],
                  if (controller.adhanAlarmError != null)
                    _WarningPanel(message: controller.adhanAlarmError!),
                  for (final slot in adhanPrayerSlots)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(slot.label),
                      subtitle: const Text('اضغط رمز السماعة للتفعيل أو الكتم'),
                      trailing: IconButton(
                        tooltip:
                            (controller.settings.adhanPrayerEnabled[slot.id] ??
                                    true)
                                ? 'كتم صوت ${slot.label}'
                                : 'تفعيل صوت ${slot.label}',
                        onPressed: _savingAdhanSettings
                            ? null
                            : () => _togglePrayerAdhan(slot.id),
                        icon: Icon(
                          (controller.settings.adhanPrayerEnabled[slot.id] ??
                                  true)
                              ? Icons.volume_up_outlined
                              : Icons.volume_off_outlined,
                          color: (controller
                                      .settings.adhanPrayerEnabled[slot.id] ??
                                  true)
                              ? _forest
                              : Colors.grey,
                        ),
                      ),
                    ),
                ],
              ],
              if (!kIsWeb &&
                  defaultTargetPlatform == TargetPlatform.android &&
                  controller.settings.prayerSummaryPermissionRequested &&
                  controller.prayerSummaryError != null)
                _WarningPanel(message: controller.prayerSummaryError!),
              _section('الشريط السفلي'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تفعيل الشريط السفلي'),
                subtitle: const Text(
                    'عند التفعيل يظهر الشريط متحركًا، وعند الإيقاف يختفي تمامًا.'),
                value: controller.settings.tickerScrollingEnabled,
                onChanged: (value) => controller.updateSettings(
                  controller.settings.copyWith(tickerScrollingEnabled: value),
                ),
              ),
              if (controller.settings.tickerScrollingEnabled) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('سرعة تمرير الشريط السفلي'),
                  subtitle: const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text('بطيئة'), Text('سريعة')],
                  ),
                  trailing: Text(controller.settings.tickerSpeed <= 28
                      ? 'بطيئة'
                      : controller.settings.tickerSpeed >= 60
                          ? 'سريعة'
                          : 'متوسطة'),
                ),
                Slider(
                  min: 8,
                  max: 80,
                  divisions: 36,
                  value: controller.settings.tickerSpeed,
                  onChanged: (value) => controller.updateSettings(
                    controller.settings.copyWith(tickerSpeed: value),
                  ),
                ),
              ],
              _section('اسم المسجد'),
              TextField(
                controller: _appName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم التطبيق',
                  helperText: 'يظهر هذا الاسم إذا لم يُكتب اسم مسجد.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mosqueName,
                key: const ValueKey('mosque-name-line-1'),
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'السطر الأول',
                  helperText: 'كل حقل اختياري؛ تظهر الأسطر المكتوبة فقط.',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mosqueNameLine2,
                key: const ValueKey('mosque-name-line-2'),
                textInputAction: TextInputAction.next,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'السطر الثاني',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _mosqueNameLine3,
                key: const ValueKey('mosque-name-line-3'),
                textInputAction: TextInputAction.done,
                textDirection: TextDirection.rtl,
                decoration: const InputDecoration(
                  labelText: 'السطر الثالث',
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _savingNames ? null : _saveNames,
                icon: const Icon(Icons.save_outlined),
                label: Text(_savingNames ? 'جارٍ الحفظ…' : 'حفظ الاسم'),
              ),
              _section('مواقيت الصلاة حسب المنطقة'),
              if (kIsWeb)
                RegionSelector(
                  options: {
                    for (final region in controller.regions.values)
                      region.id: region.name,
                  },
                  selectedId: regionSelection,
                  onChanged: (id) => setState(() => _regionSelectionDraft = id),
                )
              else
                DropdownButtonFormField<String>(
                  value: regionSelection,
                  hint: const Text('اختر المنطقة'),
                  decoration:
                      const InputDecoration(labelText: 'المنطقة الحالية'),
                  items: controller.regions.values
                      .map(
                        (region) => DropdownMenuItem(
                          value: region.id,
                          child: Text(region.name),
                        ),
                      )
                      .toList(),
                  onChanged: (id) {
                    if (id != null) setState(() => _regionSelectionDraft = id);
                  },
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed:
                    hasPendingRegionSelection ? _saveRegionSelection : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('حفظ المنطقة الحالية'),
              ),
              if (hasPendingRegionSelection)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    'سيتم اعتماد المنطقة المختارة بعد الضغط على حفظ.',
                    textAlign: TextAlign.center,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasPendingRegionSelection ||
                              controller.selectedRegion == null
                          ? null
                          : _renameRegion,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('تغيير الاسم'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: hasPendingRegionSelection ||
                              controller.selectedRegion == null
                          ? null
                          : _deleteRegion,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('حذف المنطقة'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _regionName,
                      decoration: const InputDecoration(
                        labelText: 'اسم منطقة جديدة',
                      ),
                      onSubmitted: (_) => _addRegion(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _addRegion,
                    tooltip: 'إضافة منطقة',
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _importFile,
                icon: const Icon(Icons.file_open_outlined),
                label: const Text('استيراد مواقيت أو نسخة JSON'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _exportBackup,
                icon: const Icon(Icons.file_upload_outlined),
                label: const Text('تصدير نسخة احتياطية كاملة'),
              ),
              const SizedBox(height: 12),
              Card(
                color: _settingsCream,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_month_outlined,
                            color: _forest,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تعديل يوم في ${controller.selectedRegion?.name ?? ''}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _editDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setState(() => _editDate = picked);
                          }
                        },
                        icon: const Icon(Icons.event_outlined),
                        label: Text('التاريخ: ${dateKey(_editDate)}'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed:
                            hasPendingRegionSelection ? null : _editPrayerTimes,
                        icon: const Icon(Icons.edit_calendar_outlined),
                        label: Text(
                          controller.selectedRegion?.timesFor(_editDate) == null
                              ? 'إدخال مواقيت هذا اليوم'
                              : 'تعديل مواقيت هذا اليوم',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _section('الوقت المتبقي لإقامة الصلاة'),
              ..._durationRows(_iqamaFields),
              FilledButton.icon(
                onPressed: _savingDurations ? null : _saveIqamaDurations,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _savingDurations ? 'جارٍ الحفظ…' : 'حفظ مدد الإقامة',
                ),
              ),
              _section('وقت الصلاة'),
              ..._durationRows(_prayerDurationFields),
              FilledButton.icon(
                onPressed: _savingPrayerTimes ? null : _savePrayerDurations,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _savingPrayerTimes ? 'جارٍ الحفظ…' : 'حفظ مدد الصلاة',
                ),
              ),
              _section('أذكار بعد الصلاة وخطبة الجمعة'),
              _minutesField(
                _postPrayerDhikrField,
                label: 'مدة عرض أذكار الصلاة',
              ),
              const SizedBox(height: 10),
              _minutesField(_fridayKhutbahField, label: 'مدة خطبة الجمعة'),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: _savingPostPrayer ? null : _savePostPrayerDurations,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _savingPostPrayer ? 'جارٍ الحفظ…' : 'حفظ مدد الأذكار والخطبة',
                ),
              ),
              _section('صلاة التراويح والقيام في رمضان'),
              const Text(
                'تُفعّل هذه الشاشات في رمضان فقط. تضبط الإدارة وقت القيام بحيث لا يتعارض مع الأذان أو الإقامة.',
              ),
              SwitchListTile(
                key: const ValueKey('ramadan-taraweeh-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('تفعيل شاشة صلاة التراويح'),
                value: _ramadanTaraweehEnabled,
                onChanged: _savingRamadanPrayers
                    ? null
                    : (value) =>
                        setState(() => _ramadanTaraweehEnabled = value),
              ),
              if (_ramadanTaraweehEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    key: const ValueKey('ramadan-taraweeh-duration'),
                    controller: _ramadanTaraweehMinutesField,
                    textDirection: TextDirection.ltr,
                    keyboardType: TextInputType.number,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      labelText: 'مدة شاشة التراويح بالدقائق',
                      helperText: 'المدة الافتراضية 35 دقيقة',
                      counterText: '',
                    ),
                  ),
                ),
              SwitchListTile(
                key: const ValueKey('ramadan-qiyam-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('تفعيل شاشة صلاة القيام'),
                subtitle: const Text('تعمل في العشر الأواخر فقط'),
                value: _ramadanQiyamEnabled,
                onChanged: _savingRamadanPrayers
                    ? null
                    : (value) => setState(() => _ramadanQiyamEnabled = value),
              ),
              if (_ramadanQiyamEnabled)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('ramadan-qiyam-start'),
                      onPressed: _savingRamadanPrayers
                          ? null
                          : () => _chooseQiyamTime(start: true),
                      icon: const Icon(Icons.play_arrow),
                      label: Text(
                        'تبدأ ${_ramadanTimeLabel(_ramadanQiyamStart)}',
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('ramadan-qiyam-end'),
                      onPressed: _savingRamadanPrayers
                          ? null
                          : () => _chooseQiyamTime(start: false),
                      icon: const Icon(Icons.stop),
                      label: Text(
                        'تنتهي ${_ramadanTimeLabel(_ramadanQiyamEnd)}',
                      ),
                    ),
                  ],
                ),
              FilledButton.icon(
                key: const ValueKey('save-ramadan-prayer-settings'),
                onPressed:
                    _savingRamadanPrayers ? null : _saveRamadanPrayerSettings,
                icon: const Icon(Icons.save_outlined),
                label: Text(
                  _savingRamadanPrayers
                      ? 'جارٍ الحفظ…'
                      : 'حفظ إعدادات التراويح والقيام',
                ),
              ),
              _section('تعديل التاريخ الهجري يدويًا'),
              const Text(
                'اختر اليوم والشهر الصحيحين. سيستمر التاريخ من هذا التصحيح في الأيام التالية.',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _hijriDay,
                      decoration: const InputDecoration(labelText: 'اليوم'),
                      items: [
                        for (var day = 1; day <= 30; day++)
                          DropdownMenuItem(value: day, child: Text('$day')),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _hijriDay = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<int>(
                      value: _hijriMonth,
                      decoration: const InputDecoration(labelText: 'الشهر'),
                      items: [
                        for (var month = 1; month <= 12; month++)
                          DropdownMenuItem(
                            value: month,
                            child: Text(hijriMonthNames[month - 1]),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _hijriMonth = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _savingHijriDate ? null : _saveHijriManualDate,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(
                        _savingHijriDate ? 'جارٍ الحفظ…' : 'حفظ التاريخ',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _resetHijriManualDate,
                      child: const Text('الحساب التلقائي'),
                    ),
                  ),
                ],
              ),
              _section('تصحيح الوقت بالثواني'),
              ClockCorrectionControls(controller: controller),
              _section('شهر رمضان المبارك'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.nightlight_round, color: _forest),
                title: const Text('إمساكية شهر رمضان'),
                subtitle: Text(controller.currentRamadanPlan?.custom == true
                    ? 'إمساكية خاصة لهذه السنة فقط؛ تُحذف عند انتهاء رمضان.'
                    : 'اختيار مواقيت المنطقة أو إدخال إمساكية خاصة خلال رمضان.'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () async {
                  await Navigator.of(context).push<bool>(MaterialPageRoute(
                      builder: (_) => RamadanScreen(
                          controller: controller,
                          greeting: controller.currentRamadanPlan == null)));
                  if (mounted) setState(() {});
                },
              ),
              _section('المظهر'),
              SwitchListTile(
                key: const ValueKey('dashboard-line-color-toggle'),
                contentPadding: EdgeInsets.zero,
                title: const Text('ألوان الخط'),
                subtitle: const Text(
                  'اختر لونًا ثم عاينه أو احفظه للواجهة الرئيسية.',
                ),
                value: _dashboardLineColorsEnabled,
                onChanged: _savingDashboardLineColor
                    ? null
                    : _setDashboardLineColorsEnabled,
              ),
              if (_dashboardLineColorsEnabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final option in _dashboardLineColorOptions)
                      Tooltip(
                        message: option.name,
                        child: Semantics(
                          button: true,
                          selected: option.value == _dashboardLineColorDraft,
                          label: option.name,
                          child: InkWell(
                            key: ValueKey('line-color-swatch-${option.name}'),
                            customBorder: const CircleBorder(),
                            onTap: () => setState(
                              () => _dashboardLineColorDraft = option.value,
                            ),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(option.value),
                                border: Border.all(
                                  color:
                                      option.value == _dashboardLineColorDraft
                                          ? _forest
                                          : Colors.black26,
                                  width:
                                      option.value == _dashboardLineColorDraft
                                          ? 3
                                          : 1,
                                ),
                              ),
                              child: option.value == _dashboardLineColorDraft
                                  ? Icon(
                                      Icons.check,
                                      size: 21,
                                      color: option.value == 0xFFFFFFFF
                                          ? _forest
                                          : Colors.black87,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const ValueKey('dashboard-line-color-preview'),
                        onPressed: _savingDashboardLineColor
                            ? null
                            : _previewDashboardLineColor,
                        icon: const Icon(Icons.visibility_outlined),
                        label: const Text('معاينة'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('dashboard-line-color-save'),
                        onPressed: _savingDashboardLineColor
                            ? null
                            : _saveDashboardLineColor,
                        icon: const Icon(Icons.save_outlined),
                        label: Text(
                          _savingDashboardLineColor ? 'جارٍ الحفظ…' : 'حفظ',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إظهار التاريخ الهجري'),
                value: controller.settings.showHijriDate,
                onChanged: (value) => controller.updateSettings(
                  controller.settings.copyWith(showHijriDate: value),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('استخدام خط النظام بدل Amiri'),
                value: controller.settings.systemFont,
                onChanged: (value) => controller.updateSettings(
                  controller.settings.copyWith(systemFont: value),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('التحكم بحجم الخط'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اسم المسجد فقط'),
                    Slider(
                      min: 0.8,
                      max: 1.4,
                      divisions: 6,
                      value: controller.settings.fontScale,
                      onChanged: (value) => controller.updateSettings(
                        controller.settings.copyWith(fontScale: value),
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('التحكم في حجم خط الساعة'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الساعة واليوم والتقويمين'),
                    Slider(
                      min: 0.8,
                      max: 1.3,
                      divisions: 5,
                      value: controller.settings.clockScale,
                      onChanged: (value) => controller.updateSettings(
                        controller.settings.copyWith(clockScale: value),
                      ),
                    ),
                  ],
                ),
              ),
              DropdownButtonFormField<int>(
                value: controller.settings.accentColor,
                decoration: const InputDecoration(labelText: 'لون الواجهة'),
                items: const [
                  DropdownMenuItem(
                    value: 0xFF17432E,
                    child: Text('أخضر المسجد'),
                  ),
                  DropdownMenuItem(value: 0xFF31546C, child: Text('أزرق هادئ')),
                  DropdownMenuItem(value: 0xFF6A4724, child: Text('بني دافئ')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    controller.updateSettings(
                      controller.settings.copyWith(accentColor: value),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('إبقاء الشاشة مضاءة'),
                subtitle: const Text('مناسب للشاشة المعروضة داخل المسجد.'),
                value: controller.settings.keepAwake,
                onChanged: (value) => controller.updateSettings(
                  controller.settings.copyWith(keepAwake: value),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('ملء الشاشة وإخفاء أشرطة النظام'),
                value: controller.settings.immersiveMode,
                onChanged: (value) => controller.updateSettings(
                  controller.settings.copyWith(immersiveMode: value),
                ),
              ),
              _timezoneNote(),
              _section('تشغيل الجهاز والحماية'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('محاولة فتح التطبيق عند تشغيل الجهاز'),
                subtitle: const Text(
                  'يعتمد ذلك على إصدار Android وسياسات الشركة المصنّعة. قد يمنع النظام فتح شاشة التطبيق تلقائيًا؛ لا يمكن للتطبيق تجاوز هذا القيد.',
                ),
                value: controller.settings.autoStartEnabled,
                onChanged: (value) async {
                  try {
                    await controller.setAutoStart(value);
                  } catch (_) {
                    _message(
                      controller.lastActionError ??
                          'تعذر تفعيل التشغيل التلقائي.',
                      error: true,
                    );
                  }
                },
              ),
              OutlinedButton.icon(
                onPressed: _managePin,
                icon: const Icon(Icons.lock_outline),
                label: Text(
                  controller.settings.hasPin
                      ? 'تغيير أو إزالة رمز PIN'
                      : 'حماية الإعدادات برمز PIN (اختياري)',
                ),
              ),
              _section('إعادة الضبط'),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade800,
                ),
                onPressed: _restoreDefaults,
                icon: const Icon(Icons.restart_alt),
                label: const Text('إعادة الإعدادات الافتراضية'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 9),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: _brass, size: 18),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: _forest,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _timezoneNote() {
    final offset = DateTime.now().timeZoneOffset.inMinutes;
    final zoneId = controller.deviceTimeZoneId;
    final correctZone =
        zoneId != null ? zoneId == 'Asia/Baghdad' : offset == 180;
    return _WarningPanel(
      message: correctZone
          ? 'يعرض التطبيق ساعة الجهاز المحلية. تحقق من صحة التاريخ والوقت على الجهاز؛ لا يستطيع التطبيق التحقق من الوقت الحقيقي أو تصحيحه تلقائيًا دون مصدر موثوق.'
          : 'المنطقة الزمنية الحالية: ${zoneId ?? 'فرق UTC ${offset >= 0 ? '+' : ''}${offset ~/ 60} ساعة'}. اضبط التاريخ والوقت والمنطقة الزمنية Asia/Baghdad من إعدادات Android؛ لا يستطيع التطبيق التحقق من الوقت الحقيقي أو تصحيح ساعة الجهاز تلقائيًا.',
    );
  }
}

class _DashboardLineColorOption {
  const _DashboardLineColorOption(this.name, this.value);

  final String name;
  final int value;
}

class _WarningPanel extends StatelessWidget {
  const _WarningPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF2D8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _brass),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: _forest, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      );
}
