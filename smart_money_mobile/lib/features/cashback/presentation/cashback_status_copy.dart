import '../../../core/widgets/status_badge.dart';
import '../data/models/cashback_item.dart';

/// Human-readable label for a [CashbackStatus], per the app's plain-language
/// microcopy rule (never surface raw backend status names).
String cashbackStatusLabel(CashbackStatus status) {
  switch (status) {
    case CashbackStatus.pending:
      return 'Cashback pending';
    case CashbackStatus.confirmed:
      return 'Cashback confirmed';
    case CashbackStatus.rejected:
      return 'Not approved';
    case CashbackStatus.paidOut:
      return 'Paid out';
    case CashbackStatus.reversed:
      return 'Reversed';
    case CashbackStatus.awaitingAdminReview:
      return 'Under review';
  }
}

StatusTone cashbackStatusTone(CashbackStatus status) {
  switch (status) {
    case CashbackStatus.confirmed:
    case CashbackStatus.paidOut:
      return StatusTone.success;
    case CashbackStatus.pending:
    case CashbackStatus.awaitingAdminReview:
      return StatusTone.pending;
    case CashbackStatus.rejected:
    case CashbackStatus.reversed:
      return StatusTone.danger;
  }
}
