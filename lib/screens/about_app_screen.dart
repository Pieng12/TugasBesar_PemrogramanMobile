import 'package:flutter/material.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tentang Aplikasi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Tubes Pemob',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Versi 1.0.0',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Text(
              'Aplikasi ini adalah platform layanan on-demand yang menghubungkan penyedia jasa dengan pelanggan. Dibuat sebagai bagian dari proyek Tubes Pemrograman Mobile.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 15,
                height: 1.5,
              ),
            ),
            const Spacer(),
            const Text(
              '© 2024 Tim Tubes Pemob. All Rights Reserved.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () {},
                  child: const Text('Kebijakan Privasi'),
                ),
                const Text('|'),
                TextButton(
                  onPressed: () {},
                  child: const Text('Syarat & Ketentuan'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
