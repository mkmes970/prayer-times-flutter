export 'adhan_progress_store_stub.dart'
    if (dart.library.html) 'adhan_progress_store_web.dart'
    if (dart.library.io) 'adhan_progress_store_native.dart';
