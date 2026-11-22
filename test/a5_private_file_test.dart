// A5 (0.11.2): the key fallback file is created empty, set to mode 600,
// and only then gets the key.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/private_file.dart';
import 'package:path/path.dart' as p;

int perms(File f) => f.statSync().mode & 0x1FF;

void main() {
  test(
    'A5: on Linux the mode is 600 right after creation and after writing',
    () async {
      final dir = await Directory.systemTemp.createTemp('isekai_a5');
      addTearDown(() => dir.delete(recursive: true));
      final f = File(p.join(dir.path, 'sub', 'identity_fallback.json'));
      int? modeBeforeWrite;
      int? sizeBeforeWrite;
      await writePrivateFile(
        f,
        '{"key":"secret"}',
        afterCreate: (file) async {
          modeBeforeWrite = perms(file);
          sizeBeforeWrite = await file.length();
        },
      );
      expect(sizeBeforeWrite, 0, reason: 'empty when the mode is set');
      expect(modeBeforeWrite, 0x180, reason: '0600 before the key is written');
      expect(perms(f), 0x180);
      expect(await f.readAsString(), '{"key":"secret"}');
      // Overwriting an existing (too open) file makes it private first.
      await Process.run('chmod', ['644', f.path]);
      int? modeOnOverwrite;
      await writePrivateFile(
        f,
        'new',
        afterCreate: (file) async => modeOnOverwrite = perms(file),
      );
      expect(modeOnOverwrite, 0x180);
      expect(perms(f), 0x180);
      expect(await f.readAsString(), 'new');
    },
    skip: Platform.isWindows ? 'no file modes on Windows' : false,
  );

  test('A5: platform_engine writes the fallback with writePrivateFile', () {
    final src = File('lib/engine/platform_engine.dart').readAsStringSync();
    expect(src, contains('writePrivateFile(fallback'));
    expect(src.contains("fallback.writeAsString("), isFalse);
  });
}
