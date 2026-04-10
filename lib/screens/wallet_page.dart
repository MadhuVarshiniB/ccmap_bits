import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  double _walletBalance = 0.0;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _fetchWalletData();
  }

  Future<void> _fetchWalletData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 1. Fetch wallet balance
      final profileData = await _supabase
          .from('profiles')
          .select('wallet_balance')
          .eq('id', user.id)
          .single();

      final balance = (profileData['wallet_balance'] ?? 0).toDouble();

      // 2. Fetch past rides as deductions
      final ridesData = await _supabase
          .from('rides')
          .select('fare_amount, end_time, start_time')
          .eq('user_id', user.id)
          .eq('payment_status', 'paid')
          .order('end_time', ascending: false);

      setState(() {
        _walletBalance = balance;
        _transactions = List<Map<String, dynamic>>.from(ridesData);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching wallet data: $e');
      setState(() => _isLoading = false);
    }
  }

  String _formatDate(String isoString) {
    if (isoString.isEmpty) return 'Unknown Date';
    final date = DateTime.parse(isoString).toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _showTopUpDialog() async {
    final TextEditingController amountController = TextEditingController();
    bool isUpdating = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Money to Wallet'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Enter amount to top up (Rs.):'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: 'Rs. ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isUpdating ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isUpdating ? null : () async {
                    final amount = double.tryParse(amountController.text);
                    if (amount == null || amount <= 0) return;

                    setDialogState(() => isUpdating = true);

                    try {
                      final user = _supabase.auth.currentUser;
                      if (user == null) throw 'Not authenticated';

                      final newBalance = _walletBalance + amount;
                      await _supabase
                          .from('profiles')
                          .update({'wallet_balance': newBalance})
                          .eq('id', user.id);

                      setState(() {
                        _walletBalance = newBalance;
                      });

                      if (context.mounted) Navigator.pop(context);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Top-up successful!'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      setDialogState(() => isUpdating = false);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  child: isUpdating 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Top Up'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wallet'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.green))
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                        ]),
                    child: Column(
                      children: [
                        const Text('Current Balance', style: TextStyle(color: Colors.white70, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Rs. ${_walletBalance.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text('Recent Transactions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _transactions.isEmpty
                        ? const Center(child: Text('No recent transactions.', style: TextStyle(color: Colors.grey)))
                        : ListView.builder(
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              final amount = (t['fare_amount'] ?? 0.0).toDouble();
                              final dateIso = t['end_time'] ?? t['start_time'] ?? '';

                              return ListTile(
                                leading: const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.electric_bike, color: Colors.white)),
                                title: const Text('Ride Payment'),
                                subtitle: Text(_formatDate(dateIso.toString())),
                                trailing: Text('-Rs. ${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showTopUpDialog,
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add),
        label: const Text('Add Money'),
      ),
    );
  }
}
