import 'dart:convert';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

/// This installation's cryptographic identity: an ECDSA P-256 key pair and a
/// self-signed X.509 certificate, used for mutual TLS. Other devices pin the
/// SHA-256 fingerprint of this certificate. Key generation and certificate
/// creation use the maintained basic_utils/pointycastle libraries; TLS itself
/// is the platform's BoringSSL via dart:io. No home-made cryptography.
class Identity {
  Identity({
    required this.deviceId,
    required this.certPem,
    required this.keyPem,
    required this.createdAt,
  });

  final String deviceId;
  final String certPem;
  final String keyPem;
  final DateTime createdAt;

  late final String fingerprint = fingerprintOfCertPem(certPem);

  /// 0.11.2: made before 0.11.2 with the subject every device shared.
  /// Such a certificate must be replaced (see [generate]).
  bool get hasSharedSubject => !certSubjectIsUnique(certPem);

  /// Same device id, new key and certificate with a unique subject.
  Identity renewed() => Identity.generate(deviceId: deviceId);

  Map<String, Object?> toJson() => {
    'v': 1,
    'device_id': deviceId,
    'cert_pem': certPem,
    'key_pem': keyPem,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory Identity.fromJson(Map<String, dynamic> j) => Identity(
    deviceId: j['device_id'] as String,
    certPem: j['cert_pem'] as String,
    keyPem: j['key_pem'] as String,
    createdAt: DateTime.parse(j['created_at'] as String),
  );

  /// Creates a brand-new identity. Certificate valid for about 10 years.
  ///
  /// 0.9.1: "valid from" is set 2 days in the past. With "now", a phone
  /// whose clock was a little behind refused the certificate of a freshly
  /// installed peer (not yet valid) - pairing worked, sending did not.
  ///
  /// 0.11.2: the subject is unique per device (`Isekai Drop <device id>`).
  /// Up to 0.11.1 every device had the same subject, "Isekai Drop device".
  /// TLS (BoringSSL) finds a self-signed client certificate among the
  /// trusted ones BY SUBJECT and needs an exact match, so a device that
  /// trusted two others accepted only one of them: phone to phone failed
  /// as soon as a phone also trusted a PC ("refused this device's key").
  static Identity generate({
    String? deviceId,
    DateTime? notBefore,
    // Tests only: make a pre-0.11.2 certificate (shared subject).
    bool legacySubject = false,
  }) {
    final id = deviceId ?? randomHex(16);
    final pair = CryptoUtils.generateEcKeyPair(curve: 'prime256v1');
    final priv = pair.privateKey as ECPrivateKey;
    final pub = pair.publicKey as ECPublicKey;
    final csr = X509Utils.generateEccCsrPem(
      legacySubject
          ? {'CN': 'Isekai Drop device'}
          : {'CN': '$kSubjectPrefix$id', 'O': 'Isekai Drop'},
      priv,
      pub,
    );
    final cert = X509Utils.generateSelfSignedCertificate(
      priv,
      csr,
      3652,
      notBefore:
          notBefore ?? DateTime.now().toUtc().subtract(const Duration(days: 2)),
    );
    return Identity(
      deviceId: id,
      certPem: cert,
      keyPem: CryptoUtils.encodeEcPrivateKeyToPem(priv),
      createdAt: DateTime.now().toUtc(),
    );
  }
}

/// Start of the certificate subject (CN) since 0.11.2.
const kSubjectPrefix = 'Isekai Drop ';

/// True if the certificate's CN is the per-device one from 0.11.2.
bool certSubjectIsUnique(String certPem) {
  try {
    final c = X509Utils.x509CertificateFromPem(certPem);
    final cn = c.tbsCertificate?.subject['2.5.4.3'] ?? '';
    return cn.startsWith(kSubjectPrefix) && cn != 'Isekai Drop device';
  } catch (_) {
    return false;
  }
}

String randomHex(int bytes) {
  final r = Random.secure();
  return List.generate(
    bytes,
    (_) => r.nextInt(256),
  ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

List<int> pemToDer(String pem) {
  final body = pem
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('-----'))
      .join();
  return base64Decode(body);
}

String derToPem(List<int> der) {
  final b64 = base64Encode(der);
  final lines = <String>[];
  for (var i = 0; i < b64.length; i += 64) {
    lines.add(b64.substring(i, min(i + 64, b64.length)));
  }
  return '-----BEGIN CERTIFICATE-----\n${lines.join('\n')}\n-----END CERTIFICATE-----\n';
}

/// SHA-256 of the certificate (DER), as lowercase hex.
String fingerprintOfDer(List<int> der) => sha256.convert(der).toString();

String fingerprintOfCertPem(String pem) => fingerprintOfDer(pemToDer(pem));

/// Short, readable form of a fingerprint for display (first 16 hex chars).
String shortFingerprint(String fp) {
  final s = fp.substring(0, 16).toUpperCase();
  return [for (var i = 0; i < 16; i += 4) s.substring(i, i + 4)].join(' ');
}

/// Pairing verification code shown on BOTH screens. It is derived from both
/// devices' certificate fingerprints as seen inside the TLS connection, so a
/// device in the middle would cause the two screens to show different codes.
/// 16 digits (about 53 bits) so it cannot practically be forced to match.
String verificationCode(String fingerprintA, String fingerprintB) {
  final pair = [fingerprintA, fingerprintB]..sort();
  final h = sha256
      .convert(utf8.encode('isekai-drop-pairing-v1|${pair[0]}|${pair[1]}'))
      .bytes;
  var v = BigInt.zero;
  for (var i = 0; i < 8; i++) {
    v = (v << 8) | BigInt.from(h[i]);
  }
  final s = (v % BigInt.from(10).pow(16)).toString().padLeft(16, '0');
  return [for (var i = 0; i < 16; i += 4) s.substring(i, i + 4)].join(' ');
}
