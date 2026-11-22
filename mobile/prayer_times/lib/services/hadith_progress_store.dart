export 'hadith_progress_store_stub.dart'
    if (dart.library.html) 'hadith_progress_store_web.dart'
    if (dart.library.io) 'hadith_progress_store_native.dart';
