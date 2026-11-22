import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/dua_rotation.dart';

/// A bounded queue of complete, single-line texts; never lays out the entire
/// 600-hadith catalogue or resets an animation when an item leaves the screen.
class ContinuousTicker extends StatefulWidget {
  const ContinuousTicker({
    required this.rotation,
    required this.fontSize,
    required this.accent,
    this.textColor,
    this.pixelsPerSecond = 32,
    super.key,
  });

  final DuaRotation rotation;
  final double fontSize;
  final Color accent;
  final Color? textColor;
  final double pixelsPerSecond;

  @override
  State<ContinuousTicker> createState() => _ContinuousTickerState();
}

class _ContinuousTickerState extends State<ContinuousTicker>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final Ticker _ticker;
  final _motion = _TickerMotion();
  Duration? _previousElapsed;
  bool _active = true;
  TextStyle? _style;
  Color? _accent;
  double _width = 0;
  final Queue<TextPainter> _items = Queue();
  double _offset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _active = state == null || state == AppLifecycleState.resumed;
    _ticker = createTicker(_tick);
    if (_active) _ticker.start();
  }

  TextPainter _nextPainter() {
    final text = widget.rotation.current;
    widget.rotation.next();
    return TextPainter(
      text: TextSpan(style: _style, children: [
        TextSpan(text: text),
        TextSpan(
          text: '   ﴿ ۞ ﴾   ',
          style: TextStyle(color: widget.accent),
        ),
      ]),
      textDirection: TextDirection.rtl,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
  }

  void _fillViewport() {
    var end = -_offset;
    for (final item in _items) {
      end += item.width;
    }
    // Keep the next text ready before its leading edge reaches the viewport.
    while (end < _width + 100) {
      final next = _nextPainter();
      _items.add(next);
      end += next.width;
    }
  }

  void _tick(Duration elapsed) {
    final previous = _previousElapsed;
    _previousElapsed = elapsed;
    if (!_active ||
        previous == null ||
        _items.isEmpty ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    _offset += widget.pixelsPerSecond *
        (elapsed - previous).inMicroseconds /
        Duration.microsecondsPerSecond;
    while (_items.isNotEmpty && _offset >= _items.first.width) {
      final removed = _items.removeFirst();
      _offset -= removed.width;
      removed.dispose();
    }
    _fillViewport();
    _motion.changed();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A muted route must not jump forward by the time spent off screen.
    _previousElapsed = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _previousElapsed = null;
    if (_active && !_ticker.isActive) {
      _ticker.start();
    } else if (!_active && _ticker.isActive) {
      _ticker.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    for (final item in _items) {
      item.dispose();
    }
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final style = TextStyle(
        fontFamily: 'Amiri',
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w700,
        color: widget.textColor ?? Colors.white,
        height: 1.35,
      );
      if (_style != style || _accent != widget.accent) {
        if (_style == null) {
          _style = style;
          _accent = widget.accent;
        } else {
          // Re-layout queued texts without consuming new catalogue entries.
          for (final painter in _items) {
            final old = painter.text! as TextSpan;
            painter.text = TextSpan(style: style, children: [
              old.children!.first,
              TextSpan(
                  text: '   ﴿ ۞ ﴾   ', style: TextStyle(color: widget.accent)),
            ]);
            painter.layout();
          }
          _style = style;
          _accent = widget.accent;
        }
      }
      _width = constraints.maxWidth;
      _fillViewport();
      return ClipRect(
        child: CustomPaint(
          size: Size(_width, widget.fontSize * 1.7),
          painter: ContinuousTickerPainter(
            items: _items,
            offset: () => _offset,
            repaint: _motion,
          ),
        ),
      );
    });
  }
}

class _TickerMotion extends ChangeNotifier {
  void changed() => notifyListeners();
}

/// Paints adjacent full-length Arabic texts with no clipping inside each item.
class ContinuousTickerPainter extends CustomPainter {
  ContinuousTickerPainter({
    required this.items,
    required this.offset,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final Iterable<TextPainter> items;
  final double Function() offset;

  @override
  void paint(Canvas canvas, Size size) {
    // Items enter from the left, with Arabic glyphs kept in their normal order.
    var right = size.width + offset();
    for (final item in items) {
      final left = right - item.width;
      item.paint(canvas, Offset(left, (size.height - item.height) / 2));
      right = left;
      if (right < 0) break;
    }
  }

  @override
  bool shouldRepaint(ContinuousTickerPainter oldDelegate) => true;
}
