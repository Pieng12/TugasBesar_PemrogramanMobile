import 'package:flutter/material.dart';
import '../models/job_model.dart';
import '../services/api_service.dart';
import '../widgets/profile_avatar.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class WorkerOrderScreen extends StatefulWidget {
  final Map<String, dynamic> worker;

  const WorkerOrderScreen({super.key, required this.worker});

  @override
  State<WorkerOrderScreen> createState() => _WorkerOrderScreenState();
}

class _WorkerOrderScreenState extends State<WorkerOrderScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _locationController = TextEditingController();

  JobCategory _selectedCategory = JobCategory.other;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;

  // Location data
  double? _selectedLatitude;
  double? _selectedLongitude;
  Map<String, dynamic>? _selectedSavedAddress;

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
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
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
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _requirementsController.dispose();
    _locationController.dispose();
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        _buildWorkerInfoCard(),
                        const SizedBox(height: 24),
                        _buildOrderForm(),
                        const SizedBox(height: 30),
                        _buildSubmitButton(),
                        const SizedBox(height: 40),
                      ],
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
                      const SizedBox(height: 40),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
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
                                  'Pesanan Khusus',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Buat pesanan khusus untuk ${widget.worker['name'] ?? 'Pekerja'}',
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

  Widget _buildWorkerInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D9CDB).withOpacity(0.1),
            const Color(0xFF27AE60).withOpacity(0.1),
            const Color(0xFFF2C94C).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFF2D9CDB).withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D9CDB).withOpacity(0.15),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xFF27AE60).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [const Color(0xFF2D9CDB), const Color(0xFF27AE60)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: ProfileAvatar(
                  profileImagePath: widget.worker['profile_image'],
                  radius: 32,
                  name: widget.worker['name'],
                  backgroundColor: const Color(0xFF2D9CDB).withOpacity(0.1),
                  iconColor: const Color(0xFF2D9CDB),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.worker['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D9CDB).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'User',
                        style: const TextStyle(
                          color: Color(0xFF2D9CDB),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.star_rounded,
                                color: Colors.amber[600],
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.worker['rating'] ?? 0.0}',
                                style: TextStyle(
                                  color: Colors.amber[800],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF27AE60).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF27AE60).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.work_rounded,
                                color: const Color(0xFF27AE60),
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${widget.worker['completed_jobs'] ?? 0}',
                                style: const TextStyle(
                                  color: Color(0xFF27AE60),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
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
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF27AE60).withOpacity(0.1),
                  const Color(0xFF2D9CDB).withOpacity(0.1),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF27AE60).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.verified_user_rounded,
                  color: const Color(0xFF27AE60),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pekerja Terpercaya • Siap menerima pesanan khusus',
                    style: const TextStyle(
                      color: Color(0xFF27AE60),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderForm() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: const Color(0xFF2D9CDB).withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        children: [
          _buildFormHeader(),
          _buildCategorySection(),
          _buildDivider(),
          _buildTitleSection(),
          _buildDivider(),
          _buildDescriptionSection(),
          _buildDivider(),
          _buildLocationSection(),
          _buildDivider(),
          _buildPriceSection(),
          _buildDivider(),
          _buildDivider(),
          _buildConsentSection(),
        ],
      ),
    );
  }

  Widget _buildFormHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2D9CDB).withOpacity(0.05),
            const Color(0xFF27AE60).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF2D9CDB), const Color(0xFF27AE60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.edit_note_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Isi detail pekerjaan yang ingin Anda berikan',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Divider(color: Colors.grey[200], height: 1),
    );
  }

  Widget _buildCategorySection() {
    return _buildFormCard(
      icon: Icons.category_rounded,
      title: 'Kategori Layanan',
      color: const Color(0xFF8B5CF6),
      child: DropdownButtonFormField<JobCategory>(
        initialValue: _selectedCategory,
        isExpanded: true,
        style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16),
        decoration: _inputDecoration(hintText: 'Pilih kategori layanan'),
        items: JobCategory.values.map((category) {
          return DropdownMenuItem(
            value: category,
            child: Text(_getCategoryName(category)),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() {
              _selectedCategory = value;
            });
            _showNotification('Kategori dipilih: ${_getCategoryName(value)}');
          }
        },
        validator: (value) => value == null ? 'Kategori harus dipilih' : null,
      ),
    );
  }

  Widget _buildTitleSection() {
    return _buildFormCard(
      icon: Icons.title_rounded,
      title: 'Judul Pekerjaan',
      color: const Color(0xFF2563EB),
      child: _buildTextField(
        controller: _titleController,
        hintText: 'Contoh: Bersihkan rumah 3 kamar',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Judul pekerjaan harus diisi';
          }
          if (value.length < 10) {
            return 'Judul minimal 10 karakter';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return _buildFormCard(
      icon: Icons.description_rounded,
      title: 'Detail Pekerjaan',
      color: const Color(0xFF10B981),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField(
            controller: _descriptionController,
            label: 'Deskripsi Kebutuhan',
            hintText: 'Jelaskan detail pekerjaan yang dibutuhkan...',
            maxLines: 4,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Deskripsi harus diisi';
              }
              if (value.length < 20) {
                return 'Deskripsi minimal 20 karakter';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildTextField(
            controller: _requirementsController,
            label: 'Persyaratan untuk Pekerja',
            hintText:
                'Contoh:\n• Pengalaman minimal 1 tahun\n• Membawa alat sendiri',
            maxLines: 3,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Persyaratan harus diisi';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildFormCard(
      icon: Icons.location_on_rounded,
      title: 'Lokasi & Jadwal',
      color: const Color(0xFFEF4444),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  controller: _locationController,
                  label: 'Alamat Lokasi',
                  hintText: _selectedSavedAddress != null
                      ? _selectedSavedAddress!['address']
                      : 'Pilih atau masukkan alamat lokasi',
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Alamat lokasi harus diisi';
                    }
                    if (_selectedLatitude == null ||
                        _selectedLongitude == null) {
                      return 'Lokasi harus dipilih dari peta';
                    }
                    return null;
                  },
                  readOnly: _selectedSavedAddress != null,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showLocationPickerDialog(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.location_searching_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_selectedSavedAddress != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: const Color(0xFF10B981),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedSavedAddress!['label'] ?? 'Alamat Tersimpan',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Koordinat: ${_selectedLatitude?.toStringAsFixed(6)}, ${_selectedLongitude?.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: const Color(0xFF64748B),
                    onPressed: () {
                      setState(() {
                        _selectedSavedAddress = null;
                        _locationController.clear();
                        _selectedLatitude = null;
                        _selectedLongitude = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
          ] else if (_selectedLatitude != null &&
              _selectedLongitude != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF2563EB).withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.my_location_rounded,
                    color: Color(0xFF2563EB),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Koordinat: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openMapForVerification(),
                    child: const Text(
                      'Verifikasi di Peta',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Jadwal Pekerjaan (Opsional)',
            style: TextStyle(
              color: Color(0xFF4F4F4F),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildScheduleField(
                  icon: Icons.calendar_today_outlined,
                  label: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Pilih Tanggal',
                  onTap: _selectDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScheduleField(
                  icon: Icons.access_time_outlined,
                  label: _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Pilih Waktu',
                  onTap: _selectTime,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceSection() {
    return _buildFormCard(
      icon: Icons.attach_money_rounded,
      title: 'Harga yang Ditawarkan',
      color: const Color(0xFFF59E0B),
      child: _buildTextField(
        controller: _priceController,
        hintText: 'Contoh: 150000',
        keyboardType: TextInputType.number,
        prefixText: 'Rp ',
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Harga harus diisi';
          }
          if (double.tryParse(value) == null) {
            return 'Harga harus berupa angka';
          }
          if (double.parse(value) < 10000) {
            return 'Harga minimal Rp 10.000';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildFormCard({
    required IconData icon,
    required String title,
    required Widget child,
    Color? color,
  }) {
    final accent = color ?? const Color(0xFF2563EB);
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [accent, accent.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? label,
    String? prefixText,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF4F4F4F),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          readOnly: readOnly,
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16),
          decoration: _inputDecoration(
            hintText: hintText,
            prefixText: prefixText,
          ),
          validator: validator,
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? prefixText,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFFF1F5F9),
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      prefixText: prefixText,
      prefixStyle: const TextStyle(color: Color(0xFF1E293B), fontSize: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2D9CDB), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Widget _buildScheduleField({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF2D9CDB).withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: label.contains('Pilih')
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  bool _agreeToTerms = true;
  Widget _buildConsentSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Row(
        children: [
          Checkbox(
            value: _agreeToTerms,
            onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            activeColor: const Color(0xFF2D9CDB),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Saya setuju untuk menghubungi pekerja ini secara pribadi dan memahami pesanan tidak tampil di daftar umum.',
              style: const TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color.fromARGB(255, 34, 152, 178),
            const Color(0xFF2D9CDB),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 36, 201, 238).withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color.fromRGBO(45, 156, 219, 1).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: _submitOrder,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32),
        ),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
        ),
        label: const Text(
          'Kirim Pesanan Khusus',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
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

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2D9CDB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1E293B),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2D9CDB),
              ),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _showNotification(
        'Tanggal dipilih: ${picked.day}/${picked.month}/${picked.year}',
      );
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF2D9CDB),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1E293B),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2D9CDB),
              ),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
      _showNotification('Waktu dipilih: ${picked.format(context)}');
    }
  }

  void _submitOrder() {
    if (_formKey.currentState?.validate() ?? false) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.person_add_alt_1_rounded,
                color: const Color(0xFF2D9CDB),
              ),
              const SizedBox(width: 12),
              const Text(
                'Konfirmasi Pesanan Khusus',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Anda akan membuat pesanan khusus untuk:',
                style: TextStyle(color: Colors.grey[600], fontSize: 15),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D9CDB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFF2D9CDB).withOpacity(0.2),
                      child: Text(
                        (widget.worker['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFF2D9CDB),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.worker['name'] ?? 'Unknown',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Rating: ${widget.worker['rating'] ?? 0.0} • ${widget.worker['completed_jobs'] ?? 0} pekerjaan',
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
              ),
              const SizedBox(height: 16),
              Text(
                'Pesanan ini akan langsung dikirim ke ${widget.worker['name'] ?? 'pekerja'} dan tidak akan muncul di daftar umum.',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
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
              onPressed: _isSubmitting
                  ? null
                  : () {
                      Navigator.pop(context);
                      _createOrder();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF27AE60),
                foregroundColor: Colors.white,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Ya, Kirim Pesanan'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _createOrder() async {
    try {
      setState(() {
        _isSubmitting = true;
      });

      await _apiService.loadToken();

      if (_apiService.token == null) {
        _showNotification('Silakan login terlebih dahulu', isError: true);
        return;
      }

      // Check if user is trying to create order for themselves
      final currentUser = await _apiService.getUser();
      final currentUserId = currentUser['data']?['id']?.toString();
      final targetWorkerId = widget.worker['id']?.toString();

      if (currentUserId == targetWorkerId) {
        _showNotification(
          'Anda tidak dapat membuat pesanan untuk diri sendiri',
          isError: true,
        );
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      // Prepare job data
      Map<String, dynamic> jobData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'category': _getCategoryString(_selectedCategory),
        'price': double.parse(_priceController.text.trim()),
        'address': _locationController.text.trim(),
        'additional_info': {
          'requirements': _requirementsController.text.trim(),
          'is_private_order': true,
          'target_worker_name': widget.worker['name'],
        },
        'assigned_worker_id': widget.worker['id'], // Direct assignment
      };

      // Add scheduled time if selected
      if (_selectedDate != null && _selectedTime != null) {
        DateTime scheduledDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          _selectedTime!.hour,
          _selectedTime!.minute,
        );
        jobData['scheduled_time'] = scheduledDateTime.toIso8601String();
      }

      // Add location coordinates (mock for now)
      // Add location coordinates
      if (_selectedLatitude != null && _selectedLongitude != null) {
        jobData['latitude'] = _selectedLatitude;
        jobData['longitude'] = _selectedLongitude;
      } else {
        _showNotification('Lokasi harus dipilih dari peta', isError: true);
        setState(() {
          _isSubmitting = false;
        });
        return;
      }

      print('🚀 Creating private order with data: $jobData');

      final response = await _apiService.createJob(jobData);

      if (response['success']) {
        _showSuccessDialog();
      } else {
        _showNotification(
          response['message'] ?? 'Gagal membuat pesanan khusus',
          isError: true,
        );
      }
    } catch (e) {
      print('❌ Error creating private order: $e');
      _showNotification('Terjadi kesalahan: ${e.toString()}', isError: true);
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  String _getCategoryString(JobCategory category) {
    switch (category) {
      case JobCategory.cleaning:
        return 'cleaning';
      case JobCategory.maintenance:
        return 'maintenance';
      case JobCategory.delivery:
        return 'delivery';
      case JobCategory.tutoring:
        return 'tutoring';
      case JobCategory.photography:
        return 'photography';
      case JobCategory.cooking:
        return 'cooking';
      case JobCategory.gardening:
        return 'gardening';
      case JobCategory.petCare:
        return 'petCare';
      case JobCategory.other:
        return 'other';
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF27AE60).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF27AE60),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pesanan Khusus Berhasil Dikirim!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Pesanan khusus Anda telah dikirim langsung ke ${widget.worker['name'] ?? 'pekerja'}. Mereka akan segera menghubungi Anda.',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close success dialog
                  Navigator.pop(context, true); // Go back with a result
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Kembali ke Leaderboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            const SizedBox(width: 12),
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
            : const Color(0xFF27AE60),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Copy all location picker methods from create_job_screen.dart
  // Due to length, I'll add the essential methods here
  Future<void> _showLocationPickerDialog() async {
    List<Map<String, dynamic>> savedAddresses = [];
    try {
      final prefs = await SharedPreferences.getInstance();
      final addressesJson = prefs.getString('saved_addresses');
      if (addressesJson != null) {
        final List<dynamic> decoded = json.decode(addressesJson);
        savedAddresses = decoded
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      print('Error loading addresses: $e');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
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
                          const Expanded(
                            child: Text(
                              'Pilih Lokasi',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (savedAddresses.isNotEmpty) ...[
                        const Text(
                          'Alamat Tersimpan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: savedAddresses.length,
                            itemBuilder: (context, index) {
                              final address = savedAddresses[index];
                              final coords =
                                  address['coordinates']
                                      as Map<String, dynamic>?;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: () {
                                      final lat = coords?['lat'] ?? 0.0;
                                      final lng = coords?['lng'] ?? 0.0;
                                      setState(() {
                                        _selectedSavedAddress = address;
                                        _locationController.text =
                                            address['address'] ?? '';
                                        _selectedLatitude = lat is double
                                            ? lat
                                            : (lat is int
                                                  ? lat.toDouble()
                                                  : 0.0);
                                        _selectedLongitude = lng is double
                                            ? lng
                                            : (lng is int
                                                  ? lng.toDouble()
                                                  : 0.0);
                                      });
                                      Navigator.pop(context);
                                    },
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: const Color(0xFFE2E8F0),
                                          width: 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF10B981,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Icon(
                                              address['label'] == 'Rumah'
                                                  ? Icons.home_rounded
                                                  : address['label'] == 'Kantor'
                                                  ? Icons.work_rounded
                                                  : Icons.location_on_rounded,
                                              color: const Color(0xFF10B981),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  address['label'] ?? 'Alamat',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF1E293B),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  address['address'] ?? '',
                                                  style: const TextStyle(
                                                    color: Color(0xFF64748B),
                                                    fontSize: 12,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const Icon(
                                            Icons.arrow_forward_ios_rounded,
                                            size: 16,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 20),
                      ],
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () => _getCurrentLocation(),
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Gunakan Lokasi Saat Ini'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showManualLocationDialog();
                          },
                          icon: const Icon(Icons.search_rounded),
                          label: const Text('Cari Alamat Manual'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            side: const BorderSide(color: Color(0xFF2563EB)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Future<void> _getCurrentLocation() async {
    Navigator.pop(context);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showNotification(
          'Layanan lokasi tidak aktif. Silakan aktifkan di pengaturan.',
          isError: true,
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showNotification(
            'Izin lokasi diperlukan untuk mengambil lokasi saat ini.',
            isError: true,
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showNotification(
          'Izin lokasi ditolak permanen. Aktifkan di pengaturan.',
          isError: true,
        );
        return;
      }
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      String address = 'Lokasi tidak ditemukan';
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        address = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }
      if (mounted) Navigator.pop(context);
      _showLocationConfirmationDialog(
        address: address,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showNotification(
        'Error mengambil lokasi: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showManualLocationDialog() {
    final searchController = TextEditingController();
    bool isSearching = false;
    List<Location> searchResults = [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 20),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.search_rounded,
                                color: Color(0xFF2563EB),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Cari Alamat',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Masukkan nama jalan, kota, atau alamat',
                            prefixIcon: const Icon(Icons.location_on_rounded),
                            suffixIcon: isSearching
                                ? const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.search_rounded),
                                    onPressed: () async {
                                      if (searchController.text.trim().isEmpty) {
                                        return;
                                      }
                                      setModalState(() {
                                        isSearching = true;
                                        searchResults = [];
                                      });
                                      try {
                                        final results =
                                            await locationFromAddress(
                                              searchController.text.trim(),
                                            );
                                        setModalState(() {
                                          searchResults = results;
                                          isSearching = false;
                                        });
                                      } catch (e) {
                                        setModalState(() {
                                          isSearching = false;
                                        });
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Alamat tidak ditemukan: ${e.toString()}',
                                              ),
                                              backgroundColor: const Color(
                                                0xFFEF4444,
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                  ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                          ),
                          onSubmitted: (value) async {
                            if (value.trim().isEmpty) return;
                            setModalState(() {
                              isSearching = true;
                              searchResults = [];
                            });
                            try {
                              final results = await locationFromAddress(
                                value.trim(),
                              );
                              setModalState(() {
                                searchResults = results;
                                isSearching = false;
                              });
                            } catch (e) {
                              setModalState(() {
                                isSearching = false;
                              });
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Alamat tidak ditemukan: ${e.toString()}',
                                    ),
                                    backgroundColor: const Color(0xFFEF4444),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        if (searchResults.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          const Text(
                            'Hasil Pencarian',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 200,
                            child: ListView.builder(
                              itemCount: searchResults.length,
                              itemBuilder: (context, index) {
                                final location = searchResults[index];
                                return FutureBuilder<List<Placemark>>(
                                  future: placemarkFromCoordinates(
                                    location.latitude,
                                    location.longitude,
                                  ),
                                  builder: (context, snapshot) {
                                    String addressText =
                                        'Koordinat: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
                                    if (snapshot.hasData &&
                                        snapshot.data!.isNotEmpty) {
                                      final place = snapshot.data!.first;
                                      addressText =
                                          [
                                                place.street,
                                                place.subLocality,
                                                place.locality,
                                                place.administrativeArea,
                                                place.postalCode,
                                                place.country,
                                              ]
                                              .where(
                                                (s) =>
                                                    s != null && s.isNotEmpty,
                                              )
                                              .join(', ');
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: GestureDetector(
                                        onTap: () async {
                                          // Get full address if not yet loaded
                                          String finalAddress = addressText;
                                          if (snapshot.connectionState ==
                                                  ConnectionState.waiting ||
                                              !snapshot.hasData) {
                                            try {
                                              final placemarks =
                                                  await placemarkFromCoordinates(
                                                    location.latitude,
                                                    location.longitude,
                                                  );
                                              if (placemarks.isNotEmpty) {
                                                final place = placemarks.first;
                                                finalAddress =
                                                    [
                                                          place.street,
                                                          place.subLocality,
                                                          place.locality,
                                                          place
                                                              .administrativeArea,
                                                          place.postalCode,
                                                          place.country,
                                                        ]
                                                        .where(
                                                          (s) =>
                                                              s != null &&
                                                              s.isNotEmpty,
                                                        )
                                                        .join(', ');
                                              }
                                            } catch (e) {
                                              // Use coordinates if geocoding fails
                                              finalAddress =
                                                  'Koordinat: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
                                            }
                                          }

                                          if (mounted) {
                                            Navigator.pop(context);
                                            _showLocationConfirmationDialog(
                                              address: finalAddress,
                                              latitude: location.latitude,
                                              longitude: location.longitude,
                                            );
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE2E8F0),
                                              width: 1,
                                            ),
                                          ),
                                          child:
                                              snapshot.connectionState ==
                                                  ConnectionState.waiting
                                              ? Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_rounded,
                                                      color: Color(0xFF2563EB),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          const Text(
                                                            'Memuat alamat...',
                                                            style: TextStyle(
                                                              color: Color(
                                                                0xFF1E293B,
                                                              ),
                                                              fontSize: 13,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF94A3B8,
                                                                  ),
                                                                  fontSize: 11,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const SizedBox(
                                                      width: 16,
                                                      height: 16,
                                                      child: CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              Color(0xFF2563EB),
                                                            ),
                                                      ),
                                                    ),
                                                  ],
                                                )
                                              : Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on_rounded,
                                                      color: Color(0xFF2563EB),
                                                      size: 20,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            addressText,
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF1E293B,
                                                                  ),
                                                                  fontSize: 13,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                          const SizedBox(
                                                            height: 4,
                                                          ),
                                                          Text(
                                                            '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                                                            style:
                                                                const TextStyle(
                                                                  color: Color(
                                                                    0xFF94A3B8,
                                                                  ),
                                                                  fontSize: 11,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    const Icon(
                                                      Icons
                                                          .arrow_forward_ios_rounded,
                                                      size: 16,
                                                      color: Color(0xFF94A3B8),
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLocationConfirmationDialog({
    required String address,
    required double latitude,
    required double longitude,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Color(0xFF10B981),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Konfirmasi Lokasi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF2563EB),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          address,
                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.my_location_rounded,
                        color: Color(0xFF64748B),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Koordinat: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMapForVerification(latitude, longitude),
                icon: const Icon(Icons.map_rounded, size: 18),
                label: const Text('Verifikasi di Peta'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _selectedSavedAddress = null;
                _locationController.text = address;
                _selectedLatitude = latitude;
                _selectedLongitude = longitude;
              });
              Navigator.pop(context);
              _showNotification('Lokasi berhasil dipilih', isError: false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Gunakan Lokasi Ini',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openMapForVerification([double? lat, double? lng]) async {
    final latitude = lat ?? _selectedLatitude ?? 0.0;
    final longitude = lng ?? _selectedLongitude ?? 0.0;
    if (latitude == 0.0 && longitude == 0.0) {
      _showNotification('Koordinat tidak valid', isError: true);
      return;
    }
    try {
      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showNotification('Tidak dapat membuka peta', isError: true);
      }
    } catch (e) {
      _showNotification('Error membuka peta: ${e.toString()}', isError: true);
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
