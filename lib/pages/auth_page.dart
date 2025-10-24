import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';

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
          backgroundColor: Colors.white,
          body: _showSuccessAnimation
              ? Center(
                  child: SizedBox(
                    width: 200,
                    height: 200,
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

                              // Back button
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: widget.onBack,
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: Colors.black87,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.arrow_back,
                                        color: Colors.black87,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    widget.isLogin
                                        ? 'Log In'
                                        : 'Create Account',
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ],
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
                                        // Welcome text
                                        Center(
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

                                        const SizedBox(height: 8),

                                        Center(
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

                                        // Confirm password field (only for register)
                                        if (!widget.isLogin) ...[
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
          Get.snackbar(
            'Error',
            _getErrorMessage(e.toString()),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3),
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
        Get.snackbar(
          'Error',
          _getErrorMessage(e.toString()),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
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
      Get.snackbar(
        'Warning',
        'Please enter your email address first',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    final AuthController authController = Get.find<AuthController>();

    try {
      await authController.resetPassword(_emailController.text.trim());

      if (mounted) {
        Get.snackbar(
          'Success',
          'Password reset email sent! Check your inbox.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (mounted) {
        Get.snackbar(
          'Error',
          _getErrorMessage(e.toString()),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    if (error.contains('Invalid login credentials')) {
      return 'Invalid email or password';
    } else if (error.contains('User already registered')) {
      return 'An account with this email already exists';
    } else if (error.contains('Password should be at least')) {
      return 'Password must be at least 6 characters long';
    } else if (error.contains('Invalid email')) {
      return 'Please enter a valid email address';
    } else if (error.contains('Email not confirmed')) {
      return 'Please check your email and confirm your account';
    } else if (error.contains('Too many requests')) {
      return 'Too many attempts. Please try again later';
    } else {
      return 'An error occurred. Please try again';
    }
  }
}
