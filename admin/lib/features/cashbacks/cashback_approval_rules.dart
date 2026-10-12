/// Mirrors the server's approval rule so the review page can say, before a
/// click, whether Approve will be accepted. The server is still the judge and
/// repeats the same check.
///
/// A cashback may be approved only once the affiliate network says the sale
/// is validated (the merchant accepted it after the return period) or paid.
const Set<String> _approvable = {'validated', 'paid'};

/// Null when approving is allowed; otherwise a plain reason it is not.
String? cashbackApprovalRefusal(String networkStatus) {
  final status = networkStatus.trim().toLowerCase();

  if (_approvable.contains(status)) return null;

  switch (status) {
    case 'pending':
      return 'The network still reports this sale as pending, so the return '
          'period is not over. It can be approved once it is validated.';
    case 'rejected':
    case 'cancelled':
    case 'canceled':
      return 'The network reports this sale as $status. Reject it instead.';
    case 'reversed':
      return 'The network reports this sale as reversed. Reverse or reject it.';
    case '':
      return 'The network status of this sale is not known yet.';
    default:
      return 'The network reports this sale as "$status", which is not '
          'validated yet.';
  }
}
