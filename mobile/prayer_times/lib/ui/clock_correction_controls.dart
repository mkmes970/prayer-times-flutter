import 'package:flutter/material.dart';

import '../state/prayer_controller.dart';

class ClockCorrectionControls extends StatefulWidget {
  const ClockCorrectionControls({required this.controller, super.key});

  final PrayerController controller;

  @override
  State<ClockCorrectionControls> createState() =>
      _ClockCorrectionControlsState();
}

class _ClockCorrectionControlsState extends State<ClockCorrectionControls> {
  int _seconds = 0;
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.controller.adjustClockSeconds(_seconds);
      if (!mounted) return;
      setState(() => _seconds = 0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حفظ تصحيح الوقت')),
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'تعذر حفظ التصحيح. لم يتم تطبيق التعديل.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'قدّم أو أخّر وقت التطبيق من ثانية إلى 60 ثانية في كل عملية. '
            'بعد الحفظ يعود الاختيار إلى صفر، ويبقى التصحيح محفوظًا. '
            'يشمل الساعة والعدادات ومواعيد الانتقال، ولا يغيّر ساعة الجهاز.',
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const Key('clock-correction-minus'),
                tooltip: 'إنقاص ثانية',
                onPressed: _saving || _seconds <= -60
                    ? null
                    : () => setState(() => _seconds--),
                icon: const Icon(Icons.remove),
              ),
              Text(
                '${_seconds > 0 ? '+' : ''}$_seconds ثانية',
                key: const Key('clock-correction-value'),
                textDirection: TextDirection.ltr,
              ),
              IconButton(
                key: const Key('clock-correction-plus'),
                tooltip: 'زيادة ثانية',
                onPressed: _saving || _seconds >= 60
                    ? null
                    : () => setState(() => _seconds++),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          Slider(
            key: const Key('clock-correction-slider'),
            min: -60,
            max: 60,
            divisions: 120,
            value: _seconds.toDouble(),
            label: '$_seconds ثانية',
            onChanged: _saving
                ? null
                : (value) => setState(() => _seconds = value.round()),
          ),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: Colors.red)),
          FilledButton.icon(
            key: const Key('save-clock-correction'),
            onPressed: _saving || _seconds == 0 ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ التعديل'),
          ),
        ],
      );
}
