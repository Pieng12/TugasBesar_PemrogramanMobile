import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../models/location_model.dart';
import 'job_detail_screen.dart';

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen> with TickerProviderStateMixin {
  String _selectedFilter = 'all';
  String _selectedSort = 'distance';
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> _filterOptions = [
    {'value': 'all', 'label': 'Semua', 'icon': Icons.apps, 'color': const Color(0xFF4F4F4F)}, // Info & Secondary
    {'value': 'cleaning', 'label': 'Pembersihan', 'icon': Icons.cleaning_services, 'color': const Color(0xFF27AE60)}, // Hijau untuk Aksi / CTA
    {'value': 'maintenance', 'label': 'Perbaikan', 'icon': Icons.build, 'color': const Color(0xFFF2C94C)}, // Kuning / Emas untuk Badge
    {'value': 'delivery', 'label': 'Pengiriman', 'icon': Icons.delivery_dining, 'color': const Color(0xFF2D9CDB)}, // Biru Cerah untuk Brand
    {'value': 'tutoring', 'label': 'Edukasi', 'icon': Icons.school, 'color': const Color(0xFFEB5757)}, // Merah untuk SOS / Darurat
    {'value': 'photography', 'label': 'Fotografi', 'icon': Icons.camera_alt, 'color': const Color(0xFF2D9CDB)}, // Biru Cerah untuk Brand
    {'value': 'cooking', 'label': 'Kuliner', 'icon': Icons.restaurant, 'color': const Color(0xFF27AE60)}, // Hijau untuk Aksi / CTA
  ];

  final List<Map<String, dynamic>> _sortOptions = [
    {'value': 'distance', 'label': 'Terdekat', 'icon': Icons.location_on, 'color': const Color(0xFF27AE60)}, // Hijau untuk Aksi / CTA
    {'value': 'price_high', 'label': 'Harga Tertinggi', 'icon': Icons.arrow_upward, 'color': const Color(0xFFF2C94C)}, // Kuning / Emas untuk Badge
    {'value': 'price_low', 'label': 'Harga Terendah', 'icon': Icons.arrow_downward, 'color': const Color(0xFF2D9CDB)}, // Biru Cerah untuk Brand
    {'value': 'newest', 'label': 'Terbaru', 'icon': Icons.schedule, 'color': const Color(0xFFEB5757)}, // Merah untuk SOS / Darurat
    {'value': 'rating', 'label': 'Rating', 'icon': Icons.star, 'color': const Color(0xFFF2C94C)}, // Kuning / Emas untuk Badge
  ];

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
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // App Bar
          _buildSliverAppBar(),
          // Search Bar
          _buildSearchBar(),
          // Filter Chips
          _buildFilterChips(),
          // Sort Options
          _buildSortOptions(),
          // Orders List
          _buildOrdersList(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Daftar Pesanan',
          style: TextStyle(
            color: Colors.grey[800],
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF2D9CDB), // Biru Cerah untuk Brand
                Color(0xFF1E88E5), // Biru yang lebih gelap
                Color(0xFF1976D2), // Biru gelap
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Temukan Pekerjaan Terbaik',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
            style: const TextStyle(color: Colors.black87),
            decoration: InputDecoration(
              hintText: 'Cari pesanan berdasarkan judul atau deskripsi...',
              hintStyle: TextStyle(color: Colors.grey[500]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey[500]),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _showNotification('Pencarian dihapus');
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SliverToBoxAdapter(
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _filterOptions.length,
          itemBuilder: (context, index) {
            final option = _filterOptions[index];
            final isSelected = _selectedFilter == option['value'];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = option['value'];
                  });
                  _showNotification('Filter: ${option['label']}');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? option['color'] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? option['color'] : Colors.grey[300]!,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: option['color'].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        option['icon'],
                        size: 16,
                        color: isSelected ? Colors.white : option['color'],
                      ),
                      const SizedBox(width: 6),
                      Text(
                        option['label'],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSortOptions() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.sort, color: Colors.grey[600], size: 20),
            const SizedBox(width: 8),
            Text(
              'Urutkan:',
              style: TextStyle(
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _sortOptions.map((option) {
                    final isSelected = _selectedSort == option['value'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedSort = option['value'];
                          });
                          _showNotification('Diurutkan: ${option['label']}');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? option['color'] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? option['color'] : Colors.grey[300]!,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: option['color'].withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                option['icon'],
                                size: 14,
                                color: isSelected ? Colors.white : option['color'],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                option['label'],
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList() {
    final filteredOrders = _getFilteredOrders();
    
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= filteredOrders.length) return null;
            final order = filteredOrders[index];
            return FadeTransition(
              opacity: _fadeAnimation,
              child: _buildOrderCard(order, index),
            );
          },
          childCount: filteredOrders.length,
        ),
      ),
    );
  }

  Widget _buildOrderCard(JobModel order, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey[200]!),
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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getCategoryColor(order.category).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIcon(order.category),
                      color: _getCategoryColor(order.category),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order.title,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              _getCategoryName(order.category),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getStatusColor(order.status).withOpacity(0.1),
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
              const SizedBox(height: 16),
              // Description
              Text(
                order.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Location and Price
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.location.address,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rp ${order.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF10B981),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${order.applicantIds.length} pelamar',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeAgo(order.createdAt),
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<JobModel> _getFilteredOrders() {
    List<JobModel> orders = _getMockOrders();
    
    // Filter by category
    if (_selectedFilter != 'all') {
      orders = orders.where((order) => order.category.name == _selectedFilter).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      orders = orders.where((order) =>
          order.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          order.description.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    }
    
    // Sort orders
    switch (_selectedSort) {
      case 'distance':
        orders.sort((a, b) => a.location.address.compareTo(b.location.address));
        break;
      case 'price_high':
        orders.sort((a, b) => b.price.compareTo(a.price));
        break;
      case 'price_low':
        orders.sort((a, b) => a.price.compareTo(b.price));
        break;
      case 'newest':
        orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'rating':
        orders.sort((a, b) => b.price.compareTo(a.price));
        break;
    }
    
    return orders;
  }

  List<JobModel> _getMockOrders() {
    return [
      JobModel(
        id: '1',
        customerId: 'customer1',
        title: 'Bersihkan Rumah 3 Kamar',
        description: 'Pembersihan menyeluruh rumah 3 kamar tidur, 2 kamar mandi, dan ruang tamu. Termasuk mencuci piring dan merapikan barang.',
        category: JobCategory.cleaning,
        price: 150000,
        location: Location(latitude: -6.2088, longitude: 106.8456, address: 'Jakarta Selatan, Kemang'),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        applicantIds: ['worker1', 'worker2'],
      ),
      JobModel(
        id: '2',
        customerId: 'customer2',
        title: 'Perbaiki AC Rusak',
        description: 'AC tidak dingin, perlu perbaikan dan isi freon. Unit AC 1.5 PK di ruang tamu.',
        category: JobCategory.maintenance,
        price: 200000,
        location: Location(latitude: -6.2088, longitude: 106.8456, address: 'Jakarta Pusat, Menteng'),
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        applicantIds: ['worker3'],
      ),
      JobModel(
        id: '3',
        customerId: 'customer3',
        title: 'Les Matematika SMA',
        description: 'Bimbingan belajar matematika untuk siswa SMA kelas 12. Persiapan UTBK. 2x seminggu.',
        category: JobCategory.tutoring,
        price: 100000,
        location: Location(latitude: -6.2088, longitude: 106.8456, address: 'Jakarta Utara, Kelapa Gading'),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        applicantIds: ['worker4', 'worker5', 'worker6'],
      ),
      JobModel(
        id: '4',
        customerId: 'customer4',
        title: 'Foto Prewedding',
        description: 'Sesi foto prewedding outdoor di Taman Suropati. 2-3 jam sesi foto dengan 50 hasil edit.',
        category: JobCategory.photography,
        price: 2500000,
        location: Location(latitude: -6.2088, longitude: 106.8456, address: 'Jakarta Pusat, Menteng'),
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        applicantIds: ['worker7'],
      ),
      JobModel(
        id: '5',
        customerId: 'customer5',
        title: 'Catering 50 Orang',
        description: 'Catering untuk acara kantor 50 orang. Menu nasi kotak dengan lauk pauk lengkap.',
        category: JobCategory.cooking,
        price: 500000,
        location: Location(latitude: -6.2088, longitude: 106.8456, address: 'Jakarta Barat, Kebon Jeruk'),
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        applicantIds: ['worker8', 'worker9'],
      ),
      JobModel(
        id: '6',
        customerId: 'customer6',
        title: 'Kirim Dokumen',
        description: 'Pengiriman dokumen penting ke kantor pusat. Same day delivery dalam Jakarta.',
        category: JobCategory.delivery,
        price: 25000,
        location: Location(latitude: -6.2088, longitude: 106.8456, address: 'Jakarta Selatan, Pondok Indah'),
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        applicantIds: ['worker10'],
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
        return Icons.cleaning_services;
      case JobCategory.maintenance:
        return Icons.build;
      case JobCategory.delivery:
        return Icons.delivery_dining;
      case JobCategory.tutoring:
        return Icons.school;
      case JobCategory.photography:
        return Icons.camera_alt;
      case JobCategory.cooking:
        return Icons.restaurant;
      case JobCategory.gardening:
        return Icons.local_florist;
      case JobCategory.petCare:
        return Icons.pets;
      case JobCategory.other:
        return Icons.more_horiz;
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
              Icons.info_outline,
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
        backgroundColor: const Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}