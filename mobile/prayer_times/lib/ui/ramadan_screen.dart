import 'package:flutter/material.dart';

import '../models/ramadan_schedule.dart';
import '../state/prayer_controller.dart';

const _forest = Color(0xFF17432E);
const _deepForest = Color(0xFF0E2D1F);
const _brass = Color(0xFFD4A63B);
const _cream = Color(0xFFFFFBF2);

enum _Stage { greeting, editor }

class RamadanScreen extends StatefulWidget {
  const RamadanScreen({
    required this.controller,
    this.greeting = true,
    super.key,
  });

  final PrayerController controller;
  final bool greeting;

  @override
  State<RamadanScreen> createState() => _RamadanScreenState();
}

class _RamadanScreenState extends State<RamadanScreen> {
  late final String _regionId;
  late final int _year;
  late final bool _inRamadan;
  late _Stage _stage;
  final Map<int, int> _fajr = {};
  final Map<int, int> _maghrib = {};
  final _keys = {for (var d = 1; d <= 30; d++) d: GlobalKey()};
  final _scroll = ScrollController();
  bool _busy = false;
  String? _error;
  int? _badDay;

  PrayerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _regionId = c.selectedRegionId;
    final h = c.hijriDateAt(c.now);
    _year = h.year;
    _inRamadan = h.month == 9;
    _stage = widget.greeting ? _Stage.greeting : _Stage.editor;
    final plan = c.currentRamadanPlan;
    if (plan != null && plan.year == _year) {
      plan.days.forEach((d, v) {
        if (d < 1 || d > 30) return;
        _fajr[d] = v.fajrSecondMinutes;
        _maghrib[d] = v.maghribMinutes;
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _available => _inRamadan && c.selectedRegion != null;

  String? _contextProblem() {
    final h = c.hijriDateAt(c.now);
    if (c.selectedRegionId != _regionId || c.selectedRegion == null) {
      return 'تغيّرت المنطقة أثناء التعديل. أعد فتح الشاشة.';
    }
    if (h.month != 9 || h.year != _year) {
      return 'انتهى شهر رمضان أو تغيّر التاريخ الهجري. لا يمكن الحفظ الآن.';
    }
    return null;
  }

  String _fmt12(int m) {
    final h = m ~/ 60;
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:${(m % 60).toString().padLeft(2, '0')} ${h < 12 ? 'صباحًا' : 'مساءً'}';
  }

  int? _set(Map<int, int> m, int d) {
    final v = m[d];
    return (v == null || v == 0) ? null : v;
  }

  String? _fajrError(int d) {
    final v = _set(_fajr, d);
    if (v == null) return null;
    return v >= 720 ? 'الفجر يجب أن يكون صباحًا (قبل 12:00)' : null;
  }

  String? _maghribError(int d) {
    final v = _set(_maghrib, d);
    if (v == null) return null;
    return v < 720 ? 'المغرب يجب أن يكون مساءً (بعد 12:00)' : null;
  }

  Future<void> _pick(int day, bool isFajr) async {
    if (_busy) return;
    final cur = _set(isFajr ? _fajr : _maghrib, day) ?? (isFajr ? 300 : 1080);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: isFajr ? 'فجر اليوم $day' : 'مغرب اليوم $day',
      builder: (ctx, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: MediaQuery(
          data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: false),
          child: child!,
        ),
      ),
    );
    if (!mounted || t == null) return;
    setState(() {
      (isFajr ? _fajr : _maghrib)[day] = t.hour * 60 + t.minute;
      _error = null;
      _badDay = null;
    });
  }

  void _clear(int day, bool isFajr) => setState(() {
        (isFajr ? _fajr : _maghrib).remove(day);
        _error = null;
        _badDay = null;
      });

  void _fail(int day, String msg) {
    setState(() {
      _badDay = day;
      _error = msg;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _keys[day]?.currentContext;
      if (mounted && ctx != null) {
        Scrollable.ensureVisible(ctx,
            duration: const Duration(milliseconds: 300), alignment: 0.2);
      }
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final problem = _contextProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final days = <int, RamadanDay>{};
    for (var d = 1; d <= 30; d++) {
      final f = _set(_fajr, d);
      final m = _set(_maghrib, d);
      if (f == null) return _fail(d, 'اليوم $d: أدخل وقت الفجر الثاني.');
      if (m == null) return _fail(d, 'اليوم $d: أدخل وقت المغرب.');
      final fe = _fajrError(d) ?? _maghribError(d);
      if (fe != null) return _fail(d, 'اليوم $d: $fe.');
      days[d] = RamadanDay(fajrSecondMinutes: f, maghribMinutes: m);
    }
    setState(() {
      _busy = true;
      _error = null;
      _badDay = null;
    });
    try {
      await c.saveRamadanTimes(days);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر الحفظ، مسودتك محفوظة هنا: $e';
      });
    }
  }

  Future<void> _useExisting() async {
    if (_busy) return;
    final problem = _contextProblem();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await c.useExistingRamadanTimes();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'تعذر الاعتماد: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Amiri'),
        ),
        child: !_available
            ? _unavailable()
            : _stage == _Stage.greeting
                ? _greeting()
                : _editor(),
      ),
    );
  }

  Widget _unavailable() {
    final noRegion = c.selectedRegion == null;
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
          title: const Text('رمضان'),
          backgroundColor: _forest,
          foregroundColor: _cream),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            noRegion
                ? 'لم تُحدَّد منطقة بعد. اختر المنطقة من الإعدادات ثم افتح إمساكية رمضان.'
                : 'إمساكية رمضان تتاح خلال شهر رمضان فقط حسب التاريخ الهجري المصحح في التطبيق.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, height: 1.8, color: _forest),
          ),
        ),
      ),
    );
  }

  Widget _greeting() {
    return Scaffold(
      backgroundColor: _deepForest,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 28),
                    decoration: BoxDecoration(
                      border: Border.all(color: _brass, width: 2),
                      borderRadius: BorderRadius.circular(20),
                      color: _forest,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.nightlight_round,
                            color: _brass, size: 44),
                        const SizedBox(height: 14),
                        const Text(
                          'مبارك عليكم شهر رمضان المبارك',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 34,
                              height: 1.6,
                              fontWeight: FontWeight.bold,
                              color: _brass),
                        ),
                        const Text(
                          'تقبل الله منكم صالح الأعمال',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 26, height: 1.6, color: _cream),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'هل تريد احتساب أوقات الصلاة المعتمدة أم عندك إمساكية خاصة لشهر رمضان؟',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 22, height: 1.7, color: _cream),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 18, color: Color(0xFFFFB4A8))),
                        ],
                        const SizedBox(height: 22),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton(
                              style: FilledButton.styleFrom(
                                  backgroundColor: _brass,
                                  foregroundColor: _deepForest,
                                  minimumSize: const Size(220, 54)),
                              onPressed: _busy
                                  ? null
                                  : () =>
                                      setState(() => _stage = _Stage.editor),
                              child: const Text('عندي إمساكية خاصة',
                                  style: TextStyle(fontSize: 22)),
                            ),
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: _cream,
                                  side: const BorderSide(color: _brass),
                                  minimumSize: const Size(220, 54)),
                              onPressed: _busy ? null : _useExisting,
                              child: _busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Text('اعتماد أوقات الصلاة الموجودة',
                                      style: TextStyle(fontSize: 20)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _editor() {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _forest,
        foregroundColor: _cream,
        title: const Text('إمساكية رمضان'),
        actions: [
          if (!widget.greeting)
            TextButton(
              onPressed: _busy ? null : _confirmRevert,
              child: const Text('العودة للأوقات الموجودة',
                  style: TextStyle(color: _brass)),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E7C4),
                      border: Border.all(color: _brass),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'أدخل الوقت بنظام 12 ساعة: الفجر الثاني صباحًا (مثل 4:50 صباحًا) '
                      'والمغرب مساءً (مثل 6:10 مساءً). اختر صباحًا أو مساءً في نافذة الوقت. '
                      'الوقت 00:00 يعني غير مضبوط. يلزم إدخال الأيام الثلاثين كاملة.',
                      style:
                          TextStyle(fontSize: 17, height: 1.6, color: _forest),
                    ),
                  ),
                  if (_error != null)
                    Container(
                      margin: const EdgeInsets.only(top: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE3DE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(_error!,
                          style: TextStyle(
                              fontSize: 18, color: Colors.red.shade900)),
                    ),
                  const SizedBox(height: 10),
                  for (var d = 1; d <= 30; d++) _dayRow(d),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: _forest,
                        foregroundColor: _cream,
                        minimumSize: const Size.fromHeight(54)),
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('حفظ', style: TextStyle(fontSize: 22)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRevert() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('اعتماد الأوقات الموجودة'),
          content: const Text(
              'سيتم التخلي عن الإمساكية الخاصة واعتماد أوقات الصلاة الحالية.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('إلغاء')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('اعتماد')),
          ],
        ),
      ),
    );
    if (ok == true && mounted) await _useExisting();
  }

  Widget _dayRow(int d) {
    final f = _set(_fajr, d);
    final m = _set(_maghrib, d);
    final bad = _badDay == d;
    return Container(
      key: _keys[d],
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        border: Border.all(
            color: bad ? Colors.red.shade700 : _brass.withValues(alpha: 0.6),
            width: bad ? 2 : 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('اليوم $d',
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold, color: _forest)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _timeBox('الفجر الثاني', f, _fajrError(d), true, d,
                  derived: f == null
                      ? null
                      : 'الفجر الأول ${_fmt12(f >= 30 ? f - 30 : 0)}'),
              _timeBox('المغرب', m, _maghribError(d), false, d,
                  derived: m == null || m + 80 >= 1440
                      ? null
                      : 'العشاء ${_fmt12(m + 80)}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeBox(String label, int? v, String? err, bool isFajr, int d,
      {String? derived}) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                  child: OutlinedButton(
                key: ValueKey('ramadan-${isFajr ? 'fajr' : 'maghrib'}-$d'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: _forest,
                    side: BorderSide(
                        color: err != null ? Colors.red.shade700 : _forest)),
                onPressed: _busy ? null : () => _pick(d, isFajr),
                child: Text(
                  '$label: ${v == null ? '00:00 — غير مضبوط' : _fmt12(v)}',
                  style: const TextStyle(fontSize: 17),
                ),
              )),
              if (v != null)
                IconButton(
                  tooltip: 'مسح',
                  onPressed: _busy ? null : () => _clear(d, isFajr),
                  icon: const Icon(Icons.close, size: 18),
                ),
            ],
          ),
          if (err != null)
            Text(err,
                style: TextStyle(fontSize: 14, color: Colors.red.shade800)),
          if (derived != null)
            Text(derived,
                style: TextStyle(
                    fontSize: 14, color: _forest.withValues(alpha: 0.75))),
        ],
      ),
    );
  }
}
