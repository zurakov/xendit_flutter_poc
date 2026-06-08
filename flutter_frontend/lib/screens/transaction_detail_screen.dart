import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import '../widgets/payment_detail_widget.dart';
import '../services/payout_storage_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final int transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  Timer? _pollingTimer;
  bool _isLocalLoading = false;
  Map<String, dynamic>? _transaction;

  @override
  void initState() {
    super.initState();
    _fetchDetailAndStartPolling();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _fetchDetailAndStartPolling() {
    setState(() => _isLocalLoading = true);
    final provider = context.read<PaymentProvider>();

    provider.fetchSingleTransactionUpdate(widget.transactionId).then((tx) {
      if (mounted) {
        setState(() {
          _transaction = tx;
          _isLocalLoading = false;
        });
        
        // Start polling if status is PENDING
        if (tx['status'] == 'PENDING') {
          _startPolling();
        }
      }
    }).catchError((err) {
      if (mounted) setState(() => _isLocalLoading = false);
    });
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      final provider = context.read<PaymentProvider>();
      provider.fetchSingleTransactionUpdate(widget.transactionId).then((tx) {
        if (mounted) {
          setState(() {
            _transaction = tx;
          });
          // Stop polling if status changed from PENDING
          if (tx['status'] != 'PENDING') {
            _pollingTimer?.cancel();
          }
        }
      }).catchError((e) {
        debugPrint("Polling error: $e");
      });
    });
  }

  void _showPayoutSheet() {
    final provider = context.read<PaymentProvider>();
    provider.fetchPayoutMethods().then((_) {
      if (!mounted) return;
      if (provider.payoutMethods.isEmpty) {
        _showNoPayoutMethodsDialog();
        return;
      }
      _openPayoutSelectionBottomSheet(provider.payoutMethods);
    });
  }

  void _showNoPayoutMethodsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: const Text('No Payout Accounts', style: TextStyle(color: Colors.white)),
        content: const Text(
          'You need to register at least one payout account first to request a payout.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('OK', style: TextStyle(color: Color(0xFF6366F1))),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  void _openPayoutSelectionBottomSheet(List<PayoutMethod> methods) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161925),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            String? selectedId;
            // Find default primary method
            for (var m in methods) {
              if (m.isPrimary == true) {
                selectedId = m.id;
                break;
              }
            }
            if (selectedId == null && methods.isNotEmpty) {
              selectedId = methods.first.id;
            }

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Payout Account',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Select where Xendit should disburse the payout amount.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  
                  // List of methods
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: methods.length,
                      itemBuilder: (context, index) {
                        final m = methods[index];
                        final String id = m.id;
                        final String label = m.label;
                        final String masked = m.maskedAccount;
                        final String code = m.channelCode;
                        final bool isPrimary = m.isPrimary;

                        return RadioListTile<String>(
                          value: id,
                          groupValue: selectedId,
                          activeColor: const Color(0xFF6366F1),
                          title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          subtitle: Text('$code • $masked ${isPrimary ? "(Primary)" : ""}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          onChanged: (val) {
                            setSheetState(() {
                              selectedId = val;
                            });
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: selectedId == null ? null : () {
                      final selectedMethod = methods.firstWhere((element) => element.id == selectedId);
                      _confirmPayout(selectedMethod);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm & Execute Payout', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _confirmPayout(PayoutMethod method) {
    Navigator.pop(context); // Close bottom sheet
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2230),
        title: const Text('Confirm Payout', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to disburse the funds for this transaction to the selected account?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            onPressed: () {
              Navigator.pop(context); // Close confirm dialog
              _executePayout(method);
            },
          )
        ],
      ),
    );
  }

  void _executePayout(PayoutMethod method) {
    setState(() => _isLocalLoading = true);
    final provider = context.read<PaymentProvider>();

    provider.acceptTransaction(widget.transactionId, method).then((result) {
      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payout request accepted by Xendit!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchDetailAndStartPolling(); // Refresh transaction details
      }
    }).catchError((err) {
      if (mounted) {
        setState(() => _isLocalLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payout failed: $err'),
            backgroundColor: const Color(0xFFF87171),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  void _simulatePayment() {
    setState(() => _isLocalLoading = true);
    final provider = context.read<PaymentProvider>();

    provider.simulateTransaction(widget.transactionId).then((_) {
      if (mounted) {
        setState(() {
          _isLocalLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Payment simulation request sent to Xendit!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchDetailAndStartPolling(); // Refresh transaction details
      }
    }).catchError((err) {
      if (mounted) {
        setState(() => _isLocalLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation failed: $err'),
            backgroundColor: const Color(0xFFF87171),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFFBBF24);
      case 'PAID':
        return const Color(0xFF34D399);
      case 'ACCEPTED':
        return const Color(0xFF818CF8);
      case 'DISBURSED':
        return const Color(0xFF10B981);
      case 'FAILED':
        return const Color(0xFFF87171);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tx = _transaction;

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
          'Transaction Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
      ),
      body: _isLocalLoading && tx == null
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
              ),
            )
          : tx == null
              ? const Center(
                  child: Text('Failed to load transaction detail.', style: TextStyle(color: Colors.grey)),
                )
              : Stack(
                  children: [
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Status Banner
                          _buildStatusBanner(tx['status']),
                          const SizedBox(height: 18),

                          // Base Info Card
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E2230),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withAlpha(10)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Amount', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                    _buildBadge(tx['status']),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatCurrency((tx['amount'] as num).toDouble()),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                _buildDetailRow('Description', tx['description'] ?? '-'),
                                _buildDetailRow('Transaction ID', tx['external_id'] ?? '-'),
                                _buildDetailRow('Xendit ID', tx['xendit_payment_id'] ?? '-'),
                                _buildDetailRow('Created At', tx['created_at']?.toString().replaceAll('T', ' ').substring(0, 19) ?? '-'),
                                if (tx['paid_at'] != null)
                                  _buildDetailRow('Paid At', tx['paid_at']?.toString().replaceAll('T', ' ').substring(0, 19) ?? '-'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),

                          // Dynamic Payment Detail Widget (displays VA, QR, eWallet, Retail details)
                          PaymentDetailWidget(
                            methodType: tx['payment_method_type'] ?? 'VA',
                            channel: tx['payment_channel'] ?? 'BNI',
                            details: tx['payment_details'] is Map 
                                ? Map<String, dynamic>.from(tx['payment_details']) 
                                : {},
                            amount: (tx['amount'] as num).toDouble(),
                          ),
                          
                          // Disbursement Info (if disbursed or accepted)
                          if (tx['status'] == 'DISBURSED' || tx['status'] == 'ACCEPTED') ...[
                            const SizedBox(height: 18),
                            _buildDisbursementCard(tx),
                          ],

                          const SizedBox(height: 100), // padding for the bottom button
                        ],
                      ),
                    ),
                    
                    // Loading overlay
                    if (_isLocalLoading)
                      Container(
                        color: Colors.black45,
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation(Color(0xFF6366F1)),
                          ),
                        ),
                      ),
                  ],
                ),
      // Persistent Bottom Action Bar
      bottomNavigationBar: _transaction == null ? null : _buildBottomActionBar(_transaction!),
    );
  }

  Widget _buildStatusBanner(String status) {
    if (status == 'PAID') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withAlpha(38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981).withAlpha(76)),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF34D399)),
            SizedBox(width: 10),
            Text(
              '✓ Payment Received!',
              style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 14),
            )
          ],
        ),
      );
    }

    if (status == 'PENDING') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFBBF24).withAlpha(25),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFBBF24).withAlpha(51)),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFFFBBF24))),
            ),
            SizedBox(width: 12),
            Text(
              'Waiting for payment...',
              style: TextStyle(color: Color(0xFFFBBF24), fontSize: 13),
            )
          ],
        ),
      );
    }

    if (status == 'FAILED') {
      final details = _transaction?['payment_details'] is Map 
          ? Map<String, dynamic>.from(_transaction!['payment_details']) 
          : {};
      final failureCode = details['failure_code'] ?? 'DECLINED';
      final failureReason = details['failure_reason'] ?? 'Payment was declined by the card issuer.';
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFF87171).withAlpha(38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFF87171).withAlpha(76)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFF87171)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payment Failed ($failureCode)',
                    style: const TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    failureReason,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildDisbursementCard(Map<String, dynamic> tx) {
    final payoutMethod = tx['payout_method'];
    final payoutDetails = tx['payment_details']?['payout'];
    final String disbId = tx['disbursement_external_id'] ?? 'N/A';
    
    final String label = payoutMethod != null 
        ? payoutMethod['label'] ?? '' 
        : (payoutDetails != null ? payoutDetails['account_holder_name'] ?? '' : 'Saved Payout Account');
        
    final String code = payoutMethod != null 
        ? payoutMethod['channel_code'] ?? '' 
        : (payoutDetails != null ? payoutDetails['channel_code'] ?? '' : '');
        
    final String masked = payoutMethod != null 
        ? payoutMethod['masked_account'] ?? '' 
        : (payoutDetails != null ? payoutDetails['masked_account'] ?? '' : '');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E2230),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withAlpha(51)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.send_and_archive, color: Color(0xFF10B981)),
              const SizedBox(width: 8),
              Text(
                tx['status'] == 'DISBURSED' ? 'Payout Sent ✓' : 'Payout Accepted ⏳',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 24),
          _buildDetailRow('Recipient Account', label),
          _buildDetailRow('Channel / Number', '$code • $masked'),
          _buildDetailRow('Disbursement Ref ID', disbId),
          const SizedBox(height: 6),
          Text(
            tx['status'] == 'DISBURSED' 
                ? 'The money has been successfully processed and sent to the recipient.'
                : 'Payout is being processed by Xendit in test mode.',
            style: const TextStyle(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(width: 20),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBadge(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(76)),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildBottomActionBar(Map<String, dynamic> tx) {
    final String status = tx['status'];
    
    return Container(
      color: const Color(0xFF161925),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.white.withAlpha(25)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to List', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            if (status == 'PENDING' && tx['payment_method_type'] != 'CARD') ...[
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _simulatePayment,
                  child: const Text('Simulate Payment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ],
            if (status == 'PAID') ...[
              const SizedBox(width: 14),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _showPayoutSheet,
                  child: const Text('Accept & Payout', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}
