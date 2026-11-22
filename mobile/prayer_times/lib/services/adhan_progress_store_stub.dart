class AdhanProgressStore {
  AdhanProgressStore([String storageKey = 'prayer-times.adhan-progress']);

  static Future<AdhanProgressStore> createDefault() async =>
      throw UnsupportedError('Adhan progress storage is unavailable.');

  Future<int> load() async =>
      throw UnsupportedError('Adhan progress storage is unavailable.');

  Future<void> save(int index) async =>
      throw UnsupportedError('Adhan progress storage is unavailable.');
}
