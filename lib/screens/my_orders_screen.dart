import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../models/location_model.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';
import 'package:shimmer/shimmer.dart';

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

  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _myOrders = []; // Jobs created by user
  List<Map<String, dynamic>> _myJobs = []; // Jobs taken by user
  List<Map<String, dynamic>> _myAssignedJobs =
      []; // Jobs assigned to user (private orders)
  bool _isLoading = true;
  String? _error;

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
    _loadMyJobs();
  }

  Future<void> _loadMyJobs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      if (_apiService.token == null) {
        setState(() {
          _error = 'Please login to view your orders';
          _isLoading = false;
        });
        return;
      }

      // Load all types of data in parallel
      final futures = await Future.wait([
        _loadMyCreatedJobs(), // Jobs created by user (Orders)
        _loadMyAppliedJobs(), // Jobs taken by user (Jobs)
        _loadMyAssignedJobs(), // Jobs assigned to user (Private Orders)
      ]);

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading orders: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMyCreatedJobs() async {
    // Load jobs created by user (Orders)
    final response = await _apiService.getMyCreatedJobs();

    if (response['success']) {
      final data = response['data'];
      List<Map<String, dynamic>> orders = [];

      if (data is Map && data.containsKey('data')) {
        orders = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        orders = List<Map<String, dynamic>>.from(data);
      }

      setState(() {
        _myOrders = orders;
      });
    }
  }

  Future<void> _loadMyAppliedJobs() async {
    // Load jobs applied by user (Jobs taken)
    final response = await _apiService.getMyAppliedJobs();

    if (response['success']) {
      final data = response['data'];
      List<Map<String, dynamic>> applications = [];

      if (data is Map && data.containsKey('data')) {
        applications = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        applications = List<Map<String, dynamic>>.from(data);
      }

      // Extract job data from applications
      List<Map<String, dynamic>> jobs = [];
      for (var application in applications) {
        if (application['job'] != null) {
          // Add application status to job data
          Map<String, dynamic> jobData = Map<String, dynamic>.from(
            application['job'],
          );
          jobData['application_status'] = application['status'] ?? 'pending';
          jobData['application_id'] = application['id'];
          jobData['applied_at'] = application['applied_at'];
          jobs.add(jobData);
        }
      }

      setState(() {
        _myJobs = jobs;
      });
    }
  }

  Future<void> _loadMyAssignedJobs() async {
    // Load jobs assigned to user (Private Orders)
    final response = await _apiService.getMyAssignedJobs();

    if (response['success']) {
      final data = response['data'];
      List<Map<String, dynamic>> assignedJobs = [];

      if (data is Map && data.containsKey('data')) {
        assignedJobs = List<Map<String, dynamic>>.from(data['data']);
      } else if (data is List) {
        assignedJobs = List<Map<String, dynamic>>.from(data);
      }

      setState(() {
        _myAssignedJobs = assignedJobs;
      });
    }
  }

  List<Map<String, dynamic>> _mergeWorkerJobs() {
    final Map<String, Map<String, dynamic>> mergedJobs = {};

    for (final job in _myJobs) {
      final jobId = job['id']?.toString();
      if (jobId == null) continue;
      mergedJobs[jobId] = Map<String, dynamic>.from(job);
    }

    for (final job in _myAssignedJobs) {
      final jobId = job['id']?.toString();
      if (jobId == null) continue;

      final mergedJob = Map<String, dynamic>.from(job);
      final existing = mergedJobs[jobId];

      if (existing != null) {
        if (existing.containsKey('application_status')) {
          mergedJob['application_status'] = existing['application_status'];
        }
        if (existing.containsKey('application_id') &&
            !mergedJob.containsKey('application_id')) {
          mergedJob['application_id'] = existing['application_id'];
        }
        if (existing.containsKey('applied_at') &&
            !mergedJob.containsKey('applied_at')) {
          mergedJob['applied_at'] = existing['applied_at'];
        }
      }

      mergedJobs[jobId] = mergedJob;
    }

    return mergedJobs.values.toList();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(String? dateString) {
    if (dateString == null) return 'Unknown time';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} hari yang lalu';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} jam yang lalu';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} menit yang lalu';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return 'Unknown time';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'inProgress':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFFEF4444);
      case 'disputed':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'inProgress':
        return 'Berlangsung';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'disputed':
        return 'Dispute';
      default:
        return 'Unknown';
    }
  }

  double _parseToDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  JobModel _convertApiDataToJobModel(Map<String, dynamic> jobData) {
    return JobModel(
      id: jobData['id']?.toString() ?? '',
      customerId: jobData['customer_id']?.toString() ?? '',
      title: jobData['title'] ?? '',
      description: jobData['description'] ?? '',
      category: _stringToJobCategory(jobData['category']),
      price: _parseToDouble(jobData['price'] ?? 0),
      location: Location(
        latitude: _parseToDouble(jobData['latitude'] ?? 0),
        longitude: _parseToDouble(jobData['longitude'] ?? 0),
        address: jobData['address'] ?? '',
      ),
      createdAt:
          DateTime.tryParse(jobData['created_at'] ?? '') ?? DateTime.now(),
      scheduledTime: jobData['scheduled_time'] != null
          ? DateTime.tryParse(jobData['scheduled_time'])
          : null,
      status: _stringToJobStatus(jobData['status']),
      assignedWorkerId: jobData['assigned_worker_id']?.toString(),
      imageUrls: List<String>.from(jobData['image_urls'] ?? []),
      additionalInfo: jobData['additional_info'] != null
          ? Map<String, dynamic>.from(jobData['additional_info'])
          : null,
    );
  }

  JobCategory _stringToJobCategory(String? category) {
    switch (category) {
      case 'cleaning':
        return JobCategory.cleaning;
      case 'maintenance':
        return JobCategory.maintenance;
      case 'delivery':
        return JobCategory.delivery;
      case 'tutoring':
        return JobCategory.tutoring;
      case 'photography':
        return JobCategory.photography;
      case 'cooking':
        return JobCategory.cooking;
      case 'gardening':
        return JobCategory.gardening;
      case 'petCare':
        return JobCategory.petCare;
      default:
        return JobCategory.other;
    }
  }

  JobStatus _stringToJobStatus(String? status) {
    switch (status) {
      case 'pending':
        return JobStatus.pending;
      case 'inProgress':
        return JobStatus.inProgress;
      case 'completed':
        return JobStatus.completed;
      case 'cancelled':
        return JobStatus.cancelled;
      case 'disputed':
        return JobStatus.disputed;
      default:
        return JobStatus.pending;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _loadMyJobs,
        child: CustomScrollView(
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
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.8),
              ],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
          child: Stack(
            children: [
              // Decorative vector elements
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: 10,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                right: 20,
                top: 60,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              // Wave pattern
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomPaint(
                  size: const Size(double.infinity, 60),
                  painter: _WavePatternPainter(),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Wave Pattern Painter
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
                  fontSize: 14,
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
            Expanded(
              child: _buildTabButton(
                'private',
                'Pribadi',
                Icons.person_pin_circle_rounded,
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
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildOrderCardSkeleton(),
            ),
            childCount: 5,
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFEF4444),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadMyJobs,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final orders = _getFilteredJobs(_selectedTab);
    
    if (orders.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: _buildEmptyState(
              _selectedTab == 'active'
                  ? 'Belum Ada Pesanan Aktif'
                  : _selectedTab == 'history'
                  ? 'Belum Ada Riwayat Pesanan'
                  : 'Belum Ada Pesanan Pribadi',
              _selectedTab == 'active'
                  ? 'Pesanan yang sedang berlangsung akan muncul di sini'
                  : _selectedTab == 'history'
                  ? 'Pesanan yang sudah selesai akan muncul di sini'
                  : _selectedRole == 'customer'
                  ? 'Pesanan pribadi yang Anda buat akan muncul di sini'
                  : 'Pesanan pribadi yang ditugaskan ke Anda akan muncul di sini',
              _selectedTab == 'active'
                  ? Icons.work_outline_rounded
                  : _selectedTab == 'history'
                  ? Icons.history_rounded
                  : Icons.person_pin_circle_rounded,
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= orders.length) return null;
            final order = orders[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: _buildOrderCardFromApi(order),
              ),
            );
          },
          childCount: orders.length,
        ),
      ),
    );
  }

  Widget _buildOrderCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 100,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                Container(
                  width: 80,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 200,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: 150,
              height: 14,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const Spacer(),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrders() {
    final activeOrders = _getFilteredJobs('active');

    if (activeOrders.isEmpty) {
      return _buildEmptyState(
        'Belum Ada Pesanan Aktif',
        'Pesanan yang sedang berlangsung akan muncul di sini',
        Icons.work_outline_rounded,
      );
    }

    return Column(
      children: activeOrders
          .map((order) => _buildOrderCardFromApi(order))
          .toList(),
    );
  }

  Widget _buildHistoryOrders() {
    final historyOrders = _getFilteredJobs('history');

    if (historyOrders.isEmpty) {
      return _buildEmptyState(
        'Belum Ada Riwayat Pesanan',
        'Pesanan yang sudah selesai akan muncul di sini',
        Icons.history_rounded,
      );
    }

    return Column(
      children: historyOrders
          .map((order) => _buildOrderCardFromApi(order))
          .toList(),
    );
  }

  Widget _buildPrivateOrders() {
    final privateOrders = _getFilteredJobs('private');

    if (privateOrders.isEmpty) {
      return _buildEmptyState(
        'Belum Ada Pesanan Pribadi',
        _selectedRole == 'customer'
            ? 'Pesanan pribadi yang Anda buat akan muncul di sini'
            : 'Pesanan pribadi yang ditugaskan ke Anda akan muncul di sini',
        Icons.person_pin_circle_rounded,
      );
    }

    return Column(
      children: privateOrders
          .map((order) => _buildOrderCardFromApi(order))
          .toList(),
    );
  }

  bool _isPrivateOrder(Map<String, dynamic> job) {
    // Check if this is a private order based on additional_info or assigned_worker_id
    final additionalInfo = job['additional_info'];
    if (additionalInfo is Map<String, dynamic>) {
      return additionalInfo['is_private_order'] == true;
    }

    // Alternative check: if assigned_worker_id exists and no applicants, it's likely private
    return job['assigned_worker_id'] != null &&
        (job['applicant_count'] == null || job['applicant_count'] == 0);
  }

  List<Map<String, dynamic>> _getFilteredJobs(String tab) {
    List<Map<String, dynamic>> data = [];

    if (_selectedRole == 'customer') {
      // Show orders (jobs created by user)
      data = _myOrders;
    } else {
      // Show jobs (jobs taken by user) - combine applied jobs and assigned jobs without duplicates
      data = _mergeWorkerJobs();
    }

    if (data.isEmpty) return [];

    return data.where((item) {
      final jobStatus = item['status'] ?? 'pending';
      final applicationStatus = item['application_status'] ?? 'pending';
      final isPrivate = _isPrivateOrder(item);

      if (tab == 'active') {
        // Only show PUBLIC jobs (not private) for active tab
        if (isPrivate) return false;

        if (_selectedRole == 'customer') {
          // For orders: show pending, inProgress jobs (public only)
          // Exclude completed jobs from active tab
          if (jobStatus == 'completed') return false;
          return jobStatus == 'pending' ||
              jobStatus == 'inProgress' ||
              jobStatus == 'pending_completion';
        } else {
          // For jobs: show pending application or in progress (public only)
          // Exclude rejected applications and completed jobs from active tab
          if (applicationStatus == 'rejected' ||
              applicationStatus == 'cancelled') {
            return false;
          }
          if (jobStatus == 'completed') return false;
          return applicationStatus == 'pending' ||
              applicationStatus == 'accepted' ||
              jobStatus == 'inProgress' ||
              jobStatus == 'pending_completion';
        }
      } else if (tab == 'history') {
        // Show ALL jobs (public + private) for history
        if (_selectedRole == 'customer') {
          // For orders: show completed, cancelled jobs
          return jobStatus == 'completed' || jobStatus == 'cancelled';
        } else {
          // For jobs: show completed, cancelled, or rejected jobs
          // A private job is considered "history" if it's completed, cancelled, or rejected.
          // A public job (from an application) is history if the job is done/cancelled OR the application was rejected.
          return jobStatus == 'completed' ||
              jobStatus == 'cancelled' ||
              applicationStatus == 'cancelled' ||
              (applicationStatus == 'rejected' &&
                  jobStatus != 'completed' &&
                  jobStatus != 'cancelled');
        }
      } else if (tab == 'private') {
        // Only show PRIVATE jobs for private tab
        if (!isPrivate) return false;

        if (_selectedRole == 'customer') {
          // For orders: show private orders created by user
          return jobStatus == 'pending' ||
              jobStatus == 'inProgress' ||
              jobStatus == 'pending_completion';
        } else {
          // For jobs: show private orders assigned to user
          return jobStatus == 'pending' ||
              jobStatus == 'inProgress' ||
              jobStatus == 'pending_completion';
        }
      }

      return false;
    }).toList();
  }

  Widget _buildOrderCardFromApi(Map<String, dynamic> job) {
    final jobStatus = job['status'] ?? 'pending';
    final applicationStatus = job['application_status'] ?? 'pending';

    // Check if this is a private order
    final isPrivateOrder = _isPrivateOrder(job);

    // Determine display status based on role and status
    String displayStatus;
    Color statusColor;

    if (_selectedRole == 'customer') {
      // For orders (jobs created by user)
      if (isPrivateOrder) {
        // Special status for private orders
        switch (jobStatus) {
          case 'pending':
            displayStatus = 'Menunggu Konfirmasi';
            statusColor = const Color(0xFF2D9CDB);
            break;
          case 'inProgress':
            displayStatus = 'Sedang Dikerjakan';
            statusColor = Colors.blue;
            break;
          case 'pending_completion':
            displayStatus = 'Menunggu Konfirmasi Anda';
            statusColor = Colors.purple;
            break;
          case 'completed':
            displayStatus = 'Selesai';
            statusColor = Colors.green;
            break;
          case 'cancelled':
            displayStatus = 'Dibatalkan';
            statusColor = Colors.red;
            break;
          default:
            displayStatus = _getStatusText(jobStatus);
            statusColor = _getStatusColor(jobStatus);
        }
      } else {
        // Regular public orders
        switch (jobStatus) {
          case 'pending':
            displayStatus = 'Menunggu Worker';
            statusColor = Colors.orange;
            break;
          case 'inProgress':
            displayStatus = 'Sedang Dikerjakan';
            statusColor = Colors.blue;
            break;
          case 'pending_completion':
            displayStatus = 'Menunggu Konfirmasi Anda';
            statusColor = Colors.purple;
            break;
          case 'completed':
            displayStatus = 'Selesai';
            statusColor = Colors.green;
            break;
          case 'cancelled':
            displayStatus = 'Dibatalkan';
            statusColor = Colors.red;
            break;
          default:
            displayStatus = _getStatusText(jobStatus);
            statusColor = _getStatusColor(jobStatus);
        }
      }
    } else {
      // For jobs (jobs taken by user)
      if (isPrivateOrder) {
        // Logika baru untuk pesanan pribadi dari sisi pekerja
        if (jobStatus == 'pending') {
          displayStatus = 'Menunggu Konfirmasi';
          statusColor = Colors.orange;
        } else if (jobStatus == 'inProgress') {
          displayStatus = 'Sedang Dikerjakan';
          statusColor = Colors.blue;
        } else if (jobStatus == 'pending_completion') {
          displayStatus = 'Menunggu Konfirmasi Customer';
          statusColor = Colors.purple;
        } else if (applicationStatus == 'accepted' &&
            jobStatus == 'completed') {
          displayStatus = 'Selesai';
          statusColor = Colors.green;
        } else if (applicationStatus == 'rejected') {
          displayStatus = 'Ditolak';
          statusColor = Colors.red;
        } else if (applicationStatus == 'cancelled') {
          displayStatus = 'Anda Membatalkan';
          statusColor = Colors.grey;
        } else if (jobStatus == 'cancelled') {
          displayStatus = 'Dibatalkan Pembuat';
          statusColor = Colors.red;
        } else {
          displayStatus = _getStatusText(jobStatus);
          statusColor = _getStatusColor(jobStatus);
        }
      } else {
        // Regular public jobs
        if (applicationStatus == 'rejected') {
          displayStatus = 'Ditolak';
          statusColor = Colors.red;
        } else if (applicationStatus == 'pending') {
          displayStatus = 'Lamaran Terkirim';
          statusColor = Colors.orange;
        } else if (applicationStatus == 'cancelled') {
          displayStatus = 'Anda Membatalkan';
          statusColor = Colors.grey;
        } else if (applicationStatus == 'accepted' &&
            jobStatus == 'inProgress') {
          displayStatus = 'Sedang Dikerjakan';
          statusColor = Colors.blue;
        } else if (jobStatus == 'pending_completion') {
          displayStatus = 'Menunggu Konfirmasi Customer';
          statusColor = Colors.purple;
        } else if (jobStatus == 'completed') {
          displayStatus = 'Selesai';
          statusColor = Colors.green;
        } else if (jobStatus == 'cancelled') {
          displayStatus = 'Dibatalkan Pembuat';
          statusColor = Colors.red;
        } else {
          displayStatus = _getStatusText(jobStatus);
          statusColor = _getStatusColor(jobStatus);
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isPrivateOrder
                ? const Color(0xFF2D9CDB).withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isPrivateOrder
              ? const Color(0xFF2D9CDB).withOpacity(0.3)
              : Colors.grey[200]!,
          width: isPrivateOrder ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Determine the context based on the selected role
          final viewContext = _selectedRole == 'customer'
              ? JobDetailViewContext.customer
              : JobDetailViewContext.worker;

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailScreen(
                jobId: job['id'].toString(),
                viewContext: viewContext,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with status and price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: statusColor.withOpacity(0.3),
                          ),
                        ),
                        child: Text(
                          displayStatus,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isPrivateOrder) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFF2D9CDB),
                                const Color(0xFF27AE60),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_pin_circle_rounded,
                                color: Colors.white,
                                size: 12,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Pribadi',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                ],
              ),
              const SizedBox(height: 16),

              // Job title
              Text(
                job['title'] ?? 'No Title',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),

              // Job description
              Text(
                job['description'] ?? 'No Description',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),

              // Private order info or applicant info
              if (isPrivateOrder && _selectedRole == 'customer') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF2D9CDB).withOpacity(0.05),
                        const Color(0xFF27AE60).withOpacity(0.05),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2D9CDB).withOpacity(0.2),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.person_add_alt_1_rounded,
                        color: const Color(0xFF2D9CDB),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Pesanan khusus langsung ke pekerja yang dipilih',
                          style: const TextStyle(
                            color: Color(0xFF2D9CDB),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (isPrivateOrder &&
                  _selectedRole == 'worker' &&
                  jobStatus == 'pending') ...[
                // Action buttons for private orders (worker role)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D9CDB).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF2D9CDB).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.work_outline_rounded,
                            color: const Color(0xFF2D9CDB),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Pesanan pribadi menunggu konfirmasi Anda',
                              style: const TextStyle(
                                color: Color(0xFF2D9CDB),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _acceptPrivateOrder(job),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF27AE60),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Terima',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () => _rejectPrivateOrder(job),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFE74C3C),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                              child: const Text(
                                'Tolak',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (!isPrivateOrder &&
                  _selectedRole == 'customer' &&
                  jobStatus == 'pending') ...[
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
                          'Menunggu pekerja mengajukan diri',
                          style: const TextStyle(
                            color: Color(0xFF6366F1),
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Location and time
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      job['address'] ?? 'No Address',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.access_time_outlined,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatTimeAgo(job['created_at']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
              
              // Show completion details if job is completed and the user is either the customer
              // or the worker who was accepted for the job.
              if (jobStatus == 'completed' &&
                  (_selectedRole == 'customer' ||
                      applicationStatus == 'accepted' ||
                      isPrivateOrder)) ...[
                const SizedBox(height: 16),
                _buildCompletionDetails(job, isPrivate: isPrivateOrder),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionDetails(Map<String, dynamic> job, {bool isPrivate = false}) {
    // Calculate points earned
    int pointsEarned = 0;
    if (_selectedRole == 'worker') {
      // Worker gets 50 points for completing job (+10 bonus if perfect rating)
      pointsEarned = 50; // Base points, you might want to get actual points from API
    }
    
    // Get earnings (price)
    final price = _parseToDouble(job['price'] ?? 0);
    final completedAt = job['completed_at'] ?? job['updated_at'];
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF10B981).withOpacity(0.1),
            const Color(0xFF10B981).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Color(0xFF10B981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Detail Penyelesaian',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_selectedRole == 'worker') ...[
            // Points earned
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFF59E0B),
                        Color(0xFFEF4444),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.stars_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Poin yang Didapat',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$pointsEarned poin',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          // Earnings
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF10B981),
                      Color(0xFF059669),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.attach_money_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _selectedRole == 'worker' ? 'Pendapatan' : 'Biaya',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Rp ${price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (completedAt != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Text(
                  'Selesai: ${_formatDateTime(completedAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(dynamic dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Unknown';
    }
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
              builder: (context) => JobDetailScreen(jobId: order.id.toString()),
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
                                color: _getStatusColorFromString(
                                  order.status.toString().split('.').last,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getStatusTextFromString(
                                  order.status.toString().split('.').last,
                                ),
                                style: TextStyle(
                                  color: _getStatusColorFromString(
                                    order.status.toString().split('.').last,
                                  ),
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
                      'Rp ${_formatPrice(order.price)}',
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
                      onPressed: () =>
                          _showCancelDialog(_convertJobModelToApiData(order)),
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
            onPressed: () async {
              Navigator.pop(context); // Close the applicant list dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Konfirmasi Pemilihan'),
                  content: const Text(
                    'Apakah Anda yakin ingin memilih pekerja ini? Tindakan ini tidak dapat dibatalkan.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Batal'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27AE60),
                      ),
                      child: const Text('Ya, Pilih Pekerja'),
                    ),
                  ],
                ),
              );
              if (confirm != true) return;

              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );
                // Temukan ID aplikasi pelamar ini dari daftar aplikasi order.applicants jika tersedia
                // (Kamu perlu pastikan JobModel atau API job list punya mapping applicationId)
                String? applicationId;
                // Misal, kalau order ada field applicantApplications (list peta {id, worker_id}):
                /*
                if (order.applicantApplications != null) {
                  final app = order.applicantApplications!.firstWhere(
                    (a) => a['worker_id'] == applicantId,
                    orElse: () => null,
                  );
                  if (app != null) applicationId = app['id'];
                }
                */
                // Jika tidak ada, fallback ke applicantId saja (asumsi sudah benar, kamu perlu sesuaikan ini bila perlu)
                applicationId = applicantId;
                final resp = await ApiService().acceptApplication(
                  applicationId,
                );
                Navigator.pop(context);
                if (resp['success'] == true) {
                  _showNotification('Pekerja berhasil dipilih!');
                  await _loadMyJobs();
                } else {
                  _showNotification(resp['message'] ?? 'Gagal memilih pekerja');
                }
              } catch (e) {
                Navigator.pop(context);
                _showNotification(
                  'Error saat memilih pekerja: ${e.toString()}',
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
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

  void _showNotification(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: isError ? Colors.red : Colors.white,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? Colors.red : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isError
            ? Colors.red
            : const Color(0xFF27AE60), // Hijau untuk Aksi / CTA
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getStatusTextFromString(String status) {
    switch (status) {
      case 'pending':
        return 'Menunggu';
      case 'inProgress':
        return 'Sedang Berlangsung';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      case 'disputed':
        return 'Dispute';
      default:
        return status;
    }
  }

  Color _getStatusColorFromString(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'inProgress':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'disputed':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '0';
    if (price is String) {
      return double.parse(price).toStringAsFixed(0);
    } else if (price is num) {
      return price.toStringAsFixed(0);
    }
    return '0';
  }

  Map<String, dynamic> _convertJobModelToApiData(JobModel job) {
    return {
      'id': job.id,
      'title': job.title,
      'description': job.description,
      'price': job.price,
      'status': job.status.name,
      'created_at': job.createdAt.toIso8601String(),
      'address': job.location.address,
    };
  }

  void _showCancelDialog(Map<String, dynamic> job) {
    final jobTitle = job['title'] ?? 'Job';
    final isCustomer = _selectedRole == 'customer';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cancel ${isCustomer ? 'Order' : 'Application'}?'),
        content: Text(
          isCustomer
              ? 'Are you sure you want to cancel the order "$jobTitle"? This action cannot be undone.'
              : 'Are you sure you want to cancel your application for "$jobTitle"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelJob(job);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelJob(Map<String, dynamic> job) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await _apiService.cancelJob(job['id'].toString());
      Navigator.pop(context); // Close loading dialog

      final isCustomer = _selectedRole == 'customer';

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCustomer
                  ? 'Order cancelled successfully'
                  : 'Application cancelled successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadMyJobs(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to cancel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _acceptPrivateOrder(Map<String, dynamic> job) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await _apiService.acceptPrivateOrder(
        job['id'].toString(),
      );
      Navigator.pop(context); // Close loading dialog

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pesanan pribadi berhasil diterima!'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMyJobs(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Gagal menerima pesanan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rejectPrivateOrder(Map<String, dynamic> job) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tolak Pesanan Pribadi?'),
        content: Text(
          'Apakah Anda yakin ingin menolak pesanan "${job['title'] ?? 'Job'}"? Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              try {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );

                final response = await _apiService.rejectPrivateOrder(
                  job['id'].toString(),
                );
                Navigator.pop(context); // Close loading dialog

                if (response['success']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pesanan pribadi berhasil ditolak'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  _loadMyJobs(); // Refresh the list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        response['message'] ?? 'Gagal menolak pesanan',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context); // Close loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ya, Tolak'),
          ),
        ],
      ),
    );
  }
}

// Wave Pattern Painter
class _WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * 0.5);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.3,
      size.width * 0.5,
      size.height * 0.5,
    );
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.7,
      size.width,
      size.height * 0.5,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
