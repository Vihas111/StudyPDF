import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:studypdf/core/utils/date_format.dart';
import 'package:studypdf/models/library_folder.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/workspace_shortcut.dart';

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

  @override
  void dispose() {
    _recentScrollController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final childFolders = _childFoldersOfSelection;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SizedBox(
            width: 260,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folders', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showCreateFolderDialog,
                        icon: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('New Folder'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      ListTile(
                        dense: true,
                        selected: widget.selectedFolderPath.isEmpty,
                        leading: const Icon(Icons.folder_outlined),
                        title: const Text('All Files'),
                        subtitle: const Text('Root'),
                        onTap: () => widget.onSelectFolder(''),
                      ),
                      ..._sortedFolders.map((folder) {
                        final selected =
                            folder.path == widget.selectedFolderPath;
                        final depth = _folderDepth(folder.path);
                        final name = folder.path.split(RegExp(r'[\\/]')).last;
                        return Padding(
                          padding: EdgeInsets.only(left: (depth - 1) * 14.0),
                          child: ListTile(
                            dense: true,
                            selected: selected,
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(name),
                            subtitle: Text(folder.path),
                            onTap: () => widget.onSelectFolder(folder.path),
                            trailing: IconButton(
                              tooltip: 'Delete folder',
                              onPressed: () =>
                                  _confirmDeleteFolder(folder.path),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(),
                Text(
                  'Library path:\n${widget.libraryRoot}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const VerticalDivider(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_workspaceSelectionMode)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Text('Select files for "${_workspaceName ?? ''}"'),
                        const SizedBox(width: 8),
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
                Row(
                  children: [
                    Text(
                      'Workspace Shortcuts',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 64,
                  child: widget.shortcuts.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text('No shortcuts yet.'),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: widget.shortcuts.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final shortcut = widget.shortcuts[index];
                            final color = shortcut.colorValue == null
                                ? null
                                : Color(shortcut.colorValue!);
                            return ActionChip(
                              avatar: Icon(
                                Icons.folder_copy_outlined,
                                color: color,
                              ),
                              label: Text(
                                '${shortcut.name} (${shortcut.tabPaths.length})',
                              ),
                              onPressed: () => widget.onOpenShortcut(shortcut),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 16),
                if (childFolders.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'Folders in ${widget.selectedFolderPath.isEmpty ? 'Root' : widget.selectedFolderPath}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: childFolders.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final folder = childFolders[index];
                        final name = folder.path.split(RegExp(r'[\\/]')).last;
                        return ActionChip(
                          avatar: const Icon(Icons.folder),
                          label: Text(name),
                          onPressed: () => widget.onSelectFolder(folder.path),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    Text(
                      'Recent Files',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: () =>
                          widget.onImportPdf(widget.selectedFolderPath),
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Add Local PDFs'),
                    ),
                    const SizedBox(width: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment<bool>(
                          value: true,
                          icon: Icon(Icons.grid_view),
                          label: Text('Grid'),
                        ),
                        ButtonSegment<bool>(
                          value: false,
                          icon: Icon(Icons.view_list),
                          label: Text('List'),
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
                ),
                const SizedBox(height: 12),
                Listener(
                  onPointerSignal: (event) {
                    if (event is PointerScrollEvent &&
                        _recentScrollController.hasClients) {
                      final next =
                          (_recentScrollController.offset +
                                  event.scrollDelta.dy)
                              .clamp(
                                _recentScrollController
                                    .position
                                    .minScrollExtent,
                                _recentScrollController
                                    .position
                                    .maxScrollExtent,
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
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final doc = widget.recentDocuments[index];
                        return _RecentDocCard(
                          doc: doc,
                          onOpen: () => widget.onOpenDocument(doc),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _gridView
                      ? GridView.builder(
                          itemCount: widget.documents.length,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                childAspectRatio: 1.5,
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                              ),
                          itemBuilder: (context, index) {
                            final doc = widget.documents[index];
                            return _DocumentCard(
                              doc: doc,
                              selectedForWorkspace: _workspaceDocIds.contains(
                                doc.id,
                              ),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final doc = widget.documents[index];
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onSecondaryTapDown: (_) {
                                _startWorkspaceCreationFromDocument(doc);
                              },
                              child: ListTile(
                                selected:
                                    _workspaceSelectionMode &&
                                    _workspaceDocIds.contains(doc.id),
                                tileColor:
                                    _workspaceSelectionMode &&
                                        _workspaceDocIds.contains(doc.id)
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHigh
                                    : (doc.tabColorValue == null
                                          ? null
                                          : Color(
                                              doc.tabColorValue!,
                                            ).withValues(alpha: 0.30)),
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
                                onTap: () => _workspaceSelectionMode
                                    ? _toggleWorkspaceDoc(doc.id)
                                    : widget.onOpenDocument(doc),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        child: ListTile(
          onTap: onOpen,
          title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('Last opened ${formatRelative(doc.lastOpened)}'),
          trailing: const Icon(Icons.open_in_new),
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onSecondaryTapDown: (_) {
        onShiftRightClick();
      },
      child: InkWell(
        onTap: onOpen,
        child: Card(
          color: selectionMode && selectedForWorkspace
              ? Theme.of(context).colorScheme.surfaceContainerHigh
              : (doc.tabColorValue == null
                    ? null
                    : Color(doc.tabColorValue!).withValues(alpha: 0.30)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      doc.folderPath.isEmpty ? 'Root' : doc.folderPath,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete file',
                      onPressed: onDelete,
                    ),
                  ],
                ),
                const Expanded(
                  child: Center(child: Icon(Icons.picture_as_pdf, size: 40)),
                ),
                Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: doc.progress),
                const SizedBox(height: 4),
                Text('Last opened ${formatRelative(doc.lastOpened)}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
