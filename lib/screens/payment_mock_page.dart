import 'package:flutter/material.dart';

class PaymentMockPage extends StatelessWidget {
  final String duration;
  final double distanceKm;
  final double fare;

  const PaymentMockPage({
    super.key,
    required this.duration,
    required this.distanceKm,
    required this.fare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. Success Icon
              const Icon(Icons.check_circle, size: 100, color: Colors.green),
              const SizedBox(height: 20),
              const Text(
                'Ride Completed!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Payment successful via CCmap Wallet',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),

              // 2. Summary Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Total Fare', '₹${fare.toStringAsFixed(2)}', isTotal: true),
                    const Divider(height: 30),
                    _buildSummaryRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Duration', duration),
                    const SizedBox(height: 12),
                    _buildSummaryRow('Tax (GST 5%)', '₹${(fare * 0.05).toStringAsFixed(2)}'),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // 3. Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Receipt downloaded to your device')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Download Receipt'),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 16, color: isTotal ? Colors.black : Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: isTotal ? 22 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.w500)),
      ],
    );
  }
}