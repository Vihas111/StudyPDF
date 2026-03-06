import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/tab_group.dart';

class TabStrip extends StatefulWidget {
  const TabStrip({
    super.key,
    required this.openTabs,
    required this.activeTabId,
    required this.onSelect,
    required this.onClose,
    required this.tabGroups,
    required this.groupSelectionMode,
    required this.pendingGroupTabIds,
    required this.onShiftRightClickTab,
    required this.onShiftRightClickGroup,
    required this.onTabSecondaryTap,
    required this.onToggleGroupTab,
    required this.onToggleGroupCollapse,
    required this.onGroupSecondaryTap,
  });

  final List<PdfDocument> openTabs;
  final String? activeTabId;
  final ValueChanged<String> onSelect;
  final ValueChanged<String> onClose;
  final List<TabGroup> tabGroups;
  final bool groupSelectionMode;
  final Set<String> pendingGroupTabIds;
  final ValueChanged<String> onShiftRightClickTab;
  final ValueChanged<String> onShiftRightClickGroup;
  final Future<void> Function(String tabId, Offset globalPosition)
  onTabSecondaryTap;
  final ValueChanged<String> onToggleGroupTab;
  final ValueChanged<String> onToggleGroupCollapse;
  final Future<void> Function(String groupId, Offset globalPosition)
  onGroupSecondaryTap;

  @override
  State<TabStrip> createState() => _TabStripState();
}

class _TabStripState extends State<TabStrip> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool get _shiftPressed {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.groupSelectionMode) {
      return Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent && _scrollController.hasClients) {
            final next = (_scrollController.offset + event.scrollDelta.dy)
                .clamp(
                  _scrollController.position.minScrollExtent,
                  _scrollController.position.maxScrollExtent,
                );
            _scrollController.jumpTo(next);
          }
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          child: Row(
            children: widget.openTabs
                .map((doc) => _tabChip(context, doc))
                .toList(growable: false),
          ),
        ),
      );
    }

    final docsById = <String, PdfDocument>{
      for (final doc in widget.openTabs) doc.id: doc,
    };
    final groupByTabId = <String, TabGroup>{};
    for (final group in widget.tabGroups) {
      for (final tabId in group.tabIds) {
        groupByTabId[tabId] = group;
      }
    }

    final renderedGroupIds = <String>{};
    final children = <Widget>[];

    for (final doc in widget.openTabs) {
      final group = groupByTabId[doc.id];
      if (group == null) {
        children.add(_tabChip(context, doc));
        continue;
      }
      if (renderedGroupIds.contains(group.id)) {
        continue;
      }
      renderedGroupIds.add(group.id);
      children.add(_groupChip(context, group));

      if (!group.isCollapsed) {
        for (final tabId in group.tabIds) {
          final groupedDoc = docsById[tabId];
          if (groupedDoc != null) {
            children.add(_tabChip(context, groupedDoc, grouped: true));
          }
        }
      }
    }

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent && _scrollController.hasClients) {
          final next = (_scrollController.offset + event.scrollDelta.dy).clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          );
          _scrollController.jumpTo(next);
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        child: Row(children: children),
      ),
    );
  }

  Widget _groupChip(BuildContext context, TabGroup group) {
    final groupHasActiveTab = group.tabIds.contains(widget.activeTabId);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onSecondaryTapDown: (details) async {
          if (_shiftPressed) {
            widget.onShiftRightClickGroup(group.id);
            return;
          }
          await widget.onGroupSecondaryTap(group.id, details.globalPosition);
        },
        child: InputChip(
          selected: groupHasActiveTab,
          avatar: Icon(
            group.isCollapsed
                ? Icons.keyboard_arrow_right
                : Icons.keyboard_arrow_down,
            size: 18,
          ),
          label: Text('${group.name} (${group.tabIds.length})'),
          onPressed: () => widget.onToggleGroupCollapse(group.id),
          backgroundColor: group.colorValue == null
              ? null
              : Color(group.colorValue!),
          selectedColor: group.colorValue == null
              ? null
              : Color(group.colorValue!).withValues(alpha: 0.75),
        ),
      ),
    );
  }

  Widget _tabChip(
    BuildContext context,
    PdfDocument doc, {
    bool grouped = false,
  }) {
    final active = doc.id == widget.activeTabId;
    final selectedForGrouping = widget.pendingGroupTabIds.contains(doc.id);
    return Padding(
      padding: EdgeInsets.only(right: 8, left: grouped ? 8 : 0),
      child: GestureDetector(
        onSecondaryTapDown: (details) async {
          if (_shiftPressed) {
            widget.onShiftRightClickTab(doc.id);
            return;
          }
          await widget.onTabSecondaryTap(doc.id, details.globalPosition);
        },
        child: InputChip(
          selected: widget.groupSelectionMode ? selectedForGrouping : active,
          avatar: const Icon(Icons.picture_as_pdf, size: 18),
          label: Text(doc.title),
          onPressed: () => widget.groupSelectionMode
              ? widget.onToggleGroupTab(doc.id)
              : widget.onSelect(doc.id),
          onDeleted: () => widget.onClose(doc.id),
          backgroundColor: doc.tabColorValue == null
              ? null
              : Color(doc.tabColorValue!),
          selectedColor: doc.tabColorValue == null
              ? null
              : Color(doc.tabColorValue!).withValues(alpha: 0.75),
        ),
      ),
    );
  }
}
