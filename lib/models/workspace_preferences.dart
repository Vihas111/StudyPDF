enum NotesDockOrientation { bottom, right }

class WorkspacePreferences {
  const WorkspacePreferences({
    this.notesOrientation = NotesDockOrientation.bottom,
    this.startWithAiVisible = true,
    this.startWithNotesVisible = true,
  });

  final NotesDockOrientation notesOrientation;
  final bool startWithAiVisible;
  final bool startWithNotesVisible;

  WorkspacePreferences copyWith({
    NotesDockOrientation? notesOrientation,
    bool? startWithAiVisible,
    bool? startWithNotesVisible,
  }) {
    return WorkspacePreferences(
      notesOrientation: notesOrientation ?? this.notesOrientation,
      startWithAiVisible: startWithAiVisible ?? this.startWithAiVisible,
      startWithNotesVisible:
          startWithNotesVisible ?? this.startWithNotesVisible,
    );
  }
}
