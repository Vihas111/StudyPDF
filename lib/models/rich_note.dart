import 'dart:convert';

class RichNote {
  const RichNote({
    required this.id,
    required this.pdfId,
    required this.pageNumber,
    required this.deltaJson,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String pdfId;
  final int pageNumber;
  final String deltaJson;
  final DateTime createdAt;
  final DateTime updatedAt;

  RichNote copyWith({
    String? id,
    String? pdfId,
    int? pageNumber,
    String? deltaJson,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RichNote(
      id: id ?? this.id,
      pdfId: pdfId ?? this.pdfId,
      pageNumber: pageNumber ?? this.pageNumber,
      deltaJson: deltaJson ?? this.deltaJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pdfId': pdfId,
      'pageNumber': pageNumber,
      'deltaJson': deltaJson,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static RichNote fromJson(Map<String, dynamic> json) {
    return RichNote(
      id: json['id'] as String? ?? '',
      pdfId: json['pdfId'] as String? ?? '',
      pageNumber: (json['pageNumber'] as num?)?.toInt() ?? 1,
      deltaJson: json['deltaJson'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  static String encodeList(List<RichNote> notes) {
    return jsonEncode(
      notes.map((note) => note.toJson()).toList(growable: false),
    );
  }

  static List<RichNote> decodeList(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, dynamic>())
        .map(RichNote.fromJson)
        .toList(growable: false);
  }
}
