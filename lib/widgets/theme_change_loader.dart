import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/theme_controller.dart';

class ThemeChangeLoader extends StatefulWidget {
  const ThemeChangeLoader({super.key});

  @override
  State<ThemeChangeLoader> createState() => _ThemeChangeLoaderState();
}

class _ThemeChangeLoaderState extends State<ThemeChangeLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
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
    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(
      () {
        if (themeController.isChangingTheme.value) {
          // Start animation when theme change begins
          _controller.forward();
        } else {
          // Reverse animation when theme change ends
          _controller.reverse();
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (_controller.value == 0.0) {
              return const SizedBox.shrink();
            }

            return IgnorePointer(
              ignoring: _controller.value < 0.5,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: Stack(
                  children: [
                    // Glass effect background with blur
                    BackdropFilter(
                      filter: ImageFilter.blur(
                        sigmaX: 10,
                        sigmaY: 10,
                      ),
                      child: Container(
                        width: double.infinity,
                        height: double.infinity,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    // Additional opaque layer for better coverage
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.3),
                    ),
                    // Centered icon
                    Center(
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.15)
                                : Colors.black.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.15),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Obx(
                              () => Icon(
                                themeController.isDarkMode.value
                                    ? Icons.dark_mode
                                    : Icons.light_mode,
                                size: 60,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

