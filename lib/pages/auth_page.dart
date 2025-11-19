import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:lottie/lottie.dart';
import '../controllers/auth_controller.dart';
import '../controllers/navigation_controller.dart';
import '../widgets/animated_icon_background.dart';
import '../services/translation_service.dart';
import '../services/passkey_service.dart' as passkey;

class AuthPage extends StatelessWidget {
  const AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthController authController = Get.find<AuthController>();
    final NavigationController navController = Get.find<NavigationController>();

    return Obx(() {
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
  bool _emailValidated = false;
  bool _hasPasskey = false;
  bool _checkingPasskey = false;
  String? _selectedLoginMethod; // 'password' or 'passkey'

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

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            // Animated icon background
            const Positioned.fill(child: AuthIconBackground()),

            // Main content
            _showSuccessAnimation
                ? Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.1)
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
                                      (
                                        Widget child,
                                        Animation<double> animation,
                                      ) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: child,
                                        );
                                      },
                                  child: Obx(
                                    () => Text(
                                    widget.isLogin
                                          ? TranslationService.translate('login')
                                          : TranslationService.translate('register'),
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
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            transitionBuilder:
                                                (
                                                  Widget child,
                                                  Animation<double> animation,
                                                ) {
                                                  return FadeTransition(
                                                    opacity: animation,
                                                    child: SlideTransition(
                                                      position: Tween<Offset>(
                                                        begin: const Offset(
                                                          0,
                                                          0.1,
                                                        ),
                                                        end: Offset.zero,
                                                      ).animate(animation),
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                            child: Center(
                                              key: ValueKey(
                                                'welcome_${widget.isLogin}',
                                              ),
                                              child: Obx(
                                                () => Text(
                                                  TranslationService.translate('welcome_to_eidos'),
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
                                          ),

                                          const SizedBox(height: 8),

                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            transitionBuilder:
                                                (
                                                  Widget child,
                                                  Animation<double> animation,
                                                ) {
                                                  return FadeTransition(
                                                    opacity: animation,
                                                    child: SlideTransition(
                                                      position: Tween<Offset>(
                                                        begin: const Offset(
                                                          0,
                                                          0.1,
                                                        ),
                                                        end: Offset.zero,
                                                      ).animate(animation),
                                                      child: child,
                                                    ),
                                                  );
                                                },
                                            child: Center(
                                              key: ValueKey(
                                                'subtitle_${widget.isLogin}',
                                              ),
                                              child: Obx(
                                                () => Text(
                                                widget.isLogin
                                                      ? TranslationService.translate('sign_in')
                                                      : TranslationService.translate('sign_up'),
                                                style: TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                ),
                                                textAlign: TextAlign.center,
                                                ),
                                              ),
                                            ),
                                          ),

                                          const SizedBox(height: 32),

                                          // Email field
                                          _buildTextField(
                                            controller: _emailController,
                                            label: TranslationService.translate('email'),
                                            hint: TranslationService.translate('email'),
                                            icon: Icons.email_outlined,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            onChanged: widget.isLogin ? (value) {
                                              // Reset validation state when email changes
                                              if (_emailValidated) {
                                                setState(() {
                                                  _emailValidated = false;
                                                  _hasPasskey = false;
                                                  _selectedLoginMethod = null;
                                                  _checkingPasskey = false;
                                                });
                                              }
                                              
                                              // Auto-check for passkey when email is valid (debounced)
                                              if (value.isNotEmpty && RegExp(
                                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                              ).hasMatch(value)) {
                                                // Debounce the check to avoid too many API calls
                                                Future.delayed(const Duration(milliseconds: 500), () {
                                                  if (mounted && 
                                                      _emailController.text == value && 
                                                      !_emailValidated &&
                                                      RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                                    _checkPasskeyForEmail(value.trim());
                                                  }
                                                });
                                              }
                                            } : null,
                                            onFieldSubmitted: widget.isLogin ? (value) {
                                              // When email is submitted, check for passkey if valid
                                              if (value.isNotEmpty && RegExp(
                                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                              ).hasMatch(value)) {
                                                _checkPasskeyForEmail(value.trim());
                                              }
                                            } : null,
                                            onEditingComplete: widget.isLogin ? () {
                                              // Also check when field loses focus
                                              final email = _emailController.text.trim();
                                              if (email.isNotEmpty && RegExp(
                                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                              ).hasMatch(email) && !_emailValidated) {
                                                _checkPasskeyForEmail(email);
                                              }
                                            } : null,
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return TranslationService.translate('email');
                                              }
                                              if (!RegExp(
                                                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                              ).hasMatch(value)) {
                                                return TranslationService.translate('email');
                                              }
                                              return null;
                                            },
                                          ),

                                          // Show loading indicator while checking for passkey
                                          if (widget.isLogin && _checkingPasskey) ...[
                                            const SizedBox(height: 16),
                                            const Center(
                                              child: SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 20),

                                          // Show login method selection for login mode after email is validated and has passkey
                                          if (widget.isLogin && _emailValidated && _hasPasskey) ...[
                                            // Choose login method (only show if user has passkey)
                                            Obx(
                                              () => Text(
                                                TranslationService.translate('choose_login_method'),
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            
                                            // Password login option (always available)
                                            _buildLoginMethodButton(
                                              icon: Icons.lock_outline,
                                              title: TranslationService.translate('sign_in_with_password'),
                                              isSelected: _selectedLoginMethod == 'password',
                                              onTap: () {
                                                setState(() {
                                                  _selectedLoginMethod = 'password';
                                                });
                                              },
                                            ),
                                            
                                            // Passkey login option (only if user has passkey)
                                            const SizedBox(height: 12),
                                            _buildLoginMethodButton(
                                              icon: Icons.fingerprint,
                                              title: TranslationService.translate('sign_in_with_passkey'),
                                              isSelected: _selectedLoginMethod == 'passkey',
                                              onTap: () {
                                                setState(() {
                                                  _selectedLoginMethod = 'passkey';
                                                });
                                              },
                                            ),
                                            
                                            const SizedBox(height: 20),
                                            
                                            // Password field (only shown when password method is selected)
                                            if (_selectedLoginMethod == 'password') ...[
                                          _buildTextField(
                                            controller: _passwordController,
                                                label: TranslationService.translate('password'),
                                                hint: TranslationService.translate('password'),
                                            icon: Icons.lock_outline,
                                            isPassword: true,
                                            isPasswordVisible:
                                                _isPasswordVisible,
                                            onTogglePassword: () {
                                              setState(() {
                                                _isPasswordVisible =
                                                    !_isPasswordVisible;
                                              });
                                            },
                                                onChanged: (value) {
                                                  // Force rebuild to update submit button state
                                                  setState(() {});
                                                },
                                            validator: (value) {
                                              if (value == null ||
                                                  value.isEmpty) {
                                                    return TranslationService.translate('password');
                                              }
                                              if (value.length < 6) {
                                                    return TranslationService.translate('password');
                                              }
                                              return null;
                                            },
                                          ),
                                            ],
                                          ] else if (widget.isLogin && _emailValidated && !_hasPasskey) ...[
                                            // For login without passkey, show password field directly after email validation
                                            _buildTextField(
                                              controller: _passwordController,
                                              label: TranslationService.translate('password'),
                                              hint: TranslationService.translate('password'),
                                              icon: Icons.lock_outline,
                                              isPassword: true,
                                              isPasswordVisible:
                                                  _isPasswordVisible,
                                              onTogglePassword: () {
                                                setState(() {
                                                  _isPasswordVisible =
                                                      !_isPasswordVisible;
                                                });
                                              },
                                              onChanged: (value) {
                                                // Force rebuild to update submit button state
                                                setState(() {});
                                              },
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return TranslationService.translate('password');
                                                }
                                                if (value.length < 6) {
                                                  return TranslationService.translate('password');
                                                }
                                                return null;
                                              },
                                            ),
                                          ] else if (!widget.isLogin) ...[
                                            // Password field for registration
                                            _buildTextField(
                                              controller: _passwordController,
                                              label: TranslationService.translate('password'),
                                              hint: TranslationService.translate('password'),
                                              icon: Icons.lock_outline,
                                              isPassword: true,
                                              isPasswordVisible:
                                                  _isPasswordVisible,
                                              onTogglePassword: () {
                                                setState(() {
                                                  _isPasswordVisible =
                                                      !_isPasswordVisible;
                                                });
                                              },
                                              validator: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return TranslationService.translate('password');
                                                }
                                                if (value.length < 6) {
                                                  return TranslationService.translate('password');
                                                }
                                                return null;
                                              },
                                            ),
                                          ],

                                          // Confirm password field (only for register) with animation
                                          AnimatedSwitcher(
                                            duration: const Duration(
                                              milliseconds: 300,
                                            ),
                                            transitionBuilder:
                                                (
                                                  Widget child,
                                                  Animation<double> animation,
                                                ) {
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
                                                    key: const ValueKey(
                                                      'confirm_password',
                                                    ),
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .stretch,
                                                    children: [
                                                      const SizedBox(
                                                        height: 20,
                                                      ),
                                                      _buildTextField(
                                                        controller:
                                                            _confirmPasswordController,
                                                        label:
                                                            TranslationService.translate('confirm_password'),
                                                        hint:
                                                            TranslationService.translate('confirm_password'),
                                                        icon:
                                                            Icons.lock_outline,
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
                                                            return TranslationService.translate('confirm_password');
                                                          }
                                                          if (value !=
                                                              _passwordController
                                                                  .text) {
                                                            return TranslationService.translate('confirm_password');
                                                          }
                                                          return null;
                                                        },
                                                      ),
                                                    ],
                                                  )
                                                : const SizedBox.shrink(
                                                    key: ValueKey(
                                                      'no_confirm_password',
                                                    ),
                                                  ),
                                          ),

                                          const SizedBox(height: 32),

                                          // Submit button with inline loading
                                          Obx(() {
                                            final bool isLoading =
                                                authController.isLoading.value;
                                            // For login: email must be valid, and:
                                            // - If passkey method selected: ready to submit
                                            // - If password method selected: password must be provided and valid
                                            // - If no passkey exists: password must be provided and valid
                                            // For register: all fields must be valid
                                            final String passwordText = _passwordController.text.trim();
                                            final bool isPasswordValid = passwordText.isNotEmpty && passwordText.length >= 6;
                                            
                                            final bool canSubmit = widget.isLogin
                                                ? (_emailController.text.isNotEmpty &&
                                                   RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text) &&
                                                   _emailValidated &&
                                                   ((_hasPasskey && _selectedLoginMethod == 'passkey') || 
                                                    (_hasPasskey && _selectedLoginMethod == 'password' && isPasswordValid) ||
                                                    (!_hasPasskey && isPasswordValid)))
                                                : (_emailController.text.isNotEmpty &&
                                                   RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text) &&
                                                   isPasswordValid &&
                                                   _confirmPasswordController.text.isNotEmpty &&
                                                   _confirmPasswordController.text.trim() == passwordText);
                                            return GestureDetector(
                                              onTap: (isLoading || !canSubmit)
                                                  ? null
                                                  : _handleSubmit,
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),
                                                width: double.infinity,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 16,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: (isLoading || !canSubmit)
                                                      ? Colors.grey[400]
                                                      : Colors.black87,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: Border.all(
                                                    color: (isLoading || !canSubmit)
                                                        ? Colors.grey[500]!
                                                        : Colors.black87,
                                                  ),
                                                ),
                                                child: Center(
                                                  child: isLoading
                                                      ? Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .center,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child: CircularProgressIndicator(
                                                                strokeWidth: 2,
                                                                valueColor:
                                                                    AlwaysStoppedAnimation<
                                                                      Color
                                                                    >(
                                                                      Colors
                                                                          .white,
                                                                    ),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 10),
                                                            Obx(
                                                              () => Text(
                                                                TranslationService.translate('sign_in'),
                                                                style: const TextStyle(
                                                                fontFamily:
                                                                    'Poppins',
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        )
                                                      : Obx(
                                                          () => Text(
                                                          widget.isLogin
                                                                ? TranslationService.translate('sign_in')
                                                                : TranslationService.translate('sign_up'),
                                                          style:
                                                              const TextStyle(
                                                                fontFamily:
                                                                    'Poppins',
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .white,
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),

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

                                          // Forgot password (only for login and password method)
                                          if (widget.isLogin && _selectedLoginMethod == 'password') ...[
                                            const SizedBox(height: 16),
                                            Center(
                                              child: GestureDetector(
                                                onTap: _handleForgotPassword,
                                                child: Obx(
                                                  () => Text(
                                                    TranslationService.translate('forgot_password'),
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.blue[600],
                                                    ),
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
    void Function(String)? onChanged,
    void Function(String)? onFieldSubmitted,
    VoidCallback? onEditingComplete,
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
          onChanged: onChanged,
          onFieldSubmitted: onFieldSubmitted,
          onEditingComplete: onEditingComplete,
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
    if (widget.isLogin) {
      // For login, validate email first
      if (!_formKey.currentState!.validate()) {
        return;
      }
      
      // If email is not validated yet, check for passkey first
      if (!_emailValidated && mounted) {
        await _checkPasskeyForEmail(_emailController.text.trim());
        // After checking, if no passkey, default to password
        if (!_hasPasskey && _selectedLoginMethod == null) {
          _selectedLoginMethod = 'password';
        }
        // If still not validated after check, return
        if (!_emailValidated) {
          return;
        }
      }
      
      // If user has passkey but hasn't selected a method, show error
      if (_hasPasskey && _selectedLoginMethod == null) {
        Get.snackbar(
          TranslationService.translate('error'),
          TranslationService.translate('choose_login_method'),
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red[100],
          colorText: Colors.red[800],
        );
        return;
      }
      
      // If password method is selected or no passkey exists, validate password
      if ((_selectedLoginMethod == 'password' || !_hasPasskey)) {
        if (_passwordController.text.isEmpty || _passwordController.text.length < 6) {
          Get.snackbar(
            TranslationService.translate('error'),
            TranslationService.translate('password'),
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red[100],
            colorText: Colors.red[800],
          );
          return;
        }
      }
    } else {
      // For registration, validate form
      if (!_formKey.currentState!.validate()) {
        return;
      }
    }
    
      final AuthController authController = Get.find<AuthController>();

      try {
        if (widget.isLogin) {
        // Handle login based on selected method
        if (_selectedLoginMethod == 'passkey') {
          try {
            // Handle passkey login
            final response = await authController.signInWithPasskey(
              email: _emailController.text.trim(),
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

              // Check if widget is still mounted before proceeding
              if (!mounted) return;

              // Get user profile
              final profile = await authController.getUserProfile();
              if (!mounted) return;

              final name =
                  profile?['full_name'] ??
                  response.user!.userMetadata?['full_name'] ??
                  response.user!.email?.split('@')[0] ??
                  'User';
              final email = response.user!.email ?? '';

              if (mounted && widget.onLoginSuccess != null) {
                widget.onLoginSuccess!(name, email);
              }
            }
          } catch (passkeyError) {
            // Handle passkey-specific errors
            if (mounted) {
              _showErrorDialog(
                title: TranslationService.translate('error'),
                message: _getPasskeyErrorMessage(passkeyError.toString()),
              );
            }
            return;
          }
        } else {
          // Handle password login
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

            // Check if widget is still mounted before proceeding
            if (!mounted) return;

            // Get user profile
            final profile = await authController.getUserProfile();
            if (!mounted) return;

            final name =
                profile?['full_name'] ??
                response.user!.userMetadata?['full_name'] ??
                response.user!.email?.split('@')[0] ??
                'User';
            final email = response.user!.email ?? '';

            // Don't wait for sync - let it happen in background
            // This prevents blocking the UI thread
            if (mounted && widget.onLoginSuccess != null) {
            widget.onLoginSuccess!(name, email);
            }
          }
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

            // Check if widget is still mounted before proceeding
            if (!mounted) return;

            // Get user profile
            final profile = await authController.getUserProfile();
            if (!mounted) return;

            final name =
                profile?['full_name'] ??
                response.user!.userMetadata?['full_name'] ??
                response.user!.email?.split('@')[0] ??
                'User';
            final email = response.user!.email ?? '';

            // Automatically sign in the user
            if (mounted && widget.onLoginSuccess != null) {
            widget.onLoginSuccess!(name, email);
            }
          }
        }
      } catch (e) {
        if (mounted) {
          // Check if it's a "user already exists" error
          final bool isUserExistsError = e.toString().contains(
            'User already registered',
          );

          await _showErrorDialog(
            title: TranslationService.translate('error'),
            message: _getErrorMessage(e.toString()),
          );

          // If user already exists and we're in register mode, switch to login
          if (isUserExistsError &&
              !widget.isLogin &&
              widget.onToggleMode != null) {
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

  Future<void> _checkPasskeyForEmail(String email) async {
    // Prevent duplicate checks
    if (_checkingPasskey || !mounted || email.isEmpty) return;
    
    // Validate email format first
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return;
    }
    
    debugPrint('🔍 Checking for passkey for email: $email');
    
    if (mounted) {
      setState(() {
        _checkingPasskey = true;
      });
    }

    try {
      // Check if user exists and has passkey
      debugPrint('📧 Calling hasPasskeysForEmail for: $email');
      final hasPasskey = await passkey.PasskeyService.hasPasskeysForEmail(email);
      debugPrint('✅ Passkey check result for $email: $hasPasskey');
      
      if (mounted) {
        setState(() {
          _emailValidated = true;
          _hasPasskey = hasPasskey;
          // If user has passkey, don't auto-select method (let user choose)
          // If no passkey, default to password
          if (!hasPasskey) {
            _selectedLoginMethod = 'password';
          }
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking passkey for $email: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // If error checking, assume no passkey and default to password
      // This could be because user doesn't exist or has no passkey
      if (mounted) {
        setState(() {
          _emailValidated = true;
          _hasPasskey = false;
          _selectedLoginMethod = 'password';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _checkingPasskey = false;
        });
      }
    }
  }

  Widget _buildLoginMethodButton({
    required IconData icon,
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.blue[600]! : Colors.black87,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.blue[600] : Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Colors.blue[600],
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  void _handleForgotPassword() async {
    if (_emailController.text.isEmpty) {
      _showErrorDialog(
        title: TranslationService.translate('error'),
        message: TranslationService.translate('enter_email_first'),
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
                Obx(
                  () => Text(
                    TranslationService.translate('success'),
                    style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => Text(
                    TranslationService.translate('forgot_password'),
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                  ),
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
                    child: Obx(
                      () => Text(
                        TranslationService.translate('close'),
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
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          title: TranslationService.translate('error'),
          message: _getErrorMessage(e.toString()),
        );
      }
    }
  }

  String _getErrorMessage(String error) {
    // Use translations for error messages
    if (error.contains('Invalid login credentials')) {
      return TranslationService.translate('password');
    } else if (error.contains('User already registered')) {
      return TranslationService.translate('password');
    } else if (error.contains('Password should be at least')) {
      return TranslationService.translate('password');
    } else if (error.contains('Invalid email')) {
      return TranslationService.translate('email');
    } else if (error.contains('Email not confirmed')) {
      return TranslationService.translate('email');
    } else if (error.contains('Too many requests')) {
      return TranslationService.translate('error');
    } else if (error.contains('Email rate limit exceeded')) {
      return TranslationService.translate('error');
    } else if (error.contains('User not found')) {
      return TranslationService.translate('email');
    } else {
      return TranslationService.translate('error');
    }
  }

  String _getPasskeyErrorMessage(String error) {
    if (error.contains('Device does not support')) {
      return TranslationService.translate('device_not_support_biometrics');
    } else if (error.contains('Biometric authentication failed')) {
      return TranslationService.translate('biometric_authentication_failed');
    } else if (error.contains('No passkeys found')) {
      return TranslationService.translate('no_passkeys_found');
    } else if (error.contains('User not found')) {
      return TranslationService.translate('no_passkeys_found');
    } else if (error.contains('Password not found')) {
      return TranslationService.translate('passkey_registration_incomplete');
    } else {
      return TranslationService.translate('passkey_authentication_failed');
    }
  }

  Future<void> _showErrorDialog({
    required String title,
    required String message,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          final double clamped = value.clamp(0.0, 1.0);
          return Transform.scale(
            scale: 0.8 + (0.2 * clamped),
            child: Opacity(opacity: clamped, child: child),
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
                  color: Colors.black.withValues(alpha: 0.1),
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
                            color: Colors.red.withValues(alpha: 0.1),
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
                      final double clamped = value.clamp(0.0, 1.0);
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - clamped)),
                        child: Opacity(opacity: clamped, child: child),
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
                              color: Colors.red.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Obx(
                          () => Text(
                            TranslationService.translate('close'),
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