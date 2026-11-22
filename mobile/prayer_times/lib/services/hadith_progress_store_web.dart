// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

/// Keeps browser playback progress separate from native app storage.
class HadithProgressStore {
  HadithProgressStore([this.storageKey = 'prayer-times.hadith-progress']);
  final String storageKey;
  Future<void> _queue = Future<void>.value();

  static Future<HadithProgressStore> createDefault() async =>
      HadithProgressStore();

  Future<Map<String, dynamic>?> load() async {
    final contents = html.window.localStorage[storageKey];
    if (contents == null) return null;
    final data = jsonDecode(contents);
    if (data is! Map<String, dynamic> ||
        data['version'] != 1 ||
        data['decks'] is! Map ||
        data['shares'] is! Map) {
      throw const FormatException('Invalid hadith playback progress');
    }
    return data;
  }

  Future<void> save(Map<String, dynamic> state) {
    final contents = jsonEncode(state);
    final operation = _queue.then((_) async {
      html.window.localStorage[storageKey] = contents;
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }
}
