/// Mirrors the backend's `CashbackSettingsResponse`.
class AdminCashbackSettings {
  const AdminCashbackSettings({
    required this.userSharePercent,
    required this.confirmationWindowDays,
    required this.updatedAt,
  });

  final double userSharePercent;
  final int confirmationWindowDays;
  final DateTime? updatedAt;

  factory AdminCashbackSettings.fromJson(Map<String, dynamic> json) {
    return AdminCashbackSettings(
      userSharePercent: (json['userSharePercent'] as num?)?.toDouble() ?? 0,
      confirmationWindowDays: (json['confirmationWindowDays'] as num?)?.toInt() ?? 0,
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse('${json['updatedAt']}'),
    );
  }
}
