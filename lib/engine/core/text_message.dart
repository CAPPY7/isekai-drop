// E1 (0.12.1): a short text or link sent to a paired device.
// Wire: {"t":"text","v":1,"body":"..."} as the first message of a trusted
// session; the receiver answers {"t":"text_ok"} or {"t":"decline",...}.
// Apps older than 0.12.1 answer {"t":"error","reason":"unknown_message"}.
// The text is never logged and never stored in History.
import 'dart:convert';

/// Most bytes (UTF-8) one text may have.
const int kMaxTextBytes = 8 * 1024;

/// Why [body] cannot be sent ('empty', 'too_long'), or null when fine.
String? textBodyProblem(String body) {
  if (body.trim().isEmpty) return 'empty';
  if (utf8.encode(body).length > kMaxTextBytes) return 'too_long';
  return null;
}

/// The link when the WHOLE text (spaces around it ignored) is one plain
/// http or https link; null otherwise. Only then is "Open link" offered,
/// and links are never opened without a tap.
Uri? webLinkIn(String text) {
  final t = text.trim();
  if (t.isEmpty || t.contains(RegExp(r'\s'))) return null;
  final u = Uri.tryParse(t);
  if (u == null) return null;
  if (u.scheme != 'http' && u.scheme != 'https') return null;
  if (u.host.isEmpty) return null;
  return u;
}

class TextSendException implements Exception {
  const TextSendException(this.reason);

  /// 'empty', 'too_long', 'declined', 'old_peer', 'no_address',
  /// 'not_trusted', 'busy', or another short reason.
  final String reason;

  @override
  String toString() => 'TextSendException($reason)';
}

/// Plain words for the sender.
String explainTextError(String reason) => switch (reason) {
  'empty' => 'Type a text first.',
  'too_long' =>
    'The text is too long. Up to 8 KB (about 8000 letters) can be sent.',
  'declined' => 'The other device declined the text.',
  'old_peer' =>
    'The other device has an older Isekai Drop that cannot receive text. '
        'Update the other app.',
  'no_address' =>
    'The other device was not found. Make sure it is on the same network '
        'with Isekai Drop open.',
  'not_trusted' =>
    'The other device does not trust this device any more. Pair again.',
  'expired' => 'Nobody answered on the other device.',
  _ => 'The text could not be sent. Please try again.',
};
