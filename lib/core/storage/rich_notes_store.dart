import 'package:shared_preferences/shared_preferences.dart';
import 'package:studypdf/models/rich_note.dart';

class RichNotesStore {
  static const String _storageKey = 'notes.rich.v1';
  final Map<String, RichNote> _notesByPage = <String, RichNote>{};

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) {
      _notesByPage.clear();
      return;
    }

    final notes = RichNote.decodeList(raw);
    _notesByPage
      ..clear()
      ..addEntries(
        notes.map((note) => MapEntry(_key(note.pdfId, note.pageNumber), note)),
      );
  }

  Future<RichNote?> getNote({
    required String pdfId,
    required int pageNumber,
  }) async {
    return _notesByPage[_key(pdfId, pageNumber)];
  }

  RichNote? peekNote({required String pdfId, required int pageNumber}) {
    return _notesByPage[_key(pdfId, pageNumber)];
  }

  Future<void> upsertNote({
    required String pdfId,
    required int pageNumber,
    required String deltaJson,
  }) async {
    final now = DateTime.now();
    final key = _key(pdfId, pageNumber);
    final existing = _notesByPage[key];
    _notesByPage[key] = RichNote(
      id:
          existing?.id ??
          '${pdfId}_${pageNumber}_${now.microsecondsSinceEpoch}',
      pdfId: pdfId,
      pageNumber: pageNumber,
      deltaJson: deltaJson,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _persist();
  }

  Future<List<RichNote>> getNotesForPdf(String pdfId) async {
    final notes = _notesByPage.values
        .where((note) => note.pdfId == pdfId)
        .toList(growable: false);
    notes.sort((a, b) => a.pageNumber.compareTo(b.pageNumber));
    return notes;
  }

  Future<List<RichNote>> getNotesForPdfIds(List<String> pdfIds) async {
    final ids = pdfIds.toSet();
    final notes = _notesByPage.values
        .where((note) => ids.contains(note.pdfId))
        .toList(growable: false);
    notes.sort((a, b) {
      final byPdf = a.pdfId.compareTo(b.pdfId);
      if (byPdf != 0) {
        return byPdf;
      }
      return a.pageNumber.compareTo(b.pageNumber);
    });
    return notes;
  }

  String _key(String pdfId, int pageNumber) => '$pdfId:$pageNumber';

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final serialized = RichNote.encodeList(_notesByPage.values.toList());
    await prefs.setString(_storageKey, serialized);
  }
}
