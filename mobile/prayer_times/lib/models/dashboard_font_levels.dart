/// Ten discrete settings levels, retaining the existing saved scale ranges.
class DashboardFontLevels {
  static int nameLevel(double scale) => _level(scale, 1.4);
  static int clockLevel(double scale) => _level(scale, 1.3);
  static double nameScale(int level) => _scale(level, 1.4);
  static double clockScale(int level) => _scale(level, 1.3);

  static int _level(double scale, double max) =>
      (1 + (scale - 0.8) / (max - 0.8) * 9).round().clamp(1, 10);
  static double _scale(int level, double max) =>
      0.8 + (level.clamp(1, 10) - 1) / 9 * (max - 0.8);

  static double nameRatio(double scale) =>
      0.45 + (nameLevel(scale) - 1) / 9 * 1.55;
  static double clockRatio(double scale) =>
      0.45 + (clockLevel(scale) - 1) / 9 * 0.80;
}
