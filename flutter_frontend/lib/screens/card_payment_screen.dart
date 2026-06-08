import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import 'three_ds_screen.dart';
import 'transaction_detail_screen.dart';

class CardPaymentScreen extends StatefulWidget {
  final double amount;
  final String description;

  const CardPaymentScreen({
    super.key,
    required this.amount,
    required this.description,
  });

  @override
  State<CardPaymentScreen> createState() => _CardPaymentScreenState();
}

class _CardPaymentScreenState extends State<CardPaymentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isProcessing = false;
  String _cardBrand = '';

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_onCardNumberChanged);
  }

  @override
  void dispose() {
    _cardNumberController.removeListener(_onCardNumberChanged);
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onCardNumberChanged() {
    final brand = _detectCardBrand(_cardNumberController.text.replaceAll(' ', ''));
    if (brand != _cardBrand) setState(() => _cardBrand = brand);
  }

  String _detectCardBrand(String number) {
    if (number.isEmpty) return '';
    if (number.startsWith('4')) return 'VISA';
    if (number.startsWith('34') || number.startsWith('37')) return 'AMEX';
    if (number.startsWith('35') || number.startsWith('3337')) return 'JCB';
    if (number.startsWith('18898')) return 'BCA';
    if (number.length >= 2) {
      final p2 = int.tryParse(number.substring(0, 2)) ?? 0;
      if (p2 >= 51 && p2 <= 55) return 'MASTERCARD';
    }
    if (number.length >= 4) {
      final p4 = int.tryParse(number.substring(0, 4)) ?? 0;
      if (p4 >= 2221 && p4 <= 2720) return 'MASTERCARD';
    }
    return '';
  }

  bool _isValidLuhn(String cardNumber) {
    if (cardNumber.length < 13) return false;
    int sum = 0;
    bool alternate = false;
    for (int i = cardNumber.length - 1; i >= 0; i--) {
      int n = int.tryParse(cardNumber[i]) ?? 0;
      if (alternate) {
        n *= 2;
        if (n > 9) n = (n % 10) + 1;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  Future<bool> _handle3DS(String actionUrl) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ThreeDSScreen(url: actionUrl)),
    );
    return result == true;
  }

  void _executePayment() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isProcessing = true);

    try {
      final provider = context.read<PaymentProvider>();

      // Parse expiry
      final expiryParts = _expiryController.text.split('/');
      final expiryMonth = expiryParts[0].trim();
      final expiryYear = '20${expiryParts[1].trim()}';

      // Parse name
      final nameParts = _nameController.text.trim().split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : firstName;

      // Step 1: Send card details to backend — backend calls Xendit v3 payment_request
      final result = await provider.chargeCard(
        amount: widget.amount,
        description: widget.description,
        cardNumber: _cardNumberController.text.replaceAll(' ', ''),
        expiryMonth: expiryMonth,
        expiryYear: expiryYear,
        cvn: _cvvController.text.trim(),
        cardholderFirstName: firstName,
        cardholderLastName: lastName,
        cardholderEmail: _emailController.text.trim(),
        cardholderPhone: _phoneController.text.trim(),
      );

      // Step 2: Check if payment failed directly (e.g. decline without 3DS)
      if (result['status'] == 'FAILED') {
        final details = result['payment_details'] is Map 
            ? Map<String, dynamic>.from(result['payment_details']) 
            : {};
        final failureReason = details['failure_reason'] ?? 'Payment was declined by the card issuer.';
        throw Exception(failureReason);
      }

      // Step 3: If 3DS is required, the backend returns { requires_action: true, action_url: "..." }
      final requiresAction = result['requires_action'] == true;
      final actionUrl = result['action_url'] as String?;

      if (requiresAction && actionUrl != null && actionUrl.isNotEmpty) {
        final completed = await _handle3DS(actionUrl);
        final transactionId = result['id'];

        if (transactionId != null) {
          // Add a short delay to allow the server-side redirect callback to complete database updates
          await Future.delayed(const Duration(milliseconds: 500));
          final updated = await provider.fetchSingleTransactionUpdate(transactionId as int);
          
          if (updated['status'] == 'PAID') {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => TransactionDetailScreen(transactionId: updated['id']),
              ),
            );
            return;
          }
          
          if (updated['status'] == 'FAILED') {
            final details = updated['payment_details'] is Map 
                ? Map<String, dynamic>.from(updated['payment_details']) 
                : {};
            final failureReason = details['failure_reason'] ?? 'Payment was declined by the card issuer.';
            throw Exception(failureReason);
          }
        }

        if (!completed) {
          throw Exception('3DS authentication was cancelled.');
        }
      }

      if (!mounted) return;

      // Step 3: Navigate to transaction detail
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(transactionId: result['id']),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: const Color(0xFFF87171),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        )}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161925),
        elevation: 0,
        title: const Text('💳 Card Payment'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLiveCardPreview(),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _cardNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    _CardNumberFormatter(),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Card Number', suffixIcon: _buildBrandIcon()),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter card number';
                    final clean = val.replaceAll(' ', '');
                    if (clean.length < 13) return 'Card number too short';
                    if (!_isValidLuhn(clean)) return 'Invalid card number';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _expiryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          _ExpiryFormatter(),
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Expiry (MM/YY)'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          final parts = val.split('/');
                          if (parts.length != 2 || parts[0].length != 2 || parts[1].length != 2) {
                            return 'Invalid format';
                          }
                          final month = int.tryParse(parts[0]) ?? 0;
                          final year = int.tryParse(parts[1]) ?? 0;
                          if (month < 1 || month > 12) return 'Invalid month';
                          final now = DateTime.now();
                          final shortYear = now.year % 100;
                          if (year < shortYear || (year == shortYear && month < now.month)) {
                            return 'Card expired';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _cvvController,
                        keyboardType: TextInputType.number,
                        obscureText: true,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration(_cardBrand == 'AMEX' ? 'CVV/CVN (4 digits)' : 'CVV (3 digits)'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          final minLen = _cardBrand == 'AMEX' ? 4 : 3;
                          if (val.length < minLen) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Cardholder Full Name'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'Please enter name' : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Email Address'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter email';
                    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(val)) return 'Invalid email';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Phone Number (e.g. +62812...)'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter phone';
                    if (val.trim().length < 10) return 'Too short';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isProcessing ? null : _executePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: const Color(0xFF374151),
                  ),
                  child: _isProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                        )
                      : Text('Pay ${_formatCurrency(widget.amount)}',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.grey),
                    SizedBox(width: 6),
                    Text('Secured via Xendit v3 Payments API',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLiveCardPreview() {
    final nameText =
        _nameController.text.isEmpty ? 'CARDHOLDER NAME' : _nameController.text.toUpperCase();
    final expiryText = _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;
    final cardNoText =
        _cardNumberController.text.isEmpty ? '•••• •••• •••• ••••' : _cardNumberController.text;

    return Container(
      height: 190,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF312E81), Color(0xFF4C1D95), Color(0xFF5B21B6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withAlpha(64),
            offset: const Offset(0, 10),
            blurRadius: 20,
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CREDIT CARD',
                  style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2)),
              if (_cardBrand.isNotEmpty)
                Text(_cardBrand,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5))
              else
                const Icon(Icons.credit_card, color: Colors.white70),
            ],
          ),
          Text(cardNoText,
              style: const TextStyle(
                  color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold, letterSpacing: 2.5)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('CARDHOLDER',
                        style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.2)),
                    const SizedBox(height: 4),
                    Text(nameText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('EXPIRES',
                      style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(expiryText,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildBrandIcon() {
    if (_cardBrand.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.only(right: 12),
      alignment: Alignment.centerRight,
      width: 80,
      child: Text(_cardBrand,
          style: const TextStyle(
              color: Color(0xFF6366F1), fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  InputDecoration _inputDecoration(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFF1E2230),
      suffixIcon: suffixIcon,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withAlpha(10)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1)),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newVal) {
    final text = newVal.text;
    if (newVal.selection.baseOffset == 0) return newVal;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && i + 1 != text.length) buffer.write(' ');
    }
    final result = buffer.toString();
    return newVal.copyWith(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}

class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue old, TextEditingValue newVal) {
    final text = newVal.text;
    if (newVal.selection.baseOffset == 0) return newVal;
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if (i + 1 == 2 && i + 1 != text.length) buffer.write('/');
    }
    final result = buffer.toString();
    return newVal.copyWith(text: result, selection: TextSelection.collapsed(offset: result.length));
  }
}
