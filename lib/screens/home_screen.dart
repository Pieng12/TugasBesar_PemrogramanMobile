import 'package:flutter/material.dart';
import '../models/job_model.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import 'create_job_screen.dart';
import 'job_list_screen.dart';
import 'job_detail_screen.dart';
import 'sos_screen.dart';
import 'profile_screen.dart';
import 'my_orders_screen.dart';
import 'auth_screen.dart';
import 'notifications_screen.dart';
import 'leaderboard_screen.dart';
import 'package:geolocator/geolocator.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;

  List<Widget> get _screens => [
    const HomeContentScreen(),
    const MyOrdersScreen(),
    const LeaderboardScreen(),
    const SOSScreen(),
    ProfileScreen(
      key: ValueKey(DateTime.now().millisecondsSinceEpoch),
    ), // Always fresh
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
              // Force refresh when switching to profile tab
              if (index == 4) {
                // Profile tab selected, force refresh
                Future.delayed(const Duration(milliseconds: 100), () {
                  setState(() {
                    // This will recreate the ProfileScreen
                  });
                });
              }
            },
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: const Color(
              0xFF2D9CDB,
            ), // Biru Cerah untuk Brand
            unselectedItemColor: const Color(0xFFBDBDBD), // Abu-abu terang
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 24),
                activeIcon: Icon(Icons.home_rounded, size: 26),
                label: 'Beranda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.work_outline_rounded, size: 24),
                activeIcon: Icon(Icons.work_rounded, size: 26),
                label: 'Pesanan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emoji_events_outlined, size: 24),
                activeIcon: Icon(Icons.emoji_events_rounded, size: 26),
                label: 'Ranking',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.emergency_outlined, size: 24),
                activeIcon: Icon(Icons.emergency_rounded, size: 26),
                label: 'SOS',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline_rounded, size: 24),
                activeIcon: Icon(Icons.person_rounded, size: 26),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeContentScreen extends StatefulWidget {
  const HomeContentScreen({super.key});

  @override
  State<HomeContentScreen> createState() => _HomeContentScreenState();
}

class _HomeContentScreenState extends State<HomeContentScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _recentJobs = [];
  List<Map<String, dynamic>> _leaderboardPreview = [];
  Map<String, dynamic>? _userStats;
  Map<String, dynamic>? _userRanking;
  bool _isLoading = true;
  String? _error;
  Position? _userPosition;

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

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );
    _animationController.forward();
    _loadHomeData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check authentication first
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    await _apiService.loadToken();
    if (_apiService.token == null) {
      // No token, redirect to login
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
      return;
    }
    // User is authenticated, load data
    _loadHomeData();
  }

  Future<void> _getUserLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog to enable location services
        if (mounted) {
          _showLocationPermissionDialog(
            'Layanan Lokasi Tidak Aktif',
            'Aktifkan layanan lokasi di pengaturan untuk melihat permintaan di sekitar Anda.',
          );
        }
        // Try to get location from user data as fallback
        await _getLocationFromUserData();
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission with explanation
        if (mounted) {
          final shouldRequest = await _showLocationPermissionDialog(
            'Izin Lokasi Diperlukan',
            'Aplikasi memerlukan izin lokasi untuk menampilkan permintaan pekerjaan di sekitar Anda (radius 10 km).',
            showCancel: true,
          );
          if (!shouldRequest) {
            await _getLocationFromUserData();
            return;
          }
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            _showLocationPermissionDialog(
              'Izin Lokasi Ditolak',
              'Tanpa izin lokasi, Anda tidak dapat melihat permintaan di sekitar Anda. Anda dapat mengaktifkannya nanti di pengaturan.',
            );
          }
          await _getLocationFromUserData();
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationPermissionDialog(
            'Izin Lokasi Ditolak Permanen',
            'Izin lokasi telah ditolak permanen. Aktifkan di pengaturan perangkat untuk melihat permintaan di sekitar Anda.',
          );
        }
        await _getLocationFromUserData();
        return;
      }

      // Get current position
      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      print('Error getting location: $e');
      // Try to get location from user data if available
      await _getLocationFromUserData();
    }
  }

  Future<void> _getLocationFromUserData() async {
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

  Future<bool> _showLocationPermissionDialog(String title, String message, {bool showCancel = false}) async {
    if (!mounted) return false;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF2563EB),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Text(
          message,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          if (showCancel)
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                'Nanti',
                style: TextStyle(color: Color(0xFF64748B)),
              ),
            ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(showCancel ? 'Izinkan' : 'Mengerti'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  Future<void> _loadHomeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      // Get user location first
      await _getUserLocation();

      // Load nearby jobs within 10 km radius
      List<Map<String, dynamic>> nearbyJobs = [];
      
      if (_userPosition != null) {
        // Use nearby jobs API with 10 km radius
        final jobsResponse = await _apiService.getJobs(
          latitude: _userPosition!.latitude,
          longitude: _userPosition!.longitude,
          radius: 10.0, // 10 km
        );
        
        if (jobsResponse['success']) {
          // Handle paginated response
          final data = jobsResponse['data'];
          if (data is Map && data.containsKey('data')) {
            nearbyJobs = List<Map<String, dynamic>>.from(data['data']);
          } else if (data is List) {
            nearbyJobs = List<Map<String, dynamic>>.from(data);
          }
        }
      } else {
        // Fallback: load all jobs if location not available
        final jobsResponse = await _apiService.getJobs();
        if (jobsResponse['success']) {
          final data = jobsResponse['data'];
          if (data is Map && data.containsKey('data')) {
            nearbyJobs = List<Map<String, dynamic>>.from(data['data']);
          } else if (data is List) {
            nearbyJobs = List<Map<String, dynamic>>.from(data);
          }
        }
      }

      // Filter jobs: only pending status, not cancelled, and no assigned worker
      // (Backend already filters, but we do double-check here for safety)
      nearbyJobs = nearbyJobs.where((job) {
        final status = job['status']?.toString().toLowerCase() ?? '';
        final assignedWorkerId = job['assigned_worker_id'];
        final isPrivateOrder = job['additional_info'] is Map && 
                              job['additional_info']['is_private_order'] == true;
        
        // Only show jobs that are:
        // 1. Status is 'pending' (menunggu/terbuka)
        // 2. Not cancelled
        // 3. No assigned worker (belum ada yang menerima)
        // 4. Not a private order
        return status == 'pending' && 
               status != 'cancelled' && 
               assignedWorkerId == null && 
               !isPrivateOrder;
      }).toList();

      // Calculate and add distance for each job
      if (_userPosition != null) {
        for (var job in nearbyJobs) {
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

        // Sort by distance (nearest first)
        nearbyJobs.sort((a, b) {
          final distA = a['distance_km'] ?? double.infinity;
          final distB = b['distance_km'] ?? double.infinity;
          return distA.compareTo(distB);
        });
      }

      setState(() {
        _recentJobs = nearbyJobs;
      });

      // Load leaderboard preview
      final leaderboardResponse = await _apiService.getLeaderboard(limit: 3);
      if (leaderboardResponse['success']) {
        // Handle paginated response
        final data = leaderboardResponse['data'];
        if (data is Map && data.containsKey('data')) {
          setState(() {
            _leaderboardPreview = List<Map<String, dynamic>>.from(data['data']);
          });
        } else if (data is List) {
          setState(() {
            _leaderboardPreview = List<Map<String, dynamic>>.from(data);
          });
        }
      }

      // Load user stats if logged in
      if (_apiService.token != null) {
        try {
          final userResponse = await _apiService.getUser();
          if (userResponse['success']) {
            final userData = userResponse['data'];
            setState(() {
              _userStats = userData;
            });
            
            // Load user ranking
            final userId = userData['id']?.toString();
            if (userId != null) {
              try {
                final rankingResponse = await _apiService.getUserRanking(userId);
                if (rankingResponse['success']) {
                  setState(() {
                    _userRanking = rankingResponse['data'];
                  });
                }
              } catch (e) {
                print('Error loading user ranking: $e');
              }
            }
          }
        } catch (e) {
          // User not logged in or error, continue without user stats
        }
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: ${e.toString()}';
        _isLoading = false;
      });
    }
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

  Color _getCategoryColor(String? category) {
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

  IconData _getCategoryIcon(String? category) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        color: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
        child: CustomScrollView(
          slivers: [
            // Modern App Bar
            _buildSliverAppBar(),
            // Welcome Section
            _buildWelcomeSection(),
            // Quick Actions
            _buildQuickActions(),
            // Service Categories
            _buildServiceCategories(),
            // Stats Overview
            _buildStatsOverview(),
            // Your Rank
            _buildYourRankCard(),
            // Leaderboard Preview
            _buildLeaderboardPreview(),
            // Recent Jobs
            _buildRecentJobs(),
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(_animationController),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Header with Logo and Notifications
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // App Logo and Name
                          Row(
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Transform.scale(
                                  scale: 2, 
                                  child: Image.asset(
                                    'assets/logo/Servify-nobg.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                   Text(
                                    'Servify',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                  ),
                                  Text(
                                    'Find Help, Get Things Done',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Notifications
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NotificationsScreen(),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  const Icon(
                                    Icons.notifications_outlined,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Search Bar (moved up slightly due to padding change)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const JobListScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.search_rounded,
                                color: Colors.white.withOpacity(0.8),
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cari layanan yang Anda butuhkan...',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.8),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: Colors.white.withOpacity(0.8),
                                  size: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    final userName = _userStats?['name'] ?? 'Pengguna';
    final greeting = _getGreeting();
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  userName.length > 25 ? '${userName.substring(0, 25)}...' : userName,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Selamat Pagi';
    if (hour < 17) return 'Selamat Siang';
    if (hour < 20) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  IconData _getGreetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_twilight_rounded;
    if (hour < 20) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round;
  }

  Widget _buildQuickActions() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      'Buat Pesanan',
                      Icons.add_circle_rounded,
                      const Color(0xFF10B981),
                      'Buat pesanan layanan baru',
                      () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CreateJobScreen(),
                          ),
                        );
                        if (result == true) {
                          _loadHomeData();
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildActionCard(
                      'Cari Pekerjaan',
                      Icons.search_rounded,
                      const Color(0xFF2563EB),
                      'Temukan pekerjaan terdekat',
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const JobListScreen(),
                          ),
                        );
                      },
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

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      color,
                      color.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: TextStyle(
                  color: const Color(0xFF1E293B),
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCategories() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Kategori Layanan',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JobListScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF2563EB),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 1),
            FadeTransition(
              opacity: _fadeAnimation,
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
                children: [
                  _buildCategoryCard(
                    'Pembersihan',
                    Icons.cleaning_services_rounded,
                    const Color(0xFF10B981),
                    'cleaning',
                  ),
                  _buildCategoryCard(
                    'Perbaikan',
                    Icons.build_rounded,
                    const Color(0xFFF59E0B),
                    'maintenance',
                  ),
                  _buildCategoryCard(
                    'Pengiriman',
                    Icons.delivery_dining_rounded,
                    const Color(0xFF2563EB),
                    'delivery',
                  ),
                  _buildCategoryCard(
                    'Edukasi',
                    Icons.school_rounded,
                    const Color(0xFF8B5CF6),
                    'tutoring',
                  ),
                  _buildCategoryCard(
                    'Fotografi',
                    Icons.camera_alt_rounded,
                    const Color(0xFFEF4444),
                    'photography',
                  ),
                  _buildCategoryCard(
                    'Kuliner',
                    Icons.restaurant_rounded,
                    const Color(0xFFEC4899),
                    'cooking',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    String title,
    IconData icon,
    Color color,
    String categoryValue,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to job list with category filter
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobListScreen(
                initialCategory: categoryValue,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsOverview() {
    final completedJobs = _userStats?['completed_jobs'] ?? 0;
    final totalEarnings = _userStats?['total_earnings'] ?? 0;
    final ratingValue = _userStats?['rating'];
    
    // Handle rating - bisa String atau double
    double rating = 0.0;
    if (ratingValue != null) {
      if (ratingValue is double) {
        rating = ratingValue;
      } else if (ratingValue is int) {
        rating = ratingValue.toDouble();
      } else if (ratingValue is String) {
        rating = double.tryParse(ratingValue) ?? 0.0;
      }
    }
    
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2563EB),
                  Color(0xFF3B82F6),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.bar_chart_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Statistik Anda',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(
                      completedJobs.toString(),
                      'Pesanan Selesai',
                      Icons.check_circle_outline_rounded,
                    ),
                    _buildStatItem(
                      'Rp ${_formatCurrency(totalEarnings)}',
                      'Total Pendapatan',
                      Icons.account_balance_wallet_rounded,
                    ),
                    _buildStatItem(
                      rating.toStringAsFixed(1),
                      'Rating',
                      Icons.star_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}J';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    }
    return amount.toString();
  }

  Widget _buildStatItem(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white.withOpacity(0.9),
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildYourRankCard() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF2C94C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFFF2C94C).withOpacity(0.5),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2C94C),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.shield_moon_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Peringkat Anda',
                        style: TextStyle(
                          color: const Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Naikkan peringkatmu dan dapatkan lebih banyak pesanan!',
                        style: TextStyle(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _userRanking != null && _userRanking!['rank'] != null
                      ? '#${_userRanking!['rank']}'
                      : '-',
                  style: TextStyle(
                    color: const Color(0xFFF2994A),
                    fontWeight: FontWeight.bold,
                    fontSize: 24,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardPreview() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Leaderboard Pekerja',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LeaderboardScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF2563EB),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
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
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events_rounded,
                          color: const Color(0xFF6366F1),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Top 3 Pekerja Terbaik',
                          style: TextStyle(
                            color: const Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _isLoading
                        ? Column(
                            children: List.generate(
                              3,
                              (i) => Padding(
                                padding: EdgeInsets.only(bottom: i == 2 ? 0 : 12),
                                child: _buildLeaderboardPreviewSkeleton(),
                              ),
                            ),
                          )
                        : _leaderboardPreview.isEmpty
                        ? const Text(
                            'Tidak ada data leaderboard',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                            textAlign: TextAlign.center,
                          )
                        : Column(
                            children: _leaderboardPreview.asMap().entries.map((
                              entry,
                            ) {
                              final index = entry.key;
                              final worker = entry.value;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _buildTopWorker(
                                  worker['name'] ?? 'Unknown',
                                  'User', // Simplified - all users can work
                                  index + 1,
                                  worker['points'] ?? 0,),
                              );
                            }).toList(),
                          ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopWorker(String name, String category, int rank, int points) {
    final rankColor = _getRankColor(rank);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: rankColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rankColor.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rankColor,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Text(
                '$rank',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  category,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildLeaderboardPreviewSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
      ),
    );
  }

  BoxDecoration _skeletonBox() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      );

  Widget _buildRecentJobs() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Permintaan Sekitar Anda',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontWeight: FontWeight.bold,
                    fontSize: 19,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JobListScreen(),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Lihat Semua',
                        style: TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF2563EB),
                        size: 12,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FadeTransition(
              opacity: _fadeAnimation,
              child: _isLoading
                  ? Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      enabled: true,
                      child: Column(
                        children: [
                          _buildNearbyRequestCard(
                            '',
                            'Loading...',
                            'Loading job description...',
                            'Rp 0',
                            '0 km',
                            '0.0',
                            'Loading...',
                            const Color(0xFF10B981),
                            Icons.cleaning_services_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildNearbyRequestCard(
                            '',
                            'Loading...',
                            'Loading job description...',
                            'Rp 0',
                            '0 km',
                            '0.0',
                            'Loading...',
                            const Color(0xFF3B82F6),
                            Icons.build_rounded,
                          ),
                        ],
                      ),
                    )
                  : _error != null
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error!,
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadHomeData,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  : _recentJobs.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(20),
                      child: const Text(
                        'Tidak ada pekerjaan tersedia',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : Column(
                      children: _recentJobs.take(3).map((job) {
                        // Format distance
                        String distanceText = 'Jarak tidak diketahui';
                        if (job['distance_km'] != null) {
                          final distance = job['distance_km'] is double 
                              ? job['distance_km'] 
                              : double.tryParse(job['distance_km'].toString());
                          if (distance != null && distance.isFinite) {
                            if (distance < 1) {
                              distanceText = '${(distance * 1000).toStringAsFixed(0)} m';
                            } else {
                              distanceText = '${distance.toStringAsFixed(1)} km';
                            }
                          }
                        } else if (_userPosition != null && job['latitude'] != null && job['longitude'] != null) {
                          // Calculate distance if not already calculated
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
                              distanceText = '${(distance * 1000).toStringAsFixed(0)} m';
                            } else {
                              distanceText = '${distance.toStringAsFixed(1)} km';
                            }
                          }
                        }
                        
                        // Get customer rating
                        String ratingText = '0.0';
                        final customer = job['customer'];
                        if (customer != null && customer['rating'] != null) {
                          final rating = customer['rating'];
                          if (rating is double) {
                            ratingText = rating.toStringAsFixed(1);
                          } else if (rating is int) {
                            ratingText = rating.toDouble().toStringAsFixed(1);
                          } else if (rating is String) {
                            ratingText = double.tryParse(rating)?.toStringAsFixed(1) ?? '0.0';
                          }
                        }
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildNearbyRequestCard(
                            job['id']?.toString() ?? '',
                            job['title'] ?? 'No Title',
                            job['description'] ?? 'No Description',
                            'Rp ${(job['price'] is String ? double.parse(job['price']) : (job['price'] as num)).toStringAsFixed(0)}',
                            distanceText,
                            ratingText,
                            _formatTimeAgo(job['created_at']),
                            _getCategoryColor(job['category']),
                            _getCategoryIcon(job['category']),
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

  Widget _buildNearbyRequestCard(
    String jobId,
    String title,
    String description,
    String price,
    String distance,
    String rating,
    String time,
    Color color,
    IconData icon,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // Navigate to job detail screen when card is tapped
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => JobDetailScreen(jobId: jobId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: color.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          color,
                          color.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            letterSpacing: -0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: const Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                distance,
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(
                              Icons.star_rounded,
                              size: 13,
                              color: Colors.amber[600],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              rating,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      price,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Description
              Text(
                description,
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 13,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => JobDetailScreen(jobId: jobId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 14),
                    label: const Text(
                      'Ajukan',
                      style: TextStyle(
                        fontSize: 13,
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


  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFF2C94C); // Kuning / Emas untuk Badge
      case 2:
        return const Color(0xFFBDBDBD); // Abu-abu terang
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF2563EB);
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
