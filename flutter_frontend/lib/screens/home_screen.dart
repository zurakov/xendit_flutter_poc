import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/payment_provider.dart';
import 'create_payment_screen.dart';
import 'payout_methods_screen.dart';
import 'transaction_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch initial transactions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PaymentProvider>().fetchTransactions();
    });
  }

  String _getMethodIcon(String type) {
    switch (type) {
      case 'VA':
        return '🏦';
      case 'QRIS':
        return '📱';
      case 'EWALLET':
        return '👛';
      case 'RETAIL':
        return '🏪';
      default:
        return '💰';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'PENDING':
        return const Color(0xFFFBBF24); // Gold / Yellow
      case 'PAID':
        return const Color(0xFF34D399); // Teal / Emerald
      case 'ACCEPTED':
        return const Color(0xFF818CF8); // Indigo
      case 'DISBURSED':
        return const Color(0xFF10B981); // Solid Green
      case 'FAILED':
        return const Color(0xFFF87171); // Coral / Red
      default:
        return Colors.grey;
    }
  }

  String _formatCurrency(double amount) {
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]}.',
        )}';
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2230),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Clear Payments', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: const Text(
            'Are you sure you want to remove all payments? This will permanently clean up the database.',
            style: TextStyle(color: Colors.grey),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<PaymentProvider>().clearTransactions().catchError((e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to clear payments: $e'),
                      backgroundColor: const Color(0xFFF87171),
                    ),
                  );
                });
              },
              child: const Text('Remove All', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F111A), // Dark Obsidian
      appBar: AppBar(
        backgroundColor: const Color(0xFF161925),
        elevation: 0,
        title: const Text(
          'Xendit POC Payment',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Color(0xFFF87171)),
            tooltip: 'Clear Transactions',
            onPressed: () {
              _showClearConfirmDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet, color: Colors.white70),
            tooltip: 'Payout Accounts',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PayoutMethodsScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<PaymentProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.transactions.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6366F1)),
              ),
            );
          }

          if (provider.errorMessage != null && provider.transactions.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 60, color: Color(0xFFF87171)),
                    const SizedBox(height: 16),
                    Text(
                      'Connection Error',
                      style: TextStyle(color: Colors.white.withAlpha(230), fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => provider.fetchTransactions(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Retry', style: TextStyle(color: Colors.white)),
                    )
                  ],
                ),
              ),
            );
          }

          if (provider.transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2230),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withAlpha(13)),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.receipt_long, size: 36, color: Colors.white30),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No Transactions Found',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tap the button below to generate a test payment.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: const Color(0xFF6366F1),
            backgroundColor: const Color(0xFF1E2230),
            onRefresh: () => provider.fetchTransactions(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: provider.transactions.length,
              itemBuilder: (context, index) {
                final tx = provider.transactions[index];
                final String type = tx['payment_method_type'] ?? 'VA';
                final String channel = tx['payment_channel'] ?? 'BNI';
                final String status = tx['status'] ?? 'PENDING';
                final double amount = (tx['amount'] as num).toDouble();
                final String description = tx['description'] ?? '';
                final String dateStr = tx['created_at'] != null 
                    ? tx['created_at'].toString().split('T')[0] 
                    : '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2230), // card background
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withAlpha(10)),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => TransactionDetailScreen(transactionId: tx['id']),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          // Type Icon avatar
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(13),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _getMethodIcon(type),
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Content details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      channel,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      description,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatCurrency(amount),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (dateStr.isNotEmpty)
                                  Text(
                                    dateStr,
                                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                                  ),
                              ],
                            ),
                          ),
                          // Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withAlpha(31),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: _getStatusColor(status).withAlpha(76),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                color: _getStatusColor(status),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Create Payment', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreatePaymentScreen()),
          );
        },
      ),
    );
  }
}
