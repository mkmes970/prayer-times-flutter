import 'package:prayer_times/services/countdown_format.dart';

// Also compile this check with dart compile js and run it with Node to cover
// web integer semantics, which differ from the native Dart VM.
void main() {
  final cases = <Duration, String>{
    const Duration(hours: 4, minutes: 31, seconds: 44): '04:31:44',
    const Duration(hours: 2, minutes: 5, seconds: 45): '02:05:45',
    const Duration(seconds: 30): '00:00:30',
    const Duration(seconds: 29, milliseconds: 1): '00:00:30',
    const Duration(milliseconds: 1): '00:00:01',
    Duration.zero: '00:00:00',
    const Duration(seconds: -1): '00:00:00',
  };
  for (final entry in cases.entries) {
    final actual = formatCountdownDuration(entry.key);
    if (actual != entry.value) {
      throw StateError(
        '${entry.key}: expected ${entry.value}, received $actual',
      );
    }
  }
}
