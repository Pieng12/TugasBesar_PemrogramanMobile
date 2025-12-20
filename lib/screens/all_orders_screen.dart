import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../models/location_model.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';

class AllOrdersScreen extends StatefulWidget {
  const AllOrdersScreen({super.key});

  @override
  State<AllOrdersScreen> createState() => _AllOrdersScreenState();
}

class _AllOrdersScreenState extends State<AllOrdersScreen>
    with TickerProviderStateMixin {
  String _selectedFilter = 'all';
  String _selectedSort = 'distance';
  String _searchQuery = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String? _error;

  final List<Map<String, dynamic>> _filterOptions = [
    {
      'value': 'all',
      'label': 'Semua',
      'icon': Icons.apps,
      'color': const Color(0xFF4F4F4F),
    }, // Info & Secondary
    {
      'value': 'cleaning',
      'label': 'Pembersihan',
      'icon': Icons.cleaning_services,
      'color': const Color(0xFF27AE60),
    }, // Hijau untuk Aksi / CTA
    {
      'value': 'maintenance',
      'label': 'Perbaikan',
      'icon': Icons.build,
      'color': const Color(0xFFF2C94C),
    }, // Kuning / Emas untuk Badge
    {
      'value': 'delivery',
      'label': 'Pengiriman',
      'icon': Icons.delivery_dining,
      'color': const Color(0xFF2D9CDB),
    }, // Biru Cerah untuk Brand
    {
      'value': 'tutoring',
      'label': 'Edukasi',
      'icon': Icons.school,
      'color': const Color(0xFFEB5757),
    }, // Merah untuk SOS / Darurat
    {
      'value': 'photography',
      'label': 'Fotografi',
      'icon': Icons.camera_alt,
      'color': const Color(0xFF2D9CDB),
    }, // Biru Cerah untuk Brand
    {
      'value': 'cooking',
      'label': 'Kuliner',
      'icon': Icons.restaurant,
      'color': const Color(0xFF27AE60),
    }, // Hijau untuk Aksi / CTA
  ];

  final List<Map<String, dynamic>> _sortOptions = [
    {
      'value': 'distance',
      'label': 'Terdekat',
      'icon': Icons.location_on,
      'color': const Color(0xFF27AE60),
    }, // Hijau untuk Aksi / CTA
    {
      'value': 'price_high',
      'label': 'Harga Tertinggi',
      'icon': Icons.arrow_upward,
      'color': const Color(0xFFF2C94C),
    }, // Kuning / Emas untuk Badge
    {
      'value': 'price_low',
      'label': 'Harga Terendah',
      'icon': Icons.arrow_downward,
      'color': const Color(0xFF2D9CDB),
    }, // Biru Cerah untuk Brand
    {
      'value': 'newest',
      'label': 'Terbaru',
      'icon': Icons.schedule,
      'color': const Color(0xFFEB5757),
    }, // Merah untuk SOS / Darurat
    {
      'value': 'rating',
      'label': 'Rating',
      'icon': Icons.star,
      'color': const Color(0xFFF2C94C),
    }, // Kuning / Emas untuk Badge
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
    _loadOrders();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      final response = await _apiService.getJobs();

      if (response['success']) {
        // Backend already filters out private orders
        final data = response['data'];
        List<Map<String, dynamic>> orders = [];

        if (data is Map && data.containsKey('data')) {
          orders = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          orders = List<Map<String, dynamic>>.from(data);
        }

        setState(() {
          _orders = orders;
          _isLoading = false;
        });
        _animationController.forward();
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load orders';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading orders: ${e.toString()}';
        _isLoading = false;
      });
    }
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
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2196F3), Color(0xFF1976D2)],
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                bottom: -60,
                left: -60,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              // Dotted pattern
              ...List.generate(20, (index) {
                return Positioned(
                  left: index * 30.0,
                  top: index % 2 == 0 ? 40 : 60,
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                );
              }),
              // Wave pattern
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: CustomPaint(
                  painter: WavePatternPainter(),
                  size: Size(MediaQuery.of(context).size.width, 60),
                ),
              ),
              // Main content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.work_outline,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Temukan Pekerjaan Terdekat',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? option['color'] : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? option['color'] : Colors.grey[300]!,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: option['color'].withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
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
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? option['color'] : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? option['color']
                                  : Colors.grey[300]!,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: option['color'].withOpacity(0.3),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                option['icon'],
                                size: 14,
                                color: isSelected
                                    ? Colors.white
                                    : option['color'],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                option['label'],
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey[700],
                                  fontSize: 12,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
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
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
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
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 16,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                height: 12,
                                width: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }, childCount: 5),
        ),
      );
    }

    if (_error != null) {
      return SliverPadding(
        padding: const EdgeInsets.all(16),
        sliver: SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(32),
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
            ),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Error',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(fontSize: 16, color: Colors.grey[500]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadOrders,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredOrders = _getFilteredOrders();

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= filteredOrders.length) return null;
          final order = filteredOrders[index];
          return FadeTransition(
            opacity: _fadeAnimation,
            child: _buildOrderCardFromApi(order, index),
          );
        }, childCount: filteredOrders.length),
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
              builder: (context) => JobDetailScreen(jobId: order.id.toString()),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
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
                  Icon(Icons.location_on, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.location.address,
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Rp ${_formatPrice(order.price)}',
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
                      Icon(Icons.people, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        '${order.applicantIds.length} pelamar',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
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
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
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

  List<Map<String, dynamic>> _getFilteredOrders() {
    List<Map<String, dynamic>> orders = List.from(_orders);

    // Filter by category
    if (_selectedFilter != 'all') {
      orders = orders
          .where((order) => order['category'] == _selectedFilter)
          .toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      orders = orders
          .where(
            (order) =>
                order['title'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
                order['description'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          )
          .toList();
    }

    // Sort orders
    switch (_selectedSort) {
      case 'distance':
        orders.sort(
          (a, b) => a['address'].toString().compareTo(b['address'].toString()),
        );
        break;
      case 'price_high':
        orders.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
        break;
      case 'price_low':
        orders.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
        break;
      case 'newest':
        orders.sort(
          (a, b) => DateTime.parse(
            b['created_at'],
          ).compareTo(DateTime.parse(a['created_at'])),
        );
        break;
      case 'rating':
        orders.sort((a, b) => (b['price'] as num).compareTo(a['price'] as num));
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
        applicantIds: ['worker1', 'worker2'],
      ),
      JobModel(
        id: '2',
        customerId: 'customer2',
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
        applicantIds: ['worker3'],
      ),
      JobModel(
        id: '3',
        customerId: 'customer3',
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
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        applicantIds: ['worker4', 'worker5', 'worker6'],
      ),
      JobModel(
        id: '4',
        customerId: 'customer4',
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
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        applicantIds: ['worker7'],
      ),
      JobModel(
        id: '5',
        customerId: 'customer5',
        title: 'Catering 50 Orang',
        description:
            'Catering untuk acara kantor 50 orang. Menu nasi kotak dengan lauk pauk lengkap.',
        category: JobCategory.cooking,
        price: 500000,
        location: Location(
          latitude: -6.2088,
          longitude: 106.8456,
          address: 'Jakarta Barat, Kebon Jeruk',
        ),
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        applicantIds: ['worker8', 'worker9'],
      ),
      JobModel(
        id: '6',
        customerId: 'customer6',
        title: 'Kirim Dokumen',
        description:
            'Pengiriman dokumen penting ke kantor pusat. Same day delivery dalam Jakarta.',
        category: JobCategory.delivery,
        price: 25000,
        location: Location(
          latitude: -6.2088,
          longitude: 106.8456,
          address: 'Jakarta Selatan, Pondok Indah',
        ),
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
            const Icon(Icons.info_outline, color: Colors.white, size: 20),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // New method for API data
  Widget _buildOrderCardFromApi(Map<String, dynamic> order, int index) {
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
              builder: (context) =>
                  JobDetailScreen(jobId: order['id'].toString()),
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
                      color: _getCategoryColorFromString(
                        order['category'],
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoryIconFromString(order['category']),
                      color: _getCategoryColorFromString(order['category']),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          order['title'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getCategoryDisplayName(order['category']),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColorFromString(
                        order['status'],
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _getStatusDisplayName(order['status']),
                      style: TextStyle(
                        color: _getStatusColorFromString(order['status']),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Description
              Text(
                order['description'],
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Footer
              Row(
                children: [
                  Icon(
                    Icons.attach_money_rounded,
                    color: Colors.green[600],
                    size: 20,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Rp ${(order['price'] is String ? double.parse(order['price']) : (order['price'] as num)).toStringAsFixed(0)}',
                    style: TextStyle(
                      color: Colors.green[600],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.location_on_rounded,
                    color: Colors.grey[500],
                    size: 16,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order['address'],
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(order['created_at']),
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper methods for API data
  IconData _getCategoryIconFromString(String category) {
    switch (category) {
      case 'cleaning':
        return Icons.cleaning_services;
      case 'delivery':
        return Icons.delivery_dining;
      case 'maintenance':
        return Icons.build;
      case 'gardening':
        return Icons.local_florist;
      case 'cooking':
        return Icons.restaurant;
      case 'tutoring':
        return Icons.school;
      case 'photography':
        return Icons.camera_alt;
      case 'petCare':
        return Icons.pets;
      case 'other':
      default:
        return Icons.more_horiz;
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'cleaning':
        return 'Pembersihan';
      case 'delivery':
        return 'Pengiriman';
      case 'maintenance':
        return 'Perbaikan';
      case 'gardening':
        return 'Taman';
      case 'cooking':
        return 'Kuliner';
      case 'tutoring':
        return 'Edukasi';
      case 'photography':
        return 'Fotografi';
      case 'petCare':
        return 'Perawatan Hewan';
      case 'other':
      default:
        return 'Lainnya';
    }
  }

  Color _getCategoryColorFromString(String category) {
    switch (category) {
      case 'cleaning':
        return const Color(0xFF27AE60);
      case 'delivery':
        return const Color(0xFF2D9CDB);
      case 'maintenance':
        return const Color(0xFFF2C94C);
      case 'gardening':
        return const Color(0xFF059669);
      case 'cooking':
        return const Color(0xFF27AE60);
      case 'tutoring':
        return const Color(0xFFEB5757);
      case 'photography':
        return const Color(0xFF2D9CDB);
      case 'petCare':
        return const Color(0xFF6366F1);
      case 'other':
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getStatusDisplayName(String status) {
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

  String _formatTimeAgo(String? dateTimeString) {
    if (dateTimeString == null) return '';

    try {
      DateTime dateTime = DateTime.parse(dateTimeString);
      Duration difference = DateTime.now().difference(dateTime);

      if (difference.inDays > 0) {
        return '${difference.inDays}d';
      } else if (difference.inHours > 0) {
        return '${difference.inHours}h';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes}m';
      } else {
        return 'now';
      }
    } catch (e) {
      return '';
    }
  }
}

// Add this custom painter class for the wave pattern
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path();
    path.moveTo(0, size.height * 0.8);

    // Create wave pattern
    for (double i = 0; i < size.width; i += 50) {
      path.quadraticBezierTo(
        i + 25,
        size.height * 0.7,
        i + 50,
        size.height * 0.8,
      );
    }

    canvas.drawPath(path, paint);

    // Draw second wave
    final path2 = Path();
    path2.moveTo(0, size.height * 0.9);

    for (double i = 0; i < size.width; i += 40) {
      path2.quadraticBezierTo(
        i + 20,
        size.height * 0.8,
        i + 40,
        size.height * 0.9,
      );
    }

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// Helper function for formatting price
String _formatPrice(dynamic price) {
  if (price == null) return '0';
  if (price is String) {
    return double.parse(price).toStringAsFixed(0);
  } else if (price is num) {
    return price.toStringAsFixed(0);
  }
  return '0';
}

// Add this new CustomPainter class
class WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    var path = Path();
    var path2 = Path();

    // First wave
    path.moveTo(0, size.height * 0.5);
    for (var i = 0; i < size.width; i += 50) {
      path.quadraticBezierTo(
        i + 25,
        size.height * 0.25,
        i + 50,
        size.height * 0.5,
      );
    }

    // Second wave
    path2.moveTo(0, size.height * 0.7);
    for (var i = 0; i < size.width; i += 40) {
      path2.quadraticBezierTo(
        i + 20,
        size.height * 0.9,
        i + 40,
        size.height * 0.7,
      );
    }

    canvas.drawPath(path, paint);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
