// C6 (0.11.4): an empty `catch (_) {}` may only guard pure cleanup
// (closing sockets, cancelling timers). Anything that touches files or a
// platform channel must report the problem (recordException / noteError).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/error_note.dart';
import 'package:isekaidrop/engine/core/resume_store.dart';

final _touches = RegExp(
  r'invoke(Map|List)?Method|_call<|\.delete\(|\.writeAs|\.create\(|'
  r'\.rename\(|\.open\(|\.length\(|\.readAs|File\(|Directory\(|'
  r'\bsave\(|getDownloadsDirectory|getApplication|\brun\(|Process\.',
);

/// Empty catches whose try body touches files or platform channels.
List<String> offenders() {
  final out = <String>[];
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    final lines = f.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].contains('catch (_) {}')) continue;
      // The try block: back to the closest line that opens it.
      var j = i;
      while (j > 0 && !RegExp(r'\btry \{').hasMatch(lines[j])) {
        j--;
      }
      final body = lines.sublist(j, i + 1).join('\n');
      if (_touches.hasMatch(body)) out.add('${f.path}:${i + 1}');
    }
  }
  return out;
}

void main() {
  test('C6: no silent catch around file or platform-channel work', () {
    expect(offenders(), isEmpty);
  });

  test(
    'C6: a failed cleanup is reported, not swallowed',
    skip: Platform.isWindows,
    () async {
      final seen = <String>[];
      errorSink = (what, e) => seen.add(what);
      addTearDown(() => errorSink = null);
      final dir = await Directory.systemTemp.createTemp('isekai_c6c');
      addTearDown(() => dir.delete(recursive: true));
      final store = ResumeStore(dir);
      await store.partFile('k').writeAsString('x');
      // A read-only folder: deleting the partial file fails.
      await Process.run('chmod', ['555', dir.path]);
      addTearDown(() => Process.run('chmod', ['755', dir.path]));
      await store.discard('k');
      expect(seen, contains('resume_delete'));
    },
  );
}
