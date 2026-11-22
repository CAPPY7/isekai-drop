// C6 (0.11.4): a TLS connection without a server certificate ends pairing
// with a plain message instead of a crash (was `s.peerCertificate!`).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isekaidrop/engine/core/engine.dart';

class _NoCertSocket implements SecureSocket {
  bool destroyed = false;
  @override
  X509Certificate? get peerCertificate => null;
  @override
  void destroy() => destroyed = true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('C6: no server certificate: PairingException, socket closed', () {
    final s = _NoCertSocket();
    expect(
      () => requirePeerCertificate(s),
      throwsA(
        isA<PairingException>().having(
          (e) => e.message,
          'message',
          contains('did not identify itself'),
        ),
      ),
    );
    expect(s.destroyed, isTrue);
  });
}
