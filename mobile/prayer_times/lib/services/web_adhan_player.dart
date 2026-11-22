// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import 'package:flutter/foundation.dart';

import '../models/foreground_adhan_queue.dart';

class WebAdhanPlayer {
  final status = ValueNotifier<String?>(null);
  final _queue = ForegroundAdhanQueue();
  html.AudioElement? _audio;
  Timer? _timer;
  bool _enabled = false;
  bool _unlocked = false;
  static const _ready =
      'الصوت جاهز لهذه الجلسة. أبقِ التطبيق مفتوحًا ونشطًا؛ لا يُضمن الأذان عند قفل الشاشة أو إغلاق التطبيق.';

  html.AudioElement get _player {
    if (_audio != null) return _audio!;
    final url = Uri.parse(html.document.baseUri!).resolve('audio/adhan.mp3');
    _audio = html.AudioElement(url.toString())..preload = 'none';
    _audio!.onError.listen((_) {
      _unlocked = false;
      status.value = 'تعذر تحميل تسجيل الأذان. تحقق من الإنترنت ثم اضغط تجربة الصوت.';
    });
    return _audio!;
  }

  /// Called directly from the user's click, before any storage/network await.
  Future<void> preview() async {
    final player = _player;
    player.pause();
    player.currentTime = 0;
    try {
      await player.play();
      _unlocked = true;
      status.value = _ready;
    } catch (_) {
      _unlocked = false;
      status.value =
          'لم يسمح المتصفح بتشغيل الصوت أو تعذر تحميله. تحقق من الإنترنت واضغط تجربة الصوت من جديد.';
      rethrow;
    }
  }

  void stop() {
    _audio?.pause();
    if (_audio != null) _audio!.currentTime = 0;
  }

  void synchronize(List<Map<String, Object>> events, {required bool enabled}) {
    _enabled = enabled;
    _queue.update(events);
    _timer?.cancel();
    if (!enabled || events.isEmpty) {
      stop();
      status.value = null;
      return;
    }
    if (!_unlocked) {
      status.value =
          'اضغط «تجربة الصوت وتفعيله لهذه الجلسة» للسماح بالأذان. كرر ذلك بعد إعادة فتح التطبيق إذا طلب المتصفح.';
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final due = _queue.takeDue(DateTime.now(),
          visible: html.document.visibilityState == 'visible');
      if (due && _enabled) {
        if (_unlocked) {
          unawaited(_playScheduled());
        } else {
          status.value =
              'حان الأذان لكن الصوت غير مفعّل لهذه الجلسة. افتح الإعدادات واضغط تجربة الصوت.';
        }
      }
    });
  }

  Future<void> _playScheduled() async {
    try {
      _player.currentTime = 0;
      await _player.play();
      status.value = _ready;
    } catch (_) {
      _unlocked = false;
      status.value =
          'منع المتصفح صوت الأذان. افتح الإعدادات واضغط تجربة الصوت لإعادة السماح به.';
    }
  }

  void dispose() {
    _timer?.cancel();
    stop();
    status.dispose();
  }
}
