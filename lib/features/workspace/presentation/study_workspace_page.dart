import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:studypdf/core/ai/ai_provider.dart';
import 'package:studypdf/features/ai_assistant/presentation/ai_assistant_panel.dart';
import 'package:studypdf/features/notes/presentation/page_notes_panel.dart';
import 'package:studypdf/features/pdf_viewer/presentation/pdf_viewer_panel.dart';
import 'package:studypdf/features/tabs/presentation/tab_strip.dart';
import 'package:studypdf/models/annotation.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/pdf_viewport_data.dart';
import 'package:studypdf/models/tab_group.dart';
import 'package:studypdf/models/workspace_preferences.dart';
import 'package:studypdf/models/workspace_shortcut.dart';
import 'package:studypdf/widgets/floating_panel_window.dart';

enum _PanelMode { docked, inAppPopup, nativePopup }

class StudyWorkspacePage extends StatefulWidget {
  const StudyWorkspacePage({
    super.key,
    required this.openTabs,
    required this.activeTabId,
    required this.activeDocument,
    required this.viewportData,
    required this.pageAnnotations,
    required this.assistantOutput,
    required this.providers,
    required this.onTabSelected,
    required this.onCloseTab,
    required this.onTabColorChanged,
    required this.onViewportChanged,
    required this.onRunPrompt,
    required this.onSaveNote,
    required this.onOpenExternalAiWindow,
    required this.onOpenExternalNotesWindow,
    required this.notesOrientation,
    required this.defaultAiVisible,
    required this.defaultNotesVisible,
    required this.defaultAiProviderId,
    required this.onCreateHomeShortcut,
    required this.onDeleteHomeShortcutByName,
    required this.onRenameHomeShortcutByName,
    required this.onSyncHomeShortcutByName,
    required this.shortcutLaunchRequest,
    required this.onShortcutLaunchConsumed,
  });

  final List<PdfDocument> openTabs;
  final String? activeTabId;
  final PdfDocument? activeDocument;
  final PdfViewportData viewportData;
  final List<Annotation> pageAnnotations;
  final String assistantOutput;
  final List<AIProvider> providers;
  final ValueChanged<String> onTabSelected;
  final ValueChanged<String> onCloseTab;
  final Future<void> Function(String tabId, int? colorValue) onTabColorChanged;
  final ValueChanged<PdfViewportData> onViewportChanged;
  final Future<String> Function({
    required String providerId,
    required String prompt,
  })
  onRunPrompt;
  final ValueChanged<String> onSaveNote;
  final Future<void> Function() onOpenExternalAiWindow;
  final Future<void> Function() onOpenExternalNotesWindow;
  final NotesDockOrientation notesOrientation;
  final bool defaultAiVisible;
  final bool defaultNotesVisible;
  final String defaultAiProviderId;
  final Future<bool> Function({
    required String name,
    required List<String> tabIds,
    int? colorValue,
  })
  onCreateHomeShortcut;
  final Future<void> Function(String name) onDeleteHomeShortcutByName;
  final Future<bool> Function(String oldName, String newName)
  onRenameHomeShortcutByName;
  final Future<void> Function({
    required String name,
    required List<String> tabIds,
    int? colorValue,
  })
  onSyncHomeShortcutByName;
  final ShortcutLaunchRequest? shortcutLaunchRequest;
  final ValueChanged<int> onShortcutLaunchConsumed;

  @override
  State<StudyWorkspacePage> createState() => _StudyWorkspacePageState();
}

class _StudyWorkspacePageState extends State<StudyWorkspacePage> {
  double _leftPanelRatio = 0.64;
  double _topPanelRatio = 0.66;

  late bool _aiVisible;
  late bool _notesVisible;
  _PanelMode _aiMode = _PanelMode.docked;
  _PanelMode _notesMode = _PanelMode.docked;
  final List<TabGroup> _tabGroups = [];
  bool _isGroupSelectionMode = false;
  String? _pendingGroupName;
  String? _editingGroupId;
  String? _editingOriginalName;
  final Set<String> _pendingGroupTabIds = <String>{};
  int _lastShortcutLaunchNonce = -1;

  Offset _aiOffset = const Offset(360, 120);
  Size _aiSize = const Size(480, 520);
  Offset _notesOffset = const Offset(420, 180);
  Size _notesSize = const Size(640, 420);

  @override
  void initState() {
    super.initState();
    _aiVisible = widget.defaultAiVisible;
    _notesVisible = widget.defaultNotesVisible;
  }

  @override
  void didUpdateWidget(covariant StudyWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultAiVisible != widget.defaultAiVisible) {
      _aiVisible = widget.defaultAiVisible;
      _aiMode = _PanelMode.docked;
    }
    if (oldWidget.defaultNotesVisible != widget.defaultNotesVisible) {
      _notesVisible = widget.defaultNotesVisible;
      _notesMode = _PanelMode.docked;
    }
    final launch = widget.shortcutLaunchRequest;
    if (launch != null && launch.nonce != _lastShortcutLaunchNonce) {
      _lastShortcutLaunchNonce = launch.nonce;
      _tabGroups.removeWhere(
        (group) =>
            group.name.trim().toLowerCase() == launch.name.trim().toLowerCase(),
      );
      _tabGroups.add(
        TabGroup(
          id: 'shortcut-${launch.nonce}',
          name: launch.name,
          tabIds: launch.tabIds,
          colorValue: launch.colorValue,
          isCollapsed: true,
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onShortcutLaunchConsumed(launch.nonce);
      });
    }
  }

  void _resetLayout() {
    setState(() {
      _leftPanelRatio = 0.64;
      _topPanelRatio = 0.66;
      _aiVisible = widget.defaultAiVisible;
      _notesVisible = widget.defaultNotesVisible;
      _aiMode = _PanelMode.docked;
      _notesMode = _PanelMode.docked;
      _aiOffset = const Offset(360, 120);
      _aiSize = const Size(480, 520);
      _notesOffset = const Offset(420, 180);
      _notesSize = const Size(640, 420);
    });
  }

  Future<void> _beginTabGroupFlow(
    String seedTabId, {
    String? editingGroupId,
  }) async {
    final existing = editingGroupId == null
        ? null
        : _tabGroups.firstWhere((g) => g.id == editingGroupId);
    final controller = TextEditingController(text: existing?.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          editingGroupId == null ? 'Create Workspace' : 'Edit Workspace',
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          decoration: const InputDecoration(
            labelText: 'Group name',
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

    final duplicate = _tabGroups.any(
      (g) =>
          g.name.toLowerCase() == name.toLowerCase() &&
          (editingGroupId == null || g.id != editingGroupId),
    );
    if (duplicate) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Workspace name already exists')),
        );
      }
      return;
    }

    setState(() {
      _isGroupSelectionMode = true;
      _pendingGroupName = name;
      _editingGroupId = editingGroupId;
      _editingOriginalName = existing?.name;
      _pendingGroupTabIds
        ..clear()
        ..addAll(existing?.tabIds ?? const [])
        ..add(seedTabId);
    });
  }

  void _toggleTabForGrouping(String tabId) {
    setState(() {
      if (_pendingGroupTabIds.contains(tabId)) {
        _pendingGroupTabIds.remove(tabId);
      } else {
        _pendingGroupTabIds.add(tabId);
      }
    });
  }

  void _cancelTabGroupSelection() {
    setState(() {
      _isGroupSelectionMode = false;
      _pendingGroupName = null;
      _editingGroupId = null;
      _editingOriginalName = null;
      _pendingGroupTabIds.clear();
    });
  }

  Future<void> _finishTabGroupSelection() async {
    if (_pendingGroupName == null || _pendingGroupTabIds.length < 2) {
      _cancelTabGroupSelection();
      return;
    }

    if (_editingGroupId != null &&
        _editingOriginalName != null &&
        _editingOriginalName!.trim().toLowerCase() !=
            _pendingGroupName!.trim().toLowerCase()) {
      final ok = await widget.onRenameHomeShortcutByName(
        _editingOriginalName!,
        _pendingGroupName!,
      );
      if (!ok) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Cannot rename workspace: shortcut name already exists',
              ),
            ),
          );
        }
        return;
      }
    }

    final existingIndex = _editingGroupId == null
        ? -1
        : _tabGroups.indexWhere((g) => g.id == _editingGroupId);
    final existingGroup = existingIndex == -1
        ? null
        : _tabGroups[existingIndex];
    final id =
        _editingGroupId ?? DateTime.now().microsecondsSinceEpoch.toString();
    final selectedTabIds = _pendingGroupTabIds.toList(growable: false);
    final workspaceName = _pendingGroupName!;
    final colorValue = existingGroup?.colorValue;
    final collapsed = existingGroup?.isCollapsed ?? true;
    setState(() {
      final selectedSet = selectedTabIds.toSet();
      final cleanedGroups = <TabGroup>[];
      for (final group in _tabGroups) {
        if (_editingGroupId != null && group.id == _editingGroupId) {
          continue;
        }
        final remaining = group.tabIds
            .where((tabId) => !selectedSet.contains(tabId))
            .toList(growable: false);
        if (remaining.length >= 2) {
          cleanedGroups.add(group.copyWith(tabIds: remaining));
        }
      }
      cleanedGroups.add(
        TabGroup(
          id: id,
          name: workspaceName,
          tabIds: selectedTabIds,
          colorValue: colorValue,
          isCollapsed: collapsed,
        ),
      );
      _tabGroups
        ..clear()
        ..addAll(cleanedGroups);
      _isGroupSelectionMode = false;
      _pendingGroupName = null;
      _editingGroupId = null;
      _editingOriginalName = null;
      _pendingGroupTabIds.clear();
    });
    await widget.onSyncHomeShortcutByName(
      name: workspaceName,
      tabIds: selectedTabIds,
      colorValue: colorValue,
    );
  }

  void _closeTabWithGroupCleanup(String tabId) {
    widget.onCloseTab(tabId);
    setState(() {
      final updatedGroups = <TabGroup>[];
      for (final group in _tabGroups) {
        final remaining = group.tabIds.where((id) => id != tabId).toList();
        if (remaining.length >= 2) {
          updatedGroups.add(
            TabGroup(
              id: group.id,
              name: group.name,
              tabIds: remaining,
              isCollapsed: group.isCollapsed,
            ),
          );
        }
      }
      _tabGroups
        ..clear()
        ..addAll(updatedGroups);
      _pendingGroupTabIds.remove(tabId);
    });
  }

  Future<void> _showGroupMenu(String groupId, Offset globalPosition) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'edit',
          child: Text('Edit workspace PDFs'),
        ),
        PopupMenuItem<String>(value: 'rename', child: Text('Rename workspace')),
        PopupMenuItem<String>(
          value: 'color',
          child: Text('Change group color'),
        ),
        PopupMenuItem<String>(
          value: 'shortcut',
          child: Text('Add shortcut to Home'),
        ),
        PopupMenuItem<String>(
          value: 'close',
          child: Text('Close workspace tabs'),
        ),
        PopupMenuItem<String>(value: 'delete', child: Text('Delete workspace')),
      ],
    );

    if (action == null) {
      return;
    }

    final index = _tabGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      return;
    }
    final group = _tabGroups[index];

    if (action == 'color') {
      await _showColorPicker(group);
      return;
    }

    if (action == 'edit') {
      _beginGroupMembershipEdit(group.id);
      return;
    }

    if (action == 'rename') {
      if (group.tabIds.isNotEmpty) {
        await _beginTabGroupFlow(group.tabIds.first, editingGroupId: group.id);
      }
      return;
    }

    if (action == 'shortcut') {
      final created = await widget.onCreateHomeShortcut(
        name: group.name,
        tabIds: group.tabIds,
        colorValue: group.colorValue,
      );
      if (created && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Shortcut "${group.name}" added to Home')),
        );
      }
      return;
    }

    if (action == 'close') {
      _closeWorkspaceTabs(group.id);
      return;
    }

    if (action == 'delete') {
      _deleteGroup(group.id);
      await widget.onDeleteHomeShortcutByName(group.name);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Workspace "${group.name}" deleted')),
        );
      }
    }
  }

  Future<void> _showTabMenu(String tabId, Offset globalPosition) async {
    final action = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx,
        globalPosition.dy,
      ),
      items: const [
        PopupMenuItem<String>(value: 'color', child: Text('Change tab color')),
        PopupMenuItem<String>(value: 'reset', child: Text('Reset tab color')),
      ],
    );
    if (action == null) {
      return;
    }
    if (action == 'color') {
      await _showTabColorPicker(tabId);
      return;
    }
    if (action == 'reset') {
      await widget.onTabColorChanged(tabId, null);
    }
  }

  Future<void> _showTabColorPicker(String tabId) async {
    const palette = <int>[
      0xFF90CAF9,
      0xFFA5D6A7,
      0xFFFFCC80,
      0xFFFF1E00,
      0xFFEF9A9A,
      0xFFCE93D8,
      0xFFB0BEC5,
      -1,
    ];
    PdfDocument? tab;
    for (final doc in widget.openTabs) {
      if (doc.id == tabId) {
        tab = doc;
        break;
      }
    }
    final selected = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Color for ${tab?.title ?? 'tab'}'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: palette
              .map(
                (value) => InkWell(
                  onTap: () => Navigator.of(context).pop(value),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: value == -1 ? Colors.transparent : Color(value),
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: value == -1
                        ? const Icon(Icons.block, size: 18)
                        : null,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );
    if (selected == null) {
      return;
    }
    await widget.onTabColorChanged(tabId, selected == -1 ? null : selected);
  }

  Future<void> _showColorPicker(TabGroup group) async {
    const palette = <int>[
      0xFF90CAF9,
      0xFFA5D6A7,
      0xFFFFCC80,
      0xFFFF1E00,
      0xFFEF9A9A,
      0xFFCE93D8,
      0xFFB0BEC5,
      -1,
    ];
    final selected = await showDialog<int?>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Color for ${group.name}'),
        content: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: palette
              .map(
                (value) => InkWell(
                  onTap: () => Navigator.of(context).pop(value),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: value == -1 ? Colors.transparent : Color(value),
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: value == -1
                        ? const Icon(Icons.block, size: 18)
                        : null,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    );

    if (selected == null) {
      return;
    }
    setState(() {
      final index = _tabGroups.indexWhere((g) => g.id == group.id);
      if (index == -1) {
        return;
      }
      _tabGroups[index] = _tabGroups[index].copyWith(
        colorValue: selected == -1 ? null : selected,
      );
    });
    final index = _tabGroups.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      final updated = _tabGroups[index];
      await widget.onSyncHomeShortcutByName(
        name: updated.name,
        tabIds: updated.tabIds,
        colorValue: updated.colorValue,
      );
    }
  }

  void _toggleGroupCollapse(String groupId) {
    setState(() {
      final index = _tabGroups.indexWhere((group) => group.id == groupId);
      if (index == -1) {
        return;
      }
      final current = _tabGroups[index];
      _tabGroups[index] = current.copyWith(isCollapsed: !current.isCollapsed);
    });
  }

  void _beginGroupMembershipEdit(String groupId) {
    final index = _tabGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      return;
    }
    final group = _tabGroups[index];
    setState(() {
      _isGroupSelectionMode = true;
      _pendingGroupName = group.name;
      _editingGroupId = group.id;
      _pendingGroupTabIds
        ..clear()
        ..addAll(group.tabIds);
    });
  }

  void _deleteGroup(String groupId) {
    setState(() {
      _tabGroups.removeWhere((group) => group.id == groupId);
    });
  }

  void _closeWorkspaceTabs(String groupId) {
    final index = _tabGroups.indexWhere((group) => group.id == groupId);
    if (index == -1) {
      return;
    }
    final tabIds = List<String>.from(_tabGroups[index].tabIds);
    for (final tabId in tabIds) {
      _closeTabWithGroupCleanup(tabId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.openTabs.isEmpty || widget.activeDocument == null) {
      return const Center(
        child: Text('No open PDF tabs. Open a document from Home.'),
      );
    }

    final aiPanel = AIAssistantPanel(
      providers: widget.providers,
      onRunPrompt: widget.onRunPrompt,
      initialProviderId: widget.defaultAiProviderId,
    );
    final notesPanel = PageNotesPanel(
      pageNumber: widget.viewportData.currentPage,
      annotations: widget.pageAnnotations,
      onSave: widget.onSaveNote,
    );
    final pdfPanel = PdfViewerPanel(
      key: ValueKey('pdf-${widget.activeDocument!.id}'),
      document: widget.activeDocument!,
      onViewportChanged: widget.onViewportChanged,
      initialPage: widget.viewportData.currentPage,
    );

    final aiDocked = _aiVisible && _aiMode == _PanelMode.docked;
    final notesDocked = _notesVisible && _notesMode == _PanelMode.docked;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabStrip(
                  openTabs: widget.openTabs,
                  activeTabId: widget.activeTabId,
                  onSelect: widget.onTabSelected,
                  onClose: _closeTabWithGroupCleanup,
                  tabGroups: _tabGroups,
                  groupSelectionMode: _isGroupSelectionMode,
                  pendingGroupTabIds: _pendingGroupTabIds,
                  onShiftRightClickTab: _beginTabGroupFlow,
                  onShiftRightClickGroup: _beginGroupMembershipEdit,
                  onTabSecondaryTap: _showTabMenu,
                  onToggleGroupTab: _toggleTabForGrouping,
                  onToggleGroupCollapse: _toggleGroupCollapse,
                  onGroupSecondaryTap: _showGroupMenu,
                ),
              ),
              const SizedBox(width: 8),
              if (_isGroupSelectionMode)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Row(
                    children: [
                      Text('Adding tabs to "${_pendingGroupName ?? ''}"'),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _cancelTabGroupSelection,
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          _finishTabGroupSelection();
                        },
                        child: const Text('Finish Group'),
                      ),
                    ],
                  ),
                ),
              IconButton(
                tooltip: _aiVisible ? 'Hide AI sidebar' : 'Show AI sidebar',
                onPressed: () {
                  setState(() {
                    _aiVisible = !_aiVisible;
                    if (!_aiVisible) {
                      _aiMode = _PanelMode.docked;
                    }
                  });
                },
                icon: Icon(
                  _aiVisible ? Icons.auto_awesome : Icons.auto_awesome_outlined,
                ),
              ),
              IconButton(
                tooltip: _notesVisible
                    ? 'Hide Notes panel'
                    : 'Show Notes panel',
                onPressed: () {
                  setState(() {
                    _notesVisible = !_notesVisible;
                    if (!_notesVisible) {
                      _notesMode = _PanelMode.docked;
                    }
                  });
                },
                icon: Icon(
                  _notesVisible
                      ? Icons.sticky_note_2
                      : Icons.sticky_note_2_outlined,
                ),
              ),
              IconButton(
                tooltip: _aiMode == _PanelMode.nativePopup
                    ? 'Dock AI panel'
                    : 'Open AI in native window',
                onPressed: () async {
                  if (_aiMode == _PanelMode.nativePopup) {
                    setState(() {
                      _aiVisible = true;
                      _aiMode = _PanelMode.docked;
                    });
                    return;
                  }
                  setState(() {
                    _aiVisible = true;
                    _aiMode = _PanelMode.nativePopup;
                  });
                  await widget.onOpenExternalAiWindow();
                },
                icon: Icon(
                  _aiMode == _PanelMode.nativePopup
                      ? Icons.dock_outlined
                      : Icons.open_in_new,
                ),
              ),
              IconButton(
                tooltip: _notesMode == _PanelMode.nativePopup
                    ? 'Dock Notes panel'
                    : 'Open Notes in native window',
                onPressed: () async {
                  if (_notesMode == _PanelMode.nativePopup) {
                    setState(() {
                      _notesVisible = true;
                      _notesMode = _PanelMode.docked;
                    });
                    return;
                  }
                  setState(() {
                    _notesVisible = true;
                    _notesMode = _PanelMode.nativePopup;
                  });
                  await widget.onOpenExternalNotesWindow();
                },
                icon: Icon(
                  _notesMode == _PanelMode.nativePopup
                      ? Icons.dock_outlined
                      : Icons.note_add_outlined,
                ),
              ),
              IconButton(
                tooltip: _aiMode == _PanelMode.inAppPopup
                    ? 'Dock AI panel'
                    : 'Pop out AI inside app',
                onPressed: !_aiVisible
                    ? null
                    : () {
                        setState(() {
                          _aiMode = _aiMode == _PanelMode.inAppPopup
                              ? _PanelMode.docked
                              : _PanelMode.inAppPopup;
                        });
                      },
                icon: Icon(
                  _aiMode == _PanelMode.inAppPopup
                      ? Icons.push_pin_outlined
                      : Icons.open_in_new_outlined,
                ),
              ),
              IconButton(
                tooltip: _notesMode == _PanelMode.inAppPopup
                    ? 'Dock Notes panel'
                    : 'Pop out Notes inside app',
                onPressed: !_notesVisible
                    ? null
                    : () {
                        setState(() {
                          _notesMode = _notesMode == _PanelMode.inAppPopup
                              ? _PanelMode.docked
                              : _PanelMode.inAppPopup;
                        });
                      },
                icon: Icon(
                  _notesMode == _PanelMode.inAppPopup
                      ? Icons.push_pin_outlined
                      : Icons.open_in_new_outlined,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _resetLayout,
                icon: const Icon(Icons.space_dashboard_outlined),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final body = _buildBody(
                  constraints: constraints,
                  pdfPanel: pdfPanel,
                  aiPanel: aiPanel,
                  notesPanel: notesPanel,
                  aiDocked: aiDocked,
                  notesDocked: notesDocked,
                );

                return Stack(
                  children: [
                    body,
                    if (_aiVisible && _aiMode == _PanelMode.inAppPopup)
                      FloatingPanelWindow(
                        title: 'AI Assistant',
                        offset: _aiOffset,
                        size: _aiSize,
                        onAttach: () =>
                            setState(() => _aiMode = _PanelMode.docked),
                        onDrag: (next) {
                          setState(() {
                            _aiOffset = _clampOffset(
                              next,
                              constraints.biggest,
                              _aiSize,
                            );
                          });
                        },
                        onResize: (next) {
                          setState(() {
                            _aiSize = _clampSize(next, constraints.biggest);
                            _aiOffset = _clampOffset(
                              _aiOffset,
                              constraints.biggest,
                              _aiSize,
                            );
                          });
                        },
                        child: aiPanel,
                      ),
                    if (_notesVisible && _notesMode == _PanelMode.inAppPopup)
                      FloatingPanelWindow(
                        title: 'Page Notes',
                        offset: _notesOffset,
                        size: _notesSize,
                        onAttach: () =>
                            setState(() => _notesMode = _PanelMode.docked),
                        onDrag: (next) {
                          setState(() {
                            _notesOffset = _clampOffset(
                              next,
                              constraints.biggest,
                              _notesSize,
                            );
                          });
                        },
                        onResize: (next) {
                          setState(() {
                            _notesSize = _clampSize(next, constraints.biggest);
                            _notesOffset = _clampOffset(
                              _notesOffset,
                              constraints.biggest,
                              _notesSize,
                            );
                          });
                        },
                        child: notesPanel,
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody({
    required BoxConstraints constraints,
    required Widget pdfPanel,
    required Widget aiPanel,
    required Widget notesPanel,
    required bool aiDocked,
    required bool notesDocked,
  }) {
    if (widget.notesOrientation == NotesDockOrientation.right && notesDocked) {
      return _buildRightOrientedBody(
        pdfPanel: pdfPanel,
        aiPanel: aiPanel,
        notesPanel: notesPanel,
        aiDocked: aiDocked,
      );
    }

    return _buildBottomOrientedBody(
      constraints: constraints,
      pdfPanel: pdfPanel,
      aiPanel: aiPanel,
      notesPanel: notesPanel,
      aiDocked: aiDocked,
      notesDocked: notesDocked,
    );
  }

  Widget _buildBottomOrientedBody({
    required BoxConstraints constraints,
    required Widget pdfPanel,
    required Widget aiPanel,
    required Widget notesPanel,
    required bool aiDocked,
    required bool notesDocked,
  }) {
    const splitterSize = 6.0;
    const minLeftWidth = 360.0;
    const minRightWidth = 320.0;
    const minTopHeight = 220.0;
    const minBottomHeight = 220.0;

    Widget topRow() {
      if (!aiDocked) {
        return pdfPanel;
      }
      return LayoutBuilder(
        builder: (context, topConstraints) {
          final maxWidth = topConstraints.maxWidth;
          final leftWidth = (maxWidth - splitterSize) * _leftPanelRatio;
          return Row(
            children: [
              SizedBox(
                width: leftWidth.clamp(minLeftWidth, maxWidth),
                child: pdfPanel,
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  final deltaRatio = details.delta.dx / maxWidth;
                  final candidate = _leftPanelRatio + deltaRatio;
                  final minRatio = minLeftWidth / maxWidth;
                  final maxRatio = 1 - (minRightWidth / maxWidth);
                  setState(() {
                    _leftPanelRatio = candidate.clamp(minRatio, maxRatio);
                  });
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: const SizedBox(
                    width: splitterSize,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: Color(0xFFD9DDE4)),
                    ),
                  ),
                ),
              ),
              Expanded(child: aiPanel),
            ],
          );
        },
      );
    }

    if (!notesDocked) {
      return topRow();
    }

    final availableHeight = constraints.maxHeight;
    final topHeight = (availableHeight - splitterSize) * _topPanelRatio;

    return Column(
      children: [
        SizedBox(
          height: topHeight.clamp(minTopHeight, availableHeight),
          child: topRow(),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanUpdate: (details) {
            final deltaRatio = details.delta.dy / availableHeight;
            final candidate = _topPanelRatio + deltaRatio;
            final minRatio = minTopHeight / availableHeight;
            final maxRatio = 1 - (minBottomHeight / availableHeight);
            setState(() {
              _topPanelRatio = candidate.clamp(minRatio, maxRatio);
            });
          },
          child: MouseRegion(
            cursor: SystemMouseCursors.resizeRow,
            child: const SizedBox(
              height: splitterSize,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Color(0xFFD9DDE4)),
              ),
            ),
          ),
        ),
        Expanded(child: notesPanel),
      ],
    );
  }

  Widget _buildRightOrientedBody({
    required Widget pdfPanel,
    required Widget aiPanel,
    required Widget notesPanel,
    required bool aiDocked,
  }) {
    const splitterSize = 6.0;
    const minLeftWidth = 360.0;
    const minRightWidth = 320.0;

    return LayoutBuilder(
      builder: (context, innerConstraints) {
        final maxWidth = innerConstraints.maxWidth;
        final leftWidth = (maxWidth - splitterSize) * _leftPanelRatio;

        final rightChildren = <Widget>[];
        if (aiDocked) {
          rightChildren.add(Expanded(child: aiPanel));
        }
        rightChildren.add(Expanded(child: notesPanel));

        return Row(
          children: [
            SizedBox(
              width: leftWidth.clamp(minLeftWidth, maxWidth),
              child: pdfPanel,
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                final deltaRatio = details.delta.dx / maxWidth;
                final candidate = _leftPanelRatio + deltaRatio;
                final minRatio = minLeftWidth / maxWidth;
                final maxRatio = 1 - (minRightWidth / maxWidth);
                setState(() {
                  _leftPanelRatio = candidate.clamp(minRatio, maxRatio);
                });
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: const SizedBox(
                  width: splitterSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xFFD9DDE4)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Column(
                children: rightChildren.length == 1
                    ? [rightChildren.first]
                    : [
                        rightChildren.first,
                        const SizedBox(height: 8),
                        rightChildren.last,
                      ],
              ),
            ),
          ],
        );
      },
    );
  }

  Offset _clampOffset(Offset value, Size available, Size panelSize) {
    final maxX = math.max(0, available.width - panelSize.width);
    final maxY = math.max(0, available.height - panelSize.height);
    return Offset(
      value.dx.clamp(0, maxX).toDouble(),
      value.dy.clamp(0, maxY).toDouble(),
    );
  }

  Size _clampSize(Size requested, Size available) {
    return Size(
      requested.width.clamp(320, available.width).toDouble(),
      requested.height.clamp(280, available.height).toDouble(),
    );
  }
}
