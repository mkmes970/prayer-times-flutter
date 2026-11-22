import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Decorative foreground only: never intercepts touches or changes text layout.
class OrnateFrameDecoration extends Decoration {
  const OrnateFrameDecoration({this.inset = 8, this.panel = false});
  final double inset;
  final bool panel;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _OrnateFramePainter(this);
}

class _OrnateFramePainter extends BoxPainter {
  _OrnateFramePainter(this.decoration);
  final OrnateFrameDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null || size.isEmpty) return;
    final rect = (offset & size).deflate(decoration.inset);
    if (rect.width <= 0 || rect.height <= 0) return;

    final shadow = Paint()
      ..color = const Color(0xFF574116)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2;
    final gold = Paint()
      ..color = const Color(0xFFD7B54E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final highlight = Paint()
      ..color = const Color(0xFFF4DE94)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .75;

    // The reference uses a dark keyline under several bright gold rails.
    for (final inset in [1.5, 5.0, 9.0]) {
      final rail = rect.deflate(inset);
      final radius = Radius.circular(inset < 3 ? 8 : 5);
      canvas.drawRRect(RRect.fromRectAndRadius(rail, radius), shadow);
      canvas.drawRRect(RRect.fromRectAndRadius(rail, radius), gold);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rail.deflate(1.2), radius),
        highlight,
      );
    }

    _drawEdgeGeometry(canvas, rect.deflate(7), gold, highlight);
    final sizeInUnits = math.min(
      math.min(rect.width * .115, rect.height * .25),
      104.0,
    );
    if (sizeInUnits > 8) {
      for (final corner in [
        (rect.left + 6, rect.top + 6, 1.0, 1.0),
        (rect.right - 6, rect.top + 6, -1.0, 1.0),
        (rect.left + 6, rect.bottom - 6, 1.0, -1.0),
        (rect.right - 6, rect.bottom - 6, -1.0, -1.0),
      ]) {
        canvas.save();
        canvas.translate(corner.$1, corner.$2);
        canvas.scale(
          corner.$3 * sizeInUnits / 100,
          corner.$4 * sizeInUnits / 100,
        );
        _drawCorner(canvas, gold, highlight);
        canvas.restore();
      }
      _drawMedallion(canvas, Offset(rect.center.dx, rect.top + 5),
          math.min(18, rect.height * .045), gold, highlight);
      _drawMedallion(canvas, Offset(rect.center.dx, rect.bottom - 5),
          math.min(18, rect.height * .045), gold, highlight);
    }
  }

  void _drawEdgeGeometry(
    Canvas canvas,
    Rect rect,
    Paint gold,
    Paint highlight,
  ) {
    final rail = Path()
      ..moveTo(rect.left + 112, rect.top)
      ..lineTo(rect.center.dx - 26, rect.top)
      ..moveTo(rect.center.dx + 26, rect.top)
      ..lineTo(rect.right - 112, rect.top)
      ..moveTo(rect.left + 112, rect.bottom)
      ..lineTo(rect.center.dx - 26, rect.bottom)
      ..moveTo(rect.center.dx + 26, rect.bottom)
      ..lineTo(rect.right - 112, rect.bottom)
      ..moveTo(rect.left + 112, rect.top)
      ..lineTo(rect.center.dx - 26, rect.top)
      ..moveTo(rect.center.dx + 26, rect.top)
      ..lineTo(rect.right - 112, rect.top)
      ..moveTo(rect.left + 112, rect.bottom)
      ..lineTo(rect.center.dx - 26, rect.bottom)
      ..moveTo(rect.center.dx + 26, rect.bottom)
      ..lineTo(rect.right - 112, rect.bottom);
    if (rect.height > 220) {
      rail
        ..moveTo(rect.left, rect.top + 112)
        ..lineTo(rect.left, rect.center.dy - 28)
        ..moveTo(rect.left, rect.center.dy + 28)
        ..lineTo(rect.left, rect.bottom - 112)
        ..moveTo(rect.right, rect.top + 112)
        ..lineTo(rect.right, rect.center.dy - 28)
        ..moveTo(rect.right, rect.center.dy + 28)
        ..lineTo(rect.right, rect.bottom - 112);
    }
    canvas.drawPath(rail, gold);

    final decorationPath = Path();
    final horizontalStep = math.min(90.0, rect.width / 9);
    for (final x in [
      rect.left + horizontalStep,
      rect.right - horizontalStep,
    ]) {
      for (final y in [rect.top, rect.bottom]) {
        _diamond(decorationPath, Offset(x, y), 4.2);
      }
    }
    final verticalStep = math.min(88.0, rect.height / 5);
    for (final y in [rect.top + verticalStep, rect.bottom - verticalStep]) {
      for (final x in [rect.left, rect.right]) {
        _diamond(decorationPath, Offset(x, y), 3.8);
      }
    }
    canvas.drawPath(decorationPath, highlight);
  }

  void _drawCorner(Canvas canvas, Paint gold, Paint highlight) {
    final main = Path()
      ..moveTo(2, 98)
      ..cubicTo(3, 73, 20, 70, 22, 50)
      ..cubicTo(25, 31, 8, 29, 10, 15)
      ..cubicTo(12, 1, 30, 1, 37, 14)
      ..cubicTo(44, 28, 30, 40, 42, 51)
      ..cubicTo(54, 63, 71, 49, 78, 35)
      ..cubicTo(86, 18, 93, 7, 99, 3)
      ..moveTo(3, 77)
      ..cubicTo(15, 59, 36, 68, 45, 52)
      ..cubicTo(56, 32, 37, 19, 47, 9)
      ..cubicTo(57, -1, 72, 8, 70, 21)
      ..cubicTo(68, 34, 55, 37, 61, 48)
      ..cubicTo(68, 62, 86, 59, 98, 43)
      ..moveTo(19, 97)
      ..cubicTo(27, 83, 45, 89, 54, 76)
      ..cubicTo(65, 61, 54, 50, 66, 42)
      ..cubicTo(78, 34, 92, 40, 99, 34)
      ..moveTo(4, 54)
      ..cubicTo(20, 43, 28, 46, 34, 34)
      ..cubicTo(40, 22, 32, 12, 37, 4);
    _drawLayeredPath(canvas, main, gold, highlight);

    final tendrils = Path()
      ..moveTo(7, 92)
      ..cubicTo(20, 91, 22, 79, 17, 73)
      ..cubicTo(11, 66, 4, 74, 10, 79)
      ..cubicTo(16, 83, 22, 76, 23, 69)
      ..moveTo(26, 49)
      ..cubicTo(40, 47, 43, 38, 39, 32)
      ..cubicTo(35, 26, 29, 31, 33, 36)
      ..cubicTo(38, 41, 47, 33, 48, 25)
      ..moveTo(72, 33)
      ..cubicTo(69, 19, 80, 13, 86, 20)
      ..cubicTo(92, 28, 83, 34, 78, 28)
      ..cubicTo(74, 23, 82, 14, 96, 9)
      ..moveTo(79, 58)
      ..cubicTo(90, 56, 91, 46, 86, 43)
      ..cubicTo(80, 40, 77, 49, 83, 51)
      ..cubicTo(88, 53, 94, 47, 98, 40);
    canvas.drawPath(tendrils, highlight);

    for (final center in [
      const Offset(16, 17),
      const Offset(37, 53),
      const Offset(53, 10),
      const Offset(85, 35),
      const Offset(23, 83),
      const Offset(67, 68),
    ]) {
      _drawFlower(canvas, center, 5.3, gold, highlight);
    }
    _drawLeaf(canvas, const Offset(17, 39), -1, gold, highlight);
    _drawLeaf(canvas, const Offset(34, 68), 1, gold, highlight);
    _drawLeaf(canvas, const Offset(57, 25), -1, gold, highlight);
    _drawLeaf(canvas, const Offset(78, 80), 1, gold, highlight);
    for (final point in [
      const Offset(8, 62),
      const Offset(47, 77),
      const Offset(96, 22),
    ]) {
      final path = Path();
      _diamond(path, point, 4);
      canvas.drawPath(path, gold);
    }
  }

  void _drawLeaf(Canvas canvas, Offset origin, double direction, Paint gold,
      Paint highlight) {
    canvas.save();
    canvas.translate(origin.dx, origin.dy);
    canvas.scale(direction, 1);
    final leaf = Path()
      ..moveTo(0, 0)
      ..cubicTo(8, -12, 23, -11, 27, -2)
      ..cubicTo(21, 8, 8, 9, 0, 0)
      ..close();
    final fill = Paint()
      ..color = const Color(0xFF14442D)
      ..style = PaintingStyle.fill;
    canvas.drawPath(leaf, fill);
    _drawLayeredPath(canvas, leaf, gold, highlight);
    canvas.drawLine(
      Offset(2, 0),
      const Offset(23, -2),
      highlight,
    );
    canvas.restore();
  }

  void _drawFlower(
    Canvas canvas,
    Offset center,
    double radius,
    Paint gold,
    Paint highlight,
  ) {
    final flower = Path();
    for (var petal = 0; petal < 8; petal++) {
      final angle = petal * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final perpendicular = Offset(-direction.dy, direction.dx);
      final tip = center + direction * radius;
      final start = center + perpendicular * (radius * .35);
      final end = center - perpendicular * (radius * .35);
      flower
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(
          center.dx + direction.dx * (radius * .35),
          center.dy + direction.dy * (radius * .35),
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          center.dx - direction.dx * (radius * .35),
          center.dy - direction.dy * (radius * .35),
          end.dx,
          end.dy,
        )
        ..close();
    }
    final fill = Paint()
      ..color = const Color(0xFF17442E)
      ..style = PaintingStyle.fill;
    canvas.drawPath(flower, fill);
    _drawLayeredPath(canvas, flower, gold, highlight);
    canvas.drawCircle(
      center,
      radius * .19,
      Paint()
        ..color = const Color(0xFFF4DE94)
        ..style = PaintingStyle.fill,
    );
  }

  void _drawMedallion(
    Canvas canvas,
    Offset center,
    double radius,
    Paint gold,
    Paint highlight,
  ) {
    final petals = Path();
    for (var petal = 0; petal < 8; petal++) {
      final angle = petal * math.pi / 4;
      final direction = Offset(math.cos(angle), math.sin(angle));
      final perpendicular = Offset(-direction.dy, direction.dx);
      final tip = center + direction * radius;
      final a =
          center + direction * (radius * .3) + perpendicular * (radius * .3);
      final b =
          center + direction * (radius * .3) - perpendicular * (radius * .3);
      petals
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
          center.dx + direction.dx * radius * .6,
          center.dy + direction.dy * radius * .6,
          tip.dx,
          tip.dy,
        )
        ..quadraticBezierTo(
          center.dx - direction.dx * radius * .1,
          center.dy - direction.dy * radius * .1,
          b.dx,
          b.dy,
        )
        ..close();
    }
    final fill = Paint()
      ..color = const Color(0xFF12432C)
      ..style = PaintingStyle.fill;
    canvas.drawPath(petals, fill);
    _drawLayeredPath(canvas, petals, gold, highlight);
    canvas.drawCircle(
      center,
      radius * .28,
      Paint()
        ..color = const Color(0xFFF3D783)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(center, radius * .13, fill);
  }

  void _drawLayeredPath(
    Canvas canvas,
    Path path,
    Paint gold,
    Paint highlight,
  ) {
    canvas.drawPath(path, gold);
    final inset = Paint()
      ..color = highlight.color.withAlpha(190)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55;
    canvas.drawPath(path, inset);
  }

  void _diamond(Path path, Offset center, double radius) {
    path
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius, center.dy)
      ..close();
  }
}
