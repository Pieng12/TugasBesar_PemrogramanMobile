import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../models/location_model.dart';
import 'job_detail_screen.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with TickerProviderStateMixin {
  String _selectedTab = 'active';
  String _selectedRole = 'customer'; // 'customer' or 'worker'
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          _buildSliverAppBar(),
          // Role Selector
          _buildRoleSelector(),
          // Tab Bar
          _buildTabBar(),
          // Content
          _buildContent(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      flexibleSpace: _buildFlexibleSpaceBar(),
    );
  }

  FlexibleSpaceBar _buildFlexibleSpaceBar() {
    return FlexibleSpaceBar(
      background: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.work_history_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Kelola Pesanan Anda',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pantau status dan kelola semua pesanan.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildRoleButton(
              'customer',
              'Pesanan Saya',
              Icons.shopping_bag_rounded,
              'Lihat pesanan yang Anda buat.',
            ),
            const SizedBox(width: 16),
            _buildRoleButton(
              'worker',
              'Pekerjaan Saya',
              Icons.construction_rounded,
              'Lihat pekerjaan yang Anda ambil.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleButton(
    String role,
    String label,
    IconData icon,
    String subtitle,
  ) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRole = role;
            _animationController.forward(from: 0.0);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFE2E8F0),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.15),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : const Color(0xFF64748B),
                size: 28,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: _buildTabButton(
                'active',
                'Aktif',
                Icons.play_circle_fill_rounded,
              ),
            ),
            Expanded(
              child: _buildTabButton(
                'history',
                'Riwayat',
                Icons.history_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tab, String label, IconData icon) {
    final isSelected = _selectedTab == tab;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = tab;
          _animationController.forward(from: 0.0);
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: _selectedTab == 'active'
              ? _buildActiveOrders()
              : _buildHistoryOrders(),
        ),
      ),
    );
  }

  Widget _buildActiveOrders() {
    final activeOrders = _selectedRole == 'customer'
        ? _getCustomerActiveOrders()
        : _getWorkerActiveJobs();

    if (activeOrders.isEmpty) {
      return _buildEmptyState(
        'Belum Ada Pesanan Aktif',
        'Pesanan yang sedang berlangsung akan muncul di sini',
        Icons.work_outline_rounded,
      );
    }

    return Column(
      children: activeOrders.map((order) => _buildOrderCard(order)).toList(),
    );
  }

  Widget _buildHistoryOrders() {
    final historyOrders = _selectedRole == 'customer'
        ? _getCustomerHistoryOrders()
        : _getWorkerHistoryJobs();

    if (historyOrders.isEmpty) {
      return _buildEmptyState(
        'Belum Ada Riwayat Pesanan',
        'Pesanan yang sudah selesai akan muncul di sini',
        Icons.history_rounded,
      );
    }

    return Column(
      children: historyOrders.map((order) => _buildOrderCard(order)).toList(),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, size: 48, color: const Color(0xFF6366F1)),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(JobModel order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailScreen(job: order),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(order.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(order.category),
                      color: _getCategoryColor(order.category),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          order.title,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _getCategoryName(order.category),
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  order.status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getStatusText(order.status),
                                style: TextStyle(
                                  color: _getStatusColor(order.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Description
              Text(
                order.description,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              // Location and Price
              Row(
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 14,
                    color: const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.location.address,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Rp ${order.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Applicants Info
              if (order.applicantIds.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_rounded,
                        color: const Color(0xFF6366F1),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${order.applicantIds.length} pekerja mengajukan diri',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (order.status == JobStatus.pending &&
                          _selectedRole == 'customer')
                        ElevatedButton(
                          onPressed: () => _showApplicantsDialog(order),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Pilih',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else if (_selectedRole == 'customer') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_search_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Belum ada pekerja yang mengajukan diri',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _getTimeAgo(order.createdAt),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                  if (order.status == JobStatus.pending &&
                      _selectedRole == 'customer')
                    TextButton(
                      onPressed: () => _showCancelDialog(order),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      child: const Text(
                        'Batalkan',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showApplicantsDialog(JobModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_rounded,
                color: Color(0xFF6366F1),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Pilih Pekerja',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${order.applicantIds.length} pekerja mengajukan diri untuk pekerjaan ini',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ...order.applicantIds.map(
              (applicantId) => _buildApplicantCard(applicantId),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Tutup',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApplicantCard(String applicantId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFF6366F1).withOpacity(0.1),
            child: const Icon(
              Icons.person_rounded,
              color: Color(0xFF6366F1),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pekerja ${applicantId.length > 8 ? '${applicantId.substring(0, 8)}...' : applicantId}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber[600],
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        '4.8 • 50+ pekerjaan',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Verified Badge
                      if (applicantId == 'worker1') // Contoh kondisi
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Terverifikasi',
                            style: TextStyle(
                              color: Color(0xFF27AE60),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the applicant list dialog
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Pemilihan'),
                  content: Text(
                    'Apakah Anda yakin ingin memilih pekerja ini? Tindakan ini tidak dapat dibatalkan.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _showNotification('Pekerja berhasil dipilih!');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                      ),
                      child: const Text('Ya, Pilih Pekerja'),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(
                0xFF27AE60,
              ), // Hijau untuk Aksi / CTA
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
            ),
            child: const Text(
              'Pilih',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(JobModel order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.cancel_rounded,
                color: Color(0xFFEF4444),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Batalkan Pesanan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin membatalkan pesanan "${order.title}"?',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Tidak',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showNotification('Pesanan dibatalkan');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              elevation: 0,
            ),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  List<JobModel> _getCustomerActiveOrders() {
    return [
      JobModel(
        id: '1',
        customerId: 'customer1',
        title: 'Bersihkan Rumah 3 Kamar',
        description:
            'Pembersihan menyeluruh rumah 3 kamar tidur, 2 kamar mandi, dan ruang tamu. Termasuk mencuci piring dan merapikan barang.',
        category: JobCategory.cleaning,
        price: 150000,
        location: Location(
          latitude: -6.2088,
          longitude: 106.8456,
          address: 'Jakarta Selatan, Kemang',
        ),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        applicantIds: ['worker1', 'worker2', 'worker3'],
      ),
      JobModel(
        id: '2',
        customerId: 'customer1',
        title: 'Perbaiki AC Rusak',
        description:
            'AC tidak dingin, perlu perbaikan dan isi freon. Unit AC 1.5 PK di ruang tamu.',
        category: JobCategory.maintenance,
        price: 200000,
        location: Location(
          latitude: -6.2088,
          longitude: 106.8456,
          address: 'Jakarta Pusat, Menteng',
        ),
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        applicantIds: ['worker4'],
        status: JobStatus.inProgress,
      ),
    ];
  }

  List<JobModel> _getCustomerHistoryOrders() {
    return [
      JobModel(
        id: '3',
        customerId: 'customer1',
        title: 'Les Matematika SMA',
        description:
            'Bimbingan belajar matematika untuk siswa SMA kelas 12. Persiapan UTBK. 2x seminggu.',
        category: JobCategory.tutoring,
        price: 100000,
        location: Location(
          latitude: -6.2088,
          longitude: 106.8456,
          address: 'Jakarta Utara, Kelapa Gading',
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        applicantIds: ['worker5'],
        status: JobStatus.completed,
      ),
      JobModel(
        id: '4',
        customerId: 'customer1',
        title: 'Foto Prewedding',
        description:
            'Sesi foto prewedding outdoor di Taman Suropati. 2-3 jam sesi foto dengan 50 hasil edit.',
        category: JobCategory.photography,
        price: 2500000,
        location: Location(
          latitude: -6.2088,
          longitude: 106.8456,
          address: 'Jakarta Pusat, Menteng',
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
        applicantIds: ['worker6'],
        status: JobStatus.completed,
      ),
    ];
  }

  List<JobModel> _getWorkerActiveJobs() {
    return [
      JobModel(
        id: 'worker_job_1',
        customerId: 'customer_x',
        title: 'Antar Paket ke Sudirman',
        description:
            'Mengambil paket di kantor saya dan mengantarkannya ke Gedung SCBD. Paket berupa dokumen penting.',
        category: JobCategory.delivery,
        price: 50000,
        location: Location(
          latitude: -6.22,
          longitude: 106.81,
          address: 'Jakarta Selatan, SCBD',
        ),
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        status: JobStatus.inProgress,
        assignedWorkerId: 'my_worker_id',
      ),
    ];
  }

  List<JobModel> _getWorkerHistoryJobs() {
    return [
      JobModel(
        id: 'worker_job_2',
        customerId: 'customer_y',
        title: 'Rawat Taman Rumah',
        description:
            'Merawat taman, memotong rumput, dan memberi pupuk pada tanaman hias di halaman depan.',
        category: JobCategory.gardening,
        price: 120000,
        location: Location(
          latitude: -6.25,
          longitude: 106.80,
          address: 'Jakarta Selatan, Pondok Indah',
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        status: JobStatus.completed,
        assignedWorkerId: 'my_worker_id',
      ),
      JobModel(
        id: 'worker_job_3',
        customerId: 'customer_z',
        title: 'Jaga Hewan Peliharaan',
        description: 'Menjaga anjing Golden Retriever selama 3 jam di rumah.',
        category: JobCategory.petCare,
        price: 75000,
        location: Location(
          latitude: -6.18,
          longitude: 106.83,
          address: 'Jakarta Pusat, Cikini',
        ),
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        status: JobStatus.completed,
        assignedWorkerId: 'my_worker_id',
      ),
    ];
  }

  Color _getCategoryColor(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return const Color(0xFF10B981);
      case JobCategory.maintenance:
        return const Color(0xFFF59E0B);
      case JobCategory.delivery:
        return const Color(0xFF3B82F6);
      case JobCategory.tutoring:
        return const Color(0xFF8B5CF6);
      case JobCategory.photography:
        return const Color(0xFFEF4444);
      case JobCategory.cooking:
        return const Color(0xFFEC4899);
      case JobCategory.gardening:
        return const Color(0xFF059669);
      case JobCategory.petCare:
        return const Color(0xFF6366F1);
      case JobCategory.other:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getCategoryIcon(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return Icons.cleaning_services_rounded;
      case JobCategory.maintenance:
        return Icons.build_rounded;
      case JobCategory.delivery:
        return Icons.delivery_dining_rounded;
      case JobCategory.tutoring:
        return Icons.school_rounded;
      case JobCategory.photography:
        return Icons.camera_alt_rounded;
      case JobCategory.cooking:
        return Icons.restaurant_rounded;
      case JobCategory.gardening:
        return Icons.local_florist_rounded;
      case JobCategory.petCare:
        return Icons.pets_rounded;
      case JobCategory.other:
        return Icons.more_horiz_rounded;
    }
  }

  String _getCategoryName(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return 'Pembersihan';
      case JobCategory.maintenance:
        return 'Perbaikan';
      case JobCategory.delivery:
        return 'Pengiriman';
      case JobCategory.tutoring:
        return 'Edukasi';
      case JobCategory.photography:
        return 'Fotografi';
      case JobCategory.cooking:
        return 'Kuliner';
      case JobCategory.gardening:
        return 'Taman';
      case JobCategory.petCare:
        return 'Perawatan Hewan';
      case JobCategory.other:
        return 'Lainnya';
    }
  }

  Color _getStatusColor(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return const Color(0xFFF59E0B);
      case JobStatus.inProgress:
        return const Color(0xFF3B82F6);
      case JobStatus.completed:
        return const Color(0xFF10B981);
      case JobStatus.cancelled:
        return const Color(0xFFEF4444);
      case JobStatus.disputed:
        return const Color(0xFF8B5CF6);
    }
  }

  String _getStatusText(JobStatus status) {
    switch (status) {
      case JobStatus.pending:
        return 'Menunggu';
      case JobStatus.inProgress:
        return 'Berlangsung';
      case JobStatus.completed:
        return 'Selesai';
      case JobStatus.cancelled:
        return 'Dibatalkan';
      case JobStatus.disputed:
        return 'Dispute';
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

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

  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF27AE60), // Hijau untuk Aksi / CTA
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
