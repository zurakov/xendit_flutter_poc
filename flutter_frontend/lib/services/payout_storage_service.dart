import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PayoutMethod {
  final String id;
  final String label;
  final String channelCode;   // e.g. BCA, BRI, OVO
  final String channelType;   // BANK | EWALLET
  final String accountNumber; // plain, stored encrypted
  final String? holderName;
  final String maskedAccount;
  final bool isPrimary;

  PayoutMethod({
    required this.id,
    required this.label,
    required this.channelCode,
    required this.channelType,
    required this.accountNumber,
    this.holderName,
    required this.maskedAccount,
    required this.isPrimary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'channel_code': channelCode,
        'channel_type': channelType,
        'account_number': accountNumber,
        'holder_name': holderName,
        'masked_account': maskedAccount,
        'is_primary': isPrimary,
      };

  factory PayoutMethod.fromJson(Map<String, dynamic> json) => PayoutMethod(
        id: json['id'],
        label: json['label'],
        channelCode: json['channel_code'],
        channelType: json['channel_type'],
        accountNumber: json['account_number'],
        holderName: json['holder_name'],
        maskedAccount: json['masked_account'],
        isPrimary: json['is_primary'] ?? false,
      );
}

class PayoutStorageService {
  static const _key = 'payout_methods_v1';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  Future<List<PayoutMethod>> getAll() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => PayoutMethod.fromJson(e)).toList();
  }

  Future<PayoutMethod> save({
    required String label,
    required String channelCode,
    required String channelType,
    required String accountNumber,
    String? holderName,
    bool isPrimary = false,
  }) async {
    final methods = await getAll();
    final maskedAccount =
        accountNumber.length >= 4 ? '••••${accountNumber.substring(accountNumber.length - 4)}' : '••••';

    if (isPrimary) {
      for (var m in methods) {
        m.toJson()['is_primary'] = false;
      }
    }

    final newMethod = PayoutMethod(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      label: label,
      channelCode: channelCode,
      channelType: channelType,
      accountNumber: accountNumber,
      holderName: holderName,
      maskedAccount: maskedAccount,
      isPrimary: isPrimary,
    );

    // Set existing to non-primary if needed
    final updated = methods
        .map((m) => PayoutMethod(
              id: m.id,
              label: m.label,
              channelCode: m.channelCode,
              channelType: m.channelType,
              accountNumber: m.accountNumber,
              holderName: m.holderName,
              maskedAccount: m.maskedAccount,
              isPrimary: isPrimary ? false : m.isPrimary,
            ))
        .toList();
    updated.insert(0, newMethod);

    await _storage.write(key: _key, value: jsonEncode(updated.map((e) => e.toJson()).toList()));
    return newMethod;
  }

  Future<void> delete(String id) async {
    final methods = await getAll();
    methods.removeWhere((m) => m.id == id);
    await _storage.write(key: _key, value: jsonEncode(methods.map((e) => e.toJson()).toList()));
  }
}
