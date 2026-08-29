import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_motion.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../data/models/login_request.dart';
import '../../data/models/register_request.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/services/token_storage_service.dart';
import '../widgets/otp_verification_dialog.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authApiService = AuthApiService();
  final _tokenStorageService = TokenStorageService();
  final _googleAuthService = GoogleAuthService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _referralCodeController = TextEditingController();

  String? _emailApiError;
  String? _phoneApiError;
  String? _passwordApiError;
  String? _generalApiError;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  bool get _isBusy => _isLoading || _isGoogleLoading;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _referralCodeController.dispose();
    _authApiService.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    final name = value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Full name is required';
    }

    if (name.length < 3) {
      return 'Full name must contain at least 3 characters';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Email is required';
    }

    final emailPattern = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$');

    if (!emailPattern.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return _emailApiError;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Phone number is required';
    }

    final phonePattern = RegExp(r'^[0-9]{10}$');

    if (!phonePattern.hasMatch(phone)) {
      return 'Enter a valid 10-digit phone number';
    }

    return _phoneApiError;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Password must contain an uppercase letter';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Password must contain a lowercase letter';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Password must contain a number';
    }

    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) {
      return 'Password must contain a special character';
    }

    return _passwordApiError;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirm your password';
    }

    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }

    return null;
  }

  Future<void> _submitRegistration() async {
    FocusScope.of(context).unfocus();

    setState(() {
      _emailApiError = null;
      _phoneApiError = null;
      _passwordApiError = null;
      _generalApiError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = RegisterRequest(
        fullName: _fullNameController.text,
        email: _emailController.text,
        phoneNumber: _phoneController.text,
        password: _passwordController.text,
        referralCode: _referralCodeController.text,
      );

      final response = await _authApiService.register(request);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final isVerified = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return OtpVerificationDialog(email: response.email);
        },
      );

      if (!mounted || isVerified != true) {
        return;
      }

      try {
        final loginResponse = await _authApiService.login(
          LoginRequest(
            email: _emailController.text,
            password: _passwordController.text,
          ),
        );

        await _tokenStorageService.saveTokens(
          accessToken: loginResponse.accessToken,
          refreshToken: loginResponse.refreshToken,
          accessTokenExpiresAt: loginResponse.accessTokenExpiresAt,
        );

        if (!mounted) return;
      } catch (_) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account verified. Please login to continue.'),
          ),
        );

        Navigator.pushReplacementNamed(context, RouteNames.login);
        return;
      }

      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.dashboard,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      final errorText = error.toString().toLowerCase();

      setState(() {
        _isLoading = false;

        if (errorText.contains('phone')) {
          _phoneApiError = 'This phone number is already registered.';
        } else if (errorText.contains('email')) {
          _emailApiError = 'This email address is already registered.';
        } else if (errorText.contains('password')) {
          _passwordApiError = 'Password does not meet the requirements.';
        } else {
          _generalApiError = 'Unable to create your account. Please try again.';
        }
      });

      _formKey.currentState?.validate();
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isBusy) return;

    setState(() {
      _isGoogleLoading = true;
    });

    try {
      final idToken = await _googleAuthService.signInAndGetIdToken();
      if (idToken == null) {
        return;
      }

      final response = await _authApiService.loginWithGoogle(idToken);
      await _tokenStorageService.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        accessTokenExpiresAt: response.accessTokenExpiresAt,
      );

      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.dashboard,
        (route) => false,
      );
    } on GoogleAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  InputDecoration _inputDecoration({
    required SmColors colors,
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: colors.primary),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surface,
      hintStyle: TextStyle(color: colors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SmRadius.cardLarge - 10),
        borderSide: BorderSide(color: colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SmRadius.cardLarge - 10),
        borderSide: BorderSide(color: colors.success, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SmRadius.cardLarge - 10),
        borderSide: BorderSide(color: colors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(SmRadius.cardLarge - 10),
        borderSide: BorderSide(color: colors.danger, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: colors.backgroundGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: SmSpacing.lg,
              vertical: SmSpacing.xl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: FadeSlideIn(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: SizedBox(
                            height: 150,
                            child: Image.asset(
                              'assets/images/smartmoney_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -18),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                right: -10,
                                top: -20,
                                child: Opacity(
                                  opacity: 0.44,
                                  child: Image.asset(
                                    'assets/images/register_growth_chart.png',
                                    width: 220,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text.rich(
                                      TextSpan(
                                        children: [
                                          const TextSpan(text: 'Create '),
                                          TextSpan(
                                            text: 'SmartMoney',
                                            style: TextStyle(
                                              color: colors.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: colors.textPrimary,
                                            height: 1.08,
                                          ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Start tracking rewards and cashback\n'
                                      'with a secure account.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            height: 1.45,
                                            color: colors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.all(SmSpacing.lg),
                          decoration: BoxDecoration(
                            color: colors.surface.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(
                              SmRadius.cardLarge,
                            ),
                            border: Border.all(
                              color: colors.border.withValues(alpha: 0.70),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.primary.withValues(alpha: 0.10),
                                blurRadius: 32,
                                offset: const Offset(0, 14),
                              ),
                              BoxShadow(
                                color: colors.success.withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _fullNameController,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.words,
                                validator: _validateFullName,
                                enabled: !_isBusy,
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'Full Name',
                                  icon: Icons.person_outline,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: _validateEmail,
                                enabled: !_isBusy,
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'Email',
                                  icon: Icons.email_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _phoneController,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                validator: _validatePhone,
                                enabled: !_isBusy,
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'Phone Number',
                                  icon: Icons.phone_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.next,
                                validator: _validatePassword,
                                enabled: !_isBusy,
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'Password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.next,
                                validator: _validateConfirmPassword,
                                enabled: !_isBusy,
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'Confirm Password',
                                  icon: Icons.lock_reset_outlined,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _referralCodeController,
                                textInputAction: TextInputAction.done,
                                enabled: !_isBusy,
                                onFieldSubmitted: (_) {
                                  _submitRegistration();
                                },
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'Referral Code (Optional)',
                                  icon: Icons.card_giftcard_outlined,
                                ),
                              ),
                              if (_generalApiError != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  _generalApiError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.danger,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 18),
                              _SmartMoneyRegisterButton(
                                colors: colors,
                                isLoading: _isLoading,
                                onPressed: _isBusy
                                    ? null
                                    : _submitRegistration,
                              ),
                              const SizedBox(height: SmSpacing.lg),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: colors.border),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: SmSpacing.md,
                                    ),
                                    child: Text(
                                      'or',
                                      style: TextStyle(
                                        color: colors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: colors.border),
                                  ),
                                ],
                              ),
                              const SizedBox(height: SmSpacing.lg),
                              GoogleSignInButton(
                                isLoading: _isGoogleLoading,
                                onPressed: _isBusy
                                    ? null
                                    : _handleGoogleSignIn,
                              ),
                              const SizedBox(height: SmSpacing.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 18,
                                    color: colors.success,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      'Your information is encrypted and secure',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: colors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: SmSpacing.xxl),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Already have an account?',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            TextButton(
                              onPressed: _isBusy
                                  ? null
                                  : () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        RouteNames.login,
                                      );
                                    },
                              child: Text(
                                'Log in',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: SmSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SmartMoneyRegisterButton extends StatefulWidget {
  const _SmartMoneyRegisterButton({
    required this.colors,
    required this.isLoading,
    required this.onPressed,
  });

  final SmColors colors;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_SmartMoneyRegisterButton> createState() =>
      _SmartMoneyRegisterButtonState();
}

class _SmartMoneyRegisterButtonState
    extends State<_SmartMoneyRegisterButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final colors = widget.colors;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedScale(
        scale: isEnabled && _hovering ? 1.01 : 1.0,
        duration: SmMotion.fast,
        curve: SmMotion.standard,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: isEnabled
                  ? [colors.success, colors.successHover]
                  : [
                      colors.success.withValues(alpha: 0.45),
                      colors.success.withValues(alpha: 0.45),
                    ],
            ),
            borderRadius: BorderRadius.circular(SmRadius.button),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: colors.success.withValues(alpha: 0.30),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: FilledButton(
            onPressed: isEnabled ? widget.onPressed : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(SmRadius.button),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Create Account',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
