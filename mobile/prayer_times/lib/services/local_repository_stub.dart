import '../models/app_data.dart';

class LocalRepository {
  Future<AppData> load() async =>
      throw UnsupportedError('Local storage is unavailable on this platform.');

  Future<void> save(AppData data) async =>
      throw UnsupportedError('Local storage is unavailable on this platform.');
}
