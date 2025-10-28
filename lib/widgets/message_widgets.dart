import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:async';
import '../models/chat_models.dart';

class MessageBubble extends StatefulWidget {
  final MessageLocal message;
  final bool isUser;
  final bool animateTyping;
  final VoidCallback? onTap;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isUser,
    this.animateTyping = true,
    this.onTap,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  String _displayText = '';
  bool _isTyping = false;
  Timer? _typingTimer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.isUser && widget.animateTyping) {
      _startTypingAnimation();
    } else {
      _displayText = _getMessageText();
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }

  void _startTypingAnimation() {
    final String fullText = _getMessageText();
    _isTyping = true;
    _currentIndex = 0;
    _displayText = '';
    
    _typeNextChar(fullText);
  }

  void _typeNextChar(String fullText) {
    if (_currentIndex >= fullText.length) {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _displayText = fullText.substring(0, _currentIndex + 1);
      _currentIndex++;
    });

    // Calculate delay based on the character and position
    final Duration delay = _calculateTypingDelay(
      fullText,
      _currentIndex - 1,
    );

    _typingTimer = Timer(delay, () {
      _typeNextChar(fullText);
    });
  }

  Duration _calculateTypingDelay(String text, int index) {
    if (index < 0 || index >= text.length) {
      return const Duration(milliseconds: 35);
    }

    final String char = text[index];
    final String nextChar = index + 1 < text.length ? text[index + 1] : '';

    // Pause longer after punctuation
    if (char == '.' || char == '!' || char == '?') {
      return const Duration(milliseconds: 300);
    }
    if (char == ',' || char == ';' || char == ':') {
      return const Duration(milliseconds: 150);
    }
    
    // Pause after newlines
    if (char == '\n') {
      return const Duration(milliseconds: 200);
    }

    // Longer pause after multiple spaces
    if (char == ' ' && nextChar == ' ') {
      return const Duration(milliseconds: 100);
    }

    // Vary speed based on characters
    if (char == ' ') {
      return const Duration(milliseconds: 50);
    }

    // Vary typing speed slightly for more realistic feel
    if (_isVowel(char)) {
      return Duration(milliseconds: 30 + (index % 10));
    } else if (char == char.toUpperCase() && char != 'I' && char != 'A') {
      return Duration(milliseconds: 40 + (index % 15));
    }

    return Duration(milliseconds: 35 + (index % 8));
  }

  bool _isVowel(String char) {
    final String lower = char.toLowerCase();
    return lower == 'a' || 
           lower == 'e' || 
           lower == 'i' || 
           lower == 'o' || 
           lower == 'u';
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: widget.isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.isUser) ...[
            // AI Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.grey[600]! : Colors.black87,
                ),
              ),
              child: Icon(
                Icons.smart_toy,
                color: Theme.of(context).iconTheme.color,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Message content
          Flexible(
            child: GestureDetector(
              onTap: widget.onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: widget.isUser 
                      ? (isDark ? Colors.white : Colors.black87)
                      : (isDark ? const Color(0xFF2C2C2C) : Colors.grey[50]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: widget.onTap != null && !widget.isUser 
                      ? Colors.blue[700]! 
                      : (isDark ? Colors.grey[600]! : Colors.black87),
                    width: widget.onTap != null && !widget.isUser ? 2 : 1,
                  ),
                  boxShadow: widget.onTap != null && !widget.isUser
                    ? [
                        BoxShadow(
                          color: Colors.blue.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_shouldShowCreatingAnimation() && !widget.isUser)
                      // Show creating animation
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white.withOpacity(0.1)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(75),
                              ),
                              child: Lottie.asset(
                                'assets/fonts/svgs/creating.json',
                                fit: BoxFit.contain,
                                repeat: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _displayText.isEmpty ? _getMessageText() : _displayText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                color: widget.isUser 
                                    ? (isDark ? Colors.black87 : Colors.white)
                                    : Theme.of(context).colorScheme.onSurface,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      // Regular message display
                      Text(
                        widget.isUser ? _getMessageText() : _displayText,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: widget.isUser 
                              ? (isDark ? Colors.black87 : Colors.white)
                              : Theme.of(context).colorScheme.onSurface,
                          height: 1.4,
                        ),
                      ),
                    if (_isTyping && !widget.isUser && !_shouldShowCreatingAnimation())
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: SizedBox(
                          height: 16,
                          width: 8,
                          child: const _TypingCursor(),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      _formatTime(widget.message.createdAt),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        color: widget.isUser 
                            ? (isDark ? Colors.grey[700] : Colors.grey[300])
                            : (isDark ? Colors.grey[500] : Colors.grey[600]),
                      ),
                    ),
                    if (widget.onTap != null && !widget.isUser)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[700]!, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description,
                                size: 24,
                                color: Colors.blue[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Tap to Open Document',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.blue[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward,
                                size: 20,
                                color: Colors.blue[700],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          if (widget.isUser) ...[
            const SizedBox(width: 12),
            // User Avatar
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black87,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              child: Icon(
                Icons.person,
                color: isDark ? Colors.black87 : Colors.white,
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getMessageText() {
    final dynamic content = widget.message.content;
    String text;
    if (content is Map<String, dynamic>) {
      text = content['text'] as String? ?? content.toString();
    } else {
      text = content.toString();
    }
    
    // Remove the animation marker
    if (text.contains('[ANIMATED_CREATING]')) {
      text = text.replaceAll('[ANIMATED_CREATING]', '');
    }
    
    return text;
  }
  
  bool _shouldShowCreatingAnimation() {
    final String text = _getMessageText();
    return text.contains('Creating your document');
  }

  String _formatTime(String isoString) {
    try {
      final DateTime dateTime = DateTime.parse(isoString);
      final DateTime now = DateTime.now();
      final Duration difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Just now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays < 1) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }
}

class _TypingCursor extends StatefulWidget {
  const _TypingCursor();

  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 2,
        height: 16,
        color: Colors.black87,
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // AI Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.black87,
              ),
            ),
            child: Icon(
              Icons.smart_toy,
              color: Theme.of(context).iconTheme.color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),

          // Typing bubble
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[600]! : Colors.black87,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 600),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        final double delay = index * 0.2;
        final double animationValue = (value - delay).clamp(0.0, 1.0);
        final double opacity = (animationValue * 2 - 1).abs();
        final bool isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black87).withOpacity(opacity),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      },
    );
  }
}

class ChatInput extends StatefulWidget {
  final VoidCallback? onSend;
  final TextEditingController controller;
  final bool isLoading;

  const ChatInput({
    super.key,
    this.onSend,
    required this.controller,
    this.isLoading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          ),
        ),
      ),
      child: Row(
        children: [
          // Message input
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? Colors.grey[600]! : Colors.black87,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'Type your message...',
                  hintStyle: TextStyle(
                    fontFamily: 'Poppins',
                    color: isDark ? Colors.grey[500] : Colors.grey[500],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.newline,
                onChanged: (value) {
                  // Handle text changes if needed
                },
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty && !widget.isLoading) {
                    widget.onSend?.call();
                  }
                },
              ),
            ),
          ),

          const SizedBox(width: 12),

          // Send button
          GestureDetector(
            onTap: widget.isLoading ? null : widget.onSend,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.isLoading 
                    ? Colors.grey[300] 
                    : (isDark ? Colors.white : Colors.black87),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark 
                      ? (widget.isLoading ? Colors.grey[300]! : Colors.white)
                      : Colors.black87,
                ),
              ),
              child: widget.isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          isDark ? Colors.black87 : Colors.white,
                        ),
                      ),
                    )
                  : Icon(
                      Icons.send,
                      color: isDark ? Colors.black87 : Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
