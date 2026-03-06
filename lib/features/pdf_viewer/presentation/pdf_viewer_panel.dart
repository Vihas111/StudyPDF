import 'dart:io';

import 'package:flutter/material.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/pdf_viewport_data.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerPanel extends StatefulWidget {
  const PdfViewerPanel({
    super.key,
    required this.document,
    required this.onViewportChanged,
    this.initialPage = 1,
  });

  final PdfDocument document;
  final ValueChanged<PdfViewportData> onViewportChanged;
  final int initialPage;

  @override
  State<PdfViewerPanel> createState() => _PdfViewerPanelState();
}

class _PdfViewerPanelState extends State<PdfViewerPanel> {
  final PdfViewerController _controller = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 1;
  String _pageText = 'Loading page text...';
  int _extractRequestId = 0;
  final Map<int, String> _pageTextCache = <int, String>{};

  void _emitViewport() {
    widget.onViewportChanged(
      PdfViewportData(
        currentPage: _currentPage,
        totalPages: _totalPages,
        pageText: _pageText,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage > 0 ? widget.initialPage : 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _emitViewport();
      _extractCurrentPageText();
    });
  }

  @override
  void didUpdateWidget(covariant PdfViewerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _currentPage = widget.initialPage > 0 ? widget.initialPage : 1;
      _totalPages = 1;
      _extractRequestId++;
      _pageTextCache.clear();
      _pageText = 'Loading page text...';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _emitViewport();
        _extractCurrentPageText();
      });
    }
  }

  Future<void> _extractCurrentPageText() async {
    final file = File(widget.document.path);
    if (!file.existsSync()) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pageText = 'Unable to extract text: file is missing.';
      });
      _emitViewport();
      return;
    }

    final page = _currentPage;
    final cached = _pageTextCache[page];
    if (cached != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pageText = cached;
      });
      _emitViewport();
      return;
    }

    final requestId = ++_extractRequestId;
    if (mounted) {
      setState(() {
        _pageText = 'Extracting text from page $page...';
      });
    }
    _emitViewport();

    sfpdf.PdfDocument? doc;
    try {
      final bytes = await file.readAsBytes();
      doc = sfpdf.PdfDocument(inputBytes: bytes);
      final extractor = sfpdf.PdfTextExtractor(doc);
      final raw = extractor.extractText(
        startPageIndex: page - 1,
        endPageIndex: page - 1,
      );
      final text = raw.trim().isEmpty
          ? 'No extractable text found on this page (possibly scanned image content).'
          : raw.trim();

      if (!mounted || requestId != _extractRequestId) {
        return;
      }
      _pageTextCache[page] = text;
      setState(() {
        _pageText = text;
      });
      _emitViewport();
    } catch (e) {
      if (!mounted || requestId != _extractRequestId) {
        return;
      }
      setState(() {
        _pageText = 'Failed to extract page text: ${e.toString()}';
      });
      _emitViewport();
    } finally {
      doc?.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final file = File(widget.document.path);
    if (!file.existsSync()) {
      return Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Text(
            'File missing:\n${widget.document.path}',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.document.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: _currentPage > 1
                      ? () {
                          _controller.previousPage();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$_currentPage / $_totalPages'),
                IconButton(
                  tooltip: 'Next page',
                  onPressed: _currentPage < _totalPages
                      ? () {
                          _controller.nextPage();
                        }
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: SfPdfViewer.file(
                file,
                controller: _controller,
                onPageChanged: (details) {
                  setState(() {
                    _currentPage = details.newPageNumber;
                  });
                  _emitViewport();
                  _extractCurrentPageText();
                },
                onDocumentLoaded: (details) {
                  final totalPages = details.document.pages.count;
                  final targetPage = widget.initialPage
                      .clamp(1, totalPages)
                      .toInt();
                  setState(() {
                    _totalPages = totalPages;
                    _currentPage = targetPage;
                  });
                  if (targetPage > 1) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _controller.jumpToPage(targetPage);
                    });
                  }
                  _emitViewport();
                  _extractCurrentPageText();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
