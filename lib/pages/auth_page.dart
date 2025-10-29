import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/animated_icon_background.dart';

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final NavigationController navController = Get.find<NavigationController>();

    return Obx(() {
      if (authController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return AuthView(
        onBack: () => navController.hideAuth(),
        isLogin: navController.isLoginView.value,
        onToggleMode: () => navController.toggleAuthMode(),
        onLoginSuccess: (name, email) async {
          // Get user profile to get avatar URL
          try {
            final profile = await authController.getUserProfile();
            if (profile != null) {
              authController.userAvatarUrl.value = profile['avatar_url'] ?? '';
            }
          } catch (e) {
            debugPrint('Error loading user profile: $e');
          }

          navController.hideAuth();
        },
      );
    });
  }
}

class AuthView extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isLogin; // true for login, false for register
  final VoidCallback? onToggleMode; // Callback to switch between login/register
  final Function(String, String)?
  onLoginSuccess; // Callback for successful login

  const AuthView({
    super.key,
    this.onBack,
    this.isLogin = true,
    this.onToggleMode,
    this.onLoginSuccess,
  });

  @override
  State<AuthView> createState() => _AuthViewState();
}

class _AuthViewState extends State<AuthView> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _showSuccessAnimation = false;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0.0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();

    return Obx(() {
      if (authController.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      return FadeTransition(
        opacity: _fadeAnimation,
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Stack(
            children: [
              // Animated icon background
              const Positioned.fill(
                child: AuthIconBackground(),
              ),
              
              // Main content
              _showSuccessAnimation
              ? Center(
                child: Container(
                  width: 200,
                  height: 200,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Lottie.asset(
                    'assets/fonts/svgs/check.json',
                    fit: BoxFit.contain,
                  ),
                ),
              )
              : SafeArea(
                  child: SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: MediaQuery.of(context).size.height - 100,
                      ),
                      child: IntrinsicHeight(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                          children: [
                            const SizedBox(height: 20),

                            // Title centered without back button with animation
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                return FadeTransition(
                                  opacity: animation,
                                  child: child,
                                );
                              },
                              child: Text(
                                widget.isLogin
                                    ? 'Log In'
                                    : 'Create Account',
                                key: ValueKey(widget.isLogin),
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                              const SizedBox(height: 40),

                              // Auth form
                              SlideTransition(
                                position: _slideAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.black87),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Welcome text with animation
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          transitionBuilder:
                                              (Widget child, Animation<double> animation) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0, 0.1),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: Center(
                                            key: ValueKey('welcome_${widget.isLogin}'),
                                            child: Text(
                                              widget.isLogin
                                                  ? 'Welcome back!'
                                                  : 'Join Eidos today',
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 20,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.black87,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 8),

                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          transitionBuilder:
                                              (Widget child, Animation<double> animation) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position: Tween<Offset>(
                                                  begin: const Offset(0, 0.1),
                                                  end: Offset.zero,
                                                ).animate(animation),
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: Center(
                                            key: ValueKey('subtitle_${widget.isLogin}'),
                                            child: Text(
                                              widget.isLogin
                                                  ? 'Sign in to continue your journey'
                                                  : 'Create your account to get started',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 32),

                                        // Email field
                                        _buildTextField(
                                          controller: _emailController,
                                          label: 'Email',
                                          hint: 'Enter your email',
                                          icon: Icons.email_outlined,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter your email';
                                            }
                                            if (!RegExp(
                                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                            ).hasMatch(value)) {
                                              return 'Please enter a valid email';
                                            }
                                            return null;
                                          },
                                        ),

                                        const SizedBox(height: 20),

                                        // Password field
                                        _buildTextField(
                                          controller: _passwordController,
                                          label: 'Password',
                                          hint: 'Enter your password',
                                          icon: Icons.lock_outline,
                                          isPassword: true,
                                          isPasswordVisible: _isPasswordVisible,
                                          onTogglePassword: () {
                                            setState(() {
                                              _isPasswordVisible =
                                                  !_isPasswordVisible;
                                            });
                                          },
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Please enter your password';
                                            }
                                            if (value.length < 6) {
                                              return 'Password must be at least 6 characters';
                                            }
                                            return null;
                                          },
                                        ),

                                        // Confirm password field (only for register) with animation
                                        AnimatedSwitcher(
                                          duration: const Duration(milliseconds: 300),
                                          transitionBuilder:
                                              (Widget child, Animation<double> animation) {
                                            return FadeTransition(
                                              opacity: animation,
                                              child: SizeTransition(
                                                sizeFactor: animation,
                                                axisAlignment: -1.0,
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: !widget.isLogin
                                              ? Column(
                                                  key: const ValueKey('confirm_password'),
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.stretch,
                                                  children: [
                                                    const SizedBox(height: 20),
                                                    _buildTextField(
                                                      controller:
                                                          _confirmPasswordController,
                                                      label: 'Confirm Password',
                                                      hint: 'Confirm your password',
                                                      icon: Icons.lock_outline,
                                                      isPassword: true,
                                                      isPasswordVisible:
                                                          _isConfirmPasswordVisible,
                                                      onTogglePassword: () {
                                                        setState(() {
                                                          _isConfirmPasswordVisible =
                                                              !_isConfirmPasswordVisible;
                                                        });
                                                      },
                                                      validator: (value) {
                                                        if (value == null ||
                                                            value.isEmpty) {
                                                          return 'Please confirm your password';
                                                        }
                                                        if (value !=
                                                            _passwordController.text) {
                                                          return 'Passwords do not match';
                                                        }
                                                        return null;
                                                      },
                                                    ),
                                                  ],
                                                )
                                              : const SizedBox.shrink(key: ValueKey('no_confirm_password')),
                                        ),

                                        const SizedBox(height: 32),

                                        // Submit button
                                        GestureDetector(
                                          onTap: _handleSubmit,
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.black87,
                                              ),
                                            ),
                                            child: Text(
                                              widget.isLogin
                                                  ? 'Log In'
                                                  : 'Create Account',
                                              style: const TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 20),

                                        // Divider
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Divider(
                                                color: Colors.grey[300],
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                              child: Text(
                                                'or',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                color: Colors.grey[300],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 20),

                                        // Google login button
                                        GestureDetector(
                                          onTap: _handleGoogleAuth,
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.black87,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.g_mobiledata,
                                                  color: Colors.red[600],
                                                  size: 24,
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  'Continue with Google',
                                                  style: const TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),

                                        const SizedBox(height: 24),

                                        // Switch between login/register
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              widget.isLogin
                                                  ? "Don't have an account? "
                                                  : "Already have an account? ",
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () {
                                                // Use the callback to switch between login/register
                                                widget.onToggleMode?.call();
                                              },
                                              child: Text(
                                                widget.isLogin
                                                    ? 'Sign Up'
                                                    : 'Sign In',
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),

                                        // Forgot password (only for login)
                                        if (widget.isLogin) ...[
                                          const SizedBox(height: 16),
                                          Center(
                                            child: GestureDetector(
                                              onTap: _handleForgotPassword,
                                              child: Text(
                                                'Forgot Password?',
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.blue[600],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),
                            ],
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
    });
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword && !isPasswordVisible,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              fontFamily: 'Poppins',
              color: Colors.grey[500],
            ),
            prefixIcon: Icon(icon, color: Colors.grey[600], size: 20),
            suffixIcon: isPassword
                ? GestureDetector(
                    onTap: onTogglePassword,
                    child: Icon(
                      isPasswordVisible
                          ? Icons.visibility_off
                          : Icons.visibility,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.black87),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  void _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      final AuthController authController = Get.find<AuthController>();

      try {
        if (widget.isLogin) {
          // Handle login
          final response = await authController.signIn(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

          if (response.user != null && widget.onLoginSuccess != null) {
            // Show success animation
            if (mounted) {
              setState(() {
                _showSuccessAnimation = true;
              });
            }

            // Wait for animation to complete, then proceed
            await Future.delayed(const Duration(milliseconds: 1500));

            // Get user profile
            final profile = await authController.getUserProfile();
            final name =
                profile?['full_name'] ??
                response.user!.userMetadata?['full_name'] ??
                response.user!.email?.split('@')[0] ??
                'User';
            final email = response.user!.email ?? '';

            widget.onLoginSuccess!(name, email);
          }
        } else {
          // Handle registration
          final response = await authController.signUp(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _emailController.text.split(
              '@',
            )[0], // Use email prefix as name
          );

          if (response.user != null && widget.onLoginSuccess != null) {
            // Show success animation for registration
            if (mounted) {
              setState(() {
                _showSuccessAnimation = true;
              });
            }

            // Wait for animation to complete
            await Future.delayed(const Duration(milliseconds: 1500));

            // Get user profile
            final profile = await authController.getUserProfile();
            final name =
                profile?['full_name'] ??
                response.user!.userMetadata?['full_name'] ??
                response.user!.email?.split('@')[0] ??
                'User';
            final email = response.user!.email ?? '';

            // Automatically sign in the user
            widget.onLoginSuccess!(name, email);
          }
        }
      } catch (e) {
        if (mounted) {
          // Check if it's a "user already exists" error
          final bool isUserExistsError = e.toString().contains('User already registered');
          
          await _showErrorDialog(
            title: widget.isLogin ? 'Login Failed' : 'Registration Failed',
            message: _getErrorMessage(e.toString()),
          );
          
          // If user already exists and we're in register mode, switch to login
          if (isUserExistsError && !widget.isLogin && widget.onToggleMode != null) {
            widget.onToggleMode!();
          }
        }
      } finally {
        if (mounted) {
          setState(() {
            _showSuccessAnimation = false;
          });
        }
      }
    }
  }

  void _handleGoogleAuth() async {
    final AuthController authController = Get.find<AuthController>();

    try {
      // Handle Google authentication
      await authController.signInWithGoogle();

      // Show success animation
      if (mounted) {
        setState(() {
          _showSuccessAnimation = true;
        });
      }

      // Wait for animation to complete
      await Future.delayed(const Duration(milliseconds: 1500));

      // Note: OAuth redirects will be handled by the auth state listener
      // This is a placeholder implementation
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          title: 'Authentication Failed',
          message: _getErrorMessage(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _showSuccessAnimation = false;
        });
      }
    }
  }

  void _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showErrorDialog(
        title: 'Email Required',
        message: 'Please enter your email address first to reset your password.',
      );
      return;
    }

    final AuthController authController = Get.find<AuthController>();

    try {
      await authController.resetPassword(_emailController.text.trim());

      if (mounted) {
        // Show success dialog instead of snackbar
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.all(24),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green[600],
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Email Sent',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Password reset email sent! Please check your inbox and follow the instructions.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black87),
                    ),
                    child: const Text(
                      'Got It',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          title: 'Reset Failed',
          message: _getErrorMessage(e.toString()),
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Invalid email or password. Please check your credentials and try again.';
    } else if (error.contains('User already registered')) {
      return 'An account with this email already exists. Please sign in instead or use a different email.';
    } else if (error.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long. Please choose a stronger password.';
    } else if (error.contains('Invalid email')) {
      return 'Please enter a valid email address.';
    } else if (error.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account before signing in.';
    } else if (error.contains('Too many requests')) {
      return 'Too many attempts. Please wait a few minutes and try again.';
    } else if (error.contains('Email rate limit exceeded')) {
      return 'Too many password reset requests. Please wait a few minutes before trying again.';
    } else if (error.contains('User not found')) {
      return 'No account found with this email. Please check your email or create a new account.';
    } else {
      return 'An error occurred. Please try again or contact support if the problem persists.';
    }
  }

  Future<void> _showErrorDialog({required String title, required String message}) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated Error Icon with Pulse Effect
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      return Transform.scale(
                        scale: 0.5 + (0.5 * value.clamp(0.0, 1.0)),
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Lottie.asset(
                              'assets/fonts/svgs/alert.json',
                              fit: BoxFit.contain,
                              repeat: false,
                              width: 80,
                              height: 80,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Message
                  Text(
                    message,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 28),
                  
                  // Close Button with animation
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: child,
                        ),
                      );
                    },
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[600]!, Colors.red[700]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Try Again',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
