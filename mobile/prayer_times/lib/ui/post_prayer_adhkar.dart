import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/post_prayer_adhkar.dart';
import '../state/prayer_controller.dart';

final _adhkarSource =
    rootBundle.loadString('assets/data/post-prayer-adhkar.json');
const _ink = Color(0xFF101B52);
const _recitation = Color(0xFF008000);

TextSpan _entryText(DhikrPage page, [Color recitation = _recitation]) =>
    TextSpan(children: [
      const TextSpan(text: '۞ ', style: TextStyle(color: Color(0xFF997725))),
      if (page.showDetails)
        TextSpan(
            text: '${stretchAdhkarText(page.title)}: ',
            style: const TextStyle(color: Colors.black)),
      for (var i = 0; i < (page.boardText ?? page.text).split('\n').length; i++)
        TextSpan(
          text:
              '${i > 0 ? '\n' : ''}${stretchAdhkarText((page.boardText ?? page.text).split('\n')[i], isQuran: page.boardText != null)}',
          style: TextStyle(
              color: page.id == 'tasbih' && i == 1 ? Colors.black : recitation),
        ),
    ]);

class PostPrayerAdhkar extends StatelessWidget {
  const PostPrayerAdhkar({required this.status, required this.now, super.key});

  final PrayerScreenStatus status;
  final DateTime now;

  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: 'AdhkarNaskh'),
      child: FutureBuilder<String>(
        future: _adhkarSource,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
                child: Text('تعذر تحميل أذكار الصلاة.',
                    style: TextStyle(color: _ink)));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: _ink));
          }
          final pages = adhkarForPrayer(snapshot.data!, status.prayerId);
          final columns = adhkarBoardColumns(pages);
          final remaining = status.remainingAt(now).inMicroseconds;
          final seconds = remaining <= 0
              ? 0
              : (remaining + Duration.microsecondsPerSecond - 1) ~/
                  Duration.microsecondsPerSecond;
          return LayoutBuilder(builder: (context, constraints) {
            final size =
                (constraints.maxHeight * .055).clamp(16.0, 48.0).toDouble();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Text('اذكار بعد الصلاة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _ink,
                          fontSize: size,
                          fontWeight: FontWeight.bold)),
                  Expanded(
                    child: LayoutBuilder(builder: (context, available) {
                      final columnWidth = ((available.maxWidth - 24) / 2)
                          .clamp(1.0, double.infinity)
                          .toDouble();
                      double textHeight(InlineSpan text, double fontSize) {
                        final painter = TextPainter(
                          text: TextSpan(
                              children: [text],
                              style: DefaultTextStyle.of(context).style.merge(
                                  TextStyle(
                                      fontFamily: 'AdhkarNaskh',
                                      fontSize: fontSize,
                                      height: 1.4,
                                      fontWeight: FontWeight.w900))),
                          textDirection: TextDirection.rtl,
                          // Measure the same enlarged text that Text.rich renders.
                          // Android TV can apply a different system text scale.
                          textScaler: MediaQuery.textScalerOf(context),
                          locale: Localizations.maybeLocaleOf(context),
                        )..layout(maxWidth: columnWidth);
                        final height = painter.height;
                        painter.dispose();
                        return height;
                      }

                      double fitColumn(List<DhikrPage> column) {
                        var low = 1.0, high = available.maxWidth * .045;
                        for (var attempt = 0; attempt < 12; attempt++) {
                          final candidate = (low + high) / 2;
                          final fits = column.fold<double>(
                                  0,
                                  (sum, page) =>
                                      sum +
                                      textHeight(_entryText(page), candidate) +
                                      (page.showDetails
                                          ? textHeight(
                                              TextSpan(
                                                  text: stretchAdhkarText(
                                                      page.displayNote)),
                                              candidate * .72)
                                          : 0) +
                                      candidate * .15) <=
                              available.maxHeight;
                          if (fits) {
                            low = candidate;
                          } else {
                            high = candidate;
                          }
                        }
                        return low * .99;
                      }

                      return Row(
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: _AdhkarColumn(
                                  pages: columns[0],
                                  size: fitColumn(columns[0]))),
                          const VerticalDivider(
                              width: 24,
                              thickness: 1,
                              color: Color(0xFFBD9B4F)),
                          Expanded(
                              child: _AdhkarColumn(
                                  pages: columns[1],
                                  size: fitColumn(columns[1]),
                                  colorOffset: columns[0].length)),
                        ],
                      );
                    }),
                  ),
                  Text(
                    '${now.hour % 12 == 0 ? 12 : now.hour % 12}:'
                    '${now.minute.toString().padLeft(2, '0')}:'
                    '${now.second.toString().padLeft(2, '0')}',
                    key: const ValueKey('post-prayer-clock'),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFC62828),
                      fontSize: size,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                  Text(
                      'العودة للواجهة بعد ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _ink, fontSize: size * .5)),
                ],
              ),
            );
          });
        },
      ));
}

class _AdhkarColumn extends StatelessWidget {
  const _AdhkarColumn(
      {required this.pages, required this.size, this.colorOffset = 0});
  final int colorOffset;
  final List<DhikrPage> pages;
  final double size;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < pages.length; index++)
            Padding(
              padding: EdgeInsets.only(bottom: size * .15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text.rich(
                      _entryText(
                          pages[index],
                          (index + colorOffset).isEven
                              ? _recitation
                              : const Color(0xFFD00000)),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                          fontFamily: 'AdhkarNaskh',
                          color: _recitation,
                          fontSize: size,
                          height: 1.4,
                          fontWeight: FontWeight.w900)),
                  if (pages[index].showDetails)
                    Text(stretchAdhkarText(pages[index].displayNote),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'AdhkarNaskh',
                            color: Colors.black,
                            fontSize: size * .72,
                            height: 1.4,
                            fontWeight: FontWeight.w900)),
                ],
              ),
            ),
        ],
      );
}
