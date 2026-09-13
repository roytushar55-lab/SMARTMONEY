import 'package:flutter/material.dart';

import '../../../core/auth/auth_api_service.dart';
import '../../../core/auth/forgot_password_request.dart';
import '../../../core/auth/reset_password_request.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/spaced_column.dart';

enum _Step { email, reset }

/// Two-step password reset (request a code, then submit it with a new
/// password) reusing the identity API's generic forgot/reset-password
/// endpoints — the same ones the mobile app uses. An admin's `User` row has
/// a password like any other account, so no admin-specific backend work was
/// needed.
Future<void> showForgotPasswordDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ForgotPasswordDialog(),
  );
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog();

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _authApiService = AuthApiService();

  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _Step _step = _Step.email;
  bool _submitting = false;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _authApiService.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await _authApiService.forgotPassword(
        ForgotPasswordRequest(email: _emailController.text.trim()),
      );

      if (!mounted) return;

      setState(() {
        _step = _Step.reset;
        _submitting = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await _authApiService.forgotPassword(
        ForgotPasswordRequest(email: _emailController.text.trim()),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to resend code. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _resetPassword() async {
    if (!_resetFormKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final response = await _authApiService.resetPassword(
        ResetPasswordRequest(
          email: _emailController.text.trim(),
          otp: _otpController.text.trim(),
          newPassword: _newPasswordController.text,
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(response.message)));
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _submitting = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEmailStep = _step == _Step.email;

    return AlertDialog(
      title: Text(isEmailStep ? 'Forgot password' : 'Reset password'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: isEmailStep ? _buildEmailStep() : _buildResetStep(),
        ),
      ),
      actions: isEmailStep
          ? [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: _submitting ? null : _sendCode,
                child: _submitting ? _spinner() : const Text('Send code'),
              ),
            ]
          : [
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() => _step = _Step.email),
                child: const Text('Back'),
              ),
              FilledButton(
                onPressed: _submitting ? null : _resetPassword,
                child: _submitting ? _spinner() : const Text('Reset password'),
              ),
            ],
    );
  }

  Widget _spinner() {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: withGaps([
          const Text(
            "Enter the account's email and we'll send a 6-digit code to "
            'reset its password.',
            style: TextStyle(color: AdminColors.textSecondary, fontSize: 13),
          ),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            enabled: !_submitting,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Email'),
            onFieldSubmitted: (_) => _sendCode(),
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Email is required'
                : null,
          ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: AdminColors.danger, fontSize: 13),
            ),
        ]),
      ),
    );
  }

  Widget _buildResetStep() {
    return Form(
      key: _resetFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: withGaps([
          Text(
            'Enter the 6-digit code sent to ${_emailController.text.trim()}.',
            style: const TextStyle(
              color: AdminColors.textSecondary,
              fontSize: 13,
            ),
          ),
          TextFormField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            enabled: !_submitting,
            autofocus: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Reset code',
              counterText: '',
            ),
            validator: (value) => (value == null || value.trim().length != 6)
                ? 'Enter the 6-digit code'
                : null,
          ),
          TextFormField(
            controller: _newPasswordController,
            obscureText: _obscureNewPassword,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: 'New password',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
                icon: Icon(
                  _obscureNewPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => (value == null || value.length < 8)
                ? 'At least 8 characters'
                : null,
          ),
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            enabled: !_submitting,
            onFieldSubmitted: (_) => _resetPassword(),
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value != _newPasswordController.text
                ? 'Passwords do not match'
                : null,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: _submitting ? null : _resendCode,
              child: const Text('Resend code'),
            ),
          ),
          if (_error != null)
            Text(
              _error!,
              style: const TextStyle(color: AdminColors.danger, fontSize: 13),
            ),
        ]),
      ),
    );
  }
}
