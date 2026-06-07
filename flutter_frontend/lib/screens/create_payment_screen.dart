import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import 'transaction_detail_screen.dart';
import 'card_payment_screen.dart';

class CreatePaymentScreen extends StatefulWidget {
  const CreatePaymentScreen({super.key});

  @override
  State<CreatePaymentScreen> createState() => _CreatePaymentScreenState();
}

class _CreatePaymentScreenState extends State<CreatePaymentScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentStep = 1; // 1 = selector, 2 = amount entry

  String? _selectedType; // VA, QRIS, EWALLET, RETAIL
  String? _selectedChannel;
  String? _selectedName;

  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().fetchPaymentChannels();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _selectChannel(String type, String code, String name) {
    setState(() {
      _selectedType = type;
      _selectedChannel = code;
      _selectedName = name;
      _currentStep = 2; // proceed to enter amount
    });
  }

  void _goBackToSelector() {
    setState(() {
      _currentStep = 1;
    });
  }

  void _generatePayment() {
    if (!_formKey.currentState!.validate()) return;

    final double amount = double.parse(_amountController.text.trim());
    final String desc = _descController.text.trim();

    if (_selectedType == 'CARD') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CardPaymentScreen(
            amount: amount,
            description: desc,
          ),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    final provider = context.read<PaymentProvider>();

    provider
        .createTransaction(amount, desc, _selectedType!, _selectedChannel!)
        .then((newTx) {
      if (!mounted) return;
      // Navigate to detail screen and replace current screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => TransactionDetailScreen(transactionId: newTx['id']),
        ),
      );
    }).catchError((err) {
      if (!mounted) return;
      setState(() {
        _isGenerating = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to initiate payment: $err'),
          backgroundColor: const Color(0xFFF87171),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  String _getChannelEmoji(String type) {
    switch (type) {
      case 'VA':
        return '🏦';
      case 'QRIS':
        return '📱';
      case 'EWALLET':
        return '👛';
      case 'RETAIL':
        return '🏪';
      case 'CARD':
        return '💳';
      default:
        return '💵';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PaymentProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161925),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () {
            if (_currentStep == 2) {
              _goBackToSelector();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentStep == 1 ? 'Select Payment Method' : 'Enter Payment Details',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: provider.isLoading && provider.paymentChannels.isEmpty
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
              ),
            )
          : _currentStep == 1
              ? _buildStep1Selector(provider.paymentChannels)
              : _buildStep2Details(),
    );
  }

  Widget _buildStep1Selector(Map<String, dynamic> channels) {
    if (channels.isEmpty) {
      return const Center(
        child: Text('No payment channels available.', style: TextStyle(color: Colors.grey)),
      );
    }

    final List<dynamic> vaList = channels['VA'] ?? [];
    final List<dynamic> qrList = channels['QRIS'] ?? [];
    final List<dynamic> walletList = channels['EWALLET'] ?? [];
    final List<dynamic> retailList = channels['RETAIL'] ?? [];
    final List<dynamic> cardList = channels['CARD'] ?? [];

    return Column(
      children: [
        Container(
          color: const Color(0xFF161925),
          child: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF6366F1),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Virtual Account'),
              Tab(text: 'QR Code'),
              Tab(text: 'E-Wallet'),
              Tab(text: 'Retail'),
              Tab(text: 'Card'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildChannelGrid('VA', vaList),
              _buildChannelGrid('QRIS', qrList),
              _buildChannelGrid('EWALLET', walletList),
              _buildChannelGrid('RETAIL', retailList),
              _buildChannelGrid('CARD', cardList),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildChannelGrid(String type, List<dynamic> list) {
    if (list.isEmpty) {
      return const Center(child: Text('No channels listed.', style: TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.4,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final channel = list[index];
        final String code = channel['code'];
        final String name = channel['name'];

        return InkWell(
          onTap: () => _selectChannel(type, code, name),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E2230),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withAlpha(10)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Custom visually rich representation of logo
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _getChannelEmoji(type),
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: TextStyle(
                    color: Colors.white.withAlpha(102),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep2Details() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selected Channel Badge Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2230),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF6366F1).withAlpha(51)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(38),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getChannelEmoji(_selectedType!),
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedName!,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Method type: $_selectedType',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        )
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _goBackToSelector,
                    icon: const Icon(Icons.edit, size: 14, color: Color(0xFF818CF8)),
                    label: const Text('Change', style: TextStyle(color: Color(0xFF818CF8), fontSize: 12)),
                  )
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Amount Input
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: _inputDecoration('Payment Amount (Rp)', prefixText: 'Rp '),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Please enter an amount';
                final double? amt = double.tryParse(val.trim());
                if (amt == null || amt <= 0) return 'Please enter a valid positive amount';
                if (amt < 10000) return 'Minimum payment is Rp 10.000';
                return null;
              },
            ),
            const SizedBox(height: 18),

            // Description Input
            TextFormField(
              controller: _descController,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDecoration('Description / Item Name (e.g. Test purchase)'),
              validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a description' : null,
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isGenerating ? null : _generatePayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: const Color(0xFF374151),
              ),
              child: _isGenerating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Generate Payment Link',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, {String? prefixText}) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      filled: true,
      fillColor: const Color(0xFF1E2230),
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
