import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth_service.dart';
import 'animated_icon_background.dart';
import 'package:get/get.dart';
import '../controllers/auth_controller.dart';

class EditProfileView extends StatefulWidget {
  final String currentName;
  final String currentEmail;
  final VoidCallback? onBack;
  final Function(String, String, String)? onSaveProfile;
  final VoidCallback? onDeleteAccount;

  const EditProfileView({
    super.key,
    required this.currentName,
    required this.currentEmail,
    this.onBack,
    this.onSaveProfile,
    this.onDeleteAccount,
  });

  @override
  State<EditProfileView> createState() => _EditProfileViewState();
}

class _EditProfileViewState extends State<EditProfileView> {

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String _profilePicUrl = '';
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  Color? _selectedAvatarColor;
  bool _isChangingPassword = false;
  bool _isNewPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isNavigatingBack = false;
  bool _hasPasskeys = false;
  List<Map<String, dynamic>> _userPasskeys = [];
  bool _loadingPasskeys = false;
  final _passkeyPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();

    // Initialize form fields
    _nameController.text = widget.currentName;
    _emailController.text = widget.currentEmail;

    // Load current avatar url so the real profile picture shows up
    _loadCurrentAvatar();
    
    // Load passkeys
    _loadPasskeys();
  }

  Future<void> _loadCurrentAvatar() async {
    try {
      final profile = await AuthService.getUserProfile();
      if (mounted && profile != null) {
        setState(() {
          _profilePicUrl = profile['avatar_url'] ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadPasskeys() async {
    if (!mounted) return;
    setState(() {
      _loadingPasskeys = true;
    });
    
    try {
      final authController = Get.find<AuthController>();
      final hasPasskeys = await authController.hasPasskeys();
      final passkeys = await authController.getUserPasskeys();
      
      if (mounted) {
        setState(() {
          _hasPasskeys = hasPasskeys;
          _userPasskeys = passkeys;
          _loadingPasskeys = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading passkeys: $e');
      if (mounted) {
        setState(() {
          _hasPasskeys = false;
          _userPasskeys = [];
          _loadingPasskeys = false;
        });
      }
    }
  }

  Future<void> _registerPasskey() async {
    // Show dialog to enter password for passkey registration
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Register Passkey',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter your password to register a passkey. You will use biometric authentication to sign in.',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passkeyPasswordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              _passkeyPasswordController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () {
              if (_passkeyPasswordController.text.isNotEmpty) {
                Navigator.pop(context, _passkeyPasswordController.text);
              }
            },
            child: const Text('Register', style: TextStyle(fontFamily: 'Poppins')),
          ),
        ],
      ),
    );

    if (password == null || password.isEmpty) {
      _passkeyPasswordController.clear();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authController = Get.find<AuthController>();
      await authController.registerPasskey(
        password: password,
        deviceName: 'This Device',
      );

      _passkeyPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Passkey registered successfully!',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
          ),
    );
        await _loadPasskeys();
      }
    } catch (e) {
      debugPrint('Error in _registerPasskey: $e');
      if (mounted) {
        String errorMessage = 'Failed to register passkey';
        if (e.toString().contains('Device does not support')) {
          errorMessage = 'Your device does not support biometric authentication.';
        } else if (e.toString().contains('Biometric authentication failed')) {
          errorMessage = 'Biometric authentication was cancelled or failed. Please try again.';
        } else if (e.toString().contains('User not found') || e.toString().contains('Authentication error')) {
          errorMessage = 'Authentication error. Please log out and log back in, then try again.';
        } else if (e.toString().contains('Permission denied')) {
          errorMessage = 'Permission denied. Please check your account permissions.';
        } else if (e.toString().contains('Database error')) {
          errorMessage = 'Database error. Please check your internet connection and try again.';
        } else {
          errorMessage = 'Failed to register passkey: ${e.toString()}';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deletePasskey(String passkeyId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Passkey',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this passkey?',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(fontFamily: 'Poppins', color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authController = Get.find<AuthController>();
      await authController.deletePasskey(passkeyId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Passkey deleted successfully!',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.green,
          ),
        );
        await _loadPasskeys();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to delete passkey: ${e.toString()}',
              style: const TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildPasskeySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Passkey Management',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black87),
          ),
          child: _loadingPasskeys
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _hasPasskeys
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registered Passkeys:',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._userPasskeys.map((passkey) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.fingerprint, size: 20, color: Colors.black87),
                                      const SizedBox(width: 8),
                                      Text(
                                        passkey['device_name'] ?? 'Unknown Device',
                                        style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                    onPressed: () => _deletePasskey(passkey['passkey_id'] as String),
                                  ),
                                ],
                              ),
                            )),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _registerPasskey,
                            icon: const Icon(Icons.fingerprint, size: 18),
                            label: const Text(
                              'Add New Passkey',
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        const Text(
                          'No passkeys registered. Register a passkey to sign in with biometric authentication.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _registerPasskey,
                            icon: const Icon(Icons.fingerprint, size: 18),
                            label: const Text(
                              'Register Passkey',
                              style: TextStyle(fontFamily: 'Poppins'),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Prevent any further state changes
    _isNavigatingBack = true;
    
    // Dispose text controllers
    _nameController.dispose();
    _emailController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _passkeyPasswordController.dispose();
    
    super.dispose();
  }

  void _handleBack() {
    // Prevent multiple calls
    if (_isNavigatingBack || !mounted) return;
    
    _isNavigatingBack = true;
    
    // Navigate back using GetX
    if (widget.onBack != null) {
      widget.onBack!();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't build if we're navigating back
    if (_isNavigatingBack) {
      return const SizedBox.shrink();
    }
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          const Positioned.fill(
            child: AuthIconBackground(),
          ),
          SafeArea(
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

                      // Back button and title
                      Row(
                        children: [
                          GestureDetector(
                              onTap: _handleBack,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.black87),
                              ),
                              child: const Icon(
                                Icons.arrow_back,
                                color: Colors.black87,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          const Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 40),

                      // Profile form
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.black87),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Profile picture section
                                Center(
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: _changeProfilePicture,
                                        child: Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color: _selectedAvatarColor ?? Colors.grey[200],
                                            borderRadius: BorderRadius.circular(50),
                                            border: Border.all(
                                              color: Colors.black87,
                                              width: 2,
                                            ),
                                          ),
                                          child: _selectedImage != null
                                              ? ClipRRect(
                                                  borderRadius: BorderRadius.circular(48),
                                                  child: Image.file(
                                                    _selectedImage!,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                          return const Icon(
                                                            Icons.person,
                                                            size: 50,
                                                            color: Colors.grey,
                                                          );
                                                        },
                                                  ),
                                                )
                                              : _profilePicUrl.isNotEmpty
                                              ? ClipRRect(
                                                      borderRadius: BorderRadius.circular(48),
                                                  child: Image.network(
                                                    _profilePicUrl,
                                                    fit: BoxFit.cover,
                                                        errorBuilder: (context, error, stackTrace) {
                                                          return const Icon(
                                                            Icons.person,
                                                            size: 50,
                                                            color: Colors.grey,
                                                          );
                                                        },
                                                  ),
                                                )
                                              : widget.currentName.isNotEmpty
                                              ? Center(
                                                  child: Text(
                                                            widget.currentName[0].toUpperCase(),
                                                    style: const TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 36,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.white,
                                                    ),
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.person,
                                                  size: 50,
                                                          color: Colors.white,
                                                ),
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      GestureDetector(
                                        onTap: _changeProfilePicture,
                                        child: Text(
                                          'Change Profile Picture',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.blue[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 32),

                                // Name field
                                _buildTextField(
                                  controller: _nameController,
                                  label: 'Full Name',
                                  hint: 'Enter your full name',
                                  icon: Icons.person_outline,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                // Email field
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email',
                                  hint: 'Enter your email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),

                                const SizedBox(height: 20),

                                // Password section
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 250),
                                  transitionBuilder: (child, animation) => SizeTransition(
                                    sizeFactor: animation,
                                    axisAlignment: -1.0,
                                    child: FadeTransition(opacity: animation, child: child),
                                  ),
                                  child: !_isChangingPassword
                                      ? Column(
                                          key: const ValueKey('masked_password'),
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            const Text(
                                              'Password',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.black87),
                                              ),
                                              child: const Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    '***********',
                                                    style: TextStyle(
                                                      fontFamily: 'Poppins',
                                                      fontSize: 16,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                  Icon(Icons.visibility_off, size: 20, color: Colors.black87),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerLeft,
                                              child: GestureDetector(
                                                onTap: () {
                                                  setState(() {
                                                    _isChangingPassword = true;
                                                  });
                                                },
                                                child: Text(
                                                  'Change Password',
                                                  style: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue[600],
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Column(
                                          key: const ValueKey('change_password_fields'),
                                          crossAxisAlignment: CrossAxisAlignment.stretch,
                                          children: [
                                            _buildTextField(
                                              controller: _newPasswordController,
                                              label: 'New Password',
                                              hint: 'Enter new password',
                                              icon: Icons.lock_outline,
                                              keyboardType: TextInputType.visiblePassword,
                                              isPassword: true,
                                              isPasswordVisible: _isNewPasswordVisible,
                                              onTogglePassword: () {
                                                setState(() {
                                                  _isNewPasswordVisible = !_isNewPasswordVisible;
                                                });
                                              },
                                              validator: (value) {
                                                if (!_isChangingPassword) return null;
                                                if (value == null || value.isEmpty) {
                                                  return 'Please enter a new password';
                                                }
                                                if (value.length < 6) {
                                                  return 'Password must be at least 6 characters';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 12),
                                            _buildTextField(
                                              controller: _confirmPasswordController,
                                              label: 'Confirm Password',
                                              hint: 'Re-enter new password',
                                              icon: Icons.lock_reset,
                                              keyboardType: TextInputType.visiblePassword,
                                              isPassword: true,
                                              isPasswordVisible: _isConfirmPasswordVisible,
                                              onTogglePassword: () {
                                                setState(() {
                                                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                                                });
                                              },
                                              validator: (value) {
                                                if (!_isChangingPassword) return null;
                                                if (value == null || value.isEmpty) {
                                                  return 'Please confirm your new password';
                                                }
                                                if (value != _newPasswordController.text) {
                                                  return 'Passwords do not match';
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                ),

                                const SizedBox(height: 20),

                                // Passkey Management Section
                                _buildPasskeySection(),

                                const SizedBox(height: 20),

                                // Save button
                                GestureDetector(
                                  onTap: _isLoading ? null : _handleSave,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: _isLoading ? Colors.grey[400] : Colors.black87,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black87),
                                    ),
                                    child: _isLoading
                                        ? const Center(
                                            child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                  ),
                                            ),
                                          )
                                        : const Text(
                                            'Save Changes',
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

                                const SizedBox(height: 20),

                                // Delete account button
                                GestureDetector(
                                  onTap: _handleDeleteAccount,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red[50],
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red[300]!),
                                    ),
                                    child: const Text(
                                      'Delete Account',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.red,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
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
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool isPasswordVisible = false,
    VoidCallback? onTogglePassword,
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
          maxLines: isPassword ? 1 : maxLines,
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
                      isPasswordVisible ? Icons.visibility_off : Icons.visibility,
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
              borderSide: const BorderSide(color: Colors.black87, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
          validator: validator,
        ),
      ],
    );
  }

  void _changeProfilePicture() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
                              ),
          ],
        ),
      ),
    );

      if (source != null && mounted) {
        final XFile? image = await _picker.pickImage(source: source);
        if (image != null && mounted) {
        setState(() {
          _selectedImage = File(image.path);
            _selectedAvatarColor = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleSave() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // If changing password, validate and update password first
        if (_isChangingPassword) {
          if (_newPasswordController.text.isEmpty ||
              _newPasswordController.text.length < 6 ||
              _newPasswordController.text != _confirmPasswordController.text) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                    'Please provide matching passwords (min 6 chars).',
                style: TextStyle(fontFamily: 'Poppins'),
              ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
          await AuthService.updatePassword(_newPasswordController.text);
        }

        // Upload profile picture to Supabase Storage if _selectedImage is not null
        if (_selectedImage != null) {
          final authController = Get.find<AuthController>();
          await authController.uploadProfilePicture(_selectedImage!);
        }

        // Update profile
          if (widget.onSaveProfile != null) {
            widget.onSaveProfile!(
              _nameController.text.trim(),
              _emailController.text.trim(),
              '',
            );
          }

        // Reset password fields state if changed
        if (_isChangingPassword) {
          setState(() {
            _isChangingPassword = false;
          });
          _newPasswordController.clear();
          _confirmPasswordController.clear();
        }

        // Navigate back after a brief delay
          Future.delayed(const Duration(seconds: 1), () {
          if (!mounted || _isNavigatingBack) return;
          
          _isNavigatingBack = true;
          
          // Navigate back using GetX
          if (widget.onBack != null) {
            widget.onBack!();
            }
          });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to update profile: ${e.toString()}',
                style: const TextStyle(fontFamily: 'Poppins'),
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Delete Account',
          style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: TextStyle(fontFamily: 'Poppins'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Poppins')),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (widget.onDeleteAccount != null) {
                widget.onDeleteAccount!();
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(fontFamily: 'Poppins', color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}