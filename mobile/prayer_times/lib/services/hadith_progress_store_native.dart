import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Independent of settings and schedule backups; serialized atomic writes.
class HadithProgressStore {
  HadithProgressStore(this.file);
  final File file;
  Future<void> _queue = Future<void>.value();
  int _sequence = 0;

  static Future<HadithProgressStore> createDefault() async {
    final directory = await getApplicationDocumentsDirectory();
    return HadithProgressStore(File('${directory.path}/hadith-progress.json'));
  }

  Future<Map<String, dynamic>?> load() async {
    if (!await file.exists()) return null;
    final data = jsonDecode(await file.readAsString());
    if (data is! Map<String, dynamic> ||
        data['version'] != 1 ||
        data['decks'] is! Map ||
        data['shares'] is! Map) {
      throw const FormatException('Invalid hadith playback progress');
    }
    return data;
  }

  Future<void> save(Map<String, dynamic> state) {
    // Encode now: the player may advance while an earlier write is pending.
    final contents = jsonEncode(state);
    final operation = _queue.then((_) async {
      final temporary = File('${file.path}.${_sequence++}.tmp');
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(file.path);
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }
}
