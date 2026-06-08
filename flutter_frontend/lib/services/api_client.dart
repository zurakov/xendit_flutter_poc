import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio _dio;

  factory ApiClient() => _instance;

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 20),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-Tunnel-Skip-AntiPhishing-Threshold': 'true',
        },
      ),
    );
  }

  String _handleError(dynamic error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        return (data['error'] ?? data['message'] ?? 'API error').toString();
      }
      return error.message ?? 'Network connection issue';
    }
    return error.toString();
  }

  // ─── Transactions ────────────────────────────────────────────────────────────

  Future<List<dynamic>> getTransactions() async {
    try {
      final response = await _dio.get('/transactions');
      if (response.data['success'] == true) return response.data['data'] as List;
      throw Exception(response.data['error'] ?? 'Failed to load transactions');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<void> clearTransactions() async {
    try {
      final response = await _dio.delete('/transactions');
      if (response.data['success'] != true) {
        throw Exception(response.data['error'] ?? 'Failed to clear transactions');
      }
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> getTransaction(int id) async {
    try {
      final response = await _dio.get('/transactions/$id');
      if (response.data['success'] == true) return response.data['data'] as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Failed to load transaction');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> createTransaction(
    double amount,
    String description,
    String methodType,
    String channel,
  ) async {
    try {
      final response = await _dio.post('/transactions', data: {
        'amount': amount,
        'description': description,
        'payment_method_type': methodType,
        'payment_channel': channel,
      });
      if (response.data['success'] == true) return response.data['data'] as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Failed to initiate payment');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Card charge — sends card details directly to backend for v3 payment_request
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
    try {
      final response = await _dio.post('/card/charge', data: {
        'amount': amount,
        'description': description,
        'card_number': cardNumber,
        'expiry_month': expiryMonth,
        'expiry_year': expiryYear,
        'cvn': cvn,
        'cardholder_first_name': cardholderFirstName,
        'cardholder_last_name': cardholderLastName,
        'cardholder_email': cardholderEmail,
        'cardholder_phone': cardholderPhone,
      });
      if (response.data['success'] == true) return response.data['data'] as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Card charge failed');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> simulateTransaction(int id) async {
    try {
      final response = await _dio.post('/transactions/$id/simulate');
      if (response.data['success'] == true) return response.data['data'] as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Failed to simulate payment');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  /// Accept payout — sends payout destination inline (no DB lookup on backend)
  Future<Map<String, dynamic>> acceptTransaction(
    int transactionId, {
    required String channelCode,
    required String channelType,
    required String accountNumber,
    required String accountHolderName,
  }) async {
    try {
      final response = await _dio.post('/transactions/$transactionId/accept', data: {
        'channel_code': channelCode,
        'channel_type': channelType,
        'account_number': accountNumber,
        'account_holder_name': accountHolderName,
      });
      if (response.data['success'] == true) return response.data['data'] as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Failed to execute payout');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> getPaymentChannels() async {
    try {
      final response = await _dio.get('/payment-channels');
      if (response.data['success'] == true) return response.data['data'] as Map<String, dynamic>;
      throw Exception(response.data['error'] ?? 'Failed to load payment channels');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }
}
