import 'package:flutter/material.dart';
import 'worker_detail_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../widgets/profile_avatar.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  String _selectedCategory = 'all';
  String _selectedAreaMode = 'global'; // 'global' or 'local'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final int _itemsPerPage = 10;
  int _currentPage = 1;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Animation<Offset>? _slideAnimation;
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _allLeaderboardData = [];
  List<Map<String, dynamic>> _filteredLeaderboardData = [];
  List<Map<String, dynamic>> _leaderboardData = [];
  bool _isLoading = true;
  String? _error;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
    _initializeAndLoadData();
  }

  void _applySearchAndPagination() {
    _filteredLeaderboardData = _allLeaderboardData.where((worker) {
      if (_searchQuery.isEmpty) return true;
      final name = (worker['name'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    final totalPages = _getTotalPages();
    if (_currentPage > totalPages) {
      _currentPage = totalPages;
    }
    if (_currentPage < 1) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    _leaderboardData = _filteredLeaderboardData
        .skip(startIndex)
        .take(_itemsPerPage)
        .toList();
  }

  int _getTotalPages() {
    if (_filteredLeaderboardData.isEmpty) {
      return 1;
    }
    return (_filteredLeaderboardData.length / _itemsPerPage).ceil();
  }

  Widget _buildWorkerCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
      ),
    );
  }

  Future<void> _initializeAndLoadData() async {
    await _apiService.loadToken();
    // Get user location if area mode is local
    if (_selectedAreaMode == 'local') {
      await _getUserLocation();
    }
    _loadLeaderboardData();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location service is disabled, try to use saved location from user profile
        await _loadUserLocationFromProfile();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission denied, try to use saved location from user profile
          await _loadUserLocationFromProfile();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permission denied forever, try to use saved location from user profile
        await _loadUserLocationFromProfile();
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _userPosition = position;
      });
    } catch (e) {
      print('Error getting location: $e');
      // Try to use saved location from user profile
      await _loadUserLocationFromProfile();
    }
  }

  Future<void> _loadUserLocationFromProfile() async {
    try {
      await _apiService.loadToken();
      if (_apiService.token != null) {
        final userResponse = await _apiService.getUser();
        if (userResponse['success']) {
          final userData = userResponse['data'];
          final lat = userData['current_latitude'];
          final lng = userData['current_longitude'];
          
          if (lat != null && lng != null) {
            double? latitude;
            double? longitude;
            
            if (lat is double) {
              latitude = lat;
            } else if (lat is String) {
              latitude = double.tryParse(lat);
            }
            
            if (lng is double) {
              longitude = lng;
            } else if (lng is String) {
              longitude = double.tryParse(lng);
            }
            
            if (latitude != null && longitude != null) {
              setState(() {
                _userPosition = Position(
                  latitude: latitude!,
                  longitude: longitude!,
                  timestamp: DateTime.now(),
                  accuracy: 0,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                );
              });
            }
          }
        }
      }
    } catch (e) {
      print('Error loading location from profile: $e');
    }
  }

  Future<void> _loadLeaderboardData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get location if area mode is local and position is not available
      if (_selectedAreaMode == 'local' && _userPosition == null) {
        await _getUserLocation();
      }

      // Prepare API call parameters
      double? latitude;
      double? longitude;
      double? radius;

      if (_selectedAreaMode == 'local') {
        if (_userPosition != null) {
          latitude = _userPosition!.latitude;
          longitude = _userPosition!.longitude;
          radius = 20.0; // 20 km radius
        } else {
          // If no location available, show error
          setState(() {
            _error = 'Lokasi tidak tersedia. Pastikan izin lokasi diaktifkan atau gunakan mode Global.';
            _isLoading = false;
          });
          return;
        }
      }

      print('Loading leaderboard: mode=$_selectedAreaMode, category=$_selectedCategory, lat=$latitude, lng=$longitude, radius=$radius');

      final response = await _apiService.getLeaderboard(
        category: _selectedCategory,
        limit: 20,
        latitude: latitude,
        longitude: longitude,
        radius: radius,
      );

      print('Leaderboard response: ${response['success']}, data count: ${response['data'] is List ? (response['data'] as List).length : 'N/A'}');
      
      if (response['data'] is List) {
        print('Leaderboard data (List): ${(response['data'] as List).length} items');
        for (var item in (response['data'] as List)) {
          print('  - User ID: ${item['id']}, Name: ${item['name']}, Distance: ${item['distance']}');
        }
      } else if (response['data'] is Map && (response['data'] as Map).containsKey('data')) {
        final listData = (response['data'] as Map)['data'];
        if (listData is List) {
          print('Leaderboard data (Map with data key): ${listData.length} items');
          for (var item in listData) {
            print('  - User ID: ${item['id']}, Name: ${item['name']}, Distance: ${item['distance']}');
          }
        }
      }

      if (response['success']) {
        final data = response['data'];
        List<Map<String, dynamic>> leaderboardList = [];

        if (data is Map && data.containsKey('data')) {
          final listData = data['data'];
          if (listData is List) {
            leaderboardList = List<Map<String, dynamic>>.from(listData);
          }
        } else if (data is List) {
          leaderboardList = List<Map<String, dynamic>>.from(data);
        }

        leaderboardList.sort((a, b) {
          final pointsA = a['total_points'] ?? 0;
          final pointsB = b['total_points'] ?? 0;
          return pointsB.compareTo(pointsA);
        });

        for (var i = 0; i < leaderboardList.length; i++) {
          leaderboardList[i] = {
            ...leaderboardList[i],
            'global_rank': i + 1,
          };
        }

        setState(() {
          _allLeaderboardData = leaderboardList;
          _currentPage = 1;
          _applySearchAndPagination();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load leaderboard';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error loading leaderboard: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh location if in local mode
          if (_selectedAreaMode == 'local') {
            await _getUserLocation();
          }
          await _loadLeaderboardData();
        },
        child: CustomScrollView(
          slivers: [
            // Modern App Bar (keep as is)
            _buildSliverAppBar(),
            // Area Mode Tab
            _buildAreaModeTab(),
            // Search Bar
            _buildSearchBar(),
            // Filter Chips
            _buildFilterChips(),
            // Leaderboard List
            _buildLeaderboardList(),
            // Pagination
            _buildPaginationControls(),
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
        title: Text(
          '',
          style: TextStyle(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
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
                              Icons.emoji_events_rounded,
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
                                  'Peringkat Pekerja',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Peringkat berdasarkan poin dari pekerjaan & SOS.',
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

  Widget _buildAreaModeTab() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mode Peringkat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        setState(() {
                          _selectedAreaMode = 'global';
                          _userPosition = null; // Clear location for global mode
                        });
                        await _loadLeaderboardData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: _selectedAreaMode == 'global'
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF3B82F6),
                                  ],
                                )
                              : null,
                          color: _selectedAreaMode == 'global'
                              ? null
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _selectedAreaMode == 'global'
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.public_rounded,
                              color: _selectedAreaMode == 'global'
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Global',
                              style: TextStyle(
                                color: _selectedAreaMode == 'global'
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                fontWeight: _selectedAreaMode == 'global'
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        setState(() {
                          _selectedAreaMode = 'local';
                          _isLoading = true; // Show loading immediately
                        });
                        // Get location first, then load data
                        await _getUserLocation();
                        await _loadLeaderboardData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: _selectedAreaMode == 'local'
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF10B981),
                                    Color(0xFF059669),
                                  ],
                                )
                              : null,
                          color: _selectedAreaMode == 'local'
                              ? null
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _selectedAreaMode == 'local'
                              ? [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: _selectedAreaMode == 'local'
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Area Sekitar',
                              style: TextStyle(
                                color: _selectedAreaMode == 'local'
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                fontWeight: _selectedAreaMode == 'local'
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
              _currentPage = 1;
              _applySearchAndPagination();
            });
          },
          decoration: InputDecoration(
            hintText: 'Cari pekerja berdasarkan nama...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      setState(() {
                        _searchController.clear();
                        _searchQuery = '';
                        _currentPage = 1;
                        _applySearchAndPagination();
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final categories = [
      {
        'value': 'all',
        'label': 'Semua',
        'icon': Icons.apps_rounded,
        'color': const Color(0xFF2563EB),
      },
      {
        'value': 'cleaning',
        'label': 'Pembersihan',
        'icon': Icons.cleaning_services_rounded,
        'color': const Color(0xFF10B981),
      },
      {
        'value': 'maintenance',
        'label': 'Perbaikan',
        'icon': Icons.build_rounded,
        'color': const Color(0xFF3B82F6),
      },
      {
        'value': 'delivery',
        'label': 'Pengiriman',
        'icon': Icons.local_shipping_rounded,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'value': 'tutoring',
        'label': 'Edukasi',
        'icon': Icons.school_rounded,
        'color': const Color(0xFFF59E0B),
      },
      {
        'value': 'photography',
        'label': 'Fotografi',
        'icon': Icons.camera_alt_rounded,
        'color': const Color(0xFFEF4444),
      },
      {
        'value': 'cooking',
        'label': 'Kuliner',
        'icon': Icons.restaurant_rounded,
        'color': const Color(0xFFF97316),
      },
      {
        'value': 'gardening',
        'label': 'Taman',
        'icon': Icons.eco_rounded,
        'color': const Color(0xFF22C55E),
      },
      {
        'value': 'petCare',
        'label': 'Perawatan Hewan',
        'icon': Icons.pets_rounded,
        'color': const Color(0xFF06B6D4),
      },
      {
        'value': 'other',
        'label': 'Lainnya',
        'icon': Icons.work_rounded,
        'color': const Color(0xFF6B7280),
      },
    ];

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter berdasarkan Kategori',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((category) {
                  final isSelected = _selectedCategory == category['value'];
                  final color = category['color'] as Color;
                  final label = category['label'] as String;
                  final icon = category['icon'] as IconData;

                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: GestureDetector(
                      onTap: () async {
                        setState(() {
                          _selectedCategory = category['value'] as String;
                        });
                        await _loadLeaderboardData();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                                  colors: [color, color.withOpacity(0.8)],
                                )
                              : null,
                          color: isSelected ? null : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? color.withOpacity(0.3)
                                : const Color(0xFFE2E8F0),
                            width: isSelected ? 1.5 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
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
                              color: isSelected ? Colors.white : color,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              label,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w600,
                                fontSize: 13,
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
          ],
        ),
      ),
    );
  }

  Widget _buildLeaderboardList() {
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildWorkerCardSkeleton(),
            ),
            childCount: 5,
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline,
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
                onPressed: _loadLeaderboardData,
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
      );
    }

    if (_leaderboardData.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(48),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.emoji_events_outlined,
                  color: Color(0xFF94A3B8),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Belum ada data',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= _leaderboardData.length) return null;
          final worker = _leaderboardData[index];
          final globalRank =
              (worker['global_rank'] as int?) ??
              ((_currentPage - 1) * _itemsPerPage) + index + 1;
          return InkWell(
            onTap: () {
              // Allow viewing own profile - button will be hidden in detail screen
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkerDetailScreen(
                    workerId: worker['id']?.toString() ?? '',
                    initialWorkerData: worker,
                    rankColor: _getRankColor(globalRank),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _slideAnimation != null
                  ? SlideTransition(
                      position: _slideAnimation!,
                      child: _buildWorkerCard(worker, globalRank),
                    )
                  : _buildWorkerCard(worker, globalRank),
            ),
          );
        }, childCount: _leaderboardData.length),
      ),
    );
  }

  Widget _buildPaginationControls() {
    final totalPages = _getTotalPages();
    if (totalPages <= 1) {
      return const SliverToBoxAdapter(child: SizedBox(height: 24));
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _currentPage > 1
                  ? () {
                      setState(() {
                        _currentPage--;
                        _applySearchAndPagination();
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.white,
                minimumSize: const Size(48, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.chevron_left_rounded),
            ),
            const SizedBox(width: 16),
            Text(
              'Halaman $_currentPage dari $totalPages',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: _currentPage < totalPages
                  ? () {
                      setState(() {
                        _currentPage++;
                        _applySearchAndPagination();
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                disabledForegroundColor: Colors.white,
                minimumSize: const Size(48, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker, int rank) {
    final isTopThree = rank <= 3;
    final rankColor = _getRankColor(rank);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [rankColor.withOpacity(0.9), rankColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: rankColor.withOpacity(0.45),
            blurRadius: 25,
            spreadRadius: -5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isTopThree
                    ? rankColor.withOpacity(0.6)
                    : rankColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isTopThree
                      ? rankColor.withOpacity(0.8)
                      : rankColor.withOpacity(0.7),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isTopThree
                        ? rankColor.withOpacity(0.4)
                        : Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    shadows: [
                      Shadow(
                        blurRadius: 6,
                        color: Colors.black38,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Avatar
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withOpacity(0.4),
                    Colors.white.withOpacity(0.25),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: ProfileAvatar(
                profileImagePath: worker['profile_image'],
                radius: 28,
                name: worker['name'],
                backgroundColor: Colors.white.withOpacity(0.35),
                iconColor: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            // Worker Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          worker['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                            letterSpacing: -0.3,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black38,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTopThree) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.emoji_events_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Points display - most prominent
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${worker['total_points'] ?? 0} poin',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black38,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: Colors.white,
                            size: 14,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black38,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatRating(worker['rating'] ?? 0.0),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black38,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.work_rounded,
                            color: Colors.white,
                            size: 14,
                            shadows: const [
                              Shadow(
                                blurRadius: 4,
                                color: Colors.black38,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              _selectedCategory == 'all' 
                                ? '${worker['completed_jobs'] ?? 0}'
                                : '${worker['category_jobs_count'] ?? 0}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(
                                    blurRadius: 4,
                                    color: Colors.black38,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if ((worker['completed_sos'] ?? 0) > 0 || (worker['helped_sos'] ?? 0) > 0)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.emergency_rounded,
                              color: Colors.white,
                              size: 14,
                              shadows: const [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black38,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '${(worker['completed_sos'] ?? 0) + (worker['helped_sos'] ?? 0)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      // Show distance if available (Area Sekitar mode)
                      if (_selectedAreaMode == 'local' && worker['distance'] != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.near_me_rounded,
                              color: Colors.white,
                              size: 14,
                              shadows: const [
                                Shadow(
                                  blurRadius: 4,
                                  color: Colors.black38,
                                  offset: Offset(0, 1),
                                ),
                              ],
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _formatDistance(worker['distance']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 4,
                                      color: Colors.black38,
                                      offset: Offset(0, 1),
                                    ),
                                  ],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFF2C94C); // Emas
      case 2:
        return const Color(0xFFBDBDBD); // Perak
      case 3:
        return const Color(0xFFCD7F32); // Perunggu
      default:
        return const Color(0xFF2563EB); // Biru
    }
  }

  String _formatRating(dynamic rating) {
    if (rating is double) {
      return rating.toStringAsFixed(1);
    } else if (rating is int) {
      return rating.toDouble().toStringAsFixed(1);
    } else if (rating is String) {
      final parsed = double.tryParse(rating);
      return parsed?.toStringAsFixed(1) ?? '0.0';
    }
    return '0.0';
  }

  String _formatDistance(dynamic distance) {
    if (distance == null) return '';
    
    double? dist;
    if (distance is double) {
      dist = distance;
    } else if (distance is int) {
      dist = distance.toDouble();
    } else if (distance is String) {
      dist = double.tryParse(distance);
    }
    
    if (dist == null) return '';
    
    if (dist < 1.0) {
      return '${(dist * 1000).toStringAsFixed(0)}m';
    } else {
      return '${dist.toStringAsFixed(1)}km';
    }
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
