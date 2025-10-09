import 'package:flutter/material.dart';
import '../models/job_model.dart';
import 'package:url_launcher/url_launcher.dart';

class JobDetailScreen extends StatefulWidget {
  final JobModel job;

  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
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
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDescriptionSection(),
                      const SizedBox(height: 24),
                      _buildJobDetailsCard(),
                      const SizedBox(height: 24),
                      _buildRequirementsSection(),
                      const SizedBox(height: 24),
                      _buildLocationSection(),
                      const SizedBox(height: 80), // Space for FAB
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildApplyButton(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200.0,
      pinned: true,
      floating: false,
      elevation: 2,
      backgroundColor: Theme.of(context).colorScheme.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: const Text(
        'Detail Pekerjaan',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2D9CDB),
                    Color(0xFF1E88E5),
                    Color(0xFF1976D2),
                  ],
                ),
              ),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SlideTransition(
                        position: _slideAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _getCategoryName(widget.job.category),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SlideTransition(
                        position: _slideAnimation,
                        child: Text(
                          widget.job.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 26.0,
                            shadows: [
                              Shadow(blurRadius: 10, color: Colors.black26),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SlideTransition(
                        position: _slideAnimation,
                        child: Row(
                          children: [
                            _buildInfoItem(
                              Icons.attach_money_rounded,
                              'Rp ${widget.job.price.toStringAsFixed(0)}',
                            ),
                            const SizedBox(width: 24),
                            _buildInfoItem(
                              Icons.location_on_rounded,
                              widget.job.location.address,
                            ),
                          ],
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
    );
  }

  Widget _buildInfoItem(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.9), size: 18),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    return _buildSectionCard(
      icon: Icons.description_rounded,
      iconColor: const Color(0xFF2D9CDB),
      title: 'Deskripsi Pekerjaan',
      child: Text(
        widget.job.description,
        style: const TextStyle(
          color: Color(0xFF4F4F4F),
          fontSize: 14,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildJobDetailsCard() {
    return _buildSectionCard(
      icon: Icons.info_outline_rounded,
      iconColor: const Color(0xFF6366F1),
      title: 'Detail Penting',
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.attach_money_rounded,
            label: 'Harga',
            value: 'Rp ${widget.job.price.toStringAsFixed(0)}',
            valueColor: const Color(0xFF10B981),
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(
            icon: Icons.category_rounded,
            label: 'Kategori',
            value: _getCategoryName(widget.job.category),
          ),
          const Divider(height: 24, thickness: 0.5),
          _buildDetailRow(
            icon: Icons.history_toggle_off_rounded,
            label: 'Status',
            value: 'Terbuka', // Placeholder
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        const SizedBox(width: 16),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF4F4F4F), fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? const Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRequirementsSection() {
    return _buildSectionCard(
      icon: Icons.checklist_rtl_rounded,
      iconColor: const Color(0xFF27AE60),
      title: 'Persyaratan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRequirementItem('Pengalaman minimal 1 tahun'),
          _buildRequirementItem('Alat kerja lengkap'),
          _buildRequirementItem('Sertifikat keahlian (opsional)'),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline_rounded,
            color: Color(0xFF27AE60),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Color(0xFF4F4F4F), fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildSectionCard(
      icon: Icons.location_on_outlined,
      iconColor: const Color(0xFFEB5757),
      title: 'Lokasi Pekerjaan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.job.location.address,
            style: const TextStyle(
              color: Color(0xFF4F4F4F),
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 150,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(
                    'https://media.wired.com/photos/59269cd37034dc5f91bec0f1/master/w_2560%2Cc_limit/GoogleMapTA.jpg',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Center(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMap(
                      widget.job.location.latitude,
                      widget.job.location.longitude,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1E293B),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 5,
                    ),
                    icon: const Icon(Icons.map_rounded, size: 18),
                    label: const Text(
                      'Lihat di Peta',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMap(double latitude, double longitude) async {
    final uri = Uri.tryParse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    if (uri != null) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showNotification('Tidak dapat membuka peta');
      }
    }
  }

  Widget _buildSectionCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF4F4F4F),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 20, thickness: 0.5),
          child,
        ],
      ),
    );
  }

  Widget _buildApplyButton() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _showNotification('Lamaran berhasil dikirim!');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF27AE60),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.send_rounded, size: 20),
            label: const Text(
              'Ajukan Lamaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryName(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return 'Bersih-bersih';
      case JobCategory.delivery:
        return 'Antar-Jemput';
      case JobCategory.maintenance:
        return 'Perbaikan';
      case JobCategory.gardening:
        return 'Kebun';
      case JobCategory.cooking:
        return 'Memasak';
      case JobCategory.tutoring:
        return 'Edukasi';
      case JobCategory.photography:
        return 'Fotografi';
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
        backgroundColor: const Color(0xFF27AE60), // Hijau untuk Aksi / CTA
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
