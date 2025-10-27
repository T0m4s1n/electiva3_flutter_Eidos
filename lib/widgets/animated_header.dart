import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AnimatedHeader extends StatefulWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onCreateChat;
  final bool isLoggedIn;
  final String userName;
  final String userEmail;
  final String? userAvatarUrl;
  final VoidCallback? onLogout;
  final VoidCallback? onEditProfile;

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
  }

  void _closeMenu() {
    if (_isMenuOpen) {
      setState(() {
        _isMenuOpen = false;
      });
      _menuController.reverse();
      _slideController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20), // Rounded ends
        border: Border.all(color: Colors.black87, width: 1.5),
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
                              color: _colorAnimation.value,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.black87),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
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
                                color: Colors.black87,
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
                SizedBox(
                  width: 32,
                  height: 32,
                  child: Lottie.asset(
                    'assets/fonts/svgs/dynamiccube.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),

                const Spacer(),

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
                                    errorBuilder: (context, error, stackTrace) {
                                      return widget.userName.isNotEmpty
                                          ? Center(
                                              child: Text(
                                                widget.userName[0]
                                                    .toUpperCase(),
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
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black87),
                          ),
                          child: const Icon(
                            Icons.person_outline,
                            color: Colors.grey,
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
                      color: Colors.grey[50],
                      border: Border(
                        top: BorderSide(color: Colors.black87, width: 1),
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
                              // Account section
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const Text(
                                    'Account',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // Create new chat button
                                  _buildSkeletonButton(
                                    icon: Icons.add_circle_outline,
                                    text: 'Create New Chat',
                                    onTap: () {
                                      // Close menu first
                                      _closeMenu();
                                      // Call create chat after a small delay to let menu close
                                      Future.delayed(const Duration(milliseconds: 150), () {
                                        widget.onCreateChat?.call();
                                      });
                                    },
                                    isPrimary: true,
                                  ),

                                  const SizedBox(height: 12),

                                  if (widget.isLoggedIn) ...[
                                    // User info
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black87,
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
                                            style: const TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.black87,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            widget.userEmail,
                                            style: TextStyle(
                                              fontFamily: 'Poppins',
                                              fontSize: 14,
                                              color: Colors.grey[600],
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
                                        Future.delayed(const Duration(milliseconds: 150), () {
                                          widget.onEditProfile?.call();
                                        });
                                      },
                                    ),

                                    const SizedBox(height: 12),

                                    // Logout button
                                    _buildSkeletonButton(
                                      icon: Icons.logout,
                                      text: 'Log Out',
                                      onTap: () {
                                        _closeMenu();
                                        Future.delayed(const Duration(milliseconds: 150), () {
                                          widget.onLogout?.call();
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),

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
    );
  }

  Widget _buildSkeletonButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isPrimary ? Colors.black87 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black87, width: 1.5),
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
              color: isPrimary ? Colors.white : Colors.black87,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: isPrimary ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
