import 'package:flutter/material.dart';

class ShimmerLoader extends StatefulWidget {
  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;
  final EdgeInsets padding;

  const ShimmerLoader({
    super.key,
    this.itemCount = 12,
    this.crossAxisCount = 5,
    this.aspectRatio = 0.60,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  State<ShimmerLoader> createState() => _ShimmerLoaderState();
}

class _ShimmerLoaderState extends State<ShimmerLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final o = 0.3 +
            0.3 * (_ctrl.value < 0.5 ? _ctrl.value * 2 : (1 - _ctrl.value) * 2);
        return GridView.builder(
          padding: widget.padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: widget.crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: widget.aspectRatio,
          ),
          itemCount: widget.itemCount,
          itemBuilder: (context, index) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                      color: const Color(0xFFE5E5EA).withValues(alpha: o)),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 12,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: const Color(0xFFE5E5EA).withValues(alpha: o),
                ),
              ),
              const SizedBox(height: 4),
              Container(
                height: 10,
                width: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  color: const Color(0xFFE5E5EA).withValues(alpha: o * 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
