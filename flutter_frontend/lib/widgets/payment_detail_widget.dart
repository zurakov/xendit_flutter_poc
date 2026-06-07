import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PaymentDetailWidget extends StatelessWidget {
  final String methodType;
  final String channel;
  final Map<String, dynamic> details;
  final double amount;

  const PaymentDetailWidget({
    super.key,
    required this.methodType,
    required this.channel,
    required this.details,
    required this.amount,
  });

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard!'),
        backgroundColor: const Color(0xFF10B981), // Emerald accent
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _launchEWallet(BuildContext context) async {
    final String? deeplink = details['deeplink_url'];
    final String? mobileWeb = details['mobile_web_checkout_url'];
    final String? checkout = details['checkout_url'];

    // Try deeplink first, fallback to mobile web checkout, then desktop checkout
    final List<String> urlsToTry = [
      if (deeplink != null) deeplink,
      if (mobileWeb != null) mobileWeb,
      if (checkout != null) checkout,
    ];

    bool launched = false;
    for (String urlStr in urlsToTry) {
      if (urlStr.isEmpty) continue;
      final Uri uri = Uri.parse(urlStr);
      try {
        if (await canLaunchUrl(uri)) {
          launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
          if (launched) break;
        }
      } catch (e) {
        debugPrint('Failed to launch URL: $urlStr. Error: $e');
      }
    }

    if (!launched) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not open eWallet application automatically.'),
          backgroundColor: const Color(0xFFF87171), // Coral red
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: checkout != null
              ? SnackBarAction(
                  label: 'Copy Link',
                  textColor: Colors.white,
                  onPressed: () => _copyToClipboard(context, checkout, 'Checkout URL'),
                )
              : null,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    switch (methodType) {
      case 'VA':
        final String vaNumber = details['va_number'] ?? 'N/A';
        final String bankCode = details['bank_code'] ?? channel;
        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('🏦 $bankCode Virtual Account'),
              const Divider(color: Colors.white12, height: 24),
              const Text(
                'VA Number:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      vaNumber,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF6366F1)), // Indigo
                    onPressed: () => _copyToClipboard(context, vaNumber, 'VA Number'),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              const Text(
                'Transfer Instructions:',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep('1', 'Open your mobile banking app or go to ATM.'),
              _buildInstructionStep('2', 'Select Transfer > Virtual Account.'),
              _buildInstructionStep('3', 'Enter the VA number above and verify amount.'),
              _buildInstructionStep('4', 'Authorize payment to complete.'),
            ],
          ),
        );

      case 'QRIS':
        final String qrString = details['qr_string'] ?? '';
        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('📱 QR Code (QRIS)'),
              const Divider(color: Colors.white12, height: 24),
              if (qrString.isNotEmpty)
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: qrString,
                      version: QrVersions.auto,
                      size: 200.0,
                    ),
                  ),
                )
              else
                const Center(
                  child: Text(
                    'QR string is empty or invalid.',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Scan with any Indonesian Banking or E-Wallet App:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 8),
              const Text(
                'BCA, Mandiri, OVO, GoPay, Dana, LinkAja, ShopeePay, etc.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
        );

      case 'EWALLET':
        final String walletName = details['ewallet_type'] ?? channel;
        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('👛 $walletName eWallet'),
              const Divider(color: Colors.white12, height: 24),
              const Text(
                'Payment Link:',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.open_in_new),
                label: Text('Open $walletName App'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Indigo
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _launchEWallet(context),
              ),
              const SizedBox(height: 16),
              const Text(
                'If the app does not open automatically, we will redirect you to the checkout webpage.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        );

      case 'RETAIL':
        final String paymentCode = details['payment_code'] ?? 'N/A';
        final String outlet = details['outlet'] ?? channel;
        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('🏪 $outlet Payment Code'),
              const Divider(color: Colors.white12, height: 24),
              const Text(
                'Payment Code:',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      paymentCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Color(0xFF6366F1)),
                    onPressed: () => _copyToClipboard(context, paymentCode, 'Payment Code'),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              const Text(
                'Payment Instructions:',
                style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildInstructionStep('1', 'Go to the nearest $outlet cashier counter.'),
              _buildInstructionStep('2', 'Inform the cashier that you want to make a Xendit / merchant payment.'),
              _buildInstructionStep('3', 'Show the cashier the Payment Code above.'),
              _buildInstructionStep('4', 'Pay the exact amount: Rp ${amount.toStringAsFixed(0)}. Cashier will provide a receipt.'),
            ],
          ),
        );

      case 'CARD':
        final String maskedCard = details['masked_card'] ?? '•••• •••• •••• ••••';
        final String cardType = details['card_type'] ?? 'CREDIT';
        final String network = details['network'] ?? 'VISA';
        return _buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader('💳 Card Payment Details'),
              const Divider(color: Colors.white12, height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Card Number:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    '$network $maskedCard',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Card Type:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    cardType,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(color: Colors.white12, height: 24),
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.check, size: 12, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '3DS authentication completed',
                      style: TextStyle(color: Color(0xFF10B981), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );

      default:
        return const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Unknown Payment Method Type'),
          ),
        );
    }
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230), // Premium Dark Card
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(13)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            offset: const Offset(0, 4),
            blurRadius: 12,
          )
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  Widget _buildHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildInstructionStep(String stepNumber, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Color(0xFF374151),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              stepNumber,
              style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
