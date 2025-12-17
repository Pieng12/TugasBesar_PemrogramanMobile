import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import 'job_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

class JobListScreen extends StatefulWidget {
  final String? initialCategory;
  
  const JobListScreen({super.key, this.initialCategory});

  @override
  State<JobListScreen> createState() => _JobListScreenState();
}

class _JobListScreenState extends State<JobListScreen>
    with TickerProviderStateMixin {
  JobCategory? _selectedCategory;
  String _searchQuery = '';
  String _selectedSort = 'distance';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _jobs = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserId;
  Position? _userPosition;
  bool _filterNearby = false;
  final NumberFormat _priceFormatter =
      NumberFormat.currency(locale: 'id_ID', symbol: '', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    // Set initial category if provided
    if (widget.initialCategory != null) {
      _selectedCategory = _stringToJobCategory(widget.initialCategory);
    }
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadJobs();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      // Try to get from user data
      if (_apiService.token != null) {
        try {
          final userResponse = await _apiService.getUser();
          if (userResponse['success']) {
            final userData = userResponse['data'];
            final lat = userData['current_latitude'];
            final lng = userData['current_longitude'];
            if (lat != null && lng != null) {
              _userPosition = Position(
                latitude: lat is double ? lat : double.parse(lat.toString()),
                longitude: lng is double ? lng : double.parse(lng.toString()),
                timestamp: DateTime.now(),
                accuracy: 0,
                altitude: 0,
                heading: 0,
                speed: 0,
                speedAccuracy: 0,
                altitudeAccuracy: 0,
                headingAccuracy: 0,
              );
            }
          }
        } catch (e) {
          print('Error getting location from user data: $e');
        }
      }
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  String _formatDistance(Map<String, dynamic> job) {
    if (job['distance_km'] != null) {
      final distance = job['distance_km'] is double 
          ? job['distance_km'] 
          : double.tryParse(job['distance_km'].toString());
      if (distance != null && distance.isFinite) {
        if (distance < 1) {
          return '${(distance * 1000).toStringAsFixed(0)} m';
        } else {
          return '${distance.toStringAsFixed(1)} km';
        }
      }
    } else if (_userPosition != null && job['latitude'] != null && job['longitude'] != null) {
      final jobLat = job['latitude'] is double ? job['latitude'] : double.tryParse(job['latitude'].toString());
      final jobLng = job['longitude'] is double ? job['longitude'] : double.tryParse(job['longitude'].toString());
      if (jobLat != null && jobLng != null) {
        final distance = _calculateDistance(
          _userPosition!.latitude,
          _userPosition!.longitude,
          jobLat,
          jobLng,
        );
        if (distance < 1) {
          return '${(distance * 1000).toStringAsFixed(0)} m';
        } else {
          return '${distance.toStringAsFixed(1)} km';
        }
      }
    }
    return 'Jarak tidak diketahui';
  }

  Future<void> _loadJobs() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      // Get current user ID
      if (_apiService.token != null) {
        try {
          final userResponse = await _apiService.getUser();
          if (userResponse['success']) {
            _currentUserId = userResponse['data']['id']?.toString();
          }
        } catch (e) {
          // Ignore if user data fails, proceed without it
        }
      }

      // Get user location if filter nearby is enabled
      if (_filterNearby) {
        await _getUserLocation();
      }

      final response = await _apiService.getJobs(
        category: _selectedCategory?.name,
        latitude: _filterNearby && _userPosition != null ? _userPosition!.latitude : null,
        longitude: _filterNearby && _userPosition != null ? _userPosition!.longitude : null,
        radius: _filterNearby && _userPosition != null ? 10.0 : null,
      );

      if (response['success']) {
        // Handle paginated response
        final data = response['data'];
        List<Map<String, dynamic>> fetchedJobs = [];
        if (data is Map && data.containsKey('data')) {
          fetchedJobs = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          fetchedJobs = List<Map<String, dynamic>>.from(data);
        }

        // Filter out jobs created by the current user
        if (_currentUserId != null) {
          fetchedJobs.removeWhere(
            (job) => job['customer_id']?.toString() == _currentUserId,
          );
        }

        // Filter out private jobs: assigned_worker_id != null OR additional_info[is_private_order] == true
        fetchedJobs.removeWhere((job) =>
          job['assigned_worker_id'] != null ||
          (job['additional_info'] is Map && job['additional_info']['is_private_order'] == true)
        );

        // Filter out jobs that are already cancelled
        fetchedJobs.removeWhere((job) => job['status'] == 'cancelled');

        // Apply search filter
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          fetchedJobs = fetchedJobs.where((job) {
            final title = (job['title'] ?? '').toString().toLowerCase();
            final description = (job['description'] ?? '').toString().toLowerCase();
            final customerName = (job['customer']?['name'] ?? job['customer_name'] ?? '').toString().toLowerCase();
            return title.contains(query) || 
                   description.contains(query) || 
                   customerName.contains(query);
          }).toList();
        }

        // Calculate distance for each job if user position is available
        if (_userPosition != null) {
          for (var job in fetchedJobs) {
            final jobLat = job['latitude'];
            final jobLng = job['longitude'];
            if (jobLat != null && jobLng != null) {
              final lat = jobLat is double ? jobLat : double.tryParse(jobLat.toString());
              final lng = jobLng is double ? jobLng : double.tryParse(jobLng.toString());
              if (lat != null && lng != null) {
                final distance = _calculateDistance(
                  _userPosition!.latitude,
                  _userPosition!.longitude,
                  lat,
                  lng,
                );
                job['distance_km'] = distance;
              }
            }
          }
        }

        // Apply sorting
        fetchedJobs.sort((a, b) {
          switch (_selectedSort) {
            case 'price_high':
              final priceA = _parseToDouble(a['price'] ?? 0);
              final priceB = _parseToDouble(b['price'] ?? 0);
              return priceB.compareTo(priceA);
            case 'price_low':
              final priceA = _parseToDouble(a['price'] ?? 0);
              final priceB = _parseToDouble(b['price'] ?? 0);
              return priceA.compareTo(priceB);
            case 'newest':
              try {
                final dateA = DateTime.parse(a['created_at'] ?? DateTime.now().toIso8601String());
                final dateB = DateTime.parse(b['created_at'] ?? DateTime.now().toIso8601String());
                return dateB.compareTo(dateA);
              } catch (e) {
                return 0;
              }
            case 'distance':
            default:
              // Sort by distance if available, otherwise keep original order
              if (_userPosition != null) {
                final distA = a['distance_km'] ?? double.infinity;
                final distB = b['distance_km'] ?? double.infinity;
                return distA.compareTo(distB);
              }
              return 0;
          }
        });

        setState(() {
          _jobs = fetchedJobs;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load jobs';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading jobs: ${e.toString()}';
        _isLoading = false;
      });
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

  String _formatPrice(dynamic price) {
    final value = _parseToDouble(price);
    final formatted = _priceFormatter.format(value).trim();
    return 'Rp $formatted';
  }

  Future<void> _applyFiltersAndSort() async {
    // Reload jobs to get fresh data, then apply filters and sort
    await _loadJobs();
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

  Color _getCategoryColorFromString(String? category) {
    switch (category) {
      case 'cleaning':
        return const Color(0xFF10B981);
      case 'maintenance':
        return const Color(0xFF3B82F6);
      case 'delivery':
        return const Color(0xFF8B5CF6);
      case 'tutoring':
        return const Color(0xFFF59E0B);
      case 'photography':
        return const Color(0xFFEF4444);
      case 'cooking':
        return const Color(0xFFF97316);
      case 'gardening':
        return const Color(0xFF22C55E);
      case 'petCare':
        return const Color(0xFF06B6D4);
      default:
        return const Color(0xFF6B7280);
    }
  }

  IconData _getCategoryIconFromString(String? category) {
    switch (category) {
      case 'cleaning':
        return Icons.cleaning_services_rounded;
      case 'maintenance':
        return Icons.build_rounded;
      case 'delivery':
        return Icons.local_shipping_rounded;
      case 'tutoring':
        return Icons.school_rounded;
      case 'photography':
        return Icons.camera_alt_rounded;
      case 'cooking':
        return Icons.restaurant_rounded;
      case 'gardening':
        return Icons.eco_rounded;
      case 'petCare':
        return Icons.pets_rounded;
      default:
        return Icons.work_rounded;
    }
  }

  String _getCategoryDisplayName(String? category) {
    switch (category) {
      case 'cleaning':
        return 'Pembersihan';
      case 'maintenance':
        return 'Perbaikan';
      case 'delivery':
        return 'Pengiriman';
      case 'tutoring':
        return 'Edukasi';
      case 'photography':
        return 'Fotografi';
      case 'cooking':
        return 'Kuliner';
      case 'gardening':
        return 'Kebun';
      case 'petCare':
        return 'Perawatan Hewan';
      default:
        return 'Lainnya';
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          _buildSliverAppBar(),
          // Search Bar
          _buildSearchBar(),
          // Filter Chips
          _buildFilterChips(),
          // Sort Options
          _buildSortOptions(),
          // Job List
          _buildJobList(),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 160,
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
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 80,
                top: 60,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: 20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              // Wave pattern overlay
              CustomPaint(
                size: Size.infinite,
                painter: WavePatternPainter(),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.work_outline_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Temukan Pekerjaan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedCategory != null
                                      ? 'Kategori: ${_getCategoryName(_selectedCategory!)}'
                                      : 'Semua kategori tersedia',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
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

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              // Debounce search
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_searchQuery == value) {
                  _applyFiltersAndSort();
                }
              });
            },
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Cari pekerjaan berdasarkan judul atau deskripsi...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: const Color(0xFF2563EB),
                size: 24,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: Colors.grey[400],
                        size: 20,
                      ),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                          });
                          _applyFiltersAndSort();
                        },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
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
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: JobCategory.values.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildCategoryChip('Semua', null),
              );
            }
            final category = JobCategory.values[index - 1];
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: _buildCategoryChip(
                _getCategoryName(category),
                category as JobCategory?,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, JobCategory? category) {
    final isSelected = _selectedCategory == category;
    final color = category != null
        ? _getCategoryColor(category)
        : const Color(0xFF6B7280);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = category;
          });
          _loadJobs();
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 0 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category != null ? _getCategoryIcon(category) : Icons.apps_rounded,
                size: 18,
                color: isSelected ? Colors.white : color,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF1E293B),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortOptions() {
    final sortOptions = <Map<String, dynamic>>[
      {
        'value': 'distance',
        'label': 'Terdekat',
        'icon': Icons.location_on_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'value': 'price_high',
        'label': 'Harga Tertinggi',
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'value': 'price_low',
        'label': 'Harga Terendah',
        'icon': Icons.trending_down_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'value': 'newest',
        'label': 'Terbaru',
        'icon': Icons.access_time_rounded,
        'color': const Color(0xFF8B5CF6),
      },
    ];

    // Add "Sekitar" filter option
    final filterOptions = <Map<String, dynamic>>[
      {
        'value': 'nearby',
        'label': 'Sekitar',
        'icon': Icons.near_me_rounded,
        'color': const Color(0xFF10B981),
      },
    ];

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.sort_rounded,
                  color: const Color(0xFF64748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Urutkan:',
                  style: TextStyle(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Filter "Sekitar" option
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...filterOptions.map((option) {
                    final isSelected = _filterNearby;
                    final color = option['color'] as Color;
                    final icon = option['icon'] as IconData;
                    final label = option['label'] as String;
                    return Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _filterNearby = !_filterNearby;
                              if (_filterNearby) {
                                _selectedSort = 'distance'; // Auto sort by distance when nearby filter is on
                              }
                            });
                            _applyFiltersAndSort();
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? color : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? color : const Color(0xFFE2E8F0),
                                width: isSelected ? 0 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withOpacity(0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  icon,
                                  size: 16,
                                  color: isSelected ? Colors.white : color,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  label,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color(0xFF1E293B),
                                    fontSize: 13,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(width: 8),
                  const Text(
                    '|',
                    style: TextStyle(
                      color: Color(0xFFE2E8F0),
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(width: 8), ...sortOptions.map((option) {
                  final isSelected =
                      _selectedSort == option['value'] as String;
                  final color = option['color'] as Color;
                  final icon = option['icon'] as IconData;
                  final label = option['label'] as String;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _selectedSort = option['value'] as String;
                          });
                          _applyFiltersAndSort();
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? color : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected ? color : const Color(0xFFE2E8F0),
                              width: isSelected ? 0 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: color.withOpacity(0.4),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                icon,
                                size: 16,
                                color: isSelected ? Colors.white : color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                label,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                ],
            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobList() {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildJobCardSkeleton(),
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
                  padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 20),
                Text(
                  'Terjadi Kesalahan',
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _loadJobs,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Coba Lagi'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_jobs.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Container(
            padding: const EdgeInsets.all(40),
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search_off_rounded,
                    color: Color(0xFF2563EB),
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Tidak Ada Pekerjaan',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tidak ada pekerjaan yang tersedia saat ini.\nCoba filter atau kategori lain.',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= _jobs.length) return null;
          final job = _jobs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildJobCardFromApi(job),
            ),
          );
        }, childCount: _jobs.length),
      ),
    );
  }

  Widget _buildJobCardSkeleton() {
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
              height: 20,
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

  Widget _buildJobCardFromApi(Map<String, dynamic> job) {
    final categoryColor = _getCategoryColorFromString(job['category']);
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailScreen(jobId: job['id'].toString()),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: categoryColor.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: categoryColor.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with category and price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          categoryColor,
                          categoryColor.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: categoryColor.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getCategoryIconFromString(job['category']),
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _getCategoryDisplayName(job['category']),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        _formatPrice(job['price']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Job title
              Text(
                job['title'] ?? 'No Title',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Job description
              Text(
                job['description'] ?? 'No Description',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 18),

              // Location and time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['address'] ?? 'No Address',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (job['distance_km'] != null || (_userPosition != null && job['latitude'] != null && job['longitude'] != null)) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                size: 12,
                                color: const Color(0xFF10B981),
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _formatDistance(job),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.access_time_rounded,
                      size: 16,
                      color: Color(0xFF8B5CF6),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatTimeAgo(job['created_at']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
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

  Color _getCategoryColor(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return const Color(0xFF10B981);
      case JobCategory.maintenance:
        return const Color(0xFF3B82F6);
      case JobCategory.delivery:
        return const Color(0xFF8B5CF6);
      case JobCategory.tutoring:
        return const Color(0xFFF59E0B);
      case JobCategory.photography:
        return const Color(0xFFEF4444);
      case JobCategory.cooking:
        return const Color(0xFFF97316);
      case JobCategory.gardening:
        return const Color(0xFF22C55E);
      case JobCategory.petCare:
        return const Color(0xFF06B6D4);
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
        return Icons.local_shipping_rounded;
      case JobCategory.tutoring:
        return Icons.school_rounded;
      case JobCategory.photography:
        return Icons.camera_alt_rounded;
      case JobCategory.cooking:
        return Icons.restaurant_rounded;
      case JobCategory.gardening:
        return Icons.eco_rounded;
      case JobCategory.petCare:
        return Icons.pets_rounded;
      case JobCategory.other:
        return Icons.work_rounded;
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
        return 'Kebun';
      case JobCategory.petCare:
        return 'Perawatan Hewan';
      case JobCategory.other:
        return 'Lainnya';
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
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// Wave Pattern Painter for decorative background
class WavePatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    var path = Path();
    path.moveTo(0, size.height * 0.4);

    for (var i = 0; i < size.width; i += 60) {
      path.quadraticBezierTo(
        i + 30,
        size.height * 0.25,
        i + 60,
        size.height * 0.4,
      );
    }

    canvas.drawPath(path, paint);

    var path2 = Path();
    path2.moveTo(0, size.height * 0.7);

    for (var i = 0; i < size.width; i += 50) {
      path2.quadraticBezierTo(
        i + 25,
        size.height * 0.85,
        i + 50,
        size.height * 0.7,
      );
    }

    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
