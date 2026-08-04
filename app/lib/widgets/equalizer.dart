import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animated equalizer bars used as a "now playing" indicator.
/// Animates while [active] is true, otherwise shows static low bars.
class Equalizer extends StatefulWidget {
  const Equalizer({
    super.key,
    this.active = true,
    this.color = AppColors.accent,
    this.barCount = 4,
    this.height = 18,
    this.width = 20,
    this.speed = 1.0,
  });

  final bool active;
  final Color color;
  final int barCount;
  final double height;
  final double width;
  final double speed;

  @override
  State<Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final math.Random _rand = math.Random();
  late List<double> _heights;

  @override
  void initState() {
    super.initState();
    _heights = List.generate(
      widget.barCount,
      (_) => 0.3 + _rand.nextDouble() * 0.3,
    );
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (900 / widget.speed).round()),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(Equalizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.repeat();
    } else if (!widget.active && oldWidget.active) {
      _controller.stop();
      _controller.value = 0;
    }
    if (widget.active && widget.speed != oldWidget.speed) {
      _controller.duration = Duration(
        milliseconds: (900 / widget.speed).round(),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final barWidth = widget.width / (widget.barCount * 1.6);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.barCount, (i) {
            // Smooth pseudo-random bounce per bar.
            final wave = 0.6 + 0.4 * math.sin(i * 2.3 + t * 2 * math.pi);
            final jitter = _rand.nextDouble() * 0.3;
            final heightFactor = widget.active
                ? (wave * 0.5 + 0.5) * 0.55 + jitter
                : 0.25;
            final h = (widget.height * heightFactor).clamp(3.0, widget.height);
            return Container(
              width: barWidth,
              height: h,
              margin: EdgeInsets.symmetric(horizontal: barWidth * 0.4),
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(barWidth),
              ),
            );
          }),
        );
      },
    );
  }
}
