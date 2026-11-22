import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const res = 'android_template/app/src/main/res';
  test('approved icon has every Android density and safe adaptive foreground', () {
    for (final density in {
      'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192,
    }.entries) {
      for (final adaptive in [false, true]) {
        final name = adaptive ? 'ic_launcher_foreground' : 'ic_launcher';
        final bytes = File('$res/mipmap-${density.key}/$name.png').readAsBytesSync();
        final header = ByteData.sublistView(bytes, 16, 24);
        final expected = adaptive ? (density.value * 108 / 48).round() : density.value;
        expect(header.getUint32(0), expected);
        expect(header.getUint32(4), expected);
      }
    }
    expect(File('$res/mipmap-anydpi-v26/ic_launcher.xml').readAsStringSync(),
      contains('@mipmap/ic_launcher_foreground'));
    expect(File('$res/values/prayer_icon_background.xml').readAsStringSync(),
      contains('#F9E8C0'));
    expect(File('../../scripts/bootstrap-prayer-times-android.sh').readAsStringSync(),
      contains('android_template/app/src/main/res/.'));
  });
}
