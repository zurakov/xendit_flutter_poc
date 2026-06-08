import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';

class PayoutMethodsScreen extends StatefulWidget {
  const PayoutMethodsScreen({super.key});

  @override
  State<PayoutMethodsScreen> createState() => _PayoutMethodsScreenState();
}

class _PayoutMethodsScreenState extends State<PayoutMethodsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().fetchPayoutMethods();
    });
  }

  void _showAddMethodSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF161925),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const _AddPayoutMethodForm(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161925),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white70),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payout Methods',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, provider, child) {
          if (provider.payoutMethods.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2230),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(13)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.account_balance, size: 30, color: Colors.white30),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Payout Methods Saved',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button below to register a test bank account.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.payoutMethods.length,
            itemBuilder: (context, index) {
              final method = provider.payoutMethods[index];
              final String id = method.id;
              final String label = method.label;
              final String channel = method.channelCode;
              final String masked = method.maskedAccount;
              final bool isPrimary = method.isPrimary;
              final String type = method.channelType;

              return Dismissible(
                key: Key('payout_method_$id'),
                direction: DismissDirection.endToStart,
                onDismissed: (direction) {
                  final messenger = ScaffoldMessenger.of(context);
                  provider.deletePayoutMethod(id).then((_) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Payout method "$label" deleted'),
                        backgroundColor: const Color(0xFF374151),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }).catchError((e) {
                    // Re-fetch list if deletion fails
                    provider.fetchPayoutMethods();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Error deleting method: $e'),
                        backgroundColor: const Color(0xFFF87171),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  });
                },
                background: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF87171).withAlpha(38),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete, color: Color(0xFFF87171)),
                ),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2230),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isPrimary ? const Color(0xFF6366F1).withAlpha(102) : Colors.white.withAlpha(10),
                      width: isPrimary ? 1.5 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isPrimary ? const Color(0xFF6366F1).withAlpha(25) : Colors.white.withAlpha(8),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          type == 'BANK' ? '🏦' : '👛',
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  label,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                if (isPrimary) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6366F1).withAlpha(38),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PRIMARY',
                                      style: TextStyle(color: Color(0xFF818CF8), fontSize: 9, fontWeight: FontWeight.bold),
                                    ),
                                  )
                                ]
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$channel • $masked',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.swipe_left, color: Colors.white12, size: 20),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card),
        label: const Text('Add Account', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showAddMethodSheet(context),
      ),
    );
  }
}

class _AddPayoutMethodForm extends StatefulWidget {
  const _AddPayoutMethodForm();

  @override
  State<_AddPayoutMethodForm> createState() => _AddPayoutMethodFormState();
}

class _AddPayoutMethodFormState extends State<_AddPayoutMethodForm> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _accountController = TextEditingController();
  final _holderController = TextEditingController();

  String _channelType = 'BANK'; // BANK or EWALLET
  String _channelCode = 'BCA';
  bool _isPrimary = false;
  bool _isSaving = false;

  final List<String> _bankChannels = ['BCA', 'BRI', 'BNI', 'MANDIRI'];
  final List<String> _walletChannels = ['OVO', 'GOPAY', 'DANA'];

  @override
  void dispose() {
    _labelController.dispose();
    _accountController.dispose();
    _holderController.dispose();
    super.dispose();
  }

  void _onTypeChanged(String? type) {
    if (type == null) return;
    setState(() {
      _channelType = type;
      _channelCode = type == 'BANK' ? _bankChannels.first : _walletChannels.first;
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final provider = context.read<PaymentProvider>();
    provider
        .createPayoutMethod(
      label: _labelController.text.trim(),
      channelCode: _channelCode,
      channelType: _channelType,
      accountNumber: _accountController.text.trim(),
      holderName: _channelType == 'BANK' ? _holderController.text.trim() : null,
      isPrimary: _isPrimary,
    )
        .then((_) {
      if (!mounted) return;
      Navigator.pop(context); // Close sheet
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payout account added successfully!'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }).catchError((err) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save account: $err'),
          backgroundColor: const Color(0xFFF87171),
          behavior: SnackBarBehavior.floating,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<String> currentChannels = _channelType == 'BANK' ? _bankChannels : _walletChannels;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Payout Account',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54),
                    onPressed: () => Navigator.pop(context),
                  )
                ],
              ),
              const SizedBox(height: 16),

              // Channel Type Dropdown
              DropdownButtonFormField<String>(
                value: _channelType,
                dropdownColor: const Color(0xFF1E2230),
                decoration: _inputDecoration('Payout Type'),
                style: const TextStyle(color: Colors.white),
                items: const [
                  DropdownMenuItem(value: 'BANK', child: Text('Bank Account')),
                  DropdownMenuItem(value: 'EWALLET', child: Text('E-Wallet')),
                ],
                onChanged: _onTypeChanged,
              ),
              const SizedBox(height: 16),

              // Channel Code Dropdown
              DropdownButtonFormField<String>(
                value: _channelCode,
                dropdownColor: const Color(0xFF1E2230),
                decoration: _inputDecoration('Channel / Bank'),
                style: const TextStyle(color: Colors.white),
                items: currentChannels
                    .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _channelCode = val);
                },
              ),
              const SizedBox(height: 16),

              // Label Input
              TextFormField(
                controller: _labelController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration('Account Label (e.g. My BCA, Secondary wallet)'),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter a label' : null,
              ),
              const SizedBox(height: 16),

              // Account Number Input
              TextFormField(
                controller: _accountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration(
                  _channelType == 'BANK' ? 'Account Number' : 'Phone Number (linked to wallet)',
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter digits' : null,
              ),
              const SizedBox(height: 16),

              // Account Holder Name (hidden for EWALLET)
              if (_channelType == 'BANK') ...[
                TextFormField(
                  controller: _holderController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Account Holder Name'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter holder name' : null,
                ),
                const SizedBox(height: 16),
              ],

              // Is Primary Switch
              SwitchListTile(
                title: const Text('Set as Primary Method', style: TextStyle(color: Colors.white70, fontSize: 14)),
                subtitle: const Text('This will be the default recipient for payouts', style: TextStyle(color: Colors.grey, fontSize: 11)),
                value: _isPrimary,
                activeColor: const Color(0xFF6366F1),
                contentPadding: EdgeInsets.zero,
                onChanged: (val) => setState(() => _isPrimary = val),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBackgroundColor: const Color(0xFF374151),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Save Account', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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
