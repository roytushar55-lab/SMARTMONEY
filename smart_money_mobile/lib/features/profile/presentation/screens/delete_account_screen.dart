import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/widgets/login_demo_widgets.dart';
import '../../../auth/data/services/token_storage_service.dart';
import '../../../wallet/data/models/wallet_summary.dart';
import '../../../wallet/data/services/wallet_api_service.dart';
import '../../data/services/profile_api_service.dart';

/// Confirmation step for permanently deleting the signed-in account.
///
/// The backend is the source of truth for every rule here (password check,
/// wallet balance, forfeiting pending cashback); this screen only explains
/// the consequences and mirrors the wallet check so the user isn't surprised
/// by a refusal.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _profileApiService = ProfileApiService();
  final _walletApiService = WalletApiService();
  final _tokenStorageService = const TokenStorageService();
  final _passwordController = TextEditingController();

  WalletSummary? _wallet;
  bool _isLoadingWallet = true;
  bool _walletFailed = false;
  bool _isDeleting = false;
  bool _isPasswordHidden = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() => setState(() {}));
    _loadWallet();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _profileApiService.dispose();
    _walletApiService.dispose();
    super.dispose();
  }

  bool get _hasBalance => (_wallet?.availableBalance ?? 0) > 0;

  bool get _canDelete =>
      _wallet != null &&
      !_hasBalance &&
      _passwordController.text.isNotEmpty &&
      !_isDeleting;

  Future<void> _loadWallet() async {
    setState(() {
      _isLoadingWallet = true;
      _walletFailed = false;
    });

    try {
      final wallet = await _walletApiService.getMyWallet();
      if (!mounted) return;
      setState(() {
        _wallet = wallet;
        _isLoadingWallet = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingWallet = false;
        _walletFailed = true;
      });
    }
  }

  Future<void> _deleteAccount() async {
    if (!_canDelete) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isDeleting = true;
      _error = null;
    });

    try {
      await _profileApiService.deleteAccount(_passwordController.text);
      await _tokenStorageService.clearTokens();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your account has been deleted')),
      );
      Navigator.pushNamedAndRemoveUntil(
        context,
        RouteNames.login,
        (_) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = e.message;
      });
      // A 409 means the balance changed since this screen loaded.
      if (e.statusCode == 409) {
        _loadWallet();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isDeleting = false;
        _error = 'Unable to delete your account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Scaffold(
      body: LoginDemoBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: _isDeleting
                              ? null
                              : () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Back',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.74,
                            ),
                            foregroundColor: colors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Delete account',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildWarning(colors),
                    const SizedBox(height: 16),
                    _buildConsequences(colors),
                    const SizedBox(height: 16),
                    _buildWalletCheck(colors),
                    const SizedBox(height: 16),
                    _buildConfirm(colors),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarning(SmColors colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.danger),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "This can't be undone",
                  style: TextStyle(
                    color: colors.danger,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "You'll be logged out and won't be able to sign in with "
                  'this account again.',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsequences(SmColors colors) {
    return LoginDemoGlassCard(
      borderRadius: 22,
      enableBlur: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'What happens',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _Point(
            icon: Icons.check_circle_outline_rounded,
            color: colors.success,
            text: 'Your name, email, phone number and photo are removed.',
          ),
          _Point(
            icon: Icons.check_circle_outline_rounded,
            color: colors.success,
            text: 'Any pending cashback is forfeited.',
          ),
          _Point(
            icon: Icons.info_outline_rounded,
            color: colors.warning,
            text:
                'A restricted copy of your name, email and phone number is '
                'kept for 90 days for fraud checks and disputes, then erased.',
          ),
          _Point(
            icon: Icons.info_outline_rounded,
            color: colors.warning,
            text:
                'Transaction and payout records are kept for up to 8 years, '
                'as our Privacy Policy explains.',
          ),
        ],
      ),
    );
  }

  Widget _buildWalletCheck(SmColors colors) {
    final wallet = _wallet;

    Widget status;
    if (_isLoadingWallet) {
      status = SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      );
    } else if (_walletFailed || wallet == null) {
      status = TextButton(
        onPressed: _loadWallet,
        child: const Text('Retry'),
      );
    } else {
      status = Text(
        '₹${wallet.availableBalance.toStringAsFixed(2)}',
        style: TextStyle(
          color: colors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      );
    }

    String? note;
    Color noteColor = colors.textMuted;
    if (_walletFailed) {
      note = "We couldn't check your wallet. Retry to continue.";
      noteColor = colors.danger;
    } else if (_hasBalance) {
      note =
          'Withdraw your balance first. Accounts with money in the wallet '
          "can't be deleted.";
      noteColor = colors.danger;
    } else if ((wallet?.pendingBalance ?? 0) > 0) {
      note =
          '₹${wallet!.pendingBalance.toStringAsFixed(2)} in pending cashback '
          'will be forfeited.';
      noteColor = colors.warning;
    }

    return LoginDemoGlassCard(
      borderRadius: 22,
      enableBlur: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Withdrawable balance',
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              status,
            ],
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(
              note,
              style: TextStyle(
                color: noteColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConfirm(SmColors colors) {
    return LoginDemoGlassCard(
      borderRadius: 22,
      enableBlur: false,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Confirm with your password',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _isPasswordHidden,
            enabled: !_isDeleting,
            onSubmitted: (_) => _deleteAccount(),
            decoration: InputDecoration(
              hintText: 'Password',
              prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _isPasswordHidden = !_isPasswordHidden),
                icon: Icon(
                  _isPasswordHidden
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: colors.textMuted,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: TextStyle(
                color: colors.danger,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _canDelete ? _deleteAccount : null,
            style: FilledButton.styleFrom(
              backgroundColor: colors.danger,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _isDeleting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Delete my account',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
