String formatCountdownDuration(Duration duration) {
  final microseconds = duration.inMicroseconds.clamp(0, 1 << 62);
  final totalSeconds = (microseconds + Duration.microsecondsPerSecond - 1) ~/
      Duration.microsecondsPerSecond;
  final hours = (totalSeconds ~/ 3600).toString().padLeft(2, '0');
  final minutes = (totalSeconds ~/ 60 % 60).toString().padLeft(2, '0');
  final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
