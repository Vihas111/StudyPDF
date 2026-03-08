enum PanelDockPosition { left, right, bottom }

class WorkspacePreferences {
  const WorkspacePreferences({
    this.aiDockPosition = PanelDockPosition.right,
    this.notesDockPosition = PanelDockPosition.bottom,
    this.startWithAiVisible = true,
    this.startWithNotesVisible = true,
    this.bottomPanelSpansEntireWidth = true,
  });

  final PanelDockPosition aiDockPosition;
  final PanelDockPosition notesDockPosition;
  final bool startWithAiVisible;
  final bool startWithNotesVisible;
  final bool bottomPanelSpansEntireWidth;

  WorkspacePreferences copyWith({
    PanelDockPosition? aiDockPosition,
    PanelDockPosition? notesDockPosition,
    bool? startWithAiVisible,
    bool? startWithNotesVisible,
    bool? bottomPanelSpansEntireWidth,
  }) {
    return WorkspacePreferences(
      aiDockPosition: aiDockPosition ?? this.aiDockPosition,
      notesDockPosition: notesDockPosition ?? this.notesDockPosition,
      startWithAiVisible: startWithAiVisible ?? this.startWithAiVisible,
      startWithNotesVisible:
          startWithNotesVisible ?? this.startWithNotesVisible,
      bottomPanelSpansEntireWidth:
          bottomPanelSpansEntireWidth ?? this.bottomPanelSpansEntireWidth,
    );
  }
}
