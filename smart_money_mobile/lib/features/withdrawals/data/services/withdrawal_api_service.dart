import '../../../../core/network/authorized_api_client.dart';
import '../models/withdrawal.dart';
import '../models/withdrawal_decision.dart';
import '../models/withdrawal_page.dart';
import '../models/withdrawal_preview.dart';

/// `Upi` or `BankTransfer`, as the backend spells them.
enum PayoutMethod {
  upi('Upi'),
  bankTransfer('BankTransfer');

  const PayoutMethod(this.apiValue);

  final String apiValue;
}

/// The user's own withdrawals (`/api/withdrawals`). A refused request
/// (wrong password or bad details: 400; account, balance or an open
/// withdrawal in the way: 409) surfaces as an [ApiException] carrying the
/// server's plain-language message, which is safe to show as it is.
class WithdrawalApiService {
  WithdrawalApiService({AuthorizedApiClient? client})
    : _client = client ?? AuthorizedApiClient(),
      _ownsClient = client == null;

  final AuthorizedApiClient _client;
  final bool _ownsClient;

  /// What withdrawing [amount] would cost and whether it is allowed. Amount
  /// 0 is a valid way to learn the limits and the balance before the user
  /// has typed anything.
  Future<WithdrawalPreview> preview(double amount) async {
    final json = await _client.getJson(
      '/api/withdrawals/preview?amount=${_formatAmount(amount)}',
    );
    return WithdrawalPreview.fromJson(json);
  }

  /// Asks to withdraw. [password] re-confirms the user before money moves.
  /// Send [upiId] for UPI, or [bankAccountNumber] and [ifscCode] for a bank
  /// transfer; the server validates and normalises them.
  Future<Withdrawal> request({
    required double amount,
    required PayoutMethod method,
    required String beneficiaryName,
    String? upiId,
    String? bankAccountNumber,
    String? ifscCode,
    required String password,
  }) async {
    final json = await _client.postJson(
      '/api/withdrawals',
      body: {
        'amount': amount,
        'method': method.apiValue,
        'beneficiaryName': beneficiaryName,
        'upiId': upiId,
        'bankAccountNumber': bankAccountNumber,
        'ifscCode': ifscCode,
        'password': password,
      },
    );
    return Withdrawal.fromJson(json);
  }

  /// One page of the user's withdrawals, newest first.
  Future<WithdrawalPage> list({int page = 1, int pageSize = 20}) async {
    final json = await _client.getJson(
      '/api/withdrawals?page=$page&pageSize=$pageSize',
    );
    return WithdrawalPage.fromJson(json);
  }

  /// One withdrawal, fresh from the server. 404 when it is not the user's.
  Future<Withdrawal> get(String id) async {
    final json = await _client.getJson('/api/withdrawals/$id');
    return Withdrawal.fromJson(json);
  }

  /// Takes back a request that has not been approved yet; the money returns
  /// to the wallet at once. Anything later than Requested is a 409 with the
  /// server's explanation.
  Future<WithdrawalDecision> cancel(String id) async {
    final json = await _client.postJson('/api/withdrawals/$id/cancel');
    return WithdrawalDecision.fromJson(json);
  }

  /// `500` or `500.5`, never `500.00` or `500.50`, so the query string reads
  /// naturally.
  static String _formatAmount(double amount) {
    return amount
        .toStringAsFixed(2)
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }

  void dispose() {
    if (_ownsClient) _client.dispose();
  }
}
