enum PanelDockPosition { left, right, bottom }

class WorkspacePreferences {
  const WorkspacePreferences({
    this.aiDockPosition = PanelDockPosition.right,
    this.notesDockPosition = PanelDockPosition.bottom,
    this.startWithAiVisible = true,
    this.startWithNotesVisible = true,
    this.bottomPanelSpansEntireWidth = true,
    this.enablePesuDownloader = false,
  });

  final PanelDockPosition aiDockPosition;
  final PanelDockPosition notesDockPosition;
  final bool startWithAiVisible;
  final bool startWithNotesVisible;
  final bool bottomPanelSpansEntireWidth;
  // Off by default: most users of this app aren't PESU students, so the
  // course downloader is an opt-in module rather than a fixture of the
  // core app (Phase 4b).
  final bool enablePesuDownloader;

  WorkspacePreferences copyWith({
    PanelDockPosition? aiDockPosition,
    PanelDockPosition? notesDockPosition,
    bool? startWithAiVisible,
    bool? startWithNotesVisible,
    bool? bottomPanelSpansEntireWidth,
    bool? enablePesuDownloader,
  }) {
    return WorkspacePreferences(
      aiDockPosition: aiDockPosition ?? this.aiDockPosition,
      notesDockPosition: notesDockPosition ?? this.notesDockPosition,
      startWithAiVisible: startWithAiVisible ?? this.startWithAiVisible,
      startWithNotesVisible:
          startWithNotesVisible ?? this.startWithNotesVisible,
      bottomPanelSpansEntireWidth:
          bottomPanelSpansEntireWidth ?? this.bottomPanelSpansEntireWidth,
      enablePesuDownloader: enablePesuDownloader ?? this.enablePesuDownloader,
    );
  }
}
