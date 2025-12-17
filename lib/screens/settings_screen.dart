import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<Permission, PermissionStatus> _permissions = {};
  bool _isLoadingPermissions = true;

  @override
  void initState() {
    super.initState();
    _loadPermissions();
  }

  Future<void> _loadPermissions() async {
    setState(() {
      _isLoadingPermissions = true;
    });

    final permissions = [
      Permission.camera,
      Permission.photos,
      Permission.storage,
      Permission.location,
      Permission.notification,
      Permission.phone,
    ];

    final Map<Permission, PermissionStatus> statuses = {};
    for (final permission in permissions) {
      statuses[permission] = await permission.status;
    }

    setState(() {
      _permissions = statuses;
      _isLoadingPermissions = false;
    });
  }

  Future<void> _requestPermission(Permission permission) async {
    final status = await permission.request();
    setState(() {
      _permissions[permission] = status;
    });

    if (status.isGranted) {
      _showSnackBar('Izin berhasil diberikan', isError: false);
    } else if (status.isPermanentlyDenied) {
      _showOpenSettingsDialog(permission);
    } else {
      _showSnackBar('Izin ditolak', isError: true);
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    // Reload permissions after returning from settings
    await Future.delayed(const Duration(milliseconds: 500));
    _loadPermissions();
  }

  void _showOpenSettingsDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Izin Diperlukan'),
        content: Text(
          'Izin ${_getPermissionName(permission)} dinonaktifkan secara permanen. '
          'Buka pengaturan aplikasi untuk mengaktifkannya?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  String _getPermissionName(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return 'Kamera';
      case Permission.photos:
        return 'Foto';
      case Permission.storage:
        return 'Penyimpanan';
      case Permission.location:
        return 'Lokasi';
      case Permission.notification:
        return 'Notifikasi';
      case Permission.phone:
        return 'Telepon';
      default:
        return 'Izin';
    }
  }

  IconData _getPermissionIcon(Permission permission) {
    switch (permission) {
      case Permission.camera:
        return Icons.camera_alt_rounded;
      case Permission.photos:
        return Icons.photo_library_rounded;
      case Permission.storage:
        return Icons.storage_rounded;
      case Permission.location:
        return Icons.location_on_rounded;
      case Permission.notification:
        return Icons.notifications_rounded;
      case Permission.phone:
        return Icons.phone_rounded;
      default:
        return Icons.security_rounded;
    }
  }

  Color _getPermissionStatusColor(PermissionStatus status) {
    if (status.isGranted) {
      return Colors.green;
    } else if (status.isDenied) {
      return Colors.orange;
    } else if (status.isPermanentlyDenied) {
      return Colors.red;
    } else {
      return Colors.grey;
    }
  }

  String _getPermissionStatusText(PermissionStatus status) {
    if (status.isGranted) {
      return 'Diaktifkan';
    } else if (status.isDenied) {
      return 'Dinonaktifkan';
    } else if (status.isPermanentlyDenied) {
      return 'Ditolak Permanen';
    } else {
      return 'Tidak Diketahui';
    }
  }

  Future<void> _clearCache() async {
    try {
      // Clear image cache
      imageCache.clear();
      imageCache.clearLiveImages();

      if (mounted) {
        _showSnackBar('Cache berhasil dihapus', isError: false);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Gagal menghapus cache: $e', isError: true);
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Pengaturan',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionTitle(context, 'Izin Aplikasi'),
          _buildSettingsCard(
            context,
            child: _isLoadingPermissions
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    children: _permissions.entries.map((entry) {
                      final permission = entry.key;
                      final status = entry.value;
                      final isGranted = status.isGranted;

                      return Column(
                        children: [
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: _getPermissionStatusColor(
                                  status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                _getPermissionIcon(permission),
                                color: _getPermissionStatusColor(status),
                              ),
                            ),
                            title: Text(
                              _getPermissionName(permission),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              _getPermissionStatusText(status),
                              style: TextStyle(
                                color: _getPermissionStatusColor(status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Switch(
                              value: isGranted,
                              onChanged: (value) {
                                if (value) {
                                  _requestPermission(permission);
                                } else {
                                  _showDisablePermissionDialog(permission);
                                }
                              },
                              activeThumbColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                            ),
                          ),
                          if (permission != _permissions.keys.last)
                            const Divider(height: 1),
                        ],
                      );
                    }).toList(),
                  ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, 'Umum'),
          _buildSettingsCard(
            context,
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_rounded),
              title: const Text(
                'Hapus Cache',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text('Hapus data cache aplikasi'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Hapus Cache'),
                    content: const Text(
                      'Apakah Anda yakin ingin menghapus semua cache aplikasi?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearCache();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Hapus'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showDisablePermissionDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nonaktifkan Izin'),
        content: Text(
          'Untuk menonaktifkan izin ${_getPermissionName(permission)}, '
          'Anda perlu membuka pengaturan aplikasi. Buka sekarang?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openAppSettings();
            },
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.grey.shade600,
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required Widget child}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}
