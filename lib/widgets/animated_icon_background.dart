import 'dart:math';
import 'package:flutter/material.dart';

/// A widget that displays an animated background of floating icons
/// Can be customized with different icon sets for different views
class AnimatedIconBackground extends StatefulWidget {
  final List<IconData> icons;
  final Color iconColor;
  final int iconCount;

  const AnimatedIconBackground({
    super.key,
    required this.icons,
    this.iconColor = const Color(0xFF606060),
    this.iconCount = 60,
  });

  @override
  State<AnimatedIconBackground> createState() => _AnimatedIconBackgroundState();
}

class _AnimatedIconBackgroundState extends State<AnimatedIconBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_FloatingIcon> _floatingIcons = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    _controller.addListener(() {
      setState(() {});
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_floatingIcons.isEmpty) {
      _initializeIcons();
    }
  }

  void _initializeIcons() {
    final Size size = MediaQuery.of(context).size;
    _floatingIcons.clear();

    for (int i = 0; i < widget.iconCount; i++) {
      _floatingIcons.add(_FloatingIcon(
        icon: widget.icons[_random.nextInt(widget.icons.length)],
        startX: _random.nextDouble() * size.width,
        startY: _random.nextDouble() * size.height,
        speedX: (_random.nextDouble() - 0.5) * 0.6,
        speedY: (_random.nextDouble() - 0.5) * 0.4,
        size: 24 + _random.nextDouble() * 24,
        opacity: 0.08 + _random.nextDouble() * 0.12,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 0.02,
        pulseSpeed: 0.8 + _random.nextDouble() * 1.0,
        pulseOffset: _random.nextDouble() * 2 * pi,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return CustomPaint(
      size: size,
      painter: _IconBackgroundPainter(
        icons: _floatingIcons,
        animation: _controller,
        color: widget.iconColor,
        canvasSize: size,
      ),
    );
  }
}

class _FloatingIcon {
  final IconData icon;
  final double startX;
  final double startY;
  final double speedX;
  final double speedY;
  final double size;
  final double opacity;
  final double rotation;
  final double rotationSpeed;
  final double pulseSpeed;
  final double pulseOffset;

  _FloatingIcon({
    required this.icon,
    required this.startX,
    required this.startY,
    required this.speedX,
    required this.speedY,
    required this.size,
    required this.opacity,
    required this.rotation,
    required this.rotationSpeed,
    required this.pulseSpeed,
    required this.pulseOffset,
  });
}

class _IconBackgroundPainter extends CustomPainter {
  final List<_FloatingIcon> icons;
  final Animation<double> animation;
  final Color color;
  final Size canvasSize;

  _IconBackgroundPainter({
    required this.icons,
    required this.animation,
    required this.color,
    required this.canvasSize,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    for (final floatingIcon in icons) {
      final double time = animation.value;
      
      // Calculate position with wrapping
      double x = (floatingIcon.startX + floatingIcon.speedX * time * canvasSize.width) % canvasSize.width;
      double y = (floatingIcon.startY + floatingIcon.speedY * time * canvasSize.height) % canvasSize.height;
      
      // Wrap negative positions
      if (x < 0) x += canvasSize.width;
      if (y < 0) y += canvasSize.height;

      // Calculate rotation
      final double currentRotation = floatingIcon.rotation + floatingIcon.rotationSpeed * time * 100;

      // Calculate pulsing scale (breathing effect)
      final double pulseValue = sin(floatingIcon.pulseSpeed * time * 2 * pi + floatingIcon.pulseOffset);
      final double scale = 0.94 + 0.12 * pulseValue;

      // Calculate pulsing opacity
      final double pulseOpacity = floatingIcon.opacity * (0.88 + 0.12 * pulseValue);

      // Save canvas state
      canvas.save();

      // Move to icon position, rotate and scale
      canvas.translate(x, y);
      canvas.rotate(currentRotation);
      canvas.scale(scale);

      // Draw icon
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(floatingIcon.icon.codePoint),
          style: TextStyle(
            fontFamily: floatingIcon.icon.fontFamily,
            package: floatingIcon.icon.fontPackage,
            fontSize: floatingIcon.size,
            color: color.withOpacity(pulseOpacity),
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(-textPainter.width / 2, -textPainter.height / 2),
      );

      // Restore canvas state
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_IconBackgroundPainter oldDelegate) {
    return true;
  }
}

/// Predefined icon sets for different views

class ChatIconBackground extends StatelessWidget {
  const ChatIconBackground({super.key});

  static const List<IconData> _chatIcons = [
    // Chat & Communication
    Icons.chat_bubble_outline,
    Icons.message_outlined,
    Icons.send_outlined,
    Icons.forum_outlined,
    Icons.comment_outlined,
    Icons.chat_outlined,
    Icons.question_answer_outlined,
    Icons.speaker_notes_outlined,
    Icons.mark_chat_unread_outlined,
    Icons.textsms_outlined,
    Icons.sms_outlined,
    
    // Ideas & Creativity
    Icons.lightbulb_outline,
    Icons.psychology_outlined,
    Icons.tips_and_updates_outlined,
    Icons.emoji_objects_outlined,
    Icons.wb_incandescent_outlined,
    Icons.auto_awesome_outlined,
    Icons.stars_outlined,
    
    // Technology & Code
    Icons.code_outlined,
    Icons.terminal_outlined,
    Icons.developer_mode_outlined,
    Icons.integration_instructions_outlined,
    Icons.data_object_outlined,
    
    // Content & Text
    Icons.text_snippet_outlined,
    Icons.description_outlined,
    Icons.article_outlined,
    Icons.notes_outlined,
    Icons.edit_outlined,
    
    // AI & Smart
    Icons.smart_toy_outlined,
    Icons.memory_outlined,
    Icons.psychology_alt_outlined,
    Icons.explore_outlined,
    Icons.settings_suggest_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedIconBackground(
      icons: _chatIcons,
      iconColor: isDark ? const Color(0xFF505050) : const Color(0xFF707070),
      iconCount: 60,
    );
  }
}

class DocumentIconBackground extends StatelessWidget {
  const DocumentIconBackground({super.key});

  static const List<IconData> _documentIcons = [
    Icons.description_outlined,
    Icons.article_outlined,
    Icons.folder_outlined,
    Icons.insert_drive_file_outlined,
    Icons.note_outlined,
    Icons.text_snippet_outlined,
    Icons.library_books_outlined,
    Icons.menu_book_outlined,
    Icons.list_alt_outlined,
    Icons.format_list_bulleted,
    Icons.fact_check_outlined,
    Icons.assignment_outlined,
    Icons.sticky_note_2_outlined,
    Icons.edit_note_outlined,
    Icons.text_fields_outlined,
    Icons.title_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AnimatedIconBackground(
      icons: _documentIcons,
      iconColor: isDark ? const Color(0xFF505050) : const Color(0xFF707070),
      iconCount: 60,
    );
  }
}

