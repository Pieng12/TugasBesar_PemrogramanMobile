import 'package:flutter/material.dart';

enum NotificationType { order, promo, system, warning }

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.type,
    this.isRead = false,
  });
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadMockNotifications();
  }

  void _loadMockNotifications() {
    setState(() {
      _notifications.addAll([
        NotificationItem(
          id: '1',
          title: 'Pesanan Selesai',
          body: 'Pesanan "Bersihkan Rumah 3 Kamar" telah diselesaikan oleh pekerja.',
          receivedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          type: NotificationType.order,
        ),
        NotificationItem(
          id: '2',
          title: 'Promo Spesial Untukmu!',
          body: 'Dapatkan diskon 50% untuk layanan kebersihan. Gunakan kode: BERSIH50.',
          receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
          type: NotificationType.promo,
          isRead: true,
        ),
        NotificationItem(
          id: '3',
          title: 'Pekerja Baru Mendaftar',
          body: 'Ada pekerja baru yang mendaftar untuk pekerjaan "Perbaiki AC Rusak".',
          receivedAt: DateTime.now().subtract(const Duration(hours: 8)),
          type: NotificationType.order,
        ),
        NotificationItem(
          id: '4',
          title: 'Update Sistem',
          body: 'Aplikasi telah diperbarui ke versi 1.1.0 dengan fitur baru.',
          receivedAt: DateTime.now().subtract(const Duration(days: 1)),
          type: NotificationType.system,
          isRead: true,
        ),
        NotificationItem(
          id: '5',
          title: 'Peringatan Keamanan',
          body: 'Password Anda akan segera berakhir. Harap perbarui untuk keamanan.',
          receivedAt: DateTime.now().subtract(const Duration(days: 2)),
          type: NotificationType.warning,
        ),
      ]);
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua notifikasi ditandai telah dibaca')),
    );
  }

  void _clearAll() {
    setState(() {
      _notifications.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Notifikasi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notifications.any((n) => !n.isRead))
            IconButton(
              icon: const Icon(Icons.mark_chat_read_rounded),
              onPressed: _markAllAsRead,
              tooltip: 'Tandai semua telah dibaca',
            ),
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearAll,
              tooltip: 'Hapus semua notifikasi',
            ),
        ],
      ),
      body: _notifications.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                return _buildNotificationCard(notification);
              },
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 20),
          Text(
            'Tidak Ada Notifikasi',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Semua notifikasi Anda akan muncul di sini.',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);
    final timeAgo = _getTimeAgo(notification.receivedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: notification.isRead ? Colors.grey.shade200 : iconColor,
          width: 1,
        ),
      ),
      color: notification.isRead ? Colors.white : iconColor.withOpacity(0.05),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(iconData, color: iconColor, size: 24),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: notification.isRead ? Colors.grey.shade700 : const Color(0xFF1E293B),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text(
            '${notification.body}\n$timeAgo',
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.4,
            ),
          ),
        ),
        trailing: !notification.isRead
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        onTap: () {
          setState(() {
            notification.isRead = true;
          });
        },
      ),
    );
  }

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return Icons.receipt_long_rounded;
      case NotificationType.promo:
        return Icons.local_offer_rounded;
      case NotificationType.system:
        return Icons.settings_suggest_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return const Color(0xFF3B82F6);
      case NotificationType.promo:
        return const Color(0xFF10B981);
      case NotificationType.system:
        return const Color(0xFF6366F1);
      case NotificationType.warning:
        return const Color(0xFFF59E0B);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}
    
