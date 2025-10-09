import 'package:flutter/material.dart';
import 'create_job_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  String _selectedCategory = 'all';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

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
      body: CustomScrollView(
        slivers: [
          // Modern App Bar
          _buildSliverAppBar(),
          // Filter Chips
          _buildFilterChips(),
          // Leaderboard List
          _buildLeaderboardList(),
        ],
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content moved up
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
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
                              'Lihat siapa yang paling produktif bulan ini.',
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
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final categories = [
      {
        'value': 'all',
        'label': 'Semua',
        'color': const Color(0xFF2D9CDB),
      }, // Biru Cerah untuk Brand
      {
        'value': 'monthly',
        'label': 'Bulanan',
        'color': const Color(0xFF27AE60),
      }, // Hijau untuk Aksi / CTA
      {
        'value': 'weekly',
        'label': 'Mingguan',
        'color': const Color(0xFFF2C94C),
      }, // Kuning / Emas untuk Badge
      {
        'value': 'daily',
        'label': 'Harian',
        'color': const Color(0xFFEB5757),
      }, // Merah untuk SOS / Darurat
    ];

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((category) {
              final isSelected = _selectedCategory == category['value'];
              final color = category['color'] as Color;
              final label = category['label'] as String;

              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['value'] as String;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isSelected ? color : const Color(0xFFE2E8F0),
                        width: 1,
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
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardList() {
    final workers = _getMockWorkers();

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (index >= workers.length) return null;
          final worker = workers[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => WorkerDetailScreen(
                    worker: worker,
                    rankColor: _getRankColor(index + 1),
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildWorkerCard(worker, index + 1),
            ),
          );
        }, childCount: workers.length),
      ),
    );
  }

  Widget _buildWorkerCard(Map<String, dynamic> worker, int rank) {
    final isTopThree = rank <= 3;
    final rankColor = _getRankColor(rank);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        border: isTopThree
            ? Border.all(color: rankColor.withOpacity(0.3), width: 2)
            : Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank Badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isTopThree ? rankColor : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                boxShadow: isTopThree
                    ? [
                        BoxShadow(
                          color: rankColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: TextStyle(
                    color: isTopThree ? Colors.white : const Color(0xFF64748B),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: rankColor.withOpacity(0.1),
              child: Text(
                worker['name'][0].toUpperCase(),
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
                          worker['name'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTopThree) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.emoji_events_rounded,
                          color: rankColor,
                          size: 16,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    worker['category'],
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: Colors.amber[600],
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${worker['rating']}',
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.work_rounded,
                        color: const Color(0xFF94A3B8),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${worker['jobsCompleted']} pekerjaan',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Points
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${worker['points']}',
                  style: TextStyle(
                    color: rankColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'poin',
                  style: TextStyle(
                    color: rankColor.withOpacity(0.7),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getMockWorkers() {
    return [
      {
        'name': 'Ahmad Wijaya',
        'category': 'Pembersihan',
        'rating': 4.9,
        'jobsCompleted': 156,
        'points': 2450,
      },
      {
        'name': 'Siti Rahayu',
        'category': 'Perbaikan',
        'rating': 4.8,
        'jobsCompleted': 142,
        'points': 2380,
      },
      {
        'name': 'Budi Santoso',
        'category': 'Pengiriman',
        'rating': 4.9,
        'jobsCompleted': 138,
        'points': 2320,
      },
      {
        'name': 'Dewi Kartika',
        'category': 'Edukasi',
        'rating': 4.7,
        'jobsCompleted': 125,
        'points': 2150,
      },
      {
        'name': 'Rudi Hartono',
        'category': 'Fotografi',
        'rating': 4.8,
        'jobsCompleted': 118,
        'points': 2080,
      },
      {
        'name': 'Maya Sari',
        'category': 'Kuliner',
        'rating': 4.6,
        'jobsCompleted': 112,
        'points': 1950,
      },
      {
        'name': 'Agus Prasetyo',
        'category': 'Pembersihan',
        'rating': 4.5,
        'jobsCompleted': 98,
        'points': 1820,
      },
      {
        'name': 'Lina Wijaya',
        'category': 'Perbaikan',
        'rating': 4.7,
        'jobsCompleted': 95,
        'points': 1750,
      },
      {
        'name': 'Eko Susanto',
        'category': 'Pengiriman',
        'rating': 4.6,
        'jobsCompleted': 89,
        'points': 1680,
      },
      {
        'name': 'Rina Sari',
        'category': 'Edukasi',
        'rating': 4.5,
        'jobsCompleted': 85,
        'points': 1620,
      },
    ];
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
        return const Color(0xFF2D9CDB); // Biru Cerah untuk Brand
    }
  }
}

class WorkerDetailScreen extends StatefulWidget {
  final Map<String, dynamic> worker;
  final Color rankColor;

  const WorkerDetailScreen({
    super.key,
    required this.worker,
    required this.rankColor,
  });

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
      appBar: AppBar(
        title: const Text('Detail Pekerja'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Header
            _buildProfileHeader(),
            const SizedBox(height: 24),

            // Stats
            _buildStatsSection(),
            const SizedBox(height: 24),

            // About Section
            _buildAboutSection(),
            const SizedBox(height: 24),

            // Hire Button
            _buildHireButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [widget.rankColor.withOpacity(0.8), widget.rankColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: widget.rankColor.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white.withOpacity(0.9),
                child: CircleAvatar(
                  radius: 46,
                  backgroundColor: widget.rankColor.withOpacity(0.1),
                  child: Text(
                    widget.worker['name'][0].toUpperCase(),
                    style: TextStyle(
                      color: widget.rankColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                widget.worker['name'],
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                  shadows: [Shadow(blurRadius: 5, color: Colors.black26)],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.worker['category'],
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.rankColor != const Color(0xFF2D9CDB))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_user_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pekerja Terpercaya',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
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

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF64748B), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5),
          child,
        ],
      ),
    );
  }

  Widget _buildAboutItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF27AE60), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              Icons.star_rounded,
              'Rating',
              '${widget.worker['rating']}',
              Colors.amber,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              Icons.work_rounded,
              'Pekerjaan',
              '${widget.worker['jobsCompleted']}',
              const Color(0xFF2D9CDB),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              Icons.emoji_events_rounded,
              'Poin',
              '${widget.worker['points']}',
              const Color(0xFF27AE60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: _buildSection(
        title: 'Tentang Pekerja',
        icon: Icons.info_outline_rounded,
        child: Column(
          children: [
            _buildAboutItem(
              Icons.check_circle_outline_rounded,
              'Profesional di bidang ${widget.worker['category']}',
            ),
            _buildAboutItem(
              Icons.check_circle_outline_rounded,
              'Pengalaman lebih dari 3 tahun',
            ),
            _buildAboutItem(
              Icons.check_circle_outline_rounded,
              'Dikenal karena hasil kerja yang rapi dan tepat waktu',
            ),
            _buildAboutItem(
              Icons.check_circle_outline_rounded,
              'Memiliki komunikasi yang baik dan ramah',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHireButton() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => _showHireConfirmationDialog(),
          icon: const Icon(Icons.add_shopping_cart_rounded),
          label: const Text(
            'Gunakan Jasa',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF27AE60),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }

  void _showHireConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.person_add_alt_1_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text(
              'Konfirmasi Jasa',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Text(
          'Anda akan membuat pesanan khusus untuk ${widget.worker['name']}. Lanjutkan?',
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateJobScreen(targetWorker: widget.worker),
                ),
              );
            },
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );
  }
}
