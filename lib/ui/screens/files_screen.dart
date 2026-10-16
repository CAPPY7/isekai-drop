import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';

import '../../engine/models.dart';
import '../theme/design_tokens.dart';
import '../widgets/common.dart';
import 'transfer_screen.dart';

/// One file the user picked. Only name and size are kept (no contents).
class SelectedFile {
  SelectedFile({required this.name, required this.size, this.path});

  final String name;
  final int size;
  final String? path;
}

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key, required this.isDesktop});

  final bool isDesktop;

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  final List<SelectedFile> _files = [];
  bool _picking = false;
  bool _dragging = false;
  String? _error;

  int get _total => _files.fold(0, (a, f) => a + f.size);

  Future<void> _pick() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      // System file picker, multi-select. Only names and sizes are read.
      final result = await openFiles();
      final added = <SelectedFile>[];
      for (final f in result) {
        added.add(
          SelectedFile(name: f.name, size: await f.length(), path: f.path),
        );
      }
      if (added.isNotEmpty) setState(() => _files.addAll(added));
    } catch (_) {
      setState(
        () => _error = 'The file picker could not open. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _onDrop(DropDoneDetails details) async {
    final added = <SelectedFile>[];
    for (final f in details.files) {
      try {
        added.add(
          SelectedFile(name: f.name, size: await f.length(), path: f.path),
        );
      } catch (_) {
        // Folders or unreadable items are skipped.
      }
    }
    setState(() {
      _dragging = false;
      _files.addAll(added);
      if (added.length < details.files.length) {
        _error = 'Some dropped items were skipped (folders arrive in a later phase).';
      }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pickArea = Column(
      children: [
        Icon(
          widget.isDesktop
              ? Icons.file_download_outlined
              : Icons.add_circle_outline,
          size: 48,
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
        const SizedBox(height: IdSpacing.xs),
        Text(
          'Photos, videos and documents. Folders arrive in a later phase.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );

    return PageBody(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(IdSpacing.lg),
            child: widget.isDesktop
                ? DropTarget(
                    onDragEntered: (_) => setState(() => _dragging = true),
                    onDragExited: (_) => setState(() => _dragging = false),
                    onDragDone: _onDrop,
                    child: AnimatedContainer(
                      duration: IdMotion.fast,
                      padding: const EdgeInsets.all(IdSpacing.lg),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(IdRadii.md),
                        border: Border.all(
                          color: _dragging
                              ? IdColors.accentPurple
                              : IdColors.darkOnSurfaceMuted,
                          width: _dragging ? 3 : 1,
                        ),
                      ),
                      child: pickArea,
                    ),
                  )
                : pickArea,
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: IdSpacing.sm),
            child: Text(
              _error!,
              style: const TextStyle(color: IdColors.danger),
            ),
          ),
        SectionCard(
          title: 'Selected: ${_files.length} file(s), ${formatBytes(_total)}',
          trailing: _files.isEmpty
              ? null
              : TextButton(
                  onPressed: _confirmClear,
                  child: const Text('Clear'),
                ),
          child: _files.isEmpty
              ? const StateMessage(
                  icon: Icons.inbox_outlined,
                  title: 'Nothing selected yet',
                  message: 'Tap "Pick files" to choose what to send.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < _files.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: IdLayout.minTouchTarget,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          _files[i].name,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(formatBytes(_files[i].size)),
                        trailing: IconButton(
                          tooltip: 'Remove ${_files[i].name} from list',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _files.removeAt(i)),
                        ),
                      ),
                  ],
                ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(IdLayout.minTouchTarget),
          ),
          onPressed: _files.isEmpty
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => TransferScreen(
                      fileCount: _files.length,
                      totalBytes: _total,
                    ),
                  ),
                ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Preview sending screen (DEMO)'),
        ),
        const SizedBox(height: IdSpacing.xs),
        Text(
          'Nothing is sent yet. This only shows how the sending screen will look.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
