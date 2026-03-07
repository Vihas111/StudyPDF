enum PanelDockPosition { left, right, bottom }

class WorkspacePreferences {
  const WorkspacePreferences({
    this.aiDockPosition = PanelDockPosition.right,
    this.notesDockPosition = PanelDockPosition.bottom,
    this.startWithAiVisible = true,
    this.startWithNotesVisible = true,
  });

  final PanelDockPosition aiDockPosition;
  final PanelDockPosition notesDockPosition;
  final bool startWithAiVisible;
  final bool startWithNotesVisible;

  WorkspacePreferences copyWith({
    PanelDockPosition? aiDockPosition,
    PanelDockPosition? notesDockPosition,
    bool? startWithAiVisible,
    bool? startWithNotesVisible,
  }) {
    return WorkspacePreferences(
      aiDockPosition: aiDockPosition ?? this.aiDockPosition,
      notesDockPosition: notesDockPosition ?? this.notesDockPosition,
      startWithAiVisible: startWithAiVisible ?? this.startWithAiVisible,
      startWithNotesVisible:
          startWithNotesVisible ?? this.startWithNotesVisible,
    );
  }
}
