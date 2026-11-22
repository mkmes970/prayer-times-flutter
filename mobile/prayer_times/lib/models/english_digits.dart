String englishDigits(String text) => text.replaceAllMapped(
  RegExp(r'[٠-٩۰-۹]'), (match) {
    final code = match[0]!.codeUnitAt(0);
    return '${code - (code <= 0x669 ? 0x660 : 0x6f0)}';
  });
