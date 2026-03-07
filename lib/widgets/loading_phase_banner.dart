import 'dart:math' as math;

import 'package:flutter/material.dart';

enum LoadingBannerTone { idle, busy, success, error }

class LoadingPhaseBanner extends StatelessWidget {
  const LoadingPhaseBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.tone,
    this.showBusyAnimation = false,
    this.leadingIcon,
  });

  final String title;
  final String subtitle;
  final LoadingBannerTone tone;
  final bool showBusyAnimation;
  final IconData? leadingIcon;

  Color _foregroundColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      LoadingBannerTone.error => scheme.onErrorContainer,
      LoadingBannerTone.success => scheme.onSecondaryContainer,
      LoadingBannerTone.busy => scheme.onPrimaryContainer,
      LoadingBannerTone.idle => scheme.onSurfaceVariant,
    };
  }

  Color _backgroundColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return switch (tone) {
      LoadingBannerTone.error => scheme.errorContainer,
      LoadingBannerTone.success => scheme.secondaryContainer,
      LoadingBannerTone.busy => scheme.primaryContainer,
      LoadingBannerTone.idle => scheme.surfaceContainerHighest,
    };
  }

  IconData _fallbackIcon() {
    return switch (tone) {
      LoadingBannerTone.error => Icons.error_outline,
      LoadingBannerTone.success => Icons.check_circle_outline,
      LoadingBannerTone.busy => Icons.menu_book_outlined,
      LoadingBannerTone.idle => Icons.info_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final fg = _foregroundColor(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _backgroundColor(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          showBusyAnimation
              ? _BookFlipIndicator(color: fg)
              : Icon(leadingIcon ?? _fallbackIcon(), color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg.withValues(alpha: 0.90),
                  ),
                ),
              ],
            ),
          ),
          if (showBusyAnimation)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _BookFlipIndicator extends StatefulWidget {
  const _BookFlipIndicator({required this.color});

  final Color color;

  @override
  State<_BookFlipIndicator> createState() => _BookFlipIndicatorState();
}

class _BookFlipIndicatorState extends State<_BookFlipIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeInOutCubic.transform(_controller.value);
          final angle = -math.pi * t;
          final pageShade = 0.18 + (0.22 * (1 - math.cos(angle).abs()));

          return Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 2,
                right: 2,
                top: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.15),
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.85),
                      width: 1.1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                left: 4,
                top: 5,
                bottom: 5,
                width: 1.3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Positioned(
                left: 6,
                top: 5,
                bottom: 5,
                width: 11,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Positioned(
                left: 14.2,
                top: 5,
                bottom: 5,
                width: 10.4,
                child: Transform(
                  alignment: Alignment.centerLeft,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.004)
                    ..rotateY(angle),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72 - pageShade),
                      borderRadius: BorderRadius.circular(2.5),
                      border: Border.all(
                        color: widget.color.withValues(alpha: 0.30),
                        width: 0.8,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
