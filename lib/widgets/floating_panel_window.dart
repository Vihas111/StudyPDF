import 'package:flutter/material.dart';

class FloatingPanelWindow extends StatelessWidget {
  const FloatingPanelWindow({
    super.key,
    required this.title,
    required this.offset,
    required this.size,
    required this.onDrag,
    required this.onResize,
    required this.onAttach,
    required this.child,
  });

  final String title;
  final Offset offset;
  final Size size;
  final ValueChanged<Offset> onDrag;
  final ValueChanged<Size> onResize;
  final VoidCallback onAttach;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: offset.dx,
      top: offset.dy,
      width: size.width,
      height: size.height,
      child: Material(
        elevation: 12,
        borderRadius: BorderRadius.circular(10),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              GestureDetector(
                onPanUpdate: (details) {
                  onDrag(offset + details.delta);
                },
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Attach panel',
                        onPressed: onAttach,
                        icon: const Icon(Icons.push_pin_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(child: child),
              Align(
                alignment: Alignment.bottomRight,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    onResize(
                      Size(
                        size.width + details.delta.dx,
                        size.height + details.delta.dy,
                      ),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.open_in_full, size: 16),
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
