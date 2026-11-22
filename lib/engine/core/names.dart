/// Display-safe device name from untrusted input (pairing, UDP, Bonjour):
/// removes control and bidi-override characters, collapses spaces, max 40
/// characters, cut by runes (never inside an emoji). Audit #12, A2.
String cleanDeviceName(Object? v) {
  final s = (v is String ? v : 'Device')
      .replaceAll(
        RegExp(
          r'[\x00-\x1F\x7F-\x9F\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
        ),
        '',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (s.isEmpty) return 'Device';
  final r = s.runes.toList();
  return r.length > 40 ? String.fromCharCodes(r.take(40)) : s;
}
