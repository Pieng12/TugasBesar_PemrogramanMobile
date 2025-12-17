import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shimmer/shimmer.dart';
import '../services/api_service.dart';
import 'sos_detail_screen.dart';

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> with TickerProviderStateMixin {
  bool _isEmergencyActive = false;
  late AnimationController _pulseController;
  late AnimationController _shakeController;
  late AnimationController _contentAnimationController;
  late AnimationController _countdownController;
  late TabController _tabController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _recentSOSRequests = [];
  List<Map<String, dynamic>> _completedSOSRequests = [];
  bool _isLoading = true;
  bool _isLoadingCompleted = false;
  String? _error;
  String? _currentUserId;
  int _selectedTab = 0; // 0 = Aktif, 1 = Riwayat
  Position? _userPosition;

  // Long press and countdown state
  bool _isHolding = false;
  int _countdown = 3;
  Timer? _holdTimer;
  Timer? _countdownTimer;
  Timer? _confirmationTimer;
  bool _showCountdown = false;
  bool _showConfirmation = false;
  int _confirmationSecondsLeft = 5;
  String? _activeSosId; // Store active SOS ID

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _contentAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _contentAnimationController,
        curve: Curves.easeIn,
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _contentAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _shakeAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _countdownController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );

    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index;
        });
        if (_tabController.index == 1) {
          _loadCompletedSOSData(forceReload: false);
        }
      }
    });

    _startContentAnimation();
    _loadCurrentUser();
    _getUserLocation();
    _loadSOSData();
    _checkActiveSOS();
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
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) /
        1000; // Convert to km
  }

  String _formatDistance(double? distance) {
    if (distance == null || !distance.isFinite) return 'Jarak tidak diketahui';
    if (distance < 1) {
      return '${(distance * 1000).toStringAsFixed(0)} m';
    } else {
      return '${distance.toStringAsFixed(1)} km';
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      await _apiService.loadToken();
      if (_apiService.token != null) {
        final userResponse = await _apiService.getUser();
        if (userResponse['success']) {
          setState(() {
            _currentUserId = userResponse['data']['id']?.toString();
          });
        }
      }
    } catch (e) {
      // Ignore
    }
  }

  Future<void> _checkActiveSOS() async {
    try {
      await _apiService.loadToken();
      if (_apiService.token == null) return;

      // Get current user ID
      final userResponse = await _apiService.getUser();
      if (!userResponse['success']) return;

      final userId = userResponse['data']['id']?.toString();
      if (userId == null) return;

      // Check active SOS from database
      final response = await _apiService.getSosRequests(status: 'active');

      if (response['success']) {
        final dynamic data = response['data'];
        List<Map<String, dynamic>> sosData = [];

        if (data is Map && data.containsKey('data')) {
          sosData = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          sosData = List<Map<String, dynamic>>.from(data);
        }

        // Check if user has active SOS (hanya active, tidak completed atau cancelled)
        bool foundActive = false;
        for (var sos in sosData) {
          final requesterId = sos['requester_id']?.toString();
          final status = sos['status']?.toString() ?? 'active';

          // Only consider active SOS as active (tidak ada status inProgress lagi)
          if (requesterId == userId && status == 'active') {
            setState(() {
              _activeSosId = sos['id']?.toString();
              _isEmergencyActive = true;
            });
            _pulseController.repeat(reverse: true);
            foundActive = true;
            break;
          }
        }

        // If no active SOS found, set to false
        if (!foundActive) {
          setState(() {
            _isEmergencyActive = false;
            _activeSosId = null;
          });
          _pulseController.stop();
          _pulseController.reset();
        }
      }
    } catch (e) {
      print('Error checking active SOS: $e');
      // Set to false on error
      setState(() {
        _isEmergencyActive = false;
        _activeSosId = null;
      });
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  Future<void> _loadSOSData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      // Load all active SOS requests from database
      final response = await _apiService.getSosRequests(status: 'active');

      if (response['success']) {
        final dynamic data = response['data'];
        List<Map<String, dynamic>> sosData = [];

        // Handle paginated or direct list response
        if (data is Map && data.containsKey('data')) {
          sosData = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          sosData = List<Map<String, dynamic>>.from(data);
        }

        // Calculate distance for each SOS if user position is available
        if (_userPosition != null) {
          for (var sos in sosData) {
            if (sos['latitude'] != null && sos['longitude'] != null) {
              final sosLat = sos['latitude'] is double
                  ? sos['latitude']
                  : double.tryParse(sos['latitude'].toString());
              final sosLng = sos['longitude'] is double
                  ? sos['longitude']
                  : double.tryParse(sos['longitude'].toString());
              if (sosLat != null && sosLng != null) {
                final distance = _calculateDistance(
                  _userPosition!.latitude,
                  _userPosition!.longitude,
                  sosLat,
                  sosLng,
                );
                sos['distance_km'] = distance;
              }
            }
          }
        }

        // Sort by distance if available, otherwise by created_at (newest first)
        sosData.sort((a, b) {
          if (_userPosition != null &&
              a['distance_km'] != null &&
              b['distance_km'] != null) {
            final distA = a['distance_km'] is double
                ? a['distance_km']
                : double.tryParse(a['distance_km'].toString()) ??
                      double.infinity;
            final distB = b['distance_km'] is double
                ? b['distance_km']
                : double.tryParse(b['distance_km'].toString()) ??
                      double.infinity;
            return distA.compareTo(distB);
          }
          final aTime =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
          final bTime =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
          return bTime.compareTo(aTime);
        });

        setState(() {
          _recentSOSRequests = sosData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Gagal memuat data SOS';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error memuat data SOS: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCompletedSOSData({bool forceReload = false}) async {
    if (!forceReload && _completedSOSRequests.isNotEmpty) {
      // Only skip if already loaded and not forcing reload
      return;
    }

    try {
      setState(() {
        _isLoadingCompleted = true;
      });

      await _apiService.loadToken();

      // Load completed SOS requests - load all first, then filter
      final response = await _apiService.getSosRequests(status: 'completed');

      if (response['success']) {
        final dynamic data = response['data'];
        List<Map<String, dynamic>> sosData = [];

        // Handle paginated or direct list response
        if (data is Map && data.containsKey('data')) {
          sosData = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          sosData = List<Map<String, dynamic>>.from(data);
        }

        // Filter SOS where current user is requester or helper
        // Also ensure status is actually 'completed' (not cancelled)
        if (_currentUserId != null) {
          sosData = sosData.where((sos) {
            final status = sos['status']?.toString() ?? '';
            // Only include completed SOS, not cancelled
            if (status != 'completed') return false;

            final requesterId = sos['requester_id']?.toString();
            final helperId = sos['helper_id']?.toString();
            return requesterId == _currentUserId || helperId == _currentUserId;
          }).toList();
        } else {
          // If no current user, filter out cancelled
          sosData = sosData.where((sos) {
            final status = sos['status']?.toString() ?? '';
            return status == 'completed';
          }).toList();
        }

        // Sort by updated_at or created_at (newest first)
        sosData.sort((a, b) {
          final aTime =
              DateTime.tryParse(a['updated_at'] ?? a['created_at'] ?? '') ??
              DateTime(1970);
          final bTime =
              DateTime.tryParse(b['updated_at'] ?? b['created_at'] ?? '') ??
              DateTime(1970);
          return bTime.compareTo(aTime);
        });

        setState(() {
          _completedSOSRequests = sosData;
          _isLoadingCompleted = false;
        });
      } else {
        setState(() {
          _isLoadingCompleted = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingCompleted = false;
      });
    }
  }

  void _startContentAnimation() {
    _contentAnimationController.forward();
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

  Color _getSOSStatusColor(String status) {
    switch (status) {
      case 'active':
        return const Color(0xFFEF4444);
      case 'inProgress':
        return const Color(0xFF3B82F6);
      case 'completed':
        return const Color(0xFF10B981);
      case 'cancelled':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFFEF4444);
    }
  }

  String _getSOSStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Aktif';
      case 'inProgress':
        return 'Berlangsung';
      case 'completed':
        return 'Selesai';
      case 'cancelled':
        return 'Dibatalkan';
      default:
        return 'Aktif';
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _shakeController.dispose();
    _contentAnimationController.dispose();
    _countdownController.dispose();
    _tabController.dispose();
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    _confirmationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              // Modern App Bar
              _buildSliverAppBar(),
              // Emergency Button
              _buildEmergencyButton(),
              // Emergency Contacts
              _buildEmergencyContacts(),
              // Tab Bar (moved below emergency contacts)
              _buildTabBar(),
              // SOS Requests (Active or History based on tab)
              _buildSOSRequestsContent(),
            ],
          ),
          // Confirmation Dialog Overlay
          if (_showConfirmation) _buildConfirmationOverlay(),
        ],
      ),
    );
  }

  Widget _buildSOSRequestsContent() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      sliver: SliverToBoxAdapter(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: _selectedTab == 0
                ? _buildActiveSOSContent()
                : _buildHistorySOSContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveSOSContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Semua Bantuan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_recentSOSRequests.length} Aktif',
                    style: const TextStyle(
                      color: Color(0xFFEF4444),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: _loadSOSData,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _isLoading
              ? _buildLoadingSkeleton()
              : _error != null
              ? Column(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadSOSData,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : _recentSOSRequests.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.emergency_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tidak Ada SOS Aktif',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tidak ada permintaan bantuan darurat yang sedang aktif',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentSOSRequests.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sosData = _recentSOSRequests[index];
                    return _buildSOSRequestCardFromApi(sosData);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 16),
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
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            gradient: LinearGradient(
              colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.emergency_rounded, size: 20), text: 'Aktif'),
            Tab(icon: Icon(Icons.history_rounded, size: 20), text: 'Riwayat'),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySOSContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: Color(0xFF10B981),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Riwayat SOS',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${_completedSOSRequests.length} Selesai',
                    style: const TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            IconButton(
              onPressed: () {
                _loadCompletedSOSData(forceReload: true);
              },
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _isLoadingCompleted
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _completedSOSRequests.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Belum Ada Riwayat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SOS yang sudah diselesaikan akan muncul di sini',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _completedSOSRequests.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final sosData = _completedSOSRequests[index];
                    return _buildCompletedSOSCard(sosData);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildCompletedSOSCard(Map<String, dynamic> sosData) {
    final sosId = sosData['id']?.toString() ?? '';
    final requester = sosData['requester'] as Map<String, dynamic>?;
    final helper = sosData['helper'] as Map<String, dynamic>?;
    final requesterId = sosData['requester_id']?.toString();
    final helperId = sosData['helper_id']?.toString();
    final isRequester = _currentUserId != null && requesterId == _currentUserId;
    final isHelper = _currentUserId != null && helperId == _currentUserId;

    // Get points earned (based on PointsService constants)
    int pointsEarned = 0;
    if (isRequester) {
      pointsEarned = 0; // Requester gets 0 points
    } else if (isHelper) {
      pointsEarned = 100; // Helper gets 100 points
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF10B981).withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (sosId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SOSDetailScreen(sosId: sosId),
                ),
              ).then((result) {
                // Reload data when returning from detail screen
                _loadSOSData();
                _checkActiveSOS();
                // If SOS was completed, reload completed SOS data
                if (result == true || _selectedTab == 1) {
                  _loadCompletedSOSData(forceReload: true);
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
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
                            sosData['title'] ?? 'SOS Request',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Selesai',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _formatTimeAgo(
                                  sosData['updated_at'] ??
                                      sosData['created_at'],
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
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
                // Role and points info
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF10B981).withOpacity(0.1),
                        const Color(0xFF10B981).withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
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
                              isRequester
                                  ? 'Anda Membuat Permintaan SOS'
                                  : 'Anda Membantu SOS Ini',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (pointsEarned > 0)
                              Text(
                                'Poin yang Didapat: $pointsEarned poin',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (sosData['description'] != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    sosData['description'],
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 14,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        sosData['address'] ?? 'Lokasi tidak tersedia',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isRequester && helper != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: const Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              helper['name'] ?? 'Helper',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isHelper && requester != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D9CDB).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.person_rounded,
                              size: 12,
                              color: const Color(0xFF2D9CDB),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              requester['name'] ?? 'Requester',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2D9CDB),
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
          ),
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
                Theme.of(context).colorScheme.error,
                Theme.of(context).colorScheme.error.withOpacity(0.8),
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
                              Icons.sos_rounded,
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
                                  'Butuh Bantuan Cepat?',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Gunakan fitur darurat jika diperlukan.',
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

  Widget _buildEmergencyButton() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isEmergencyActive ? _pulseAnimation.value : 1.0,
                    child: GestureDetector(
                      onLongPressStart: _onLongPressStart,
                      onLongPressEnd: _onLongPressEnd,
                      onLongPressCancel: _onLongPressCancel,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ring with animation
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFEF4444).withOpacity(0.2),
                                  const Color(0xFFEF4444).withOpacity(0),
                                ],
                                stops: const [0.6, 1.0],
                              ),
                            ),
                          ),
                          // Middle ring
                          Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFEF4444).withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                          ),
                          // Main SOS Button
                          Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: _isEmergencyActive
                                    ? [
                                        const Color(0xFFDC2626),
                                        const Color(0xFFB91C1C),
                                      ]
                                    : [
                                        const Color(0xFFEF4444),
                                        const Color(0xFFDC2626),
                                      ],
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withOpacity(0.4),
                                  blurRadius: 30,
                                  spreadRadius: _isEmergencyActive ? 5 : 0,
                                ),
                                BoxShadow(
                                  color: const Color(
                                    0xFFEF4444,
                                  ).withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (_showCountdown && _countdown > 0)
                                    Text(
                                      '$_countdown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 64,
                                        letterSpacing: 0,
                                      ),
                                    )
                                  else
                                    Icon(
                                      _isEmergencyActive
                                          ? Icons.notifications_active_rounded
                                          : Icons.sos_rounded,
                                      color: Colors.white,
                                      size: 50,
                                    ),
                                  if (!_showCountdown) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _isEmergencyActive ? 'AKTIF' : 'SOS',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 24,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _isEmergencyActive
                      ? 'Sinyal darurat aktif\nBantuan sedang menuju lokasi Anda'
                      : _showCountdown
                      ? 'Tahan untuk $_countdown detik...'
                      : 'Tahan tombol selama 3 detik\nuntuk mengaktifkan sinyal darurat',
                  style: TextStyle(
                    color: const Color(0xFFEF4444),
                    fontSize: 14,
                    height: 1.5,
                    fontWeight: _isEmergencyActive || _showCountdown
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (_isEmergencyActive) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _cancelActiveSOS,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text(
                      'Batalkan SOS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(
                        color: Color(0xFFEF4444),
                        width: 2,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Kirim SOS sekarang?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap Cancel dalam ${_confirmationSecondsLeft}s untuk membatalkan',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelSOS,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _confirmSOS,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Kirim',
                        style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildEmergencyContacts() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      sliver: SliverToBoxAdapter(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.contact_phone_rounded,
                        color: Color(0xFF3B82F6),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Kontak Cepat',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildEmergencyContactCard(
                        'Polisi',
                        '110',
                        Icons.local_police_rounded,
                        const Color(0xFF3B82F6),
                        true,
                      ),
                      const Divider(height: 1),
                      _buildEmergencyContactCard(
                        'Ambulans',
                        '118',
                        Icons.medical_services_rounded,
                        const Color(0xFFEF4444),
                        true,
                      ),
                      const Divider(height: 1),
                      _buildEmergencyContactCard(
                        'Pemadam Kebakaran',
                        '113',
                        Icons.local_fire_department_rounded,
                        const Color(0xFFF59E0B),
                        false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyContactCard(
    String name,
    String number,
    IconData icon,
    Color color,
    bool showDivider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
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
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.phone_rounded, size: 14, color: color),
                    const SizedBox(width: 4),
                    Text(
                      number,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _callEmergency(number),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Panggil',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }

  Widget _buildSOSRequestCardFromApi(Map<String, dynamic> sosData) {
    final status = sosData['status'] ?? 'active';
    final statusColor = _getSOSStatusColor(status);
    final sosId = sosData['id']?.toString() ?? '';
    final requester = sosData['requester'] as Map<String, dynamic>?;
    final requesterName = requester?['name'] ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: statusColor.withOpacity(0.3), width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (sosId.isNotEmpty) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SOSDetailScreen(sosId: sosId),
                ),
              ).then((result) {
                // Reload data when returning from detail screen
                _loadSOSData();
                _checkActiveSOS();
                // If SOS was completed, reload completed SOS data
                if (result == true && _selectedTab == 1) {
                  _loadCompletedSOSData(forceReload: true);
                }
              });
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.2),
                            statusColor.withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: statusColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.emergency_rounded,
                        color: statusColor,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sosData['title'] ?? 'Permintaan Bantuan Darurat',
                            style: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.person_rounded,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                requesterName,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [statusColor, statusColor.withOpacity(0.8)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        _getSOSStatusText(status),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (sosData['description'] != null &&
                    sosData['description'].toString().isNotEmpty) ...[
                  Text(
                    sosData['description'],
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 14,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Icon(
                      Icons.location_on_rounded,
                      size: 16,
                      color: const Color(0xFFEF4444),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sosData['address'] ?? 'Lokasi tidak tersedia',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTimeAgo(sosData['created_at']),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                    if (sosData['distance_km'] != null ||
                        (_userPosition != null &&
                            sosData['latitude'] != null &&
                            sosData['longitude'] != null)) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.near_me_rounded,
                        size: 14,
                        color: const Color(0xFF10B981),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          _formatDistance(
                            sosData['distance_km'] ??
                                (_userPosition != null &&
                                        sosData['latitude'] != null &&
                                        sosData['longitude'] != null
                                    ? _calculateDistance(
                                        _userPosition!.latitude,
                                        _userPosition!.longitude,
                                        sosData['latitude'] is double
                                            ? sosData['latitude']
                                            : double.tryParse(
                                                    sosData['latitude']
                                                        .toString(),
                                                  ) ??
                                                  0.0,
                                        sosData['longitude'] is double
                                            ? sosData['longitude']
                                            : double.tryParse(
                                                    sosData['longitude']
                                                        .toString(),
                                                  ) ??
                                                  0.0,
                                      )
                                    : null),
                          ),
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSOSRequestCard(
    String title,
    String location,
    String time,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.emergency_rounded, color: color, size: 24),
          ),
          const SizedBox(width: 16),
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
                  ),
                ),
                const SizedBox(height: 4),
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
                        location,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ElevatedButton.icon(
              onPressed: () => _respondToSOS(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                elevation: 2,
                shadowColor: const Color(0xFF27AE60).withOpacity(0.3),
              ),
              icon: const Icon(Icons.directions_walk_rounded, size: 16),
              label: const Text(
                'Bantu',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (_isEmergencyActive) return;

    setState(() {
      _isHolding = true;
      _showCountdown = true;
      _countdown = 3;
    });

    // Start countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_countdown > 1) {
          _countdown--;
          // Haptic feedback for each countdown
          HapticFeedback.mediumImpact();
        } else {
          // Countdown finished
          timer.cancel();
          _countdownTimer = null;
          _showCountdown = false;
          _showConfirmation = true;
          _startConfirmationTimer();
        }
      });
    });

    // Haptic feedback on start
    HapticFeedback.lightImpact();
  }

  void _onLongPressEnd(LongPressEndDetails details) {
    if (_countdownTimer != null) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }

    setState(() {
      _isHolding = false;
      _showCountdown = false;
      _countdown = 3;
    });
  }

  void _onLongPressCancel() {
    _onLongPressEnd(const LongPressEndDetails());
  }

  void _startConfirmationTimer() {
    _confirmationSecondsLeft = 5;
    _confirmationTimer?.cancel();
    _confirmationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _confirmationSecondsLeft--;
      });

      if (_confirmationSecondsLeft <= 0) {
        timer.cancel();
        _confirmationTimer = null;
        _cancelSOS();
      }
    });
  }

  void _cancelSOS() {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;
    setState(() {
      _showConfirmation = false;
      _countdown = 3;
      _showCountdown = false;
    });
  }

  Future<void> _cancelActiveSOS() async {
    if (_activeSosId == null) {
      setState(() {
        _isEmergencyActive = false;
      });
      _pulseController.stop();
      _pulseController.reset();
      return;
    }

    // Check if SOS is already completed - don't allow cancellation
    try {
      await _apiService.loadToken();
      final sosResponse = await _apiService.getSosRequest(_activeSosId!);
      if (sosResponse['success']) {
        final sosData = sosResponse['data'];
        final status = sosData['status']?.toString() ?? '';
        if (status == 'completed') {
          // SOS already completed, cannot cancel
          setState(() {
            _isEmergencyActive = false;
            _showConfirmation = false;
          });
          _pulseController.stop();
          _pulseController.reset();
          _checkActiveSOS(); // Re-check to update state
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'SOS sudah selesai dan tidak dapat dibatalkan',
                ),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                margin: const EdgeInsets.all(16),
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      // Continue with cancellation if check fails
    }

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFEF4444),
              size: 28,
            ),
            SizedBox(width: 12),
            Text(
              'Batalkan SOS?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan permintaan bantuan darurat ini?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Ya, Batalkan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final response = await _apiService.updateSosRequest(
        id: _activeSosId!,
        status: 'cancelled',
      );

      if (mounted) Navigator.pop(context); // Close loading

      if (response['success']) {
        setState(() {
          _isEmergencyActive = false;
          _activeSosId = null;
        });
        _pulseController.stop();
        _pulseController.reset();
        _showNotification('SOS berhasil dibatalkan');
        _loadSOSData(); // Refresh the list
        _checkActiveSOS(); // Re-check active SOS
        // Reload completed SOS data if on history tab
        if (_selectedTab == 1) {
          _loadCompletedSOSData(forceReload: true);
        }
      } else {
        _showNotification(
          response['message'] ?? 'Gagal membatalkan SOS',
          isError: true,
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      _showNotification('Error: ${e.toString()}');
    }
  }

  Future<void> _confirmSOS() async {
    _confirmationTimer?.cancel();
    _confirmationTimer = null;

    setState(() {
      _showConfirmation = false;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showNotification(
          'Layanan lokasi tidak aktif. Silakan aktifkan di pengaturan.',
        );
        return;
      }

      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showNotification(
            'Izin lokasi diperlukan untuk mengirim SOS. Silakan berikan izin lokasi.',
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showNotification(
          'Izin lokasi ditolak permanen. Silakan aktifkan di pengaturan perangkat.',
        );
        return;
      }

      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Get address from coordinates
      String address = 'Lokasi tidak ditemukan';
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          final place = placemarks.first;
          address = [
            place.street,
            place.subLocality,
            place.locality,
            place.administrativeArea,
            place.country,
          ].where((s) => s != null && s.isNotEmpty).join(', ');
        }
      } catch (e) {
        print('Error getting address: $e');
        address = '${position.latitude}, ${position.longitude}';
      }

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Load token
      await _apiService.loadToken();

      // Send SOS request
      final response = await _apiService.createSosRequest(
        title: 'Permintaan Bantuan Darurat',
        description: 'Saya membutuhkan bantuan darurat di lokasi saya',
        latitude: position.latitude,
        longitude: position.longitude,
        address: address,
        rewardAmount: 10000,
      );

      if (response['success']) {
        final sosId = response['data']?['id']?.toString();
        setState(() {
          _isEmergencyActive = true;
          _activeSosId = sosId;
        });
        _pulseController.repeat(reverse: true);
        _showNotification(
          'SOS berhasil dikirim! Bantuan akan segera menuju lokasi Anda.',
        );
        _loadSOSData(); // Refresh the list
        _checkActiveSOS(); // Re-check to ensure status is correct
      } else {
        _showNotification(response['message'] ?? 'Gagal mengirim SOS');
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog if still open
        _showNotification('Error: ${e.toString()}');
      }
    }
  }

  Future<void> _callEmergency(String number) async {
    // Cek permission dulu
    var status = await Permission.phone.status;

    if (!status.isGranted) {
      status = await Permission.phone.request();
    }

    if (status.isGranted) {
      final Uri launchUri = Uri(scheme: 'tel', path: number);
      if (await canLaunchUrl(launchUri)) {
        // Buka dialer, tidak auto calling
        await launchUrl(launchUri, mode: LaunchMode.externalApplication);
      } else {
        _showNotification('Tidak dapat melakukan panggilan ke $number');
      }
    } else {
      _showNotification(
        'Izin panggilan telepon diperlukan untuk menghubungi nomor darurat.',
        isError: true,
      );
    }
  }

  void _respondToSOS() {
    _showNotification('Anda akan membantu!');
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
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF2D9CDB), // Biru Cerah untuk Brand
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Add this helper method for mock SOS data
  List<Map<String, dynamic>> _getMockSOSData() {
    return [
      {
        'title': 'Kecelakaan Motor',
        'location': 'Jl. Sudirman, Jakarta Pusat',
        'time': '5 menit yang lalu',
        'color': const Color(0xFFEF4444),
      },
      {
        'title': 'Kebakaran Rumah',
        'location': 'Jl. Thamrin, Jakarta Selatan',
        'time': '15 menit yang lalu',
        'color': const Color(0xFFF59E0B),
      },
      {
        'title': 'Pencurian',
        'location': 'Jl. Gatot Subroto, Jakarta Selatan',
        'time': '30 menit yang lalu',
        'color': const Color(0xFF3B82F6),
      },
    ];
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
