import 'package:flutter/material.dart';

import 'package:studypdf/core/theme/design_tokens.dart';

/// A reusable hover-reactive surface for desktop panels.
///
/// Wraps [child] in a [MouseRegion] and animates its background/elevation
/// on hover, per CLAUDE.md's requirement that every interactive desktop
/// surface have an explicit hover state instead of relying on touch-first
/// defaults. This widget is new in Phase 0 and is not yet wired into
/// existing panels — later phases can adopt it incrementally.
class HoverSurface extends StatefulWidget {
  const HoverSurface({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.hoverColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppRadii.md)),
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.elevation = AppElevation.none,
    this.hoverElevation = AppElevation.low,
    this.cursor = SystemMouseCursors.click,
    this.duration = const Duration(milliseconds: 120),
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Color? hoverColor;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final double elevation;
  final double hoverElevation;
  final MouseCursor cursor;
  final Duration duration;

  @override
  State<HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<HoverSurface> {
  bool _hovering = false;

  void _setHovering(bool value) {
    if (_hovering == value) {
      return;
    }
    setState(() {
      _hovering = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseColor = widget.color ?? Colors.transparent;
    final hoverColor = widget.hoverColor ?? scheme.surfaceContainerHighest;

    return MouseRegion(
      cursor: widget.cursor,
      onEnter: (_) => _setHovering(true),
      onExit: (_) => _setHovering(false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: widget.duration,
          curve: Curves.easeOut,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _hovering ? hoverColor : baseColor,
            borderRadius: widget.borderRadius,
            boxShadow: _hovering && widget.hoverElevation > 0
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: widget.hoverElevation,
                      offset: Offset(0, widget.hoverElevation / 2),
                    ),
                  ]
                : (widget.elevation > 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: widget.elevation,
                            offset: Offset(0, widget.elevation / 2),
                          ),
                        ]
                      : null),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
