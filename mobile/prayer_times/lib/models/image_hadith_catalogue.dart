/// Decode the manually transcribed image catalogue. Its source numbering is
/// provenance only, never a numbered display collection like Nawawi.
List<Map<String, dynamic>> parseImageHadithCatalogue(
  Map<String, dynamic> catalogue,
) {
  final narrators = (catalogue['narrators'] as Map).cast<String, String>();
  final reports = (catalogue['reports'] as Map).cast<String, String>();
  final sources = (catalogue['sources'] as Map).cast<String, String>();
  final rows = catalogue['entries'] as List<dynamic>;
  if (rows.length != 200) {
    throw const FormatException('Image catalogue must contain 200 hadiths.');
  }
  return rows.asMap().entries.map((item) {
    final row = item.value as List<dynamic>;
    if ((row.length != 5 && row.length != 6) ||
        row[0] != item.key + 1 ||
        !narrators.containsKey(row[1]) ||
        !reports.containsKey(row[2]) ||
        !sources.containsKey(row[4]) ||
        row[3] is! String ||
        (row[3] as String).trim().isEmpty) {
      throw FormatException('Invalid image hadith ${item.key + 1}.');
    }
    final reportId = row[2] as String;
    final report = reports[reportId]!;
    final body = row[3] as String;
    final prefix = 'عن ${narrators[row[1]]}';
    final narrative = reportId == 'narrative' ||
        reportId == 'womanNarrative' ||
        reportId == 'plain';
    final text = report.isEmpty
        ? '$prefix $body'
        : '$prefix $report: ${narrative ? body : '«$body»'}';
    return <String, dynamic>{
      'sourceNumber': row[0],
      'text': text,
      'source': sources[row[4]],
      if (row.length == 6) 'explanation': row[5],
    };
  }).toList();
}
