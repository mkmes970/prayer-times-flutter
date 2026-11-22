// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import '../models/app_data.dart';
import 'bundled_schedules.dart';

class LocalRepository {
  static const _storageKey = 'mwaqit_data.json';
  Future<void> _writeQueue = Future<void>.value();

  Future<AppData> load() async {
    final bundled = await loadBundledSchedules();
    final contents = html.window.localStorage[_storageKey];
    if (contents == null) {
      return AppData.empty().withAvailableRegions(bundled);
    }
    return AppData.fromJson(jsonDecode(contents)).withAvailableRegions(bundled);
  }

  Future<void> save(AppData data) {
    final contents = const JsonEncoder.withIndent('  ').convert(data.toJson());
    final operation = _writeQueue.then((_) async {
      html.window.localStorage[_storageKey] = contents;
    });
    _writeQueue = operation.catchError((Object _) {});
    return operation;
  }
}
