import 'package:flutter/material.dart';

class PaymentMethodsScreen extends StatelessWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data for payment methods
    final List<Map<String, String>> paymentMethods = [
      {'type': 'MasterCard', 'last4': '1234', 'expiry': '12/26'},
      {'type': 'Visa', 'last4': '5678', 'expiry': '08/25'},
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Metode Pembayaran',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: paymentMethods.length,
        itemBuilder: (context, index) {
          final method = paymentMethods[index];
          return _buildPaymentCard(context, method);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Logic to add a new payment method
        },
        label: const Text('Tambah Metode'),
        icon: const Icon(Icons.add_card_rounded),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, Map<String, String> method) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 12,
        ),
        leading: Icon(
          method['type'] == 'MasterCard'
              ? Icons.credit_card
              : Icons.credit_card_rounded,
          color: Theme.of(context).colorScheme.primary,
          size: 40,
        ),
        title: Text(
          '**** **** **** ${method['last4']}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 1.5,
            color: Color(0xFF1E293B),
          ),
        ),
        subtitle: Text(
          'Berakhir pada ${method['expiry']}',
          style: const TextStyle(color: Color(0xFF64748B)),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            // Handle edit or delete
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_rounded),
                title: Text('Edit'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete_rounded, color: Colors.red),
                title: Text('Hapus', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
          icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
        ),
      ),
    );
  }
}
