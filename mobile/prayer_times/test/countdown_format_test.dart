import 'package:flutter_test/flutter_test.dart';
import 'package:prayer_times/services/countdown_format.dart';

void main() {
  test('rounds a fractional remaining second up for the visible clock', () {
    expect(
      formatCountdownDuration(
        const Duration(hours: 2, minutes: 5, seconds: 44, milliseconds: 500),
      ),
      '02:05:45',
    );
  });

  test('keeps an exact second unchanged', () {
    expect(
      formatCountdownDuration(
          const Duration(hours: 2, minutes: 5, seconds: 45)),
      '02:05:45',
    );
  });

  test('shows zero after a deadline and pads short durations', () {
    expect(
        formatCountdownDuration(const Duration(milliseconds: -1)), '00:00:00');
    expect(
      formatCountdownDuration(const Duration(milliseconds: 1)),
      '00:00:01',
    );
  });
}
