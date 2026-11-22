// E1 (0.12.1): "Received text" dialog: the text, Copy, and - only when the
// whole text is one http/https link - "Open link". Never opened by itself.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../engine/transfer_engine.dart' show webLinkIn;
import 'file_actions.dart';
import 'theme/design_tokens.dart';

Future<void> showReceivedText(
  BuildContext context, {
  required String from,
  required String body,
  Future<bool> Function(Uri link)? openLink,
}) {
  final link = webLinkIn(body);
  final open = openLink ?? savedFileActions.openLink;
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text('Text from $from'),
      content: SingleChildScrollView(
        child: SelectableText(body, key: const ValueKey('received-text')),
      ),
      actions: [
        _CopyButton(body: body),
        if (link != null)
          TextButton.icon(
            style: TextButton.styleFrom(
              minimumSize: const Size(0, IdLayout.minTouchTarget),
            ),
            onPressed: () => open(link),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open link'),
          ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, IdLayout.minTouchTarget),
          ),
          onPressed: () => Navigator.pop(c),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Copy, then "Copied" on the button (works without a Scaffold).
class _CopyButton extends StatefulWidget {
  const _CopyButton({required this.body});
  final String body;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(
      minimumSize: const Size(0, IdLayout.minTouchTarget),
    ),
    onPressed: () async {
      await Clipboard.setData(ClipboardData(text: widget.body));
      if (mounted) setState(() => _copied = true);
    },
    icon: Icon(_copied ? Icons.check : Icons.copy),
    label: Text(_copied ? 'Copied' : 'Copy'),
  );
}
