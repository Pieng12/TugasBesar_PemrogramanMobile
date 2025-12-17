import 'package:flutter/material.dart';
import '../models/user_model.dart' as user_model;
import '../services/api_service.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedCategory = 'all';
  
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _userBadges = [];
  List<Map<String, dynamic>> _allBadges = [];
  bool _isLoading = true;
  String? _error;

  final List<Map<String, dynamic>> _categories = [
    {'value': 'all', 'label': 'Semua', 'icon': Icons.apps},
    {'value': 'reliability', 'label': 'Kepercayaan', 'icon': Icons.verified},
    {'value': 'speed', 'label': 'Kecepatan', 'icon': Icons.speed},
    {'value': 'quality', 'label': 'Kualitas', 'icon': Icons.emoji_events},
    {'value': 'helpfulness', 'label': 'Membantu', 'icon': Icons.favorite},
    {'value': 'emergency', 'label': 'Darurat', 'icon': Icons.emergency},
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
    _loadBadgesData();
  }

  Future<void> _loadBadgesData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      if (_apiService.token == null) {
        setState(() {
          _error = 'Please login to view badges';
          _isLoading = false;
        });
        return;
      }

      // Load user badges
      final userBadgesResponse = await _apiService.getUserBadges();
      if (userBadgesResponse['success']) {
        setState(() {
          _userBadges = List<Map<String, dynamic>>.from(userBadgesResponse['data']);
        });
      }

      // Load all badges
      final allBadgesResponse = await _apiService.getAllBadges();
      if (allBadgesResponse['success']) {
        setState(() {
          _allBadges = List<Map<String, dynamic>>.from(allBadgesResponse['data']);
        });
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading badges: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool _isBadgeEarnedFromApi(String? badgeId) {
    if (badgeId == null) return false;
    return _userBadges.any((userBadge) => userBadge['badge_id']?.toString() == badgeId);
  }

  IconData _getBadgeIcon(String? type) {
    switch (type) {
      case 'reliability':
        return Icons.verified;
      case 'speed':
        return Icons.speed;
      case 'quality':
        return Icons.emoji_events;
      case 'helpfulness':
        return Icons.favorite;
      case 'emergency':
        return Icons.emergency;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Lencana Saya'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.grey[800],
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.grey[800]),
        shadowColor: Colors.black.withOpacity(0.1),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: CustomScrollView(
          slivers: [
            // Header
            _buildHeader(),
            // Category Filter
            _buildCategoryFilter(),
            // Badges Grid
            _buildBadgesGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF8B5CF6),
              Color(0xFF6366F1),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Koleksi Lencana',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kumpulkan lencana dengan menyelesaikan berbagai pencapaian',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('12', 'Total Lencana'),
                _buildStatItem('8', 'Terkumpul'),
                _buildStatItem('67%', 'Progress'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: _categories.map((category) {
            final isSelected = _selectedCategory == category['value'];
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['value'];
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF8B5CF6) : Colors.grey[300]!,
                      ),
                      boxShadow: isSelected ? [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ] : null,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'],
                          size: 16,
                          color: isSelected ? Colors.white : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category['label'],
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
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBadgesGrid() {
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: CircularProgressIndicator(),
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
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadBadgesData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final badges = _getFilteredBadges();
    
    if (badges.isEmpty) {
      return SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: const Center(
            child: Text(
              'Tidak ada lencana tersedia',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
          ),
        ),
      );
    }
    
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index >= badges.length) return null;
            final badge = badges[index];
            return _buildBadgeCardFromApi(badge);
          },
          childCount: badges.length,
        ),
      ),
    );
  }

  Widget _buildBadgeCardFromApi(Map<String, dynamic> badge) {
    final isEarned = _isBadgeEarnedFromApi(badge['id']);
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isEarned ? const Color(0xFF8B5CF6) : Colors.grey[200]!,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isEarned 
                  ? const Color(0xFF8B5CF6).withOpacity(0.1)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getBadgeIcon(badge['type']),
              size: 40,
              color: isEarned ? const Color(0xFF8B5CF6) : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            badge['name'] ?? 'No Name',
            style: TextStyle(
              color: isEarned ? const Color(0xFF1E293B) : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            badge['description'] ?? 'No Description',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isEarned 
                  ? const Color(0xFF8B5CF6)
                  : Colors.grey[300],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isEarned ? 'Diperoleh' : 'Belum Diperoleh',
              style: TextStyle(
                color: isEarned ? Colors.white : Colors.grey[600],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard(user_model.UserBadge badge) {
    final isEarned = _isBadgeEarned(badge.id);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isEarned ? _getBadgeColor(badge.type) : Colors.grey[200]!,
          width: isEarned ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Badge Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isEarned 
                  ? _getBadgeColor(badge.type).withOpacity(0.1)
                  : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              _getBadgeIcon(badge.type.toString()),
              color: isEarned ? _getBadgeColor(badge.type) : Colors.grey[400],
              size: 30,
            ),
          ),
          const SizedBox(height: 12),
          // Badge Name
          Text(
            badge.name,
            style: TextStyle(
              color: isEarned ? Colors.black87 : Colors.grey[500],
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Badge Description
          Text(
            badge.description,
            style: TextStyle(
              color: isEarned ? Colors.grey[600] : Colors.grey[400],
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isEarned 
                  ? _getBadgeColor(badge.type).withOpacity(0.1)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isEarned ? 'Diperoleh' : 'Belum',
              style: TextStyle(
                color: isEarned ? _getBadgeColor(badge.type) : Colors.grey[500],
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredBadges() {
    if (_allBadges.isEmpty) return [];
    
    if (_selectedCategory == 'all') {
      return _allBadges;
    }
    
    return _allBadges.where((badge) {
      return badge['type'] == _selectedCategory;
    }).toList();
  }

  List<user_model.UserBadge> _getMockBadges() {
    return [
      user_model.UserBadge(
        id: '1',
        name: 'Pembantu Pertama',
        description: 'Menyelesaikan pekerjaan pertama',
        icon: '🎯',
        type: user_model.BadgeType.quality,
        earnedDate: DateTime.now().subtract(const Duration(days: 30)),
      ),
      user_model.UserBadge(
        id: '2',
        name: 'Terpercaya',
        description: 'Mendapat rating 5 bintang',
        icon: '⭐',
        type: user_model.BadgeType.reliability,
        earnedDate: DateTime.now().subtract(const Duration(days: 15)),
      ),
      user_model.UserBadge(
        id: '3',
        name: 'SOS Hero',
        description: 'Membantu 5 permintaan SOS',
        icon: '🆘',
        type: user_model.BadgeType.emergency,
        earnedDate: DateTime.now().subtract(const Duration(days: 7)),
      ),
      user_model.UserBadge(
        id: '4',
        name: 'Pekerja Keras',
        description: 'Menyelesaikan 10 pekerjaan',
        icon: '💪',
        type: user_model.BadgeType.quality,
        earnedDate: DateTime.now().subtract(const Duration(days: 5)),
      ),
      user_model.UserBadge(
        id: '5',
        name: 'Pelanggan Setia',
        description: 'Mendapat 20 review positif',
        icon: '❤️',
        type: user_model.BadgeType.helpfulness,
        earnedDate: DateTime.now().subtract(const Duration(days: 3)),
      ),
      user_model.UserBadge(
        id: '6',
        name: 'Super Helper',
        description: 'Membantu 50 pekerjaan',
        icon: '🚀',
        type: user_model.BadgeType.helpfulness,
        earnedDate: null,
      ),
      user_model.UserBadge(
        id: '7',
        name: 'Expert',
        description: 'Mendapat rating 4.8+',
        icon: '🎓',
        type: user_model.BadgeType.quality,
        earnedDate: null,
      ),
      user_model.UserBadge(
        id: '8',
        name: 'Community Hero',
        description: 'Membantu 100 pekerjaan',
        icon: '🏆',
        type: user_model.BadgeType.emergency,
        earnedDate: null,
      ),
    ];
  }

  bool _isBadgeEarned(String badgeId) {
    final badge = _getMockBadges().firstWhere((b) => b.id == badgeId);
    return badge.earnedDate != null;
  }

  Color _getBadgeColor(user_model.BadgeType type) {
    switch (type) {
      case user_model.BadgeType.reliability:
        return const Color(0xFF10B981);
      case user_model.BadgeType.speed:
        return const Color(0xFFF59E0B);
      case user_model.BadgeType.quality:
        return const Color(0xFF3B82F6);
      case user_model.BadgeType.helpfulness:
        return const Color(0xFFEC4899);
      case user_model.BadgeType.emergency:
        return const Color(0xFF8B5CF6);
    }
  }

}