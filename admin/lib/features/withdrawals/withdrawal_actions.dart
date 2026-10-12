import 'models/admin_withdrawal.dart';

/// Which actions an admin is offered on a withdrawal.
///
/// These mirror the backend's rules closely enough to hide buttons that would
/// certainly be refused. The server stays the final judge: anything this cannot
/// tell for sure (for example whether the active payment provider pays
/// automatically) is still offered, and a refusal comes back as a plain message.
///
/// The key rule: once a payment provider has been asked to pay a withdrawal, it
/// owns it. A person may only step in after it needs attention (its retries ran
/// out, or something contradicted our records). Otherwise declining or settling
/// by hand could pay the user twice, once by the provider and once by the admin.
class WithdrawalActions {
  const WithdrawalActions({
    required this.approve,
    required this.decline,
    required this.markPaid,
    required this.markFailed,
    required this.acknowledge,
    required this.providerOwns,
  });

  /// Requested only: clears it for payout.
  final bool approve;

  /// Requested or Approved: refunds the user, and tells them why.
  final bool decline;

  /// Records a payment made outside the system. Works straight from Requested
  /// (it approves first).
  final bool markPaid;

  /// Approved or Processing: the payout could not be made; refunds the user.
  final bool markFailed;

  /// Needs attention: clears the flag. Moves no money.
  final bool acknowledge;

  /// The payment provider is handling it and nothing here can safely change
  /// that yet.
  final bool providerOwns;

  bool get any => approve || decline || markPaid || markFailed || acknowledge;

  factory WithdrawalActions.of(AdminWithdrawal w) {
    final requested = w.status == 'Requested';
    final approved = w.status == 'Approved';
    final processing = w.status == 'Processing';

    // A submission has started once we recorded a send time or an attempt,
    // even one that timed out: the provider may have received it.
    final started = w.submittedAt != null || w.submissionAttempts > 0;
    final providerOwns = w.isOpen && started && !w.needsAttention;

    return WithdrawalActions(
      approve: requested,
      decline: (requested || approved) && !providerOwns,
      markPaid: (requested || approved || processing) && !providerOwns,
      markFailed: (approved || processing) && !providerOwns,
      acknowledge: w.needsAttention,
      providerOwns: providerOwns,
    );
  }
}
