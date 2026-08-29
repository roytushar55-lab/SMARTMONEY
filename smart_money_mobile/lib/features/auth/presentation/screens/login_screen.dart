import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_motion.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/google_sign_in_button.dart';
import '../../data/models/login_request.dart';
import '../../data/services/auth_api_service.dart';
import '../../data/services/google_auth_service.dart';
import '../../data/services/token_storage_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authApiService = AuthApiService();
  final _tokenStorageService = TokenStorageService();
  final _googleAuthService = GoogleAuthService();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

  bool get _isBusy => _isLoading || _isGoogleLoading;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _authApiService.dispose();
    super.dispose();
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

    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Password is required';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }

    return null;
  }

  Future<void> _submitLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final request = LoginRequest(
        email: _emailController.text,
        password: _passwordController.text,
      );

      final response = await _authApiService.login(request);
      await _tokenStorageService.saveTokens(
        accessToken: response.accessToken,
        refreshToken: response.refreshToken,
        accessTokenExpiresAt: response.accessTokenExpiresAt,
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.dashboard,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
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
      prefixIcon: Icon(icon, color: colors.success),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: colors.surface,
      hintStyle: TextStyle(color: colors.textMuted),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
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
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeSlideIn(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: SizedBox(
                            height: 200,
                            child: Image.asset(
                              'assets/images/smartmoney_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: const Offset(0, -28),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                right: -10,
                                top: -12,
                                child: Opacity(
                                  opacity: 0.45,
                                  child: Image.asset(
                                    'assets/images/login_growth_chart.png',
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
                                    Text(
                                      'Shop smarter.\nGet money back.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: colors.textPrimary,
                                            height: 1.08,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Log in to manage your money,\n'
                                      'cashback and rewards.',
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
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
                        const SizedBox(height: 6),
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
                              const SizedBox(height: 15),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                validator: _validatePassword,
                                enabled: !_isBusy,
                                onFieldSubmitted: (_) {
                                  _submitLogin();
                                },
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
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _isBusy
                                      ? null
                                      : () {
                                          Navigator.pushNamed(
                                            context,
                                            RouteNames.forgotPassword,
                                          );
                                        },
                                  child: Text(
                                    'Forgot password?',
                                    style: TextStyle(
                                      color: colors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              _SmartMoneyLoginButton(
                                colors: colors,
                                isLoading: _isLoading,
                                onPressed: _isBusy ? null : _submitLogin,
                              ),
                              const SizedBox(height: SmSpacing.xl),
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(
                                      color: colors.border,
                                    ),
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
                                    child: Divider(
                                      color: colors.border,
                                    ),
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
                            ],
                          ),
                        ),
                        const SizedBox(height: SmSpacing.xxl),
                        _TrustIndicators(colors: colors),
                        const SizedBox(height: SmSpacing.lg),
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Do not have an account?',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 15,
                              ),
                            ),
                            TextButton(
                              onPressed: _isBusy
                                  ? null
                                  : () {
                                      Navigator.pushNamed(
                                        context,
                                        RouteNames.register,
                                      );
                                    },
                              child: Text(
                                'Create account',
                                style: TextStyle(
                                  color: colors.primary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Center(
                          child: Image.asset(
                            'assets/images/login_wallet_illustration.png',
                            width: 380,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 25),
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

class _TrustIndicators extends StatelessWidget {
  const _TrustIndicators({required this.colors});

  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.success),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: SmSpacing.lg,
      runSpacing: SmSpacing.sm,
      children: [
        item(Icons.verified_user_outlined, 'Secure'),
        item(Icons.lock_outline, 'Private'),
        item(Icons.track_changes_outlined, 'Cashback tracked'),
      ],
    );
  }
}

class _SmartMoneyLoginButton extends StatefulWidget {
  const _SmartMoneyLoginButton({
    required this.colors,
    required this.isLoading,
    required this.onPressed,
  });

  final SmColors colors;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_SmartMoneyLoginButton> createState() =>
      _SmartMoneyLoginButtonState();
}

class _SmartMoneyLoginButtonState extends State<_SmartMoneyLoginButton> {
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
                      Icon(Icons.login_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Log in',
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
