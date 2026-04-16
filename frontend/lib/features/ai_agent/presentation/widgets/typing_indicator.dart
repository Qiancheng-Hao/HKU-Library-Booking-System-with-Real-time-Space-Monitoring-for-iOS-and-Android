import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
        ),
        child: BouncingDots(color: cs.onSurfaceVariant),
      ),
    );
  }
}

class BouncingDots extends StatefulWidget {
  final Color color;
  const BouncingDots({super.key, required this.color});

  @override
  State<BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          size: const Size(36, 16),
          painter: _DotsPainter(
            progress: _controller.value,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _DotsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    const dotRadius = 4.0;
    const spacing = 5.0;
    const amplitude = 5.0;
    const totalWidth = 3 * dotRadius * 2 + 2 * spacing;
    final startX = (size.width - totalWidth) / 2 + dotRadius;
    final centerY = size.height / 2;

    for (int i = 0; i < 3; i++) {
      final phase = (progress - i / 3.0) % 1.0;
      final dy = -math.sin(phase * 2 * math.pi).abs() * amplitude;
      final cx = startX + i * (dotRadius * 2 + spacing);
      canvas.drawCircle(Offset(cx, centerY + dy), dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) =>
      old.progress != progress || old.color != color;
}
