import 'package:flutter/foundation.dart';

class WebAdhanPlayer {
  final status = ValueNotifier<String?>(null);
  Future<void> preview() async {}
  void stop() {}
  void synchronize(List<Map<String, Object>> events, {required bool enabled}) {}
  void dispose() => status.dispose();
}
