import 'dart:convert';

class MergedNote {
  const MergedNote({
    required this.id,
    required this.pdfId,
    required this.pdfTitle,
    required this.markdownContent,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String pdfId;
  final String pdfTitle;
  final String markdownContent;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pdfId': pdfId,
      'pdfTitle': pdfTitle,
      'markdownContent': markdownContent,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory MergedNote.fromMap(Map<String, dynamic> map) {
    return MergedNote(
      id: map['id'] ?? '',
      pdfId: map['pdfId'] ?? '',
      pdfTitle: map['pdfTitle'] ?? '',
      markdownContent: map['markdownContent'] ?? '',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory MergedNote.fromJson(String source) => MergedNote.fromMap(json.decode(source));

  static String encodeList(List<MergedNote> list) {
    return json.encode(list.map((note) => note.toMap()).toList());
  }

  static List<MergedNote> decodeList(String source) {
    final parsed = json.decode(source);
    if (parsed is! List) return [];
    return parsed.map((e) => MergedNote.fromMap(e as Map<String, dynamic>)).toList();
  }

  MergedNote copyWith({
    String? id,
    String? pdfId,
    String? pdfTitle,
    String? markdownContent,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MergedNote(
      id: id ?? this.id,
      pdfId: pdfId ?? this.pdfId,
      pdfTitle: pdfTitle ?? this.pdfTitle,
      markdownContent: markdownContent ?? this.markdownContent,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
