import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';
import '../controllers/theme_controller.dart';
import '../routes/app_routes.dart';

class AnimatedHeader extends StatefulWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onCreateChat;
  final bool isLoggedIn;
  final String userName;
  final String userEmail;
  final String? userAvatarUrl;
  final VoidCallback? onLogout;
  final VoidCallback? onEditProfile;
  final VoidCallback? onPreferences;
  final ValueChanged<bool>? onMenuStateChanged;
  final ValueChanged<String>? onOpenConversation; // open chat by id

  const AnimatedHeader({
    super.key,
    this.onLogin,
    this.onCreateChat,
    this.isLoggedIn = false,
    this.userName = '',
    this.userEmail = '',
    this.userAvatarUrl,
    this.onLogout,
    this.onEditProfile,
    this.onPreferences,
    this.onMenuStateChanged,
    this.onOpenConversation,
  });

  @override
  State<AnimatedHeader> createState() => _AnimatedHeaderState();
}

class _AnimatedHeaderState extends State<AnimatedHeader>
    with TickerProviderStateMixin {
  bool _isMenuOpen = false;
  late AnimationController _menuController;
  late AnimationController _slideController;
  late Animation<double> _menuAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();

    // Animation controller for hamburger menu rotation
    _menuController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Animation controller for dropdown menu
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    // Hamburger menu rotation animation
    _menuAnimation =
        Tween<double>(
          begin: 0.0,
          end: 0.125, // 45 degrees (1/8 of a full rotation)
        ).animate(
          CurvedAnimation(parent: _menuController, curve: Curves.elasticOut),
        );

    // Scale animation for button press effect
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
    );

    // Color animation for button background
    _colorAnimation = ColorTween(begin: Colors.grey[100], end: Colors.grey[200])
        .animate(
          CurvedAnimation(parent: _menuController, curve: Curves.easeInOut),
        );

    // Dropdown animation for the menu panel
    _slideAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _menuController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  // Public method to allow parent to close the menu
  void closeMenuExternal() => _closeMenu();

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });

    if (_isMenuOpen) {
      _menuController.forward();
      _slideController.forward();
    } else {
      _menuController.reverse();
      _slideController.reverse();
    }

    // Notify parent about menu state change
    widget.onMenuStateChanged?.call(_isMenuOpen);
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
      });
      _menuController.reverse();
      _slideController.reverse();

      // Notify parent about menu state change
      widget.onMenuStateChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(20), // Rounded ends
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]!
                  : Colors.black87,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main header bar
              Container(
                height: 60,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    // Hamburger menu button
                    GestureDetector(
                      onTap: _toggleMenu,
                      child: AnimatedBuilder(
                        animation: Listenable.merge([
                          _menuAnimation,
                          _scaleAnimation,
                          _colorAnimation,
                        ]),
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Transform.rotate(
                              angle: _menuAnimation.value * 2 * 3.14159,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[800]
                                      : _colorAnimation.value,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Colors.grey[600]!
                                        : Colors.black87,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    _isMenuOpen ? Icons.close : Icons.menu,
                                    key: ValueKey(_isMenuOpen),
                                    color: Theme.of(context).iconTheme.color,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(width: 20),

                    // App logo with dynamiccube icon
                    Container(
                      width: 32,
                      height: 32,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Lottie.asset(
                        'assets/fonts/svgs/dynamiccube.json',
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    ),

                    const Spacer(),

                    // New chat button
                    GestureDetector(
                      onTap: widget.onCreateChat,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[800]
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? Colors.grey[600]!
                                : Colors.black87,
                          ),
                        ),
                        child: Icon(
                          Icons.add,
                          color: Theme.of(context).iconTheme.color,
                          size: 20,
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Theme toggle button
                    _buildThemeToggle(),

                    const SizedBox(width: 12),

                    // User avatar or login button
                    widget.isLoggedIn
                        ? GestureDetector(
                            onTap: _toggleMenu,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.black87),
                              ),
                              child:
                                  widget.userAvatarUrl != null &&
                                      widget.userAvatarUrl!.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(20),
                                      child: Image.network(
                                        widget.userAvatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return widget.userName.isNotEmpty
                                                  ? Center(
                                                      child: Text(
                                                        widget.userName[0]
                                                            .toUpperCase(),
                                                        style: const TextStyle(
                                                          fontFamily: 'Poppins',
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Colors.black87,
                                                        ),
                                                      ),
                                                    )
                                                  : const Icon(
                                                      Icons.person_outline,
                                                      color: Colors.grey,
                                                      size: 18,
                                                    );
                                            },
                                      ),
                                    )
                                  : widget.userName.isNotEmpty
                                  ? Center(
                                      child: Text(
                                        widget.userName[0].toUpperCase(),
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    )
                                  : const Icon(
                                      Icons.person_outline,
                                      color: Colors.grey,
                                      size: 18,
                                    ),
                            ),
                          )
                        : GestureDetector(
                            onTap: widget.onLogin,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.grey[600]!
                                      : Colors.black87,
                                ),
                              ),
                              child: Icon(
                                Icons.person_outline,
                                color: Theme.of(context).iconTheme.color,
                                size: 18,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              // Animated dropdown menu
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: _slideAnimation.value,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF1A1A1A)
                              : Colors.grey[50],
                          border: Border(
                            top: BorderSide(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[600]!
                                  : Colors.black87,
                              width: 1,
                            ),
                          ),
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.6,
                          ),
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // (Search moved to HomePage above conversations list)
                                  // Account section
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'Account',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurface,
                                        ),
                                      ),
                                      const SizedBox(height: 16),

                                      if (widget.isLoggedIn) ...[
                                        // User info
                                        Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color:
                                                Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? const Color(0xFF2C2C2C)
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  Theme.of(
                                                        context,
                                                      ).brightness ==
                                                      Brightness.dark
                                                  ? Colors.grey[600]!
                                                  : Colors.black87,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                widget.userName.isNotEmpty
                                                    ? widget.userName
                                                    : 'User',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                widget.userEmail,
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                  color:
                                                      Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.dark
                                                      ? Colors.grey[400]
                                                      : Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),

                                        // Edit profile button
                                        _buildSkeletonButton(
                                          icon: Icons.edit_outlined,
                                          text: 'Edit Profile',
                                          onTap: () {
                                            _closeMenu();
                                            Future.delayed(
                                              const Duration(milliseconds: 150),
                                              () {
                                                widget.onEditProfile?.call();
                                              },
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // Preferences button
                                        _buildSkeletonButton(
                                          icon: Icons.settings_outlined,
                                          text: 'Preferences',
                                          onTap: () {
                                            _closeMenu();
                                            Future.delayed(
                                              const Duration(milliseconds: 150),
                                              () {
                                                widget.onPreferences?.call();
                                              },
                                            );
                                          },
                                        ),

                                        const SizedBox(height: 12),

                                        // Logout button
                                        _buildSkeletonButton(
                                          icon: Icons.logout,
                                          text: 'Log Out',
                                          onTap: () {
                                            _closeMenu();
                                            Future.delayed(
                                              const Duration(milliseconds: 150),
                                              () {
                                                widget.onLogout?.call();
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Create new chat button
                                  _buildSkeletonButton(
                                    icon: Icons.add_circle_outline,
                                    text: 'Create New Chat',
                                    onTap: () {
                                      // Close menu first
                                      _closeMenu();
                                      // Call create chat after a small delay to let menu close
                                      Future.delayed(
                                        const Duration(milliseconds: 150),
                                        () {
                                          widget.onCreateChat?.call();
                                        },
                                      );
                                    },
                                    isPrimary: true,
                                  ),

                                  const SizedBox(height: 24),

                                  // Tools navigation
                                  _buildSkeletonButton(
                                    icon: Icons.archive_outlined,
                                    text: 'Chat Archive',
                                    onTap: () {
                                      _closeMenu();
                                      Future.delayed(const Duration(milliseconds: 150), () {
                                        Get.toNamed(AppRoutes.archive);
                                      });
                                    },
                                  ),
                                  const SizedBox(height: 12),
                                  // (Documents and Analytics moved near chat list search bar)
                                  const SizedBox(height: 12),
                                  // (Advanced Settings, Notifications, Feedback moved to Preferences page)
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeletonButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isPrimary
              ? (isDark ? Colors.white : Colors.black87)
              : (isDark ? const Color(0xFF2C2C2C) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.grey[600]! : Colors.black87,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPrimary
                  ? (isDark ? Colors.black87 : Colors.white)
                  : (isDark ? Colors.white : Colors.black87),
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isPrimary
                    ? (isDark ? Colors.black87 : Colors.white)
                    : (isDark ? Colors.white : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    final ThemeController themeController = Get.find<ThemeController>();

    return Obx(
      () => GestureDetector(
        onTap: () => themeController.toggleTheme(),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.grey[600]!
                  : Colors.black87,
            ),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: animation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              themeController.isDarkMode.value
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
              key: ValueKey(themeController.isDarkMode.value),
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.amber[300]
                  : Colors.black87,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }
}
