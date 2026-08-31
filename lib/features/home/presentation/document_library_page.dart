import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studypdf/core/native/window_constraints_channel.dart';
import 'package:studypdf/core/theme/design_tokens.dart';
import 'package:studypdf/core/utils/date_format.dart';
import 'package:studypdf/models/library_folder.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/workspace_shortcut.dart';
import 'package:studypdf/widgets/hover_surface.dart';

class DocumentLibraryPage extends StatefulWidget {
  const DocumentLibraryPage({
    super.key,
    required this.documents,
    required this.recentDocuments,
    required this.folders,
    required this.shortcuts,
    required this.selectedFolderPath,
    required this.libraryRoot,
    required this.onSelectFolder,
    required this.onCreateFolder,
    required this.onImportPdf,
    required this.onDeleteDocument,
    required this.onDeleteFolder,
    required this.onOpenDocument,
    required this.onOpenShortcut,
    required this.onDeleteShortcut,
    required this.onCreateWorkspaceFromDocuments,
  });

  final List<PdfDocument> documents;
  final List<PdfDocument> recentDocuments;
  final List<LibraryFolder> folders;
  final List<WorkspaceShortcut> shortcuts;
  final String selectedFolderPath;
  final String libraryRoot;
  final ValueChanged<String> onSelectFolder;
  final Future<void> Function(String name, String parentPath) onCreateFolder;
  final Future<void> Function(String targetFolderPath) onImportPdf;
  final Future<void> Function(PdfDocument document) onDeleteDocument;
  final Future<void> Function(String folderPath) onDeleteFolder;
  final ValueChanged<PdfDocument> onOpenDocument;
  final ValueChanged<WorkspaceShortcut> onOpenShortcut;
  final ValueChanged<WorkspaceShortcut> onDeleteShortcut;
  final Future<bool> Function(String name, List<PdfDocument> documents)
  onCreateWorkspaceFromDocuments;

  @override
  State<DocumentLibraryPage> createState() => _DocumentLibraryPageState();
}

class _DocumentLibraryPageState extends State<DocumentLibraryPage> {
  bool _gridView = true;
  final ScrollController _recentScrollController = ScrollController();
  bool _workspaceSelectionMode = false;
  String? _workspaceName;
  final Set<String> _workspaceDocIds = <String>{};

  double _folderPanelWidth = 272;
  bool _folderPanelCollapsed = false;
  static const double _minFolderPanelWidth = 200;
  static const double _maxFolderPanelWidth = 480;
  static const double _collapsedFolderPanelWidth = 48;

  @override
  void dispose() {
    _recentScrollController.dispose();
    // Don't leave the app's window stuck at a narrower minimum size than
    // usual after this page is torn down.
    WindowConstraintsChannel.setMinSize(
      WindowConstraintsChannel.defaultMinWidth,
      WindowConstraintsChannel.defaultMinHeight,
    );
    super.dispose();
  }

  void _setFolderPanelCollapsed(bool collapsed) {
    setState(() => _folderPanelCollapsed = collapsed);
    // Collapsing the folder panel removes most of the width pressure that
    // the app's minimum window size otherwise has to guard against, so
    // let the window go narrower while it's collapsed.
    WindowConstraintsChannel.setMinSize(
      collapsed
          ? WindowConstraintsChannel.collapsedFolderPanelMinWidth
          : WindowConstraintsChannel.defaultMinWidth,
      WindowConstraintsChannel.defaultMinHeight,
    );
  }

  Future<void> _showCreateFolderDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create Folder'),
          content: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
            decoration: const InputDecoration(
              labelText: 'Folder name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (result == null || result.isEmpty) {
      return;
    }

    await widget.onCreateFolder(result, widget.selectedFolderPath);
  }

  Future<void> _confirmDeleteFolder(String folderPath) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Folder'),
          content: const Text(
            'Delete this folder and all PDFs inside it from the project library?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      await widget.onDeleteFolder(folderPath);
    }
  }

  int _folderDepth(String path) {
    if (path.isEmpty) {
      return 0;
    }
    return path.split(RegExp(r'[\\/]')).length;
  }

  List<LibraryFolder> get _sortedFolders {
    final folders = widget.folders.where((f) => f.path.isNotEmpty).toList()
      ..sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return folders;
  }

  List<LibraryFolder> get _childFoldersOfSelection {
    final selected = widget.selectedFolderPath;
    final selectedDepth = _folderDepth(selected);
    return _sortedFolders
        .where((folder) {
          if (selected.isEmpty) {
            return _folderDepth(folder.path) == 1;
          }
          final normalized = folder.path.replaceAll('\\', '/');
          final prefix = '${selected.replaceAll('\\', '/')}/';
          return normalized.startsWith(prefix) &&
              _folderDepth(folder.path) == selectedDepth + 1;
        })
        .toList(growable: false);
  }

  Future<void> _startWorkspaceCreationFromDocument(PdfDocument doc) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Workspace'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          decoration: const InputDecoration(
            labelText: 'Workspace name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) {
      return;
    }

    setState(() {
      _workspaceSelectionMode = true;
      _workspaceName = name;
      _workspaceDocIds
        ..clear()
        ..add(doc.id);
    });
  }

  void _toggleWorkspaceDoc(String docId) {
    setState(() {
      if (_workspaceDocIds.contains(docId)) {
        _workspaceDocIds.remove(docId);
      } else {
        _workspaceDocIds.add(docId);
      }
    });
  }

  void _cancelWorkspaceSelection() {
    setState(() {
      _workspaceSelectionMode = false;
      _workspaceName = null;
      _workspaceDocIds.clear();
    });
  }

  Future<void> _finishWorkspaceSelection() async {
    if (_workspaceName == null || _workspaceDocIds.length < 2) {
      _cancelWorkspaceSelection();
      return;
    }

    final map = <String, PdfDocument>{
      for (final d in widget.documents) d.id: d,
    };
    final docs = _workspaceDocIds
        .map((id) => map[id])
        .whereType<PdfDocument>()
        .toList(growable: false);
    if (docs.length < 2) {
      _cancelWorkspaceSelection();
      return;
    }
    final created = await widget.onCreateWorkspaceFromDocuments(
      _workspaceName!,
      docs,
    );
    if (created && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Workspace "${_workspaceName!}" created')),
      );
    }
    if (created) {
      _cancelWorkspaceSelection();
    }
  }

  Widget _sectionHeader(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  @override
  Widget build(BuildContext context) {
    final childFolders = _childFoldersOfSelection;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _folderPanelCollapsed
                ? _collapsedFolderPanelWidth
                : _folderPanelWidth,
            child: _folderPanelCollapsed
                ? _buildCollapsedFolderPanel(context)
                : _buildFolderPanel(context),
          ),
          if (!_folderPanelCollapsed)
            MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _folderPanelWidth = (_folderPanelWidth + details.delta.dx)
                        .clamp(_minFolderPanelWidth, _maxFolderPanelWidth);
                  });
                },
                child: const SizedBox(
                  width: AppSpacing.md,
                  child: Center(
                    child: VerticalDivider(width: 1, thickness: 1),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_workspaceSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Card(
                      elevation: AppElevation.low,
                      color: theme.colorScheme.secondaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadii.md),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg,
                          vertical: AppSpacing.sm,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Select files for "${_workspaceName ?? ''}"',
                                style: theme.textTheme.bodyMedium,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            TextButton(
                              onPressed: _cancelWorkspaceSelection,
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: _finishWorkspaceSelection,
                              child: const Text('Create Workspace'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                _sectionHeader(context, 'Workspace Shortcuts'),
                const SizedBox(height: AppSpacing.sm),
                _buildShortcutsRow(context),
                if (childFolders.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  _sectionHeader(
                    context,
                    'Folders in ${widget.selectedFolderPath.isEmpty ? 'Root' : widget.selectedFolderPath}',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildChildFoldersRow(context, childFolders),
                ],
                const SizedBox(height: AppSpacing.lg),
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Below this, even a single-line label button doesn't
                    // reliably fit — drop to icon-only (with tooltips) so
                    // there's nothing left to overflow.
                    final iconOnly = constraints.maxWidth < 260;
                    final title = Text(
                      'Recent Files',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    );
                    final actions = Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        iconOnly
                            ? Tooltip(
                                message: 'Add Local PDFs',
                                child: IconButton.filled(
                                  onPressed: () => widget.onImportPdf(
                                    widget.selectedFolderPath,
                                  ),
                                  icon: const Icon(Icons.upload_file),
                                ),
                              )
                            : FilledButton.icon(
                                onPressed: () => widget.onImportPdf(
                                  widget.selectedFolderPath,
                                ),
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Add Local PDFs'),
                              ),
                        SegmentedButton<bool>(
                          segments: [
                            ButtonSegment<bool>(
                              value: true,
                              icon: const Icon(Icons.grid_view),
                              label: iconOnly ? null : const Text('Grid'),
                            ),
                            ButtonSegment<bool>(
                              value: false,
                              icon: const Icon(Icons.view_list),
                              label: iconOnly ? null : const Text('List'),
                            ),
                          ],
                          selected: {_gridView},
                          onSelectionChanged: (selection) {
                            setState(() {
                              _gridView = selection.first;
                            });
                          },
                        ),
                      ],
                    );
                    // Below a certain width the title + buttons no longer
                    // fit on one line (this is what was overflowing when
                    // the window wasn't maximized) — stack them instead.
                    if (constraints.maxWidth < 560) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          title,
                          const SizedBox(height: AppSpacing.sm),
                          actions,
                        ],
                      );
                    }
                    return Row(
                      children: [title, const Spacer(), actions],
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _buildRecentFilesRow(context),
                const SizedBox(height: AppSpacing.lg),
                _buildDocumentsArea(context),
              ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedFolderPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Column(
          children: [
            Tooltip(
              message: 'Expand folders panel',
              child: HoverSurface(
                onTap: () => _setFolderPanelCollapsed(false),
                padding: const EdgeInsets.all(AppSpacing.xs),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                child: Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Icon(
              Icons.folder_outlined,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Folders',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Collapse folders panel',
                  child: HoverSurface(
                    onTap: () => _setFolderPanelCollapsed(true),
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: const Icon(Icons.chevron_left, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            HoverSurface(
              onTap: _showCreateFolderDialog,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              color: theme.colorScheme.primaryContainer.withValues(
                alpha: 0.35,
              ),
              hoverColor: theme.colorScheme.primaryContainer.withValues(
                alpha: 0.6,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.create_new_folder_outlined,
                    size: 18,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'New Folder',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: ListView(
                children: [
                  _FolderRow(
                    icon: Icons.folder_outlined,
                    title: 'All Files',
                    subtitle: 'Root',
                    selected: widget.selectedFolderPath.isEmpty,
                    onTap: () => widget.onSelectFolder(''),
                  ),
                  ..._sortedFolders.map((folder) {
                    final selected = folder.path == widget.selectedFolderPath;
                    final depth = _folderDepth(folder.path);
                    final name = folder.path.split(RegExp(r'[\\/]')).last;
                    return Padding(
                      padding: EdgeInsets.only(left: (depth - 1) * 14.0),
                      child: _FolderRow(
                        icon: Icons.folder_outlined,
                        title: name,
                        subtitle: folder.path,
                        selected: selected,
                        onTap: () => widget.onSelectFolder(folder.path),
                        onDelete: () => _confirmDeleteFolder(folder.path),
                      ),
                    );
                  }),
                ],
              ),
            ),
            const Divider(height: AppSpacing.lg),
            Text(
              'Library path:\n${widget.libraryRoot}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsRow(BuildContext context) {
    if (widget.shortcuts.isEmpty) {
      return _EmptyStateStrip(
        icon: Icons.bookmark_border,
        message: 'No workspace shortcuts yet.',
      );
    }
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: widget.shortcuts.map((shortcut) {
        final color = shortcut.colorValue == null
            ? null
            : Color(shortcut.colorValue!);
        return _ShortcutChip(
          icon: Icons.folder_copy_outlined,
          iconColor: color,
          label: '${shortcut.name} (${shortcut.tabPaths.length})',
          onTap: () => widget.onOpenShortcut(shortcut),
          onDelete: () => _confirmDeleteShortcut(context, shortcut),
        );
      }).toList(growable: false),
    );
  }

  Future<void> _confirmDeleteShortcut(
    BuildContext context,
    WorkspaceShortcut shortcut,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove workspace shortcut?'),
        content: Text(
          'This removes the "${shortcut.name}" shortcut from Home. '
          'It does not delete any files.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.onDeleteShortcut(shortcut);
    }
  }

  Widget _buildChildFoldersRow(
    BuildContext context,
    List<LibraryFolder> childFolders,
  ) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: childFolders.map((folder) {
        final name = folder.path.split(RegExp(r'[\\/]')).last;
        return _ShortcutChip(
          icon: Icons.folder,
          label: name,
          onTap: () => widget.onSelectFolder(folder.path),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildRecentFilesRow(BuildContext context) {
    if (widget.recentDocuments.isEmpty) {
      return const _EmptyStateStrip(
        icon: Icons.history,
        message: 'No recent files yet — open a PDF to see it here.',
        height: 110,
      );
    }
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            _recentScrollController.hasClients) {
          final next =
              (_recentScrollController.offset + event.scrollDelta.dy).clamp(
                _recentScrollController.position.minScrollExtent,
                _recentScrollController.position.maxScrollExtent,
              );
          _recentScrollController.jumpTo(next);
        }
      },
      child: SizedBox(
        height: 110,
        child: ListView.separated(
          controller: _recentScrollController,
          scrollDirection: Axis.horizontal,
          itemCount: widget.recentDocuments.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (context, index) {
            final doc = widget.recentDocuments[index];
            return _RecentDocCard(
              doc: doc,
              onOpen: () => widget.onOpenDocument(doc),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDocumentsArea(BuildContext context) {
    if (widget.documents.isEmpty) {
      return const _EmptyStateStrip(
        icon: Icons.picture_as_pdf_outlined,
        message: 'No documents in this folder yet.\nAdd a local PDF to get started.',
        expand: true,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = (constraints.maxWidth / 260)
            .floor()
            .clamp(1, 6);
        return _gridView
            ? GridView.builder(
                itemCount: widget.documents.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: 1.5,
                  crossAxisSpacing: AppSpacing.md,
                  mainAxisSpacing: AppSpacing.md,
                ),
                itemBuilder: (context, index) {
                  final doc = widget.documents[index];
                  return _DocumentCard(
                    doc: doc,
                    selectedForWorkspace: _workspaceDocIds.contains(doc.id),
                    selectionMode: _workspaceSelectionMode,
                    onOpen: () => _workspaceSelectionMode
                        ? _toggleWorkspaceDoc(doc.id)
                        : widget.onOpenDocument(doc),
                    onDelete: () => widget.onDeleteDocument(doc),
                    onShiftRightClick: () =>
                        _startWorkspaceCreationFromDocument(doc),
                  );
                },
              )
            : ListView.separated(
                itemCount: widget.documents.length,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final doc = widget.documents[index];
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onSecondaryTapDown: (_) {
                      _startWorkspaceCreationFromDocument(doc);
                    },
                    child: HoverSurface(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      color:
                          _workspaceSelectionMode &&
                              _workspaceDocIds.contains(doc.id)
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : (doc.tabColorValue == null
                                ? null
                                : Color(
                                    doc.tabColorValue!,
                                  ).withValues(alpha: 0.30)),
                      onTap: () => _workspaceSelectionMode
                          ? _toggleWorkspaceDoc(doc.id)
                          : widget.onOpenDocument(doc),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf),
                        title: Text(doc.title),
                        subtitle: Text(
                          'Folder: ${doc.folderPath.isEmpty ? 'Root' : doc.folderPath}\n'
                          'Last opened ${formatRelative(doc.lastOpened)}',
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Delete file',
                          onPressed: () => widget.onDeleteDocument(doc),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    ),
                  );
                },
              );
      },
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.onDelete,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: HoverSurface(
        onTap: onTap,
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : null,
        hoverColor: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.6)
            : theme.colorScheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (onDelete != null)
              Tooltip(
                message: 'Delete folder',
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  const _ShortcutChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.onDelete,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return HoverSurface(
      onTap: onTap,
      color: theme.colorScheme.surfaceContainerHigh,
      hoverColor: theme.colorScheme.surfaceContainerHighest,
      elevation: AppElevation.low,
      hoverElevation: AppElevation.medium,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: theme.textTheme.bodyMedium),
          if (onDelete != null) ...[
            const SizedBox(width: AppSpacing.sm),
            Tooltip(
              message: 'Remove shortcut',
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onDelete,
                  behavior: HitTestBehavior.opaque,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyStateStrip extends StatelessWidget {
  const _EmptyStateStrip({
    required this.icon,
    required this.message,
    this.height = 64,
    this.expand = false,
  });

  final IconData icon;
  final String message;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      width: double.infinity,
      constraints: expand ? null : BoxConstraints(minHeight: height),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.5,
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          style: BorderStyle.solid,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 28,
              color: theme.colorScheme.onSurfaceVariant.withValues(
                alpha: 0.7,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? Center(child: content) : content;
  }
}

class _RecentDocCard extends StatelessWidget {
  const _RecentDocCard({required this.doc, required this.onOpen});

  final PdfDocument doc;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        elevation: AppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        child: HoverSurface(
          onTap: onOpen,
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: ListTile(
            title: Text(
              doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('Last opened ${formatRelative(doc.lastOpened)}'),
            trailing: const Icon(Icons.open_in_new),
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.doc,
    required this.onOpen,
    required this.onDelete,
    required this.onShiftRightClick,
    required this.selectionMode,
    required this.selectedForWorkspace,
  });

  final PdfDocument doc;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onShiftRightClick;
  final bool selectionMode;
  final bool selectedForWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (_) {
        onShiftRightClick();
      },
      child: Card(
        elevation: AppElevation.low,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        color: selectionMode && selectedForWorkspace
            ? theme.colorScheme.surfaceContainerHigh
            : (doc.tabColorValue == null
                  ? null
                  : Color(doc.tabColorValue!).withValues(alpha: 0.30)),
        child: HoverSurface(
          onTap: onOpen,
          padding: EdgeInsets.zero,
          borderRadius: BorderRadius.circular(AppRadii.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      doc.folderPath.isEmpty ? 'Root' : doc.folderPath,
                      style: theme.textTheme.labelSmall,
                    ),
                    const Spacer(),
                    Tooltip(
                      message: 'Delete file',
                      child: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                      ),
                    ),
                  ],
                ),
                const Expanded(
                  child: Center(child: Icon(Icons.picture_as_pdf, size: 40)),
                ),
                Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(value: doc.progress),
                const SizedBox(height: AppSpacing.xs),
                Text('Last opened ${formatRelative(doc.lastOpened)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
