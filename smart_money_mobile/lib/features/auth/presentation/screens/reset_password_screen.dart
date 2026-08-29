import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_motion.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/fade_slide_in.dart';
import '../../../../core/widgets/otp_code_input.dart';
import '../../data/models/forgot_password_request.dart';
import '../../data/models/reset_password_request.dart';
import '../../data/services/auth_api_service.dart';

/// Second half of password recovery: enter the OTP just emailed plus a new
/// password. Reached only from [ForgotPasswordScreen], which supplies the
/// email as the route argument.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});

  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _authApiService = AuthApiService();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpInputKey = GlobalKey<OtpCodeInputState>();

  String _otp = '';
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  bool _isResending = false;

  Timer? _resendTimer;
  int _remainingSeconds = 0;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _resendTimer?.cancel();
    _authApiService.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();

    setState(() => _remainingSeconds = 120);

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _remainingSeconds = 0);
        return;
      }
      if (mounted) setState(() => _remainingSeconds--);
    });
  }

  String? _validateNewPassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'New password is required';
    }
    if (password.length < 8) {
      return 'Password must be at least 8 characters';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _newPasswordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _resendCode() async {
    if (_isResending) return;

    setState(() => _isResending = true);

    try {
      await _authApiService.forgotPassword(
        ForgotPasswordRequest(email: widget.email),
      );

      if (!mounted) return;

      _startResendTimer();
      _otpInputKey.currentState?.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A new code has been sent')),
      );
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to resend code. Please try again.')),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the complete 6-digit code')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await _authApiService.resetPassword(
        ResetPasswordRequest(
          email: widget.email,
          otp: _otp,
          newPassword: _newPasswordController.text,
        ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.login,
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
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
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.of(context).pop(),
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                color: colors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Reset Password',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Enter the 6-digit code sent to\n${widget.email}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            height: 1.45,
                            color: colors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: SmSpacing.xxl),
                        OtpCodeInput(
                          key: _otpInputKey,
                          onChanged: (value) => setState(() => _otp = value),
                        ),
                        const SizedBox(height: SmSpacing.md),
                        Center(
                          child: _remainingSeconds > 0
                              ? Text(
                                  'Resend code in '
                                  '${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:'
                                  '${(_remainingSeconds % 60).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textSecondary,
                                  ),
                                )
                              : TextButton(
                                  onPressed: _isResending ? null : _resendCode,
                                  child: _isResending
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          'Resend code',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: colors.primary,
                                          ),
                                        ),
                                ),
                        ),
                        const SizedBox(height: SmSpacing.lg),
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
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _obscureNewPassword,
                                textInputAction: TextInputAction.next,
                                validator: _validateNewPassword,
                                enabled: !_isSubmitting,
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'New password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscureNewPassword =
                                          !_obscureNewPassword,
                                    ),
                                    icon: Icon(
                                      _obscureNewPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                textInputAction: TextInputAction.done,
                                validator: _validateConfirmPassword,
                                enabled: !_isSubmitting,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: _inputDecoration(
                                  colors: colors,
                                  hintText: 'Confirm new password',
                                  icon: Icons.lock_outline,
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: colors.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: SmSpacing.lg),
                              _ResetSubmitButton(
                                colors: colors,
                                isLoading: _isSubmitting,
                                onPressed: _isSubmitting ? null : _submit,
                              ),
                            ],
                          ),
                        ),
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

class _ResetSubmitButton extends StatefulWidget {
  const _ResetSubmitButton({
    required this.colors,
    required this.isLoading,
    required this.onPressed,
  });

  final SmColors colors;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_ResetSubmitButton> createState() => _ResetSubmitButtonState();
}

class _ResetSubmitButtonState extends State<_ResetSubmitButton> {
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
                : const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
