import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../engine/platform_engine.dart';
import '../../engine/transfer_engine.dart';
import '../app_scope.dart';
import '../pairing_flow.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import '../widgets/discovery_hint.dart';
import 'transfer_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({
    super.key,
    required this.isDesktop,
    this.initialFiles = const [],
  });

  final bool isDesktop;

  /// Files already in step 1 (tests; the pickers need a real platform).
  @visibleForTesting
  final List<SendSource> initialFiles;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final List<SendSource> _files = [];
  bool _picking = false;
  bool _dragging = false;
  String? _error;
  String? _targetId;

  int get _total => _files.fold(0, (a, f) => a + f.size);

  @override
  void initState() {
    super.initState();
    _files.addAll(widget.initialFiles);
  }

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await pickFilesToSend();
      setState(() => _files.addAll(picked));
    } catch (_) {
      setState(
        () => _error = 'The file picker could not open. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _pickFolder() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await pickFolderToSend();
      setState(() {
        _files.addAll(picked);
        if (picked.isEmpty) _error = null;
      });
    } catch (_) {
      setState(
        () => _error =
            'The folder could not be opened here. Try picking files instead.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    final added = <SendSource>[];
    var skipped = 0;
    for (final f in details.files) {
      try {
        added.addAll(await sendSourcesFromPath(f.path));
      } catch (_) {
        skipped++;
      }
    }
    setState(() {
      _dragging = false;
      _files.addAll(added);
      if (skipped > 0) _error = '$skipped dropped item(s) could not be read.';
    });
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Clear selection?'),
        content: const Text(
          'This removes all files from the list. Your files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) setState(_files.clear);
  }

  /// 0.9.1: send to a nearby device that is not paired yet. It gets one
  /// question ("NAME wants to send you N files - Accept?").
  Future<void> _sendNearby(NearbyDevice n) async {
    final job = await sendToNearbyFlow(context, n, List.of(_files));
    if (job == null || !mounted) return;
    setState(_files.clear);
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => TransferScreen(job: job)));
  }

  Future<void> _send(TrustedDevice dev) async {
    final engine = AppScope.of(context).engine;
    NearbyDevice? live;
    for (final n in engine.nearby) {
      // Skip announcements whose key does not match (possible spoofing).
      if (n.trusted?.id == dev.id && !n.fingerprintMismatch) live = n;
    }
    final job = await engine.send(
      dev,
      List.of(_files),
      host: live?.host,
      port: live?.port,
    );
    if (!mounted) return;
    setState(_files.clear);
    if (job.queued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Added to the queue. It starts when the current send finishes.',
          ),
        ),
      );
    }
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => TransferScreen(job: job)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final engine = AppScope.of(context).engine;
    final pickArea = Column(
      children: [
        Icon(
          widget.isDesktop
              ? Icons.file_download_outlined
              : Icons.add_circle_outline,
          size: 36,
          color: IdColors.accentGlow,
        ),
        const SizedBox(height: IdSpacing.sm),
        Text(
          widget.isDesktop ? 'Drag files here, or' : 'Choose files to send',
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: IdSpacing.sm),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(200, IdLayout.minTouchTarget),
          ),
          onPressed: _picking ? null : _pick,
          icon: _picking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.folder_open),
          label: Text(_picking ? 'Opening...' : 'Pick files'),
        ),
        const SizedBox(height: IdSpacing.sm),
        if (canPickFolder)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(200, IdLayout.minTouchTarget),
            ),
            onPressed: _picking ? null : _pickFolder,
            icon: const Icon(Icons.create_new_folder_outlined),
            label: const Text('Pick a folder'),
          ),
        const SizedBox(height: IdSpacing.xs),
        Text(
          canPickFolder
              ? 'Files of any type, or a whole folder (its sub-folders are kept).'
              : 'Files of any type. Folders cannot be picked on iPhone/iPad yet - '
                    'pick the files inside instead.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) {
        final targets = engine.trustedDevices
            .where((d) => d.isTrusted)
            .toList();
        // Nearby devices that are not paired: one tap sends, the other
        // device answers one question (and both are paired after that).
        final unpaired = [
          for (final n in engine.nearby)
            if (n.trusted == null || !n.trusted!.isTrusted) n,
        ];
        final ids = [
          for (final d in targets) d.id,
          for (final n in unpaired) 'nearby:${n.deviceId}',
        ];
        if (_targetId != null && !ids.contains(_targetId)) {
          _targetId = null;
        }
        _targetId ??= ids.isEmpty ? null : ids.first;
        TrustedDevice? target;
        for (final d in targets) {
          if (d.id == _targetId) target = d;
        }
        NearbyDevice? nearbyTarget;
        for (final n in unpaired) {
          if ('nearby:${n.deviceId}' == _targetId) nearbyTarget = n;
        }
        final targetName = target?.name ?? nearbyTarget?.name;
        final pickCard = widget.isDesktop
            ? DropTarget(
                onDragEntered: (_) => setState(() => _dragging = true),
                onDragExited: (_) => setState(() => _dragging = false),
                onDragDone: _onDrop,
                child: AnimatedContainer(
                  duration: IdMotion.fast,
                  padding: const EdgeInsets.all(IdSpacing.md),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(IdRadii.md),
                    border: Border.all(
                      color: _dragging
                          ? IdColors.accentPurple
                          : theme.colorScheme.outline,
                      width: _dragging ? 3 : 1,
                    ),
                  ),
                  child: pickArea,
                ),
              )
            : pickArea;
        final ready = _files.isNotEmpty && targetName != null;
        final sendButton = FilledButton.icon(
          key: const ValueKey('send-button'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
          ),
          onPressed: !ready
              ? null
              : () {
                  // Spec D22: a light tap when the send starts.
                  HapticFeedback.lightImpact();
                  target != null ? _send(target) : _sendNearby(nearbyTarget!);
                },
          icon: const Icon(Icons.send_rounded),
          label: Text(
            targetName == null
                ? 'Send'
                : _files.isEmpty
                ? 'Send to $targetName'
                : 'Send ${_files.length} file(s) to $targetName',
            overflow: TextOverflow.ellipsis,
          ),
        );
        // 0.11.0: three steps. The list scrolls; step 3 (Send) sits right
        // under it and stays pinned at the bottom when the list is long.
        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: IdLayout.maxContentWidth,
            ),
            child: Padding(
              padding: const EdgeInsets.all(IdSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        SectionCard(
                          title: _files.isEmpty
                              ? '1. Pick files'
                              : '1. Files: ${_files.length}, ${formatBytes(_total)}',
                          trailing: _files.isEmpty
                              ? null
                              : TextButton(
                                  onPressed: _confirmClear,
                                  child: const Text('Clear'),
                                ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              pickCard,
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: IdSpacing.sm,
                                  ),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                                ),
                              for (var i = 0; i < _files.length && i < 100; i++)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  minTileHeight: IdLayout.minTouchTarget,
                                  leading: const Icon(
                                    Icons.insert_drive_file_outlined,
                                  ),
                                  title: Text(
                                    _files[i].relativePath,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(formatBytes(_files[i].size)),
                                  trailing: IconButton(
                                    tooltip:
                                        'Remove ${_files[i].name} from list',
                                    icon: const Icon(Icons.close),
                                    onPressed: () =>
                                        setState(() => _files.removeAt(i)),
                                  ),
                                ),
                              if (_files.length > 100)
                                Text('...and ${_files.length - 100} more'),
                            ],
                          ),
                        ),
                        SectionCard(
                          title: '2. Pick a device',
                          child: ids.isEmpty
                              ? DiscoveryHint(engine: engine)
                              : DropdownButton<String>(
                                  isExpanded: true,
                                  value: _targetId,
                                  items: [
                                    for (final d in targets)
                                      DropdownMenuItem(
                                        value: d.id,
                                        child: Text(
                                          engine.nearby.any(
                                                (n) => n.trusted?.id == d.id,
                                              )
                                              ? '${d.name}  (nearby)'
                                              : d.name,
                                        ),
                                      ),
                                    for (final n in unpaired)
                                      DropdownMenuItem(
                                        value: 'nearby:${n.deviceId}',
                                        child: Text(
                                          '${n.name}  (nearby, asks once to accept)',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _targetId = v),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: IdSpacing.sm),
                  sendButton,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
