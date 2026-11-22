import 'package:flutter/material.dart';

import '../state/prayer_controller.dart';
import 'dashboard_screen.dart';
import 'prayer_period_theme.dart';
import 'theme_catalog.dart';

const _forest = Color(0xFF17432E);
const _brass = Color(0xFFD4A63B);

DashboardTheme _originalFor(PrayerPeriod period) => dashboardThemes
    .firstWhere((t) => t.sourcePeriod == period && t.variant == 0);

DashboardTheme _savedFor(PrayerController c, PrayerPeriod period) =>
    themeForId(c.settings.periodThemes[period.name]) ?? _originalFor(period);

Future<bool> _saveMapping(
  BuildContext context,
  PrayerController c,
  PrayerPeriod period,
  DashboardTheme theme,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final merged = {...c.settings.periodThemes, period.name: theme.id};
    await c.updateSettings(c.settings.copyWith(periodThemes: merged));
    messenger.showSnackBar(SnackBar(
      content: Text('تم حفظ ${theme.label} لفترة ${periodLabel(period)}.'),
      backgroundColor: _forest,
    ));
    return true;
  } catch (error) {
    messenger.showSnackBar(SnackBar(
      content: Text('تعذر الحفظ: $error'),
      backgroundColor: Colors.red.shade800,
    ));
    return false;
  }
}

void _preview(BuildContext context, PrayerController c, DashboardTheme t) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => DashboardScreen(controller: c, previewTheme: t),
  ));
}

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({required this.controller, super.key});

  final PrayerController controller;

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  bool _busy = false;

  PrayerController get c => widget.controller;

  Future<void> _toggle(bool value) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await c.updateSettings(c.settings.copyWith(customThemesEnabled: value));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تعذر الحفظ: $error'),
          backgroundColor: Colors.red.shade800,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(PrayerPeriod period, DashboardTheme theme) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _saveMapping(context, c, period, theme);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: c,
        builder: (context, _) {
          final on = c.settings.customThemesEnabled;
          return Scaffold(
            appBar: AppBar(title: const Text('واجهة التطبيق')),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                  children: [
                    if (c.storageError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(c.storageError!,
                            style: TextStyle(color: Colors.red.shade800)),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('السمات',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      value: on,
                      onChanged: _busy ? null : _toggle,
                    ),
                    if (!on)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'السمات التلقائية الأصلية مفعلة: تتغير واجهة التطبيق تلقائيًا مع كل فترة من فترات اليوم. فعّل السمات لاختيار مظهر مخصص لكل فترة.',
                          style: TextStyle(height: 1.7),
                        ),
                      )
                    else
                      for (final period in PrayerPeriod.values)
                        _periodRow(context, period),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _periodRow(BuildContext context, PrayerPeriod period) {
    final theme = _savedFor(c, period);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _forest.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ThemePickerScreen(c, period),
          )),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(width: 96, child: ThemeThumb(theme: theme)),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 120),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(periodLabel(period),
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(theme.label),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _preview(context, c, theme),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('معاينة'),
                ),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _save(period, theme),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('حفظ'),
                ),
                const Icon(Icons.chevron_left),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ThemeThumb extends StatelessWidget {
  const ThemeThumb({required this.theme, this.selected = false, super.key});

  final DashboardTheme theme;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = theme.palette;
    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? _brass : Colors.black26,
            width: selected ? 3 : 1,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [p.skyTop, p.skyMiddle, p.skyBottom],
          ),
          image: theme.backgroundAsset == null
              ? null
              : DecorationImage(
                  image: AssetImage(theme.backgroundAsset!),
                  fit: BoxFit.cover,
                  onError: (_, __) {},
                ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 14,
                child: ColoredBox(color: p.ribbon),
              ),
              Positioned(
                left: 8,
                right: 8,
                top: 10,
                height: 18,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.card.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                    border:
                        Border(bottom: BorderSide(color: p.accent, width: 2)),
                  ),
                ),
              ),
              if (selected)
                const Positioned(
                  top: 4,
                  right: 4,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: _brass,
                    child: Icon(Icons.check, size: 16, color: _forest),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class ThemePickerScreen extends StatefulWidget {
  const ThemePickerScreen(this.controller, this.period, {super.key});

  final PrayerController controller;
  final PrayerPeriod period;

  @override
  State<ThemePickerScreen> createState() => _ThemePickerScreenState();
}

class _ThemePickerScreenState extends State<ThemePickerScreen> {
  late DashboardTheme _draft;
  bool _saving = false;

  PrayerController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _draft = _savedFor(c, widget.period);
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await _saveMapping(context, c, widget.period, _draft);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final saved = _savedFor(c, widget.period);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: Text('سمة فترة ${periodLabel(widget.period)}')),
        body: LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth - 32;
          final cols = width >= 1000 ? 6 : (width >= 640 ? 4 : 3);
          const gap = 10.0;
          final tile = (width - gap * (cols - 1)) / cols;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              for (final source in PrayerPeriod.values) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 8),
                  child: Text(periodLabel(source),
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700)),
                ),
                Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in dashboardThemes
                        .where((t) => t.sourcePeriod == source))
                      SizedBox(
                        width: tile,
                        child: _tile(t, t.id == saved.id),
                      ),
                  ],
                ),
              ],
            ],
          );
        }),
        bottomNavigationBar: Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _preview(context, c, _draft),
                      icon: const Icon(Icons.visibility_outlined),
                      label: const Text('معاينة'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(DashboardTheme t, bool isSaved) {
    final selected = t.id == _draft.id;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => setState(() => _draft = t),
      child: Column(
        children: [
          ThemeThumb(theme: t, selected: selected),
          const SizedBox(height: 4),
          Text(
            isSaved ? '${t.label} (محفوظة)' : t.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              color: selected ? _forest : null,
            ),
          ),
        ],
      ),
    );
  }
}
