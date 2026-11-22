class HadithProgressStore {
  HadithProgressStore([String storageKey = 'prayer-times.hadith-progress']);

  static Future<HadithProgressStore> createDefault() async =>
      throw UnsupportedError('Hadith progress storage is unavailable.');

  Future<Map<String, dynamic>?> load() async =>
      throw UnsupportedError('Hadith progress storage is unavailable.');

  Future<void> save(Map<String, dynamic> state) async =>
      throw UnsupportedError('Hadith progress storage is unavailable.');
}
