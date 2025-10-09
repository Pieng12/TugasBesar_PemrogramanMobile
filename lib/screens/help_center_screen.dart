import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pusat Bantuan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Search Bar
          TextField(
            decoration: InputDecoration(
              hintText: 'Cari pertanyaan Anda...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 24),

          // FAQ Section
          Text(
            'Pertanyaan Umum (FAQ)',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFaqItem(
            'Bagaimana cara membuat pesanan?',
            'Anda dapat membuat pesanan melalui tombol "Buat Pesanan" di halaman Beranda. Isi semua detail yang diperlukan dan publikasikan.',
          ),
          _buildFaqItem(
            'Bagaimana cara membatalkan pesanan?',
            'Pesanan yang belum memiliki pekerja dapat dibatalkan melalui halaman "Pesanan Saya".',
          ),
          _buildFaqItem(
            'Apakah pembayaran aman?',
            'Ya, kami menggunakan gateway pembayaran yang aman dan terenkripsi untuk melindungi data Anda.',
          ),
          const SizedBox(height: 24),

          // Contact Support
          Text(
            'Butuh Bantuan Lain?',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 2,
            shadowColor: Colors.black.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              leading: Icon(
                Icons.support_agent_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              title: const Text(
                'Hubungi Tim Support',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Kami siap membantu Anda 24/7'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Text(
              answer,
              style: TextStyle(color: Colors.grey.shade700, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
