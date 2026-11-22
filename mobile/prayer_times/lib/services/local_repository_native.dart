import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_data.dart';
import 'bundled_schedules.dart';

class LocalRepository {
  static const _fileName = 'mwaqit_data.json';
  Future<void> _writeQueue = Future<void>.value();
  int _temporaryFileSequence = 0;

  Future<File> _dataFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_fileName');
  }

  Future<AppData> load() async {
    final file = await _dataFile();
    final bundled = await loadBundledSchedules();
    if (!await file.exists()) {
      return AppData.empty().withAvailableRegions(bundled);
    }
    final decoded = jsonDecode(await file.readAsString());
    return AppData.fromJson(decoded).withAvailableRegions(bundled);
  }

  Future<void> save(AppData data) {
    final contents = const JsonEncoder.withIndent('  ').convert(data.toJson());
    final operation = _writeQueue.then((_) async {
      final file = await _dataFile();
      final temporary = File('${file.path}.${_temporaryFileSequence++}.tmp');
      await temporary.writeAsString(contents, flush: true);
      await temporary.rename(file.path);
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }
}
