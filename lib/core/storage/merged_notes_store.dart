import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypdf/models/merged_note.dart';

class MergedNotesStore {
  static const String _storageKey = 'notes.merged.v1';
  final Map<String, MergedNote> _notesById = <String, MergedNote>{};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _notesById.clear();
      return;
    }

    final notes = MergedNote.decodeList(raw);
    _notesById
      ..clear()
      ..addEntries(
        notes.map((note) => MapEntry(note.id, note)),
      );
  }

  List<MergedNote> getAllNotes() {
    final list = _notesById.values.toList(growable: false);
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }
  
  MergedNote? getNoteById(String id) {
    return _notesById[id];
  }

  MergedNote? getNoteByPdfId(String pdfId) {
    for (final note in _notesById.values) {
      if (note.pdfId == pdfId) return note;
    }
    return null;
  }

  Future<void> saveNote(MergedNote note) async {
    _notesById[note.id] = note;
    await _persist();
  }

  Future<void> deleteNote(String id) async {
    _notesById.remove(id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = MergedNote.encodeList(_notesById.values.toList());
    await prefs.setString(_storageKey, serialized);
  }
}
