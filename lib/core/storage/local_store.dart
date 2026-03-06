import 'package:studypdf/models/annotation.dart';

class LocalStore {
  final Map<String, List<Annotation>> _annotationsByPage = {};

  List<Annotation> getAnnotations({required String pdfId, required int page}) {
    return List.unmodifiable(_annotationsByPage['$pdfId:$page'] ?? const []);
  }

  void addAnnotation(Annotation annotation) {
    final key = '${annotation.pdfId}:${annotation.pageNumber}';
    final existing = List<Annotation>.from(_annotationsByPage[key] ?? const []);
    existing.add(annotation);
    _annotationsByPage[key] = existing;
  }
}
