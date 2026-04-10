import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

class PaymentMockPage extends StatelessWidget {
  final String rideId;
  final String duration;
  final double distanceKm;
  final double fare;
  final String? cycleId;
  final String? startStationName;
  final String? endStationName;
  final String? userName;
  final String? userEmail;

  const PaymentMockPage({
    super.key,
    required this.rideId,
    required this.duration,
    required this.distanceKm,
    required this.fare,
    this.cycleId,
    this.startStationName,
    this.endStationName,
    this.userName,
    this.userEmail,
  });

  Future<void> _downloadReceipt(BuildContext context) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formatter = DateFormat('dd MMM yyyy, hh:mm a');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('CCmap Ride Receipt', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                pw.SizedBox(height: 10),
                pw.Divider(color: PdfColors.grey),
                pw.SizedBox(height: 20),
                
                pw.Text('Customer Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                _pwBuildRow('Name', userName ?? 'User'),
                _pwBuildRow('Email', userEmail ?? 'N/A'),
                pw.SizedBox(height: 20),

                pw.Text('Ride Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                _pwBuildRow('Ride ID', rideId),
                _pwBuildRow('Date', formatter.format(now)),
                _pwBuildRow('Cycle ID', cycleId ?? 'N/A'),
                pw.SizedBox(height: 20),
                
                pw.Text('Trip Details', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                _pwBuildRow('From', startStationName ?? 'Station A'),
                _pwBuildRow('To', endStationName ?? 'Station B'),
                _pwBuildRow('Duration', duration),
                _pwBuildRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
                pw.SizedBox(height: 20),
                
                pw.Divider(),
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Total Fare', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Rs. ${fare.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.green)),
                  ],
                ),
                pw.SizedBox(height: 40),
                pw.Center(
                  child: pw.Text('Brought to you by TRIAL Lab :)', style: pw.TextStyle(color: PdfColors.grey, fontStyle: pw.FontStyle.italic)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Receipt_$rideId.pdf',
    );
  }

  pw.Widget _pwBuildRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(color: PdfColors.grey700)),
          pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle, size: 80, color: Colors.green),
                const SizedBox(height: 20),
                const Text(
                  'Ride Completed!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Payment successful via CCmap Wallet',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 30),

                // Summary Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSummaryRow('Total Fare', 'Rs. ${fare.toStringAsFixed(2)}', isTotal: true),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(),
                      ),
                      _buildSummaryRow('Rider', userName ?? 'User'),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Ride ID', rideId.substring(0, 8) + '...'),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Duration', duration),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Distance', '${distanceKm.toStringAsFixed(2)} km'),
                      const SizedBox(height: 12),
                      _buildSummaryRow('Start Station', startStationName ?? 'Unknown'),
                      const SizedBox(height: 12),
                      _buildSummaryRow('End Station', endStationName ?? 'Unknown'),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('BACK TO HOME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => _downloadReceipt(context),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Download PDF Receipt'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 15, color: isTotal ? Colors.black : Colors.grey[600])),
        Text(value, style: TextStyle(fontSize: isTotal ? 22 : 15, fontWeight: isTotal ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }
}