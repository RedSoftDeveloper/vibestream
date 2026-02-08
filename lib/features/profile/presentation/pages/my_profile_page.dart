import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';
import 'package:vibestream/features/auth/data/app_user_service.dart';

class MyProfilePage extends StatefulWidget {
  const MyProfilePage({super.key});

  @override
  State<MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<MyProfilePage> {
  final _authService = AuthService();
  final _appUserService = AppUserService();
  
  AppUser? _appUser;
  bool _isLoading = true;
  bool _isOAuthUser = false;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final appUser = await _appUserService.getCurrentAppUser();
      final currentUser = _authService.currentUser;
      
      if (mounted) {
        setState(() {
          _appUser = appUser;
          _isOAuthUser = _authService.isOAuthUser;
          _userEmail = currentUser?.email;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context, isDark),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _buildProfileAvatar(isDark),
                          const SizedBox(height: 24),
                          _buildCard(isDark, [
                            _buildEditableItem(
                              icon: Icons.person_outline,
                              title: 'Display Name',
                              value: _appUser?.displayNameOrDefault ?? 'Movie Lover',
                              isDark: isDark,
                              onTap: () => _showEditNameSheet(context),
                            ),
                          ]),
                          const SizedBox(height: 16),
                          _buildCard(isDark, [
                            _buildEditableItem(
                              icon: Icons.email_outlined,
                              title: 'Email',
                              value: _userEmail ?? 'Not set',
                              isDark: isDark,
                              onTap: _isOAuthUser ? null : () => _showEditEmailSheet(context),
                              isDisabled: _isOAuthUser,
                            ),
                            _buildEditableItem(
                              icon: Icons.lock_outline,
                              title: 'Password',
                              value: '••••••••',
                              isDark: isDark,
                              onTap: _isOAuthUser ? null : () => _showChangePasswordSheet(context),
                              isDisabled: _isOAuthUser,
                            ),
                          ]),
                          if (_isOAuthUser) ...[
                            const SizedBox(height: 12),
                            _buildOAuthNotice(isDark),
                          ],
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.settings),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFFFFFFF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chevron_left,
                color: isDark ? Colors.white : Colors.black,
                size: 26,
              ),
            ),
          ),
          Expanded(
            child: Text(
              'My Profile',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildProfileAvatar(bool isDark) {
    final avatarUrl = _appUser?.avatarUrl;
    
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
              width: 2,
            ),
          ),
          child: avatarUrl != null && avatarUrl.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.person_outline,
                      size: 48,
                      color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                    ),
                  ),
                )
              : Icon(
                  Icons.person_outline,
                  size: 48,
                  color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                ),
        ),
        const SizedBox(height: 16),
        Text(
          _appUser?.displayNameOrDefault ?? 'Movie Lover',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _userEmail ?? '',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildEditableItem({
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    VoidCallback? onTap,
    bool isDisabled = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isDisabled
                  ? (isDark ? const Color(0xFF505050) : const Color(0xFFB0B0B0))
                  : (isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isDisabled
                          ? (isDark ? const Color(0xFF505050) : const Color(0xFFB0B0B0))
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            if (!isDisabled)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOAuthNotice(bool isDark) {
    final provider = _authService.oauthProvider ?? 'social';
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Email and password cannot be changed for $provider accounts.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditNameSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameController = TextEditingController(text: _appUser?.displayName ?? '');
    bool isLoading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit Display Name',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Display Name',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: errorMessage,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            setSheetState(() => errorMessage = 'Name cannot be empty');
                            return;
                          }
                          setSheetState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          final success = await _appUserService.updateDisplayName(name);

                          if (!ctx.mounted) return;

                          if (success) {
                            Navigator.pop(ctx);
                            _loadUserData();
                            _showSuccess('Display name updated successfully');
                          } else {
                            setSheetState(() {
                              isLoading = false;
                              errorMessage = 'Failed to update name. Please try again.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        )
                      : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditEmailSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final emailController = TextEditingController(text: _userEmail ?? '');
    bool isLoading = false;
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Change Email',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A verification code will be sent to your new email address.',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'New Email',
                  labelStyle: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  errorText: errorMessage,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final email = emailController.text.trim();
                          if (email.isEmpty || !_isValidEmail(email)) {
                            setSheetState(() => errorMessage = 'Please enter a valid email address');
                            return;
                          }
                          if (email == _userEmail) {
                            setSheetState(() => errorMessage = 'New email must be different from current email');
                            return;
                          }
                          setSheetState(() {
                            isLoading = true;
                            errorMessage = null;
                          });

                          final result = await _authService.updateEmail(email);

                          if (!ctx.mounted) return;

                          if (result.success) {
                            Navigator.pop(ctx);
                            // Navigate to OTP verification for email change
                            context.push(
                              AppRoutes.otpVerification,
                              extra: {
                                'email': email,
                                'flowType': AuthFlowType.emailChange,
                              },
                            );
                          } else {
                            setSheetState(() {
                              isLoading = false;
                              errorMessage = result.errorMessage ?? 'Failed to update email';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: isDark ? Colors.black : Colors.white,
                          ),
                        )
                      : const Text('Continue', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showChangePasswordSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    bool showCurrentPassword = false;
    bool showNewPassword = false;
    bool showConfirmPassword = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: currentPasswordController,
                  obscureText: !showCurrentPassword,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showCurrentPassword ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                      ),
                      onPressed: () => setSheetState(() => showCurrentPassword = !showCurrentPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showNewPassword ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                      ),
                      onPressed: () => setSheetState(() => showNewPassword = !showNewPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !showConfirmPassword,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    labelStyle: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                        color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                      ),
                      onPressed: () => setSheetState(() => showConfirmPassword = !showConfirmPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Password must be at least 8 characters long',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            errorMessage!,
                            style: const TextStyle(fontSize: 13, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : () async {
                            final currentPassword = currentPasswordController.text;
                            final newPassword = newPasswordController.text;
                            final confirmPassword = confirmPasswordController.text;

                            // Validate inputs
                            if (currentPassword.isEmpty) {
                              setSheetState(() => errorMessage = 'Please enter your current password');
                              return;
                            }
                            if (newPassword.length < 8) {
                              setSheetState(() => errorMessage = 'New password must be at least 8 characters');
                              return;
                            }
                            if (newPassword != confirmPassword) {
                              setSheetState(() => errorMessage = 'Passwords do not match');
                              return;
                            }
                            if (currentPassword == newPassword) {
                              setSheetState(() => errorMessage = 'New password must be different from current password');
                              return;
                            }

                            setSheetState(() {
                              isLoading = true;
                              errorMessage = null;
                            });

                            // First verify current password
                            final verifyResult = await _authService.verifyPassword(currentPassword);
                            if (!verifyResult.success) {
                              if (!ctx.mounted) return;
                              setSheetState(() {
                                isLoading = false;
                                errorMessage = 'Current password is incorrect';
                              });
                              return;
                            }

                            // Then update password
                            final updateResult = await _authService.updatePassword(newPassword);

                            if (!ctx.mounted) return;

                            if (updateResult.success) {
                              Navigator.pop(ctx);
                              _showSuccess('Password changed successfully');
                            } else {
                              setSheetState(() {
                                isLoading = false;
                                errorMessage = updateResult.errorMessage ?? 'Failed to update password';
                              });
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : Colors.black,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isLoading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                          )
                        : const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    SnackbarUtils.showSuccess(context, message);
  }
}
