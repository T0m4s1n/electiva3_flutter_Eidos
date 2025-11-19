import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Animated wave background with flowing waves
class AnimatedWaveBackground extends StatefulWidget {
  final Widget child;
  final List<Color>? waveColors;
  final double? waveHeight;
  final double? waveSpeed;

  const AnimatedWaveBackground({
    super.key,
    required this.child,
    this.waveColors,
    this.waveHeight,
    this.waveSpeed,
  });

  @override
  State<AnimatedWaveBackground> createState() => _AnimatedWaveBackgroundState();
}

class _AnimatedWaveBackgroundState extends State<AnimatedWaveBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  List<WavePainter>? _waves;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_waves == null) {
      _initializeWaves();
    }
  }

  void _initializeWaves() {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Color> colors = widget.waveColors ??
        (isDark
            ? [
                const Color(0xFF1E3A8A).withValues(alpha: 0.3),
                const Color(0xFF3B82F6).withValues(alpha: 0.25),
                const Color(0xFF60A5FA).withValues(alpha: 0.2),
              ]
            : [
                const Color(0xFF3B82F6).withValues(alpha: 0.15),
                const Color(0xFF60A5FA).withValues(alpha: 0.12),
                const Color(0xFF93C5FD).withValues(alpha: 0.1),
              ]);

    _waves = List.generate(
      3,
      (index) => WavePainter(
        color: colors[index],
        height: (widget.waveHeight ?? 120) + (index * 40),
        speed: (widget.waveSpeed ?? 1.0) + (index * 0.2),
        offset: index * 0.3,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_waves == null) {
      return widget.child;
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WaveBackgroundPainter(
            waves: _waves!,
            animationValue: _controller.value,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _WaveBackgroundPainter extends CustomPainter {
  final List<WavePainter> waves;
  final double animationValue;

  _WaveBackgroundPainter({
    required this.waves,
    required this.animationValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final wave in waves) {
      wave.paint(canvas, size, animationValue);
    }
  }

  @override
  bool shouldRepaint(_WaveBackgroundPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class WavePainter {
  final Color color;
  final double height;
  final double speed;
  final double offset;

  WavePainter({
    required this.color,
    required this.height,
    required this.speed,
    required this.offset,
  });

  void paint(Canvas canvas, Size size, double animationValue) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();
    final double wavePhase = (animationValue * 2 * math.pi * speed) + (offset * 2 * math.pi);
    final double waveLength = size.width / 2;
    final double amplitude = height * 0.5;

    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 1) {
      final double y = size.height - amplitude -
          (amplitude * math.sin((x / waveLength) * 2 * math.pi + wavePhase));
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }
}

