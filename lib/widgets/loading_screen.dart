import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingScreen extends StatefulWidget {
  final String? message;
  final bool showMessage;
  final Duration? duration;

  const LoadingScreen({
    super.key,
    this.message,
    this.showMessage = true,
    this.duration,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );

    _fadeController.forward();

    // Auto-hide after duration if specified
    // Note: Only pop if we're in a navigator context (as a route/dialog)
    // If used directly as a widget, rely on parent state management
    if (widget.duration != null) {
      Future.delayed(widget.duration!, () {
        if (mounted) {
          _fadeController.reverse().then((_) {
            if (mounted && Navigator.canPop(context)) {
              Navigator.of(context).pop();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Quad cube animation
              Container(
                width: 200,
                height: 200,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Lottie.asset(
                  'assets/fonts/svgs/quadcube.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ),

              const SizedBox(height: 40),

              // Loading message
              if (widget.showMessage)
                Text(
                  widget.message ?? 'Loading...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Utility class for showing loading screens
class LoadingOverlay {
  static OverlayEntry? _overlayEntry;

  static void show(
    BuildContext context, {
    String? message,
    bool showMessage = true,
    Duration? duration,
  }) {
    if (_overlayEntry != null) return;

    _overlayEntry = OverlayEntry(
      builder: (context) => LoadingScreen(
        message: message,
        showMessage: showMessage,
        duration: duration,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
