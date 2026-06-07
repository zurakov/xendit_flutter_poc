import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  late final Dio _dio;

  factory ApiClient() {
    return _instance;
  }

  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
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
      if (error.response?.data != null && error.response!.data is Map) {
        final data = error.response!.data;
        if (data['error'] != null) {
          return data['error'].toString();
        }
        if (data['message'] != null) {
          return data['message'].toString();
        }
      }
      return error.message ?? 'Network connection issue';
    }
    return error.toString();
  }

  Future<List<dynamic>> getTransactions() async {
    try {
      final response = await _dio.get('/transactions');
      if (response.data['success'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to load transactions');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<void> clearTransactions() async {
    try {
      final response = await _dio.delete('/transactions');
      if (response.data['success'] == true) {
        return;
      }
      throw Exception(response.data['error'] ?? 'Failed to clear transactions');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> getTransaction(int id) async {
    try {
      final response = await _dio.get('/transactions/$id');
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to load transaction detail');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> createTransaction(
    double amount,
    String description,
    String methodType,
    String channel, {
    String? paymentTokenId,
  }) async {
    try {
      final response = await _dio.post(
        '/transactions',
        data: {
          'amount': amount,
          'description': description,
          'payment_method_type': methodType,
          'payment_channel': channel,
          if (paymentTokenId != null) 'payment_token_id': paymentTokenId,
        },
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to initiate payment');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> createCardSession({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      final response = await _dio.post(
        '/card/session',
        data: {
          'customer_name': customerName,
          'customer_email': customerEmail,
          'customer_phone': customerPhone,
        },
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to create card session');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> acceptTransaction(int id, int payoutMethodId) async {
    try {
      final response = await _dio.post(
        '/transactions/$id/accept',
        data: {
          'payout_method_id': payoutMethodId,
        },
      );
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to execute payout');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<List<dynamic>> getPayoutMethods() async {
    try {
      final response = await _dio.get('/payout-methods');
      if (response.data['success'] == true) {
        return response.data['data'] as List<dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to load payout methods');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> createPayoutMethod(Map<String, dynamic> data) async {
    try {
      final response = await _dio.post('/payout-methods', data: data);
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to save payout method');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<void> deletePayoutMethod(int id) async {
    try {
      final response = await _dio.delete('/payout-methods/$id');
      if (response.data['success'] == true) {
        return;
      }
      throw Exception(response.data['error'] ?? 'Failed to delete payout method');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> getPaymentChannels() async {
    try {
      final response = await _dio.get('/payment-channels');
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to load payment channels');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }

  Future<Map<String, dynamic>> simulateTransaction(int id) async {
    try {
      final response = await _dio.post('/transactions/$id/simulate');
      if (response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      throw Exception(response.data['error'] ?? 'Failed to simulate payment');
    } catch (e) {
      throw Exception(_handleError(e));
    }
  }
}
