// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

/// Keeps browser playback progress separate from native app storage.
class AdhanProgressStore {
  AdhanProgressStore([this.storageKey = 'prayer-times.adhan-progress']);
  final String storageKey;
  Future<void> _queue = Future<void>.value();

  static Future<AdhanProgressStore> createDefault() async =>
      AdhanProgressStore();

  Future<int> load() async {
    final contents = html.window.localStorage[storageKey];
    if (contents == null) return 0;
    final data = jsonDecode(contents);
    final index = data is Map ? data['index'] : null;
    if (index is! int || index < 0) {
      throw const FormatException('Invalid adhan playback progress');
    }
    return index;
  }

  Future<void> save(int index) {
    final operation = _queue.then((_) async {
      html.window.localStorage[storageKey] = jsonEncode({'index': index});
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }
}
