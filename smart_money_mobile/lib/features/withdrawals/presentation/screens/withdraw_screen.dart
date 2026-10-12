import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../data/models/withdrawal.dart';
import '../../data/models/withdrawal_preview.dart';
import '../../data/services/withdrawal_api_service.dart';

String _rupees(double value) => '₹${value.toStringAsFixed(2)}';

/// Same shapes the server accepts, so a typo is caught before a round trip.
/// The server remains the judge: anything it refuses is shown as it says it.
final _upiPattern = RegExp(r'^[a-z0-9._-]{2,256}@[a-z][a-z0-9]{1,63}$');
final _accountPattern = RegExp(r'^[0-9]{9,18}$');
final _ifscPattern = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');

/// Asks for a withdrawal: amount (with the fee and the limits checked live),
/// where to pay it, and the password again. On success it shows what was
/// requested and pops with `true` so the wallet reloads.
class WithdrawScreen extends StatefulWidget {
  const WithdrawScreen({
    super.key,
    this.service,
    this.previewDelay = const Duration(milliseconds: 400),
  });

  /// For tests. When null the screen creates, and later disposes, its own.
  final WithdrawalApiService? service;

  /// How long typing must pause before the fee is looked up.
  final Duration previewDelay;

  @override
  State<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends State<WithdrawScreen> {
  late final WithdrawalApiService _service =
      widget.service ?? WithdrawalApiService();

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _nameController = TextEditingController();
  final _upiController = TextEditingController();
  final _accountController = TextEditingController();
  final _ifscController = TextEditingController();
  final _passwordController = TextEditingController();

  PayoutMethod _method = PayoutMethod.upi;
  bool _hidePassword = true;

  /// The limits and balance, learnt from a preview of amount 0 on open.
  WithdrawalPreview? _limits;
  bool _limitsFailed = false;

  /// The live preview of the typed amount.
  WithdrawalPreview? _preview;
  bool _previewLoading = false;
  bool _previewFailed = false;
  Timer? _previewTimer;
  int _previewToken = 0;

  bool _submitting = false;
  String? _submitError;

  /// Set once the request succeeded; the screen then shows the result.
  Withdrawal? _result;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_onAmountChanged);
    _loadLimits();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    _amountController.dispose();
    _nameController.dispose();
    _upiController.dispose();
    _accountController.dispose();
    _ifscController.dispose();
    _passwordController.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  double? get _amount => double.tryParse(_amountController.text.trim());

  Future<void> _loadLimits() async {
    setState(() => _limitsFailed = false);
    try {
      final limits = await _service.preview(0);
      if (!mounted) return;
      setState(() => _limits = limits);
    } catch (_) {
      if (!mounted) return;
      setState(() => _limitsFailed = true);
    }
  }

  void _onAmountChanged() {
    _previewTimer?.cancel();
    final amount = _amount;
    final token = ++_previewToken;

    if (amount == null || amount <= 0) {
      setState(() {
        _preview = null;
        _previewLoading = false;
        _previewFailed = false;
      });
      return;
    }

    setState(() {
      _previewLoading = true;
      _previewFailed = false;
    });
    _previewTimer = Timer(
      widget.previewDelay,
      () => _fetchPreview(amount, token),
    );
  }

  Future<void> _fetchPreview(double amount, int token) async {
    try {
      final preview = await _service.preview(amount);
      if (!mounted || token != _previewToken) return;
      setState(() {
        _preview = preview;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted || token != _previewToken) return;
      setState(() {
        _preview = null;
        _previewLoading = false;
        _previewFailed = true;
      });
    }
  }

  void _useFullBalance() {
    final available = _limits?.availableBalance ?? 0;
    _amountController.text = available == available.roundToDouble()
        ? available.toStringAsFixed(0)
        : available.toStringAsFixed(2);
  }

  String? _validateAmount(String? value) {
    final amount = double.tryParse((value ?? '').trim());
    if (amount == null || amount <= 0) return 'Enter an amount.';
    final limits = _limits;
    if (limits != null && amount < limits.minimumAmount) {
      return 'The minimum withdrawal is ${_rupees(limits.minimumAmount)}.';
    }
    if (limits != null && amount > limits.maximumAmount) {
      return 'The maximum for one withdrawal is '
          '${_rupees(limits.maximumAmount)}.';
    }
    return null;
  }

  String? _validateName(String? value) => (value ?? '').trim().length < 2
      ? "Enter the account holder's name."
      : null;

  String? _validateUpi(String? value) =>
      _upiPattern.hasMatch((value ?? '').trim().toLowerCase())
      ? null
      : 'Enter a valid UPI ID, like name@bank.';

  String? _validateAccount(String? value) =>
      _accountPattern.hasMatch((value ?? '').trim())
      ? null
      : 'Enter a valid bank account number (9 to 18 digits).';

  String? _validateIfsc(String? value) =>
      _ifscPattern.hasMatch((value ?? '').trim().toUpperCase())
      ? null
      : 'Enter a valid IFSC code, like HDFC0001234.';

  String? _validatePassword(String? value) =>
      (value ?? '').isEmpty ? 'Enter your password.' : null;

  Future<void> _submit() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _submitting = true;
      _submitError = null;
    });

    try {
      final result = await _service.request(
        amount: _amount!,
        method: _method,
        beneficiaryName: _nameController.text.trim(),
        upiId: _method == PayoutMethod.upi
            ? _upiController.text.trim().toLowerCase()
            : null,
        bankAccountNumber: _method == PayoutMethod.bankTransfer
            ? _accountController.text.trim()
            : null,
        ifscCode: _method == PayoutMethod.bankTransfer
            ? _ifscController.text.trim().toUpperCase()
            : null,
        password: _passwordController.text,
      );
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _result = result;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = e.message;
      });
      // The balance or an open withdrawal got in the way: show the fresh
      // picture so the user is not refused twice for the same reason.
      if (e.statusCode == 409) {
        _loadLimits();
        _onAmountChanged();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitError = 'Unable to request the withdrawal. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final result = _result;

    // After a success every way out, including the system back button,
    // tells the wallet to reload.
    return PopScope(
      canPop: result == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        backgroundColor: colors.bgPrimary,
        appBar: AppBar(title: const Text('Withdraw')),
        body: SafeArea(
          top: false,
          child: result == null
              ? _buildForm(colors)
              : _SuccessView(
                  withdrawal: result,
                  colors: colors,
                  onDone: () => Navigator.of(context).pop(true),
                ),
        ),
      ),
    );
  }

  Widget _buildForm(SmColors colors) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          SmSpacing.lg,
          SmSpacing.lg,
          SmSpacing.lg,
          SmSpacing.xxl,
        ),
        children: [
          _sectionTitle(colors, 'Amount'),
          const SizedBox(height: SmSpacing.sm),
          _card(colors, [
            TextFormField(
              controller: _amountController,
              enabled: !_submitting,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              validator: _validateAmount,
              decoration: InputDecoration(
                hintText: 'Amount to withdraw',
                prefixIcon: Icon(
                  Icons.currency_rupee_rounded,
                  color: colors.primary,
                ),
              ),
            ),
            const SizedBox(height: SmSpacing.sm),
            _buildLimitsLine(colors),
            const SizedBox(height: SmSpacing.sm),
            _buildPreview(colors),
          ]),
          const SizedBox(height: SmSpacing.xl),
          _sectionTitle(colors, 'Pay to'),
          const SizedBox(height: SmSpacing.sm),
          _card(colors, [
            SegmentedButton<PayoutMethod>(
              segments: const [
                ButtonSegment(
                  value: PayoutMethod.upi,
                  label: Text('UPI'),
                  icon: Icon(Icons.qr_code_2_rounded),
                ),
                ButtonSegment(
                  value: PayoutMethod.bankTransfer,
                  label: Text('Bank transfer'),
                  icon: Icon(Icons.account_balance_outlined),
                ),
              ],
              selected: {_method},
              showSelectedIcon: false,
              onSelectionChanged: _submitting
                  ? null
                  : (selection) => setState(() => _method = selection.first),
            ),
            const SizedBox(height: SmSpacing.md),
            TextFormField(
              controller: _nameController,
              enabled: !_submitting,
              textCapitalization: TextCapitalization.words,
              validator: _validateName,
              decoration: InputDecoration(
                hintText: 'Account holder name',
                prefixIcon: Icon(Icons.person_outline, color: colors.primary),
              ),
            ),
            const SizedBox(height: SmSpacing.md),
            if (_method == PayoutMethod.upi)
              TextFormField(
                controller: _upiController,
                enabled: !_submitting,
                keyboardType: TextInputType.emailAddress,
                validator: _validateUpi,
                decoration: InputDecoration(
                  hintText: 'UPI ID, like name@bank',
                  prefixIcon: Icon(
                    Icons.alternate_email_rounded,
                    color: colors.primary,
                  ),
                ),
              )
            else ...[
              TextFormField(
                controller: _accountController,
                enabled: !_submitting,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: _validateAccount,
                decoration: InputDecoration(
                  hintText: 'Bank account number',
                  prefixIcon: Icon(
                    Icons.numbers_rounded,
                    color: colors.primary,
                  ),
                ),
              ),
              const SizedBox(height: SmSpacing.md),
              TextFormField(
                controller: _ifscController,
                enabled: !_submitting,
                textCapitalization: TextCapitalization.characters,
                validator: _validateIfsc,
                decoration: InputDecoration(
                  hintText: 'IFSC code, like HDFC0001234',
                  prefixIcon: Icon(
                    Icons.account_balance_outlined,
                    color: colors.primary,
                  ),
                ),
              ),
            ],
            const SizedBox(height: SmSpacing.sm),
            Text(
              'Double-check these details. Money sent to a wrong account '
              'cannot be recovered.',
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ]),
          const SizedBox(height: SmSpacing.xl),
          _sectionTitle(colors, 'Confirm with your password'),
          const SizedBox(height: SmSpacing.sm),
          _card(colors, [
            TextFormField(
              controller: _passwordController,
              enabled: !_submitting,
              obscureText: _hidePassword,
              validator: _validatePassword,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'Password',
                prefixIcon: Icon(Icons.lock_outline, color: colors.primary),
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
            if (_submitError != null) ...[
              const SizedBox(height: SmSpacing.sm),
              Text(
                _submitError!,
                style: TextStyle(
                  color: colors.danger,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: SmSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SmRadius.button),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _amount == null || _amount! <= 0
                          ? 'Withdraw'
                          : 'Withdraw ${_rupees(_amount!)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildLimitsLine(SmColors colors) {
    final limits = _limits;
    final muted = TextStyle(
      color: colors.textMuted,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    if (_limitsFailed) {
      return Row(
        children: [
          Expanded(child: Text("Couldn't load your balance.", style: muted)),
          TextButton(onPressed: _loadLimits, child: const Text('Retry')),
        ],
      );
    }
    if (limits == null) {
      return Text('Loading your balance...', style: muted);
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            'Available ${_rupees(limits.availableBalance)} · '
            'Min ${_rupees(limits.minimumAmount)} · '
            'Max ${_rupees(limits.maximumAmount)}',
            style: muted,
          ),
        ),
        if (limits.availableBalance >= limits.minimumAmount)
          TextButton(
            onPressed: _submitting ? null : _useFullBalance,
            child: const Text('Use full balance'),
          ),
      ],
    );
  }

  Widget _buildPreview(SmColors colors) {
    final amount = _amount;
    if (amount == null || amount <= 0) return const SizedBox.shrink();

    if (_previewLoading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: SmSpacing.sm),
          Text(
            'Checking the fee...',
            style: TextStyle(color: colors.textMuted, fontSize: 12.5),
          ),
        ],
      );
    }

    if (_previewFailed) {
      return Text(
        "Couldn't check the fee right now. You can still continue.",
        style: TextStyle(
          color: colors.textMuted,
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final preview = _preview;
    if (preview == null) return const SizedBox.shrink();

    if (!preview.canWithdraw) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: colors.warning, size: 18),
          const SizedBox(width: SmSpacing.sm),
          Expanded(
            child: Text(
              preview.message ?? 'This amount cannot be withdrawn right now.',
              style: TextStyle(
                color: colors.warning,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _previewRow(colors, 'Amount', _rupees(preview.amount)),
        _previewRow(
          colors,
          preview.userFee > 0 ? 'Fee (your share)' : 'Fee',
          preview.userFee > 0 ? '- ${_rupees(preview.userFee)}' : 'None',
        ),
        const Divider(height: SmSpacing.lg),
        _previewRow(
          colors,
          "You'll receive",
          _rupees(preview.netAmount),
          strong: true,
        ),
      ],
    );
  }

  Widget _previewRow(
    SmColors colors,
    String label,
    String value, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? colors.textPrimary : colors.textSecondary,
                fontSize: 13.5,
                fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong ? colors.success : colors.textPrimary,
              fontSize: strong ? 16 : 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(SmColors colors, String text) {
    return Text(
      text,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _card(SmColors colors, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(SmSpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SmRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

/// What was requested, and what happens next.
class _SuccessView extends StatelessWidget {
  const _SuccessView({
    required this.withdrawal,
    required this.colors,
    required this.onDone,
  });

  final Withdrawal withdrawal;
  final SmColors colors;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SmSpacing.lg,
        SmSpacing.xxxl,
        SmSpacing.lg,
        SmSpacing.xxl,
      ),
      children: [
        Container(
          width: 72,
          height: 72,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.success.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check_rounded, color: colors.success, size: 40),
        ),
        const SizedBox(height: SmSpacing.lg),
        Text(
          'Withdrawal requested',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: SmSpacing.sm),
        Text(
          "We'll review it and pay ${_rupees(withdrawal.netAmount)} to "
          '${withdrawal.destination}. You can cancel it until it is approved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: SmSpacing.xl),
        Container(
          padding: const EdgeInsets.all(SmSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(SmRadius.card),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              _row('Amount', _rupees(withdrawal.amount)),
              if (withdrawal.userFee > 0)
                _row('Fee (your share)', '- ${_rupees(withdrawal.userFee)}'),
              _row("You'll receive", _rupees(withdrawal.netAmount)),
              _row('Pay to', withdrawal.destination),
              _row('Reference', withdrawal.reference),
            ],
          ),
        ),
        const SizedBox(height: SmSpacing.xl),
        FilledButton(
          onPressed: onDone,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(SmRadius.button),
            ),
          ),
          child: const Text(
            'Done',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: SmSpacing.md),
          Expanded(
            child: SelectableText(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
