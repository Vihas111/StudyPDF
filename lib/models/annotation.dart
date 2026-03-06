class Annotation {
  const Annotation({
    required this.id,
    required this.pdfId,
    required this.pageNumber,
    required this.content,
    required this.createdAt,
  });

  final String id;
  final String pdfId;
  final int pageNumber;
  final String content;
  final DateTime createdAt;
}
