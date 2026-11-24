String formatCountdownDuration(Duration duration) {
  // Large bit shifts have different semantics in compiled JavaScript.
  // Only negative durations need clamping; no upper limit is required.
  final microseconds = duration.isNegative ? 0 : duration.inMicroseconds;
  final totalSeconds = (microseconds + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;
  final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = (totalSeconds ~/ 60 % 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
