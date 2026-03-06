class PdfViewportData {
  const PdfViewportData({
    required this.currentPage,
    required this.totalPages,
    required this.pageText,
  });

  final int currentPage;
  final int totalPages;
  final String pageText;
}
