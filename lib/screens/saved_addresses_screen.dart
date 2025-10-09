import 'package:flutter/material.dart';

class SavedAddressesScreen extends StatelessWidget {
  const SavedAddressesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Dummy data for addresses
    final List<Map<String, String>> addresses = [
      {
        'label': 'Rumah',
        'address': 'Jl. Cikutra No. 113, Kota Bandung, Jawa Barat 40132',
        'recipient': 'John Doe',
      },
      {
        'label': 'Kantor',
        'address': 'Jl. Dipati Ukur No. 35, Kota Bandung, Jawa Barat 40132',
        'recipient': 'John Doe',
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Alamat Tersimpan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: addresses.length,
        itemBuilder: (context, index) {
          final address = addresses[index];
          return _buildAddressCard(context, address);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Logic to add a new address
        },
        label: const Text('Tambah Alamat Baru'),
        icon: const Icon(Icons.add_location_alt_rounded),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, Map<String, String> address) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  address['label'] == 'Rumah'
                      ? Icons.home_rounded
                      : Icons.work_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  address['label']!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    // Handle edit or delete
                  },
                  itemBuilder: (BuildContext context) =>
                      <PopupMenuEntry<String>>[
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
                            leading: Icon(
                              Icons.delete_rounded,
                              color: Colors.red,
                            ),
                            title: Text(
                              'Hapus',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      ],
                  icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              address['recipient']!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              address['address']!,
              style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
