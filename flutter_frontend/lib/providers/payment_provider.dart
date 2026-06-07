import 'package:flutter/material.dart';
import '../services/api_client.dart';

class PaymentProvider extends ChangeNotifier {
  final ApiClient _apiClient = ApiClient();

  List<dynamic> _transactions = [];
  List<dynamic> _payoutMethods = [];
  Map<String, dynamic> _paymentChannels = {};
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get transactions => _transactions;
  List<dynamic> get payoutMethods => _payoutMethods;
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

  Future<void> fetchPayoutMethods() async {
    _setError(null);
    try {
      _payoutMethods = await _apiClient.getPayoutMethods();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> fetchPaymentChannels() async {
    if (_paymentChannels.isNotEmpty) return; // cache locally
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

  Future<Map<String, dynamic>> createTransaction(
    double amount,
    String description,
    String methodType,
    String channel, {
    String? paymentTokenId,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final newTx = await _apiClient.createTransaction(
        amount,
        description,
        methodType,
        channel,
        paymentTokenId: paymentTokenId,
      );
      // Insert at the top of local list
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

  Future<Map<String, dynamic>> createCardSession({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final session = await _apiClient.createCardSession(
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );
      return session;
    } catch (e) {
      _setError(e.toString());
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>> acceptTransaction(int id, int payoutMethodId) async {
    _setLoading(true);
    _setError(null);
    try {
      final result = await _apiClient.acceptTransaction(id, payoutMethodId);
      // Update local transaction status
      final index = _transactions.indexWhere((tx) => tx['id'] == id);
      if (index != -1) {
        _transactions[index]['status'] = 'ACCEPTED';
        _transactions[index]['payout_method_id'] = payoutMethodId;
        _transactions[index]['disbursement_external_id'] = result['disbursement']['external_id'] ?? '';
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
      final Map<String, dynamic> data = {
        'label': label,
        'channel_code': channelCode,
        'channel_type': channelType,
        'account_number': accountNumber,
        'is_primary': isPrimary,
      };
      if (holderName != null && holderName.isNotEmpty) {
        data['holder_name'] = holderName;
      }

      final newMethod = await _apiClient.createPayoutMethod(data);
      if (isPrimary) {
        // Set others to not primary in local state
        for (var method in _payoutMethods) {
          method['is_primary'] = false;
        }
      }
      _payoutMethods.insert(0, newMethod);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  Future<void> deletePayoutMethod(int id) async {
    _setError(null);
    try {
      await _apiClient.deletePayoutMethod(id);
      _payoutMethods.removeWhere((method) => method['id'] == id);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
      rethrow;
    }
  }

  /// Lightweight fetch for polling transaction status
  Future<Map<String, dynamic>> fetchSingleTransactionUpdate(int id) async {
    try {
      final updatedTx = await _apiClient.getTransaction(id);
      final index = _transactions.indexWhere((tx) => tx['id'] == id);
      if (index != -1) {
        // Only update fields and notify if changed
        if (_transactions[index]['status'] != updatedTx['status']) {
          _transactions[index] = updatedTx;
          notifyListeners();
        }
      }
      return updatedTx;
    } catch (e) {
      debugPrint("Single transaction fetch error: $e");
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
}
