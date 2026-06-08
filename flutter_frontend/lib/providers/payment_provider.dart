import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../services/payout_storage_service.dart';

class PaymentProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  final PayoutStorageService _payoutStorage = PayoutStorageService();

  List<dynamic> _transactions = [];
  List<PayoutMethod> _payoutMethods = [];
  Map<String, dynamic> _paymentChannels = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get transactions => _transactions;
  List<PayoutMethod> get payoutMethods => _payoutMethods;
  Map<String, dynamic> get paymentChannels => _paymentChannels;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // ─── Transactions ─────────────────────────────────────────────────────────

  Future<void> fetchTransactions() async {
    _setLoading(true);
    _setError(null);
    try {
      _transactions = await _apiClient.getTransactions();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> createTransaction(
    double amount,
    String description,
    String methodType,
    String channel,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final newTx = await _apiClient.createTransaction(amount, description, methodType, channel);
      _transactions.insert(0, newTx);
      notifyListeners();
      return newTx;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> chargeCard({
    required double amount,
    required String description,
    required String cardNumber,
    required String expiryMonth,
    required String expiryYear,
    required String cvn,
    required String cardholderFirstName,
    required String cardholderLastName,
    required String cardholderEmail,
    required String cardholderPhone,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _apiClient.chargeCard(
        amount: amount,
        description: description,
        cardNumber: cardNumber,
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvn: cvn,
        cardholderFirstName: cardholderFirstName,
        cardholderLastName: cardholderLastName,
        cardholderEmail: cardholderEmail,
        cardholderPhone: cardholderPhone,
      );
      // If status is SUCCEEDED immediately, add to local transactions
      if ((result['status'] ?? '').toString().toUpperCase() == 'SUCCEEDED') {
        _transactions.insert(0, result);
        notifyListeners();
      }
      return result;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> acceptTransaction(
    int id,
    PayoutMethod method,
  ) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _apiClient.acceptTransaction(
        id,
        channelCode: method.channelCode,
        channelType: method.channelType,
        accountNumber: method.accountNumber,
        accountHolderName: method.holderName ?? method.label,
      );
      final index = _transactions.indexWhere((tx) => tx['id'] == id);
      if (index != -1) {
        _transactions[index]['status'] = 'ACCEPTED';
      }
      notifyListeners();
      return result;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> fetchSingleTransactionUpdate(int id) async {
    try {
      final updatedTx = await _apiClient.getTransaction(id);
      final index = _transactions.indexWhere((tx) => tx['id'] == id);
      if (index != -1 && _transactions[index]['status'] != updatedTx['status']) {
        _transactions[index] = updatedTx;
        notifyListeners();
      }
      return updatedTx;
    } catch (e) {
      debugPrint('Single transaction fetch error: $e');
      rethrow;
    }
  }

  Future<void> simulateTransaction(int id) async {
    _setLoading(true);
    _setError(null);
    try {
      await _apiClient.simulateTransaction(id);
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> clearTransactions() async {
    _setLoading(true);
    _setError(null);
    try {
      await _apiClient.clearTransactions();
      _transactions.clear();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> fetchPaymentChannels() async {
    if (_paymentChannels.isNotEmpty) return;
    _setLoading(true);
    _setError(null);
    try {
      _paymentChannels = await _apiClient.getPaymentChannels();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ─── Payout Methods (local encrypted storage) ─────────────────────────────

  Future<void> fetchPayoutMethods() async {
    _setError(null);
    try {
      _payoutMethods = await _payoutStorage.getAll();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> createPayoutMethod({
    required String label,
    required String channelCode,
    required String channelType,
    required String accountNumber,
    String? holderName,
    bool isPrimary = false,
  }) async {
    _setError(null);
    try {
      final newMethod = await _payoutStorage.save(
        label: label,
        channelCode: channelCode,
        channelType: channelType,
        accountNumber: accountNumber,
        holderName: holderName,
        isPrimary: isPrimary,
      );
      if (isPrimary) {
        _payoutMethods = _payoutMethods.map((m) => PayoutMethod(
          id: m.id, label: m.label, channelCode: m.channelCode,
          channelType: m.channelType, accountNumber: m.accountNumber,
          holderName: m.holderName, maskedAccount: m.maskedAccount, isPrimary: false,
        )).toList();
      }
      _payoutMethods.insert(0, newMethod);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> deletePayoutMethod(String id) async {
    _setError(null);
    try {
      await _payoutStorage.delete(id);
      _payoutMethods.removeWhere((m) => m.id == id);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }
}
