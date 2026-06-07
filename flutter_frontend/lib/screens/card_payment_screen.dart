import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:xendit_cards_session/xendit_cards_session.dart';
import '../../main.dart'; // import global xenditCardsSession
import '../config/app_config.dart';
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
    final cleanNumber = _cardNumberController.text.replaceAll(' ', '');
    final brand = _detectCardBrand(cleanNumber);
    if (brand != _cardBrand) {
      setState(() {
        _cardBrand = brand;
      });
    }
  }

  String _detectCardBrand(String number) {
    if (number.isEmpty) return '';
    if (number.startsWith('4')) return 'VISA';
    if (number.startsWith('35')) return 'JCB';
    
    if (number.length >= 2) {
      final prefix2 = int.tryParse(number.substring(0, 2)) ?? 0;
      if (prefix2 >= 51 && prefix2 <= 55) return 'MASTERCARD';
    }
    if (number.length >= 4) {
      final prefix4 = int.tryParse(number.substring(0, 4)) ?? 0;
      if (prefix4 >= 2221 && prefix4 <= 2720) return 'MASTERCARD';
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
        if (n > 9) {
          n = (n % 10) + 1;
        }
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  Future<void> _handle3DS(String actionUrl) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ThreeDSScreen(url: actionUrl),
      ),
    );
    if (result != true) {
      throw Exception('Payment Cancelled by User');
    }
  }

  void _executePayment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isProcessing = true);

    try {
      final provider = context.read<PaymentProvider>();

      // Step 1: Create tokenization session via backend (SAVE session, amount=0)
      final session = await provider.createCardSession(
        customerName: _nameController.text.trim(),
        customerEmail: _emailController.text.trim(),
        customerPhone: _phoneController.text.trim(),
      );

      final sessionId = session['payment_session_id'];

      // Parse expiry
      final expiryParts = _expiryController.text.split('/');
      final expiryMonth = expiryParts[0].trim();
      final expiryYear = '20${expiryParts[1].trim()}';

      // Parse first / last name
      final name = _nameController.text.trim();
      final nameParts = name.split(' ');
      final firstName = nameParts.first;
      final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : firstName;

      // Step 2: Tokenize card data against the session client-side
      final CardResponse tokenResponse;
      final isPlaceholderKey = AppConfig.xenditPublicKey == 'xnd_public_development_YOUR_PUBLIC_KEY' || AppConfig.xenditPublicKey.isEmpty;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS) && !isPlaceholderKey) {
        tokenResponse = await xenditCardsSession.collectCardData(
          cardNumber: _cardNumberController.text.replaceAll(' ', ''),
          expiryMonth: expiryMonth,
          expiryYear: expiryYear,
          cvn: _cvvController.text.trim(),
          cardholderFirstName: firstName,
          cardholderLastName: lastName,
          cardholderEmail: _emailController.text.trim(),
          cardholderPhoneNumber: _phoneController.text.trim(),
          paymentSessionId: sessionId,
        );
      } else {
        // Mock tokenization for Web and Desktop testing
        await Future.delayed(const Duration(seconds: 1));
        
        final cardNumber = _cardNumberController.text.replaceAll(' ', '');
        String? actionUrl;
        if (cardNumber == '4000000000001091') {
          // Point mock 3DS redirect to the backend's success endpoint to auto-complete
          actionUrl = '${AppConfig.baseUrl.replaceAll('/api', '')}/payment/success';
        }
        
        tokenResponse = CardResponse(
          paymentTokenId: 'pt-mock-token-' + DateTime.now().millisecondsSinceEpoch.toString(),
          actionUrl: actionUrl,
          message: 'Mock Success Tokenization',
        );
      }

      // Step 2b: Handle 3DS if actionUrl is present
      if (tokenResponse.actionUrl != null && tokenResponse.actionUrl!.isNotEmpty) {
        await _handle3DS(tokenResponse.actionUrl!);
      }

      // Step 3: Charge the card token via backend
      final transaction = await provider.createTransaction(
        widget.amount,
        widget.description,
        'CARD',
        'CARDS',
        paymentTokenId: tokenResponse.paymentTokenId,
      );

      if (!mounted) return;

      // Navigate to detail screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TransactionDetailScreen(transactionId: transaction['id']),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);

      String errMsg = e.toString().replaceAll('Exception: ', '');
      if (errMsg.contains('TOKEN_NOT_ACTIVE')) {
        errMsg = 'Card tokenization is still processing. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errMsg),
          backgroundColor: const Color(0xFFF87171),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
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
                // Live Card Preview
                _buildLiveCardPreview(),
                const SizedBox(height: 28),

                // Card Number Input
                TextFormField(
                  controller: _cardNumberController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    CardNumberInputFormatter(),
                  ],
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Card Number',
                      suffixIcon: _buildCardBrandIcon()),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter card number';
                    final cleanNum = val.replaceAll(' ', '');
                    if (cleanNum.length < 13) return 'Card number is too short';
                    if (!_isValidLuhn(cleanNum)) return 'Invalid card number (Luhn check failed)';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                Row(
                  children: [
                    // Expiry Input
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _expiryController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                          CardMonthInputFormatter(),
                        ],
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Expiry Date (MM/YY)'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          final parts = val.split('/');
                          if (parts.length != 2 || parts[0].length != 2 || parts[1].length != 2) {
                            return 'Invalid';
                          }
                          final month = int.tryParse(parts[0]) ?? 0;
                          final year = int.tryParse(parts[1]) ?? 0;
                          if (month < 1 || month > 12) return 'Invalid Month';
                          
                          // Check if expired
                          final now = DateTime.now();
                          final currentYearShort = now.year % 100;
                          final currentMonth = now.month;
                          if (year < currentYearShort || (year == currentYearShort && month < currentMonth)) {
                            return 'Expired';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // CVV Input
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
                        decoration: _inputDecoration('CVV / CVN'),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return 'Required';
                          if (val.length < 3 || val.length > 4) return 'Invalid';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Cardholder Name
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Cardholder Full Name'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter cardholder name' : null,
                ),
                const SizedBox(height: 18),

                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Email Address'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter email';
                    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
                    if (!emailRegex.hasMatch(val.trim())) return 'Invalid email format';
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Phone Number'),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Please enter phone number';
                    final cleanPhone = val.trim();
                    if (!cleanPhone.startsWith('+') && !cleanPhone.startsWith('0')) {
                      return 'Must start with + or 0';
                    }
                    if (cleanPhone.length < 10) return 'Must be at least 10 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
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
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          'Pay ${_formatCurrency(widget.amount)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
                const SizedBox(height: 16),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.lock, size: 14, color: Colors.grey),
                    SizedBox(width: 6),
                    Text(
                      'Secured client-side via Xendit',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
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
    final nameText = _nameController.text.isEmpty ? 'CARDHOLDER NAME' : _nameController.text.toUpperCase();
    final expiryText = _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text;
    final cardNoText = _cardNumberController.text.isEmpty ? '•••• •••• •••• ••••' : _cardNumberController.text;

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
              const Text(
                'CREDIT CARD',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              if (_cardBrand.isNotEmpty)
                Text(
                  _cardBrand,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                )
              else
                const Icon(Icons.credit_card, color: Colors.white70),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            cardNoText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CARDHOLDER',
                      style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.2),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      nameText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'EXPIRES',
                    style: TextStyle(color: Colors.white54, fontSize: 9, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    expiryText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget? _buildCardBrandIcon() {
    if (_cardBrand.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.only(right: 12),
      alignment: Alignment.centerRight,
      width: 60,
      child: Text(
        _cardBrand,
        style: const TextStyle(
          color: Color(0xFF6366F1),
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
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

class CardNumberInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex % 4 == 0 && nonZeroIndex != text.length) {
        buffer.write(' ');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}

class CardMonthInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var newText = newValue.text;
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    var buffer = StringBuffer();
    for (int i = 0; i < newText.length; i++) {
      buffer.write(newText[i]);
      var nonZeroIndex = i + 1;
      if (nonZeroIndex == 2 && nonZeroIndex != newText.length) {
        buffer.write('/');
      }
    }
    var string = buffer.toString();
    return newValue.copyWith(
      text: string,
      selection: TextSelection.collapsed(offset: string.length),
    );
  }
}
