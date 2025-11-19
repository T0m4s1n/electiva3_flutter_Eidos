import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/auth_controller.dart';
import '../widgets/animated_intro_background.dart';
import '../routes/app_routes.dart';

class IntroAnimationPage extends StatefulWidget {
  const IntroAnimationPage({super.key});

  @override
  State<IntroAnimationPage> createState() => _IntroAnimationPageState();
}

class _IntroAnimationPageState extends State<IntroAnimationPage>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  late AnimationController _iconController;
  late AnimationController _titleController;
  late AnimationController _descriptionController;
  late AnimationController _featuresController;
  late AnimationController _securityController;

  late Animation<double> _iconScaleAnimation;
  late Animation<double> _iconFadeAnimation;
  late Animation<Offset> _iconSlideAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<Offset> _titleSlideAnimation;
  late Animation<double> _descriptionFadeAnimation;
  late Animation<Offset> _descriptionSlideAnimation;

  @override
  void initState() {
    super.initState();

    // Icon animations
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _iconScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _iconFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _iconSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _iconController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    // Title animations
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _titleSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _titleController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Description animations
    _descriptionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _descriptionFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _descriptionController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOut),
      ),
    );

    _descriptionSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _descriptionController,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Features animations
    _featuresController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Security message animation
    _securityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _startAnimations();
  }

  void _startAnimations() {
    _iconController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _descriptionController.forward();
    });
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _featuresController.forward();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _featuresController.dispose();
    _securityController.dispose();
    super.dispose();
  }

  void _nextPage() async {
    if (_isCompleting) return;

    if (_currentPage < 2) {
      _resetAnimations();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _isCompleting = true;
      await Future.delayed(const Duration(milliseconds: 200));
      await _completeIntro();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _resetAnimations();
      _pageController.previousPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _resetAnimations() {
    _iconController.reset();
    _titleController.reset();
    _descriptionController.reset();
    _featuresController.reset();
    _securityController.reset();
    _startAnimations();
  }

  Future<void> _completeIntro() async {
    try {
      final authController = Get.find<AuthController>();
      await authController.completeOnboarding();
      
      // Navigate to auth/login page
      Get.offNamed(AppRoutes.auth);
    } catch (e) {
      debugPrint('Error completing intro: $e');
      // Still navigate even if onboarding save fails
      Get.offNamed(AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: AnimatedIntroBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Skip button
              if (_currentPage < 2)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        TextButton.icon(
                          onPressed: _previousPage,
                          icon: Icon(
                            Icons.arrow_back_ios,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                          label: Text(
                            'Back',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      TextButton(
                        onPressed: _completeIntro,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Page indicator
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOutCubic,
                      width: _currentPage == index ? 32 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? (isDark ? Colors.white : Colors.black87)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.2)),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ),

              // Content with vertical scroll animation
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                    _resetAnimations();
                  },
                  children: [
                    _buildWelcomePage(isDark),
                    _buildProductivityPage(isDark),
                    _buildGetStartedPage(isDark),
                  ],
                ),
              ),

              // Navigation button
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(
                        scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOut,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: _isCompleting
                      ? SizedBox(
                          key: const ValueKey('loading'),
                          width: 48,
                          height: 48,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        )
                      : ElevatedButton(
                          key: ValueKey('button_$_currentPage'),
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isDark ? Colors.white : Colors.black87,
                            foregroundColor:
                                isDark ? Colors.black87 : Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            _currentPage < 2 ? 'Next' : 'Get Started',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomePage(bool isDark) {
    return _buildPage(
      isDark: isDark,
      lottieAsset: 'assets/fonts/svgs/chat.json',
      icon: Icons.wb_twilight_rounded,
      title: 'Welcome to Eidos',
      description:
          'Your intelligent AI companion designed to help you think, create, and accomplish more.',
      features: [
        'AI-Powered Conversations',
        'Smart Document Creation',
        'Intelligent Reminders',
        'Activity Analytics',
      ],
    );
  }

  Widget _buildProductivityPage(bool isDark) {
    return _buildPage(
      isDark: isDark,
      lottieAsset: 'assets/fonts/svgs/productivity.json',
      icon: Icons.rocket_launch_rounded,
      title: 'Boost Your Productivity',
      description:
          'Stay organized with intelligent reminders, track your activity with analytics, and sync across all your devices.',
      features: [
        'Smart reminder scheduling',
        'Activity analytics dashboard',
        'Cloud sync & backup',
        'Secure & private',
      ],
    );
  }

  Widget _buildGetStartedPage(bool isDark) {
    return _buildPage(
      isDark: isDark,
      lottieAsset: 'assets/fonts/svgs/work.json',
      icon: Icons.celebration_rounded,
      title: 'Ready to Begin?',
      description:
          'Start your journey with Eidos today. Create an account to save your conversations and unlock all features.',
      features: [
        'Quick setup in seconds',
        'Beautiful dark & light themes',
        'Multi-language support',
        'Your data, always secure',
      ],
      isLastPage: true,
    );
  }

  Widget _buildPage({
    required bool isDark,
    String? lottieAsset,
    required IconData icon,
    required String title,
    required String description,
    required List<String> features,
    bool isLastPage = false,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: 32.0,
            vertical: constraints.maxHeight * 0.1,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight * 0.8,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon/Lottie with smooth scale, fade, and slide animations
                    AnimatedBuilder(
                      animation: _iconController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            _iconSlideAnimation.value.dx,
                            _iconSlideAnimation.value.dy * 50,
                          ),
                          child: Transform.scale(
                            scale: _iconScaleAnimation.value,
                            child: Opacity(
                              opacity: _iconFadeAnimation.value,
                              child: lottieAsset != null
                                  ? Container(
                                      height: 180,
                                      width: 180,
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.05)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(90),
                                      ),
                                      child: Lottie.asset(
                                        lottieAsset,
                                        fit: BoxFit.contain,
                                        repeat: true,
                                        animate: true,
                                      ),
                                    )
                                  : Container(
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.1)
                                            : Colors.black.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.2)
                                              : Colors.black.withValues(alpha: 0.1),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        icon,
                                        size: 50,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Title with smooth fade, slide, and scale animations
                    AnimatedBuilder(
                      animation: _titleController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            _titleSlideAnimation.value.dx,
                            _titleSlideAnimation.value.dy * 50,
                          ),
                          child: Transform.scale(
                            scale: 0.95 + (_titleFadeAnimation.value * 0.05),
                            child: Opacity(
                              opacity: _titleFadeAnimation.value,
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Description with smooth fade and slide animations
                    AnimatedBuilder(
                      animation: _descriptionController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(
                            _descriptionSlideAnimation.value.dx,
                            _descriptionSlideAnimation.value.dy * 30,
                          ),
                          child: Opacity(
                            opacity: _descriptionFadeAnimation.value,
                            child: Text(
                              description,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.8)
                                    : Colors.black87.withValues(alpha: 0.7),
                                height: 1.6,
                                letterSpacing: 0.2,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 40),

                    // Features list with staggered animations
                    ...features.asMap().entries.map((entry) {
                      final int index = entry.key;
                      final String feature = entry.value;

                      final double delay = index * 0.12;
                      final double featureProgress = (delay < 1.0)
                          ? ((_featuresController.value - delay).clamp(0.0, 0.5) / 0.5)
                          .clamp(0.0, 1.0)
                          : 0.0;

                      return AnimatedBuilder(
                        animation: _featuresController,
                        builder: (context, child) {
                          final double value = featureProgress;
                          return Transform.translate(
                            offset: Offset(0, 25 * (1 - value)),
                            child: Transform.scale(
                              scale: 0.9 + (value * 0.1),
                              child: Opacity(
                                opacity: value,
                                child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0,
                                  vertical: 8.0,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.05)
                                        : Colors.black.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.1)
                                          : Colors.black.withValues(alpha: 0.08),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    feature,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white : Colors.black87,
                                      height: 1.4,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          );
                        },
                      );
                    }),

                    if (isLastPage) ...[
                      const SizedBox(height: 30),
                      AnimatedBuilder(
                        animation: _featuresController,
                        builder: (context, child) {
                          final double securityProgress = ((_featuresController.value - 0.6)
                                  .clamp(0.0, 0.4) / 0.4)
                              .clamp(0.0, 1.0);

                          return Transform.translate(
                            offset: Offset(0, 20 * (1 - securityProgress)),
                            child: Opacity(
                              opacity: securityProgress,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : Colors.black.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.08),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 18,
                                      color: isDark ? Colors.white70 : Colors.black54,
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Your data is encrypted and secure',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          color: isDark ? Colors.white70 : Colors.black54,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
