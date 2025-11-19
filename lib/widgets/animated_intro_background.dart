import 'package:flutter/material.dart';

/// Subtle animated background for intro screens
/// Features: simple vertical scroll animation matching app theme
class AnimatedIntroBackground extends StatefulWidget {
  final Widget child;

  const AnimatedIntroBackground({
    super.key,
    required this.child,
  });

  @override
  State<AnimatedIntroBackground> createState() => _AnimatedIntroBackgroundState();
}

class _AnimatedIntroBackgroundState extends State<AnimatedIntroBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _scrollController;

  @override
  void initState() {
    super.initState();
    
    _scrollController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedBuilder(
      animation: _scrollController,
      builder: (context, child) {
        return CustomPaint(
          painter: _ScrollBackgroundPainter(
            scrollValue: _scrollController.value,
            isDark: isDark,
            size: MediaQuery.of(context).size,
          ),
          child: widget.child,
        );
      },
    );
  }
}

class _ScrollBackgroundPainter extends CustomPainter {
  final double scrollValue;
  final bool isDark;
  final Size size;

  _ScrollBackgroundPainter({
    required this.scrollValue,
    required this.isDark,
    required this.size,
  });

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // Simple gradient background matching app theme
    final List<Color> colors = isDark
        ? [
            const Color(0xFF121212),
            const Color(0xFF1E1E1E),
            const Color(0xFF121212),
          ]
        : [
            Colors.white,
            const Color(0xFFF5F5F5),
            Colors.white,
          ];

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: const [0.0, 0.5, 1.0],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      Paint()..shader = gradient.createShader(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      ),
    );

    // Subtle vertical scroll lines (very subtle)
    final Paint linePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black)
          .withValues(alpha: isDark ? 0.03 : 0.02)
      ..strokeWidth = 1;

    final double lineSpacing = 40.0;
    final double scrollOffset = (scrollValue * lineSpacing * 2) % (lineSpacing * 2);

    for (double y = -lineSpacing + scrollOffset; y < canvasSize.height + lineSpacing; y += lineSpacing) {
      // Horizontal subtle lines
      canvas.drawLine(
        Offset(0, y),
        Offset(canvasSize.width, y),
        linePaint,
      );
    }

    // Very subtle vertical lines
    final double verticalLineSpacing = 60.0;
    final double verticalScrollOffset = (scrollValue * verticalLineSpacing * 2) % (verticalLineSpacing * 2);

    for (double x = -verticalLineSpacing + verticalScrollOffset; x < canvasSize.width + verticalLineSpacing; x += verticalLineSpacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, canvasSize.height),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ScrollBackgroundPainter oldDelegate) {
    return oldDelegate.scrollValue != scrollValue;
  }
}
