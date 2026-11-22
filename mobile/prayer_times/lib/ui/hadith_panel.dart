import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/hadith_rotation.dart';
import '../models/pdf_hadith_catalogue.dart';
import '../models/hadith_timing.dart';
import '../models/image_hadith_catalogue.dart';
import '../models/evening_adhkar.dart';
import '../models/morning_adhkar.dart';
import '../models/english_digits.dart';
import '../models/adhan_hadiths.dart';
import '../models/adhan_playback.dart';
import '../services/adhan_progress_store.dart';
import '../services/hadith_progress_store.dart';
import '../models/recitation_colors.dart';

TextSpan _coloredRecitation(String text, bool evening) => TextSpan(children: [
      for (final part in recitationParts(text, evening: evening))
        TextSpan(
            text: englishDigits(part.text),
            style: TextStyle(
                color:
                    part.recitation ? const Color(0xFFD00000) : Colors.black)),
    ]);

/// Changes only the information area; prayer times and timers are siblings.
class HadithPanel extends StatefulWidget {
  const HadithPanel({
    required this.child,
    this.enabled = false,
    this.fridayMode = false,
    this.ramadanMode = false,
    this.rightBoundaryKey,
    this.onVisibilityChanged,
    this.now,
    this.eveningMaghribAt,
    this.eveningEndsAt,
    this.morningStartsAt,
    this.morningEndsAt,
    this.adhanTimes = const [],
    this.adhanBlocked = false,
    super.key,
  });

  final Widget child;
  final DateTime? now;
  final DateTime? eveningMaghribAt;
  final DateTime? eveningEndsAt;
  final DateTime? morningStartsAt;
  final DateTime? morningEndsAt;
  final List<DateTime> adhanTimes;
  final bool adhanBlocked;
  final bool enabled;
  final bool fridayMode;
  final bool ramadanMode;
  final GlobalKey? rightBoundaryKey;
  final ValueChanged<bool>? onVisibilityChanged;

  @override
  State<HadithPanel> createState() => _HadithPanelState();
}

class _HadithPanelState extends State<HadithPanel> with WidgetsBindingObserver {
  Timer? _timer;
  bool _showHadith = false;
  HadithRotation? _rotation;
  bool _loadFailed = false;
  String? _eveningSource;
  String? _morningSource;
  HadithProgressStore? _progressStore;
  int _timerGeneration = 0;
  bool _writingProgress = false;
  bool get _morningActive => morningWindowActive(
      widget.now, widget.morningStartsAt, widget.morningEndsAt);
  List<Map<String, dynamic>> _adhanHadiths = [];
  AdhanPlayback? _adhanPlayback;
  AdhanProgressStore? _adhanStore;
  Map<String, dynamic>? _currentAdhanEntry;
  DateTime? get _adhanEnd => widget.now == null
      ? null
      : adhanWindowEnd(widget.now!, widget.adhanTimes);
  bool get _adhanActive => _adhanEnd != null;
  Map<String, dynamic>? get _adhanEntry => _currentAdhanEntry;
  void _updateAdhanPlayback() {
    final player = _adhanPlayback;
    final now = widget.now;
    if (player == null || now == null) return;
    final previousIndex = player.index;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _currentAdhanEntry = player.at(_adhanHadiths, now, _adhanEnd,
        blocked: !widget.enabled ||
            widget.adhanBlocked ||
            ModalRoute.of(context)?.isCurrent == false ||
            (lifecycle != null && lifecycle != AppLifecycleState.resumed));
    if (player.index != previousIndex) {
      unawaited(_adhanStore!.save(player.index).catchError((Object error) {
        debugPrint('Cannot save adhan playback progress: $error');
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
              content: Text('تعذر حفظ موضع أحاديث الأذان على هذا الجهاز.')));
        }
      }));
    }
  }

  bool get _eveningActive =>
      widget.now != null &&
      eveningWindowActive(
          widget.now!, widget.eveningMaghribAt, widget.eveningEndsAt);
  bool get _contentVisible =>
      widget.enabled && (_adhanActive ? _adhanEntry != null : _showHadith);
  bool get _canPlay {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return widget.enabled &&
        !widget.adhanBlocked &&
        !_adhanActive &&
        ModalRoute.of(context)?.isCurrent != false &&
        (lifecycle == null || lifecycle == AppLifecycleState.resumed);
  }

  void _updateModes() {
    final now = widget.now;
    _rotation
      ?..setFridayMode(widget.fridayMode)
      ..setRamadanMode(widget.ramadanMode)
      ..setRecitationMode(
          _morningActive
              ? 'morning'
              : _eveningActive
                  ? 'evening'
                  : null,
          session: now == null ? null : '${now.year}-${now.month}-${now.day}');
  }

  void _reportProgressError(Object error) {
    debugPrint('Cannot save hadith playback progress: $error');
    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(
          content: Text('تعذر حفظ تقدم الأحاديث على هذا الجهاز.')));
    }
  }

  final _areaKey = GlobalKey();
  double _rightExpansion = 0;

  void _measureRightExpansion() {
    if (!mounted) return;
    final area = _areaKey.currentContext?.findRenderObject();
    final boundary =
        widget.rightBoundaryKey?.currentContext?.findRenderObject();
    var expansion = 0.0;
    if (area is RenderBox &&
        boundary is RenderBox &&
        area.hasSize &&
        boundary.hasSize) {
      final rightLimit = area
              .globalToLocal(
                boundary.localToGlobal(Offset.zero),
              )
              .dx -
          12;
      expansion = math.max(0.0, rightLimit - area.size.width);
    }
    if ((_rightExpansion - expansion).abs() > 0.5) {
      setState(() => _rightExpansion = expansion);
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onVisibilityChanged?.call(false);
    });
    _loadHadiths();
  }

  Future<void> _loadHadiths() async {
    try {
      final eveningSource =
          await rootBundle.loadString('assets/data/evening-adhkar.txt');
      parseEveningAdhkar(eveningSource);
      _morningSource =
          await rootBundle.loadString('assets/data/morning-adhkar.txt');
      parseMorningAdhkar(_morningSource!);
      final data = jsonDecode(
        await rootBundle.loadString(
          'assets/data/dashboard-hadiths.json',
        ),
      ) as Map<String, dynamic>;
      final ordered = (data['ordered'] as List<dynamic>)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final random = (data['random'] as List<dynamic>)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final imageHadiths = parseImageHadithCatalogue(
        jsonDecode(
          await rootBundle.loadString(
            'assets/data/daily-hadiths-from-images.json',
          ),
        ) as Map<String, dynamic>,
      );
      final friday = (data['friday'] as List<dynamic>)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final fridayAdditional = (data['fridayAdditional'] as List<dynamic>)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      final ramadanData = jsonDecode(
        await rootBundle.loadString('assets/data/ramadan-hadiths.json'),
      ) as Map<String, dynamic>;
      final ramadanHadiths = (ramadanData['entries'] as List<dynamic>)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      if (ordered.length != 42 ||
          ramadanHadiths.length != 75 ||
          ramadanHadiths
              .any((entry) => (entry['text'] as String? ?? '').isEmpty) ||
          ordered.asMap().entries.any(
                (entry) =>
                    entry.value['number'] != entry.key + 1 ||
                    (entry.value['text'] as String? ?? '').isEmpty,
              ) ||
          random.any((entry) => (entry['text'] as String? ?? '').isEmpty) ||
          fridayAdditional.any(
            (entry) => (entry['text'] as String? ?? '').isEmpty,
          ) ||
          friday.length != 40 ||
          friday.asMap().entries.any(
                (entry) =>
                    entry.value['number'] != entry.key + 1 ||
                    (entry.value['text'] as String? ?? '').isEmpty,
              )) {
        throw const FormatException('Hadith list is incomplete or invalid.');
      }
      if (!mounted) return;
      setState(() => _eveningSource = eveningSource);
      final pdfData = jsonDecode(await rootBundle.loadString(
        'assets/data/abu-hurayra-50-hadiths.json',
      )) as Map<String, dynamic>;
      final pdfHadiths = (pdfData['entries'] as List)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      if (pdfHadiths.length != 50 ||
          pdfHadiths.asMap().entries.any(
                (entry) =>
                    entry.value['number'] != entry.key + 1 ||
                    (entry.value['text'] as String? ?? '').isEmpty,
              )) {
        throw const FormatException('PDF hadith collection is incomplete.');
      }
      final randomForOtherDays = [
        ...random,
        ...imageHadiths,
        ...pdfHadiths,
        for (final count in [100, 600])
          ...parsePdfHadithCatalogue(
            jsonDecode(await rootBundle
                .loadString('assets/data/pdf-hadiths-$count.json')),
            count,
          ),
      ];
      final adhanData = jsonDecode(await rootBundle.loadString(
        'assets/data/adhan-hadiths.json',
      )) as Map<String, dynamic>;
      final adhanHadiths = (adhanData['entries'] as List)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      if (adhanHadiths.length != 9 ||
          adhanHadiths
              .any((entry) => (entry['text'] as String? ?? '').isEmpty)) {
        throw const FormatException('Invalid adhan hadith catalogue.');
      }
      if (!mounted) return;
      final explanationsData = jsonDecode(await rootBundle.loadString(
        'assets/data/adhan-explanations.json',
      )) as Map<String, dynamic>;
      final explanations = (explanationsData['entries'] as List)
          .map((entry) => (entry as Map).cast<String, dynamic>())
          .toList();
      if (explanations.length != 10 ||
          explanations.asMap().entries.any((entry) =>
              entry.value['number'] != entry.key + 1 ||
              (entry.value['text'] as String? ?? '').isEmpty)) {
        throw const FormatException('Invalid adhan explanations catalogue.');
      }
      if (!mounted) return;
      _adhanStore = await AdhanProgressStore.createDefault();
      _adhanPlayback = AdhanPlayback(await _adhanStore!.load());
      if (!mounted) return;
      setState(() {
        _adhanHadiths = [...explanations, ...adhanHadiths];
        _updateAdhanPlayback();
      });
      // All 19 dedicated adhan entries are excluded from the general pool.
      _progressStore = await HadithProgressStore.createDefault();
      final progress = await _progressStore!.load();
      if (!mounted) return;
      _rotation = HadithRotation(
        ordered: ordered,
        randomHadiths: randomForOtherDays,
        fridayHadiths: [...friday, ...fridayAdditional],
        ramadanHadiths: ramadanHadiths,
        morningAdhkar: parseMorningAdhkar(_morningSource!),
        eveningAdhkar: parseEveningAdhkar(_eveningSource!),
        state: progress,
      );
      _updateModes();
      _scheduleNextPanel();
    } catch (error) {
      debugPrint('Cannot load hadith playback: $error');
      if (!mounted) return;
      setState(() => _loadFailed = true);
    }
  }

  @override
  void didUpdateWidget(covariant HadithPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final previousMorningActive = morningWindowActive(
        oldWidget.now, oldWidget.morningStartsAt, oldWidget.morningEndsAt);
    final previousAdhanEnd = oldWidget.now == null
        ? null
        : adhanWindowEnd(oldWidget.now!, oldWidget.adhanTimes);
    final previousAdhanEntry = _currentAdhanEntry;
    _updateAdhanPlayback();
    final previousWindow = oldWidget.now != null &&
        eveningWindowActive(oldWidget.now!, oldWidget.eveningMaghribAt,
            oldWidget.eveningEndsAt);
    final changed = previousMorningActive != _morningActive ||
        previousWindow != _eveningActive ||
        previousAdhanEnd != _adhanEnd ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.adhanBlocked != widget.adhanBlocked ||
        oldWidget.fridayMode != widget.fridayMode ||
        oldWidget.ramadanMode != widget.ramadanMode;
    _updateModes();
    if (changed || !_canPlay) {
      _showHadith = false;
      _scheduleNextPanel();
    } else if (!_writingProgress && (_timer == null || !_timer!.isActive)) {
      _scheduleNextPanel();
    }
    if (changed || (previousAdhanEntry != null) != (_adhanEntry != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onVisibilityChanged?.call(_contentVisible);
      });
    }
  }

  void _scheduleNextPanel() {
    _timer?.cancel();
    final generation = ++_timerGeneration;
    if (!_canPlay || _rotation == null) return;
    final seconds = _showHadith
        ? hadithDurationSeconds(_rotation!.current.values.whereType<String>())
        : normalInformationSeconds;
    _timer = Timer(Duration(seconds: seconds), () async {
      if (!mounted) return;
      if (_canPlay) {
        final wasShowing = _showHadith;
        if (wasShowing) {
          _rotation!.advance();
          setState(() => _showHadith = false);
          widget.onVisibilityChanged?.call(false);
        } else {
          // Persist the pending entry before exposing it on screen.
          _rotation!.current;
        }
        _writingProgress = true;
        try {
          await _progressStore!.save(_rotation!.toJson());
        } catch (error) {
          _reportProgressError(error);
          if (!mounted || generation != _timerGeneration) return;
          setState(() => _showHadith = false);
          _scheduleNextPanel();
          return;
        } finally {
          _writingProgress = false;
        }
        if (!mounted || generation != _timerGeneration) return;
        if (_canPlay) {
          setState(() => _showHadith = !wasShowing);
          widget.onVisibilityChanged?.call(_showHadith);
        }
      } else {
        setState(() => _showHadith = false);
        widget.onVisibilityChanged?.call(false);
      }
      _scheduleNextPanel();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      _rotation?.restartRandomSession();
    }
    setState(() => _showHadith = false);
    _updateAdhanPlayback();
    _scheduleNextPanel();
    widget.onVisibilityChanged?.call(_contentVisible);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timerGeneration++;
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_contentVisible && !(_loadFailed && widget.enabled)) {
      return widget.child;
    }
    return LayoutBuilder(
      key: _areaKey,
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _measureRightExpansion(),
        );
        final content = _buildContent(context);
        if (!_contentVisible || _rightExpansion == 0) return content;
        return OverflowBox(
          alignment: Alignment.centerLeft,
          minWidth: constraints.maxWidth + _rightExpansion,
          maxWidth: constraints.maxWidth + _rightExpansion,
          minHeight: constraints.maxHeight,
          maxHeight: constraints.maxHeight,
          child: content,
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_loadFailed) {
      return Column(
        children: [
          Expanded(child: widget.child),
          const Text(
            'تعذر تحميل الأحاديث.',
            style: TextStyle(color: Colors.red),
          ),
        ],
      );
    }
    if (!_contentVisible) return widget.child;
    final hadith = _adhanActive ? _adhanEntry! : _rotation!.current;
    final text = hadith['text'] as String;
    final body = _coloredRecitation(
        text, !_adhanActive && _rotation!.currentIsRecitation);
    final richText = TextSpan(children: [
      for (final prefix in [hadith['narrator'], hadith['introduction']]
          .whereType<String>()
          .where((value) => value.isNotEmpty))
        TextSpan(
            text: '${englishDigits(prefix)}\n\n',
            style: const TextStyle(color: Colors.black)),
      body,
    ]);
    final source = englishDigits(hadith['source'] as String? ?? '');
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xfffff5df),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (text.contains('\n') || text.length + source.length > 180) {
            return Column(
              children: [
                Expanded(
                  child: _FittedHadithText(
                    text: richText,
                    size: Size(
                      constraints.maxWidth,
                      constraints.maxHeight - (source.isNotEmpty ? 54 : 0),
                    ),
                  ),
                ),
                if (source.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 1,
                          color: const Color(0xffb99a51),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          source,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xff6b5b36),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          }
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      englishDigits(hadith['narrator'] as String? ?? ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontSize: 23),
                    ),
                    Text(
                      englishDigits(hadith['introduction'] as String? ?? ''),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black, fontSize: 23),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text.rich(
                        body,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xff183d30),
                          fontSize: 40,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      width: 80,
                      height: 1,
                      color: const Color(0xffb99a51),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      source,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xff6b5b36), fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FittedHadithText extends StatelessWidget {
  const _FittedHadithText({required this.text, required this.size});

  final InlineSpan text;
  final Size size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily ?? 'Amiri',
      color: const Color(0xff183d30),
      height: 1.65,
    );
    final painter = TextPainter(
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.justify,
      textScaler: TextScaler.noScaling,
    );
    var low = 1.0;
    var high = 36.0;
    for (var step = 0; step < 12; step++) {
      final fontSize = (low + high) / 2;
      painter.text = TextSpan(
        children: [text],
        style: style.copyWith(fontSize: fontSize),
      );
      painter.layout(maxWidth: size.width);
      if (painter.height <= size.height - 1) {
        low = fontSize;
      } else {
        high = fontSize;
      }
    }
    painter.dispose();
    return Center(
      child: Text.rich(
        text,
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        textScaler: TextScaler.noScaling,
        softWrap: true,
        style: style.copyWith(fontSize: low),
      ),
    );
  }
}
