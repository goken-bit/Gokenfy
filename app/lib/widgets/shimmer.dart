import 'package:flutter/material.dart';

import '../core/theme.dart';

/// A pulsing gradient placeholder shown while content loads.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.width = 120,
    this.height = 120,
    this.radius = 10,
    this.baseColor = AppColors.surfaceAlt,
    this.highlightColor = const Color(0xFF3A3A3A),
  });

  final double width;
  final double height;
  final double radius;
  final Color baseColor;
  final Color highlightColor;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Alignment> _alignment;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _alignment = TweenSequence<Alignment>([
      TweenSequenceItem(
        tween: Tween(
          begin: const Alignment(-2.2, 0.0),
          end: const Alignment(2.2, 0.0),
        ),
        weight: 1,
      ),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _alignment,
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: _alignment.value,
            end: Alignment.center,
            colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
          ),
        ),
      ),
    );
  }
}
