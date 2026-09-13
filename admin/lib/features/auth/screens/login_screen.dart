import 'package:flutter/material.dart';

import '../../../core/auth/admin_session.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/google_sign_in_button.dart';
import '../widgets/login_brand_panel.dart';
import 'forgot_password_dialog.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  bool _obscurePassword = true;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await AdminSession.instance.login(
        _emailController.text.trim(),
        _passwordController.text,
        rememberMe: _rememberMe,
      );
      // Navigation happens via the ValueListenableBuilder in main.dart once
      // claims.value flips non-null — nothing to push here.
    } catch (error) {
      setState(() {
        _errorMessage = error is StateError
            ? error.message
            : 'Invalid email or password.';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _notify(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.surface,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: AdminColors.backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSplit =
                  constraints.maxWidth >= AdminBreakpoints.loginSplit;

              final form = _LoginForm(
                formKey: _formKey,
                emailController: _emailController,
                passwordController: _passwordController,
                submitting: _submitting,
                obscurePassword: _obscurePassword,
                rememberMe: _rememberMe,
                errorMessage: _errorMessage,
                showBrandLockup: !isSplit,
                onTogglePasswordVisibility: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onRememberMeChanged: (value) =>
                    setState(() => _rememberMe = value ?? true),
                onSubmit: _submit,
                onForgotPassword: () => showForgotPasswordDialog(context),
                onGoogleSignIn: () => _notify(
                  "Google sign-in isn't available for the admin panel yet.",
                ),
              );

              if (!isSplit) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminSpacing.xxl,
                    vertical: AdminSpacing.huge,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: form,
                    ),
                  ),
                );
              }

              return Row(
                children: [
                  const Expanded(flex: 5, child: LoginBrandPanel()),
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminSpacing.huge,
                        vertical: AdminSpacing.huge,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: form,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  const _LoginForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.submitting,
    required this.obscurePassword,
    required this.rememberMe,
    required this.errorMessage,
    required this.showBrandLockup,
    required this.onTogglePasswordVisibility,
    required this.onRememberMeChanged,
    required this.onSubmit,
    required this.onForgotPassword,
    required this.onGoogleSignIn,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool submitting;
  final bool obscurePassword;
  final bool rememberMe;
  final String? errorMessage;
  final bool showBrandLockup;
  final VoidCallback onTogglePasswordVisibility;
  final ValueChanged<bool?> onRememberMeChanged;
  final VoidCallback onSubmit;
  final VoidCallback onForgotPassword;
  final VoidCallback onGoogleSignIn;

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, size: 20, color: AdminColors.textMuted),
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showBrandLockup) ...[
            const Center(child: LoginBrandLockup(centered: true)),
            const SizedBox(height: AdminSpacing.xxl),
          ],
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AdminColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AdminRadius.chip),
                ),
                child: const Text(
                  'Admin Access',
                  style: TextStyle(
                    color: AdminColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: AdminSpacing.lg),
              const Text(
                'Admin Login',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Access the SmartMoney admin dashboard',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AdminColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.huge),
          const Text(
            'Email Address',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !submitting,
            textInputAction: TextInputAction.next,
            decoration: _decoration(
              hint: 'admin@smartmoney.com',
              icon: Icons.mail_outline_rounded,
            ),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Email is required'
                : null,
          ),
          const SizedBox(height: AdminSpacing.lg),
          const Text(
            'Password',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: passwordController,
            obscureText: obscurePassword,
            enabled: !submitting,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: _decoration(
              hint: 'Enter your password',
              icon: Icons.lock_outline_rounded,
              suffixIcon: IconButton(
                onPressed: onTogglePasswordVisibility,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AdminColors.textMuted,
                ),
              ),
            ),
            validator: (value) => (value == null || value.isEmpty)
                ? 'Password is required'
                : null,
          ),
          const SizedBox(height: AdminSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: submitting ? null : onForgotPassword,
              child: const Text('Forgot password?'),
            ),
          ),
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: rememberMe,
                  onChanged: submitting
                      ? null
                      : (value) => onRememberMeChanged(value),
                  activeColor: AdminColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(width: AdminSpacing.sm),
              const Text(
                'Keep me signed in',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AdminColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          if (errorMessage != null) ...[
            const SizedBox(height: AdminSpacing.md),
            Text(
              errorMessage!,
              style: const TextStyle(color: AdminColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: AdminSpacing.xl),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: submitting ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AdminColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AdminRadius.button),
                ),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.login_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Log In',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: AdminSpacing.xl),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminSpacing.md,
                ),
                child: Text(
                  'or',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: AdminSpacing.xl),
          GoogleSignInButton(onPressed: submitting ? null : onGoogleSignIn),
          if (showBrandLockup) ...[
            const SizedBox(height: AdminSpacing.xxxl),
            const Center(child: LoginTrustBadges()),
          ],
          const SizedBox(height: AdminSpacing.xxl),
          const Text(
            'Only authorized personnel can access this system.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AdminColors.textMuted),
          ),
        ],
      ),
    );
  }
}
