import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;
import 'package:studypdf/core/theme/design_tokens.dart';
import 'package:studypdf/models/pdf_document.dart';
import 'package:studypdf/models/pdf_viewport_data.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

/// A from-scratch PDF viewport: not "an image resized to fit the
/// container," but a document with its own coordinate system, a zoom
/// transform, and independent scroll state — matching how a real PDF
/// viewer (Adobe/Chrome/etc.) behaves. `syncfusion_flutter_pdfviewer` was
/// dropped for this widget because it owns rendering/zoom/scroll
/// internally with a hardcoded 1.0 zoom floor and no page-layout API to
/// hook into; `pdfrx` (pdfium-backed) exposes raw per-page rasterization,
/// which is what a real viewport needs.
enum _ZoomMode { fitWidth, fitPage, actualSize, custom }

class _PageGeometry {
  _PageGeometry({required this.pdfWidth, required this.pdfHeight});

  final double pdfWidth;
  final double pdfHeight;

  double top = 0;
  double left = 0;
  double width = 0;
  double height = 0;
}

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
  static const double _minZoom = 0.25;
  static const double _maxZoom = 4.0;
  static const double _zoomStep = 0.25;
  static const double _pageSpacing = 16;
  static const double _horizontalPadding = 24;
  static const int _renderBufferPages = 1;
  static const int _maxRenderDimension = 2600;

  // Page-turn rule: current page changes once less than 15% of it remains
  // visible; reverts only once the previous page is back above 20% visible.
  // The small hysteresis gap exists purely to absorb a scroll position
  // sitting exactly on the boundary for one frame — geometry here is exact
  // (real page sizes from pdfrx), not the estimated aspect-ratio guess the
  // old SfPdfViewer-based version had to use, so the gap can stay small.
  static const double _pageVisibilityThreshold = 0.15;
  static const double _revertVisibilityThreshold = 0.20;

  pdfrx.PdfDocument? _doc;
  final List<_PageGeometry> _pages = <_PageGeometry>[];
  int _totalPages = 0;
  bool _loading = true;
  String? _loadError;

  double _zoom = 1.0;
  _ZoomMode _zoomMode = _ZoomMode.fitWidth;
  double _scrollX = 0;
  double _scrollY = 0;
  Size _viewportSize = Size.zero;
  double _documentWidth = 0;
  double _documentHeight = 0;

  int _currentPage = 1;
  String _pageText = 'Loading page text...';
  int _extractRequestId = 0;
  final Map<int, String> _pageTextCache = <int, String>{};

  final Map<int, ui.Image> _imageCache = <int, ui.Image>{};
  final Map<int, double> _renderedZoomFor = <int, double>{};
  final Set<int> _renderingPages = <int>{};
  final Map<int, pdfrx.PdfPageRenderCancellationToken> _renderTokens =
      <int, pdfrx.PdfPageRenderCancellationToken>{};
  Timer? _renderDebounce;
  int _renderGeneration = 0;

  final FocusNode _focusNode = FocusNode();
  // Tracked locally off this widget's own key events rather than trusting
  // HardwareKeyboard.instance.isControlPressed directly — that global flag
  // is prone to a known Flutter-on-Windows desync where a modifier key
  // released while the app didn't have focus never reports its key-up,
  // leaving it stuck "pressed" and turning every future plain scroll into
  // a zoom. Confirmed happening live: the zoom level kept changing on
  // every scroll tick while the page position stayed frozen.
  bool _ctrlHeldLocally = false;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage > 0 ? widget.initialPage : 1;
    _loadDocument();
  }

  @override
  void dispose() {
    _renderDebounce?.cancel();
    _cancelPendingRenders();
    _focusNode.dispose();
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _doc?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant PdfViewerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document.id != widget.document.id) {
      _renderGeneration++;
      _cancelPendingRenders();
      for (final image in _imageCache.values) {
        image.dispose();
      }
      _imageCache.clear();
      _renderedZoomFor.clear();
      _renderingPages.clear();
      _pages.clear();
      _pageTextCache.clear();
      _totalPages = 0;
      _currentPage = widget.initialPage > 0 ? widget.initialPage : 1;
      _zoomMode = _ZoomMode.fitWidth;
      _scrollX = 0;
      _scrollY = 0;
      _pageText = 'Loading page text...';
      _extractRequestId++;
      _loading = true;
      _loadError = null;
      final oldDoc = _doc;
      _doc = null;
      oldDoc?.dispose();
      _loadDocument();
    }
  }

  Future<void> _loadDocument() async {
    final generation = _renderGeneration;
    final file = File(widget.document.path);
    if (!file.existsSync()) {
      if (!mounted || generation != _renderGeneration) return;
      setState(() {
        _loading = false;
        _loadError = 'File missing:\n${widget.document.path}';
      });
      return;
    }
    try {
      final doc = await pdfrx.PdfDocument.openFile(widget.document.path);
      if (!mounted || generation != _renderGeneration) {
        await doc.dispose();
        return;
      }
      final pages = <_PageGeometry>[
        for (final page in doc.pages)
          _PageGeometry(pdfWidth: page.width, pdfHeight: page.height),
      ];
      setState(() {
        _doc = doc;
        _pages
          ..clear()
          ..addAll(pages);
        _totalPages = pages.length;
        _currentPage = widget.initialPage.clamp(1, math.max(1, _totalPages));
        _loading = false;
      });
      _recalculateLayout();
      _scrollY = _currentPage > 1 ? _pages[_currentPage - 1].top : 0;
      _clampScroll();
      _scheduleRenderVisible();
      _emitViewport();
      _extractCurrentPageText();
    } catch (e) {
      if (!mounted || generation != _renderGeneration) return;
      setState(() {
        _loading = false;
        _loadError = 'Failed to open PDF: $e';
      });
    }
  }

  // ── Layout ────────────────────────────────────────────────────────────

  void _recalculateLayout() {
    if (_pages.isEmpty || _viewportSize.width <= 0) return;

    if (_zoomMode == _ZoomMode.fitWidth) {
      // Fit to the page currently being viewed, not the widest page
      // anywhere in the document — a single unusually wide outlier page
      // (a landscape diagram, a scanned table) would otherwise shrink
      // every normal page in the book to make room for it. This is only
      // recalculated on load / explicit reset / viewport resize, never on
      // scroll, so zoom doesn't jump around as the user moves between
      // differently sized pages.
      final page = _pages[(_currentPage - 1).clamp(0, _pages.length - 1)];
      if (page.pdfWidth > 0) {
        _zoom = ((_viewportSize.width - _horizontalPadding * 2) / page.pdfWidth)
            .clamp(_minZoom, _maxZoom);
      }
    } else if (_zoomMode == _ZoomMode.fitPage) {
      final page = _pages[(_currentPage - 1).clamp(0, _pages.length - 1)];
      final widthZoom =
          (_viewportSize.width - _horizontalPadding * 2) / page.pdfWidth;
      final heightZoom = _viewportSize.height / page.pdfHeight;
      _zoom = math.min(widthZoom, heightZoom).clamp(_minZoom, _maxZoom);
    } else if (_zoomMode == _ZoomMode.actualSize) {
      _zoom = 1.0;
    }

    var maxRenderedWidth = 0.0;
    for (final page in _pages) {
      maxRenderedWidth = math.max(maxRenderedWidth, page.pdfWidth * _zoom);
    }
    _documentWidth = math.max(
      _viewportSize.width,
      maxRenderedWidth + _horizontalPadding * 2,
    );

    var top = _pageSpacing;
    for (final page in _pages) {
      page.width = page.pdfWidth * _zoom;
      page.height = page.pdfHeight * _zoom;
      page.left = (_documentWidth - page.width) / 2;
      page.top = top;
      top += page.height + _pageSpacing;
    }
    _documentHeight = top;
  }

  void _clampScroll() {
    final maxScrollY = math.max(0.0, _documentHeight - _viewportSize.height);
    final maxScrollX = math.max(0.0, _documentWidth - _viewportSize.width);
    _scrollX = _scrollX.clamp(0.0, maxScrollX);
    _scrollY = _scrollY.clamp(0.0, maxScrollY);
  }

  // ── Zoom ──────────────────────────────────────────────────────────────

  void _setZoom(double newZoom, {Offset? anchor, bool userInitiated = true}) {
    if (_pages.isEmpty || _viewportSize.width <= 0) return;
    final clamped = newZoom.clamp(_minZoom, _maxZoom);
    final oldZoom = _zoom;
    if ((clamped - oldZoom).abs() < 0.001 &&
        (!userInitiated || _zoomMode == _ZoomMode.custom)) {
      return;
    }
    final effectiveAnchor =
        anchor ?? Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    final contentX = _scrollX + effectiveAnchor.dx;
    final contentY = _scrollY + effectiveAnchor.dy;
    final scale = clamped / oldZoom;

    setState(() {
      if (userInitiated) {
        _zoomMode = _ZoomMode.custom;
      }
      _zoom = clamped;
      _recalculateLayoutAtFixedZoom();
      _scrollX = contentX * scale - effectiveAnchor.dx;
      _scrollY = contentY * scale - effectiveAnchor.dy;
      _clampScroll();
    });
    // A render already in flight (or merely queued behind others in
    // pdfium's single-threaded worker) is for a zoom level this change
    // just made obsolete. Cancelling it here — rather than only debouncing
    // the *next* render — matters specifically during a rapid zoom
    // gesture: without it, every intermediate zoom step still queues a
    // full-resolution render that runs to completion before the next one
    // starts, and the backlog can outlast the gesture, leaving pages blank
    // long after the user has settled on a final zoom level (confirmed via
    // screen recording: page position advanced correctly but content never
    // caught up after a burst of zoom changes).
    _cancelPendingRenders();
    _scheduleRenderVisible(debounced: true);
    _updateCurrentPageFromScroll();
  }

  void _cancelPendingRenders() {
    for (final token in _renderTokens.values) {
      token.cancel();
    }
    _renderTokens.clear();
  }

  /// Same as [_recalculateLayout] but trusts `_zoom` as already set —
  /// used by [_setZoom], which computes zoom itself (fit modes don't apply
  /// mid-gesture; only [_recalculateLayout] recalculates fit-based zoom).
  void _recalculateLayoutAtFixedZoom() {
    var maxRenderedWidth = 0.0;
    for (final page in _pages) {
      maxRenderedWidth = math.max(maxRenderedWidth, page.pdfWidth * _zoom);
    }
    _documentWidth = math.max(
      _viewportSize.width,
      maxRenderedWidth + _horizontalPadding * 2,
    );
    var top = _pageSpacing;
    for (final page in _pages) {
      page.width = page.pdfWidth * _zoom;
      page.height = page.pdfHeight * _zoom;
      page.left = (_documentWidth - page.width) / 2;
      page.top = top;
      top += page.height + _pageSpacing;
    }
    _documentHeight = top;
  }

  void _zoomByStep(double delta) {
    _setZoom(_zoom + delta);
  }

  void _resetToFitWidth() {
    setState(() {
      _zoomMode = _ZoomMode.fitWidth;
    });
    _recalculateLayout();
    _clampScroll();
    _scheduleRenderVisible();
    setState(() {});
  }

  // ── Scrolling ─────────────────────────────────────────────────────────

  void _scrollBy(double dx, double dy) {
    setState(() {
      _scrollX += dx;
      _scrollY += dy;
      _clampScroll();
    });
    _scheduleRenderVisible();
    _updateCurrentPageFromScroll();
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    // Registering with the resolver (rather than handling the event
    // directly) is the standard way to claim a wheel event — it avoids
    // any ambiguity with ancestor scrollables also wanting the same
    // event, which would otherwise be a plausible reason wheel input
    // never reliably reaches this widget.
    GestureBinding.instance.pointerSignalResolver.register(event, (
      PointerSignalEvent event,
    ) {
      event as PointerScrollEvent;
      if (_ctrlHeldLocally) {
        final factor = math.pow(1.0015, -event.scrollDelta.dy).toDouble();
        _setZoom(_zoom * factor, anchor: event.localPosition);
      } else {
        _scrollBy(event.scrollDelta.dx, event.scrollDelta.dy);
      }
    });
  }

  static final _controlKeys = <LogicalKeyboardKey>{
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
    LogicalKeyboardKey.control,
  };

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_controlKeys.contains(event.logicalKey)) {
      _ctrlHeldLocally = event is! KeyUpEvent;
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final page = _viewportSize.height * 0.9;
    switch (event.logicalKey) {
      case LogicalKeyboardKey.pageDown:
      case LogicalKeyboardKey.space:
        _scrollBy(0, page);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        _scrollBy(0, -page);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown:
        _scrollBy(0, 60);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        _scrollBy(0, -60);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.home:
        _goToPage(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        _goToPage(_totalPages);
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _goToPage(int pageNumber) {
    if (_pages.isEmpty) return;
    final index = pageNumber.clamp(1, _totalPages) - 1;
    setState(() {
      _scrollY = _pages[index].top;
      _clampScroll();
    });
    _scheduleRenderVisible();
    _updateCurrentPageFromScroll();
  }

  // ── Current-page tracking ────────────────────────────────────────────

  double _visibleFractionOf(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _pages.length) return 0;
    final page = _pages[pageIndex];
    if (page.height <= 0) return 0;
    final end = page.top + page.height;
    final remaining = (end - _scrollY).clamp(0.0, page.height);
    return remaining / page.height;
  }

  void _updateCurrentPageFromScroll() {
    if (_pages.isEmpty) return;
    final currentIndex = _currentPage - 1;
    int target = _currentPage;
    if (_currentPage < _totalPages &&
        _visibleFractionOf(currentIndex) < _pageVisibilityThreshold) {
      target = _currentPage + 1;
    } else if (_currentPage > 1 &&
        _visibleFractionOf(currentIndex - 1) > _revertVisibilityThreshold) {
      target = _currentPage - 1;
    }
    if (target != _currentPage) {
      setState(() => _currentPage = target);
      _emitViewport();
      _extractCurrentPageText();
      if (_zoomMode == _ZoomMode.fitPage) {
        _recalculateLayout();
        _clampScroll();
      }
    }
  }

  // ── Rendering ─────────────────────────────────────────────────────────

  List<int> _visiblePageIndices() {
    final result = <int>[];
    for (var i = 0; i < _pages.length; i++) {
      final page = _pages[i];
      final visible =
          page.top + page.height >= _scrollY &&
          page.top <= _scrollY + _viewportSize.height;
      if (visible) result.add(i);
    }
    if (result.isEmpty) return result;
    final first = math.max(0, result.first - _renderBufferPages);
    final last = math.min(_pages.length - 1, result.last + _renderBufferPages);
    return [for (var i = first; i <= last; i++) i];
  }

  void _scheduleRenderVisible({bool debounced = false}) {
    if (!debounced) {
      _renderVisiblePages();
      return;
    }
    _renderDebounce?.cancel();
    _renderDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) _renderVisiblePages();
    });
  }

  void _renderVisiblePages() {
    final doc = _doc;
    if (doc == null) return;
    for (final index in _visiblePageIndices()) {
      final needsRender =
          !_renderingPages.contains(index) &&
          (_renderedZoomFor[index] == null ||
              (_renderedZoomFor[index]! - _zoom).abs() > 0.01);
      if (needsRender) {
        _renderPage(index);
      }
    }
  }

  Future<void> _renderPage(int index) async {
    final doc = _doc;
    if (doc == null || index < 0 || index >= doc.pages.length) return;
    final generation = _renderGeneration;
    final devicePixelRatio =
        WidgetsBinding.instance.platformDispatcher.views.first.devicePixelRatio;
    final renderScale = _zoom * devicePixelRatio;
    final geometry = _pages[index];
    var targetWidth = (geometry.pdfWidth * renderScale).round();
    var targetHeight = (geometry.pdfHeight * renderScale).round();
    final longest = math.max(targetWidth, targetHeight);
    if (longest > _maxRenderDimension) {
      final scale = _maxRenderDimension / longest;
      targetWidth = (targetWidth * scale).round();
      targetHeight = (targetHeight * scale).round();
    }
    if (targetWidth <= 0 || targetHeight <= 0) return;

    _renderingPages.add(index);
    final page = doc.pages[index];
    final token = page.createCancellationToken();
    _renderTokens[index]?.cancel();
    _renderTokens[index] = token;
    try {
      final rendered = await page.render(
        fullWidth: targetWidth.toDouble(),
        fullHeight: targetHeight.toDouble(),
        cancellationToken: token,
      );
      // A null result means pdfium either had nothing to render or the
      // token above was cancelled mid-flight (superseded by a newer zoom)
      // — either way, leave whatever was on screen before untouched.
      if (rendered == null) {
        return;
      }
      if (!mounted || generation != _renderGeneration) {
        rendered.dispose();
        return;
      }
      final image = await _decodeBgra(
        rendered.pixels,
        rendered.width,
        rendered.height,
      );
      rendered.dispose();
      if (!mounted || generation != _renderGeneration) {
        image.dispose();
        return;
      }
      final old = _imageCache[index];
      _imageCache[index] = image;
      _renderedZoomFor[index] = _zoom;
      old?.dispose();
      setState(() {});
    } catch (_) {
      // Leave the previous (possibly stale) render in place, if any.
    } finally {
      _renderingPages.remove(index);
      if (identical(_renderTokens[index], token)) {
        _renderTokens.remove(index);
      }
    }
  }

  Future<ui.Image> _decodeBgra(dynamic pixels, int width, int height) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.bgra8888,
      completer.complete,
    );
    return completer.future;
  }

  // ── Viewport reporting / text extraction (unchanged logic) ─────────────

  void _emitViewport() {
    widget.onViewportChanged(
      PdfViewportData(
        currentPage: _currentPage,
        totalPages: _totalPages,
        pageText: _pageText,
      ),
    );
  }

  Future<void> _extractCurrentPageText() async {
    final file = File(widget.document.path);
    if (!file.existsSync()) {
      if (!mounted) return;
      setState(() {
        _pageText = 'Unable to extract text: file is missing.';
      });
      _emitViewport();
      return;
    }

    final page = _currentPage;
    final cached = _pageTextCache[page];
    if (cached != null) {
      if (!mounted) return;
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

  // ── Build ────────────────────────────────────────────────────────────

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
    if (_loadError != null) {
      return Card(
        margin: EdgeInsets.zero,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(_loadError!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    final canZoomOut = _zoom > _minZoom + 0.001;
    final canZoomIn = _zoom < _maxZoom - 0.001;

    return Card(
      margin: EdgeInsets.zero,
      elevation: AppElevation.low,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.document.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Tooltip(
                  message: canZoomOut
                      ? 'Zoom out'
                      : 'Already at the minimum zoom (${(_minZoom * 100).round()}%)',
                  child: IconButton(
                    onPressed: canZoomOut
                        ? () => _zoomByStep(-_zoomStep)
                        : null,
                    icon: const Icon(Icons.zoom_out),
                  ),
                ),
                Tooltip(
                  message: 'Reset to fit width',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    onTap: _resetToFitWidth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Text(
                        '${(_zoom * 100).round()}%',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: canZoomIn
                      ? 'Zoom in'
                      : 'Already at the maximum zoom (${(_maxZoom * 100).round()}%)',
                  child: IconButton(
                    onPressed: canZoomIn ? () => _zoomByStep(_zoomStep) : null,
                    icon: const Icon(Icons.zoom_in),
                  ),
                ),
                Tooltip(
                  message: 'Previous page',
                  child: IconButton(
                    onPressed: _currentPage > 1
                        ? () => _goToPage(_currentPage - 1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                  ),
                  child: Text(
                    '$_currentPage / $_totalPages',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Tooltip(
                  message: 'Next page',
                  child: IconButton(
                    onPressed: _currentPage < _totalPages
                        ? () => _goToPage(_currentPage + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  if (size != _viewportSize) {
                    _viewportSize = size;
                    if (!_loading && _pages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          if (_zoomMode == _ZoomMode.fitWidth ||
                              _zoomMode == _ZoomMode.fitPage) {
                            _recalculateLayout();
                          } else {
                            _recalculateLayoutAtFixedZoom();
                          }
                          _clampScroll();
                        });
                        _scheduleRenderVisible();
                      });
                    }
                  }
                  if (_loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return Focus(
                    focusNode: _focusNode,
                    onKeyEvent: _handleKey,
                    child: Listener(
                      onPointerSignal: _handlePointerSignal,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.basic,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _focusNode.requestFocus(),
                          onPanUpdate: (details) =>
                              _scrollBy(-details.delta.dx, -details.delta.dy),
                          child: ClipRect(child: _buildDocumentSurface()),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSurface() {
    final theme = Theme.of(context);
    final visible = _visiblePageIndices().toSet();
    // OverflowBox is load-bearing here, not decorative: the ancestor chain
    // (Expanded -> LayoutBuilder -> Focus/Listener/MouseRegion/
    // GestureDetector/ClipRect) all hands down TIGHT constraints pinned to
    // the viewport size. A plain SizedBox can't exceed a tight incoming
    // constraint — Flutter clamps it straight back down — so the
    // document-sized canvas below was silently being squeezed to viewport
    // size and clipped there by Stack's own bounds, regardless of the
    // Transform.translate scroll offset. Confirmed live: page images were
    // decoding and caching successfully, but nothing beyond roughly one
    // viewport-height ever painted, no matter how far you scrolled.
    // OverflowBox explicitly overrides the constraints handed to its
    // child, letting the real document-sized canvas lay out at full size;
    // the outer ClipRect (in build()) still clips the *painted* result
    // back down to the viewport.
    return OverflowBox(
      minWidth: 0,
      maxWidth: double.infinity,
      minHeight: 0,
      maxHeight: double.infinity,
      alignment: Alignment.topLeft,
      child: Transform.translate(
        offset: Offset(-_scrollX, -_scrollY),
        child: SizedBox(
          width: _documentWidth,
          height: _documentHeight,
          child: Stack(
            children: [
              for (var i = 0; i < _pages.length; i++)
                if (visible.contains(i))
                  Positioned(
                    left: _pages[i].left,
                    top: _pages[i].top,
                    width: _pages[i].width,
                    height: _pages[i].height,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _imageCache[i] != null
                          ? RawImage(
                              image: _imageCache[i],
                              width: _pages[i].width,
                              height: _pages[i].height,
                              fit: BoxFit.fill,
                            )
                          : Container(
                              color: theme.colorScheme.surfaceContainerHighest,
                            ),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}
