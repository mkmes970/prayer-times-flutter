import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Separate from user settings: serialized, atomic cursor writes.
class AdhanProgressStore {
  AdhanProgressStore(this.file);
  final File file;
  Future<void> _queue = Future<void>.value();
  int _sequence = 0;

  static Future<AdhanProgressStore> createDefault() async {
    final directory = await getApplicationDocumentsDirectory();
    return AdhanProgressStore(File('${directory.path}/adhan-progress.json'));
  }

  Future<int> load() async {
    if (!await file.exists()) return 0;
    final data = jsonDecode(await file.readAsString());
    final index = data is Map ? data['index'] : null;
    if (index is! int || index < 0) {
      throw const FormatException('Invalid adhan playback progress');
    }
    return index;
  }

  Future<void> save(int index) {
    final operation = _queue.then((_) async {
      final temporary = File('${file.path}.${_sequence++}.tmp');
      await temporary.writeAsString(jsonEncode({'index': index}), flush: true);
      await temporary.rename(file.path);
    });
    _queue = operation.catchError((Object _) {});
    return operation;
  }
}
