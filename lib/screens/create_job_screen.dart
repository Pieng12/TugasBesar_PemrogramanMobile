import 'package:flutter/material.dart';
import '../models/job_model.dart';

class CreateJobScreen extends StatefulWidget {
  final Map<String, dynamic>? targetWorker;

  const CreateJobScreen({super.key, this.targetWorker});

  @override
  State<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends State<CreateJobScreen>
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
      appBar: AppBar(
        title: const Text(
          'Buat Pesanan Baru',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary,
                Theme.of(context).colorScheme.primary.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(30),
            ),
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showHelpDialog();
            },
            icon: const Icon(Icons.help_outline_rounded),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.targetWorker != null) _buildTargetWorkerInfo(),
                _buildHeader(),
                // Category Selection
                _buildCategorySection(),
                const SizedBox(height: 24),
                // Job Title
                _buildTitleSection(),
                const SizedBox(height: 24),
                // Description & Requirements
                _buildDescriptionSection(),
                const SizedBox(height: 24),
                // Location & Schedule
                _buildLocationSection(),
                const SizedBox(height: 24),
                // Price
                _buildPriceSection(),
                const SizedBox(height: 32),
                // Submit Button
                _buildSubmitButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTargetWorkerInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.person_pin_circle_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pesanan Khusus Untuk:',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.targetWorker!['name'] ?? 'Pekerja',
                    style: const TextStyle(
                      color: Color(0xFF1E293B),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
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

  Widget _buildCategorySection() {
    return _buildFormSection(
      icon: Icons.category_rounded,
      title: 'Kategori Layanan',
      subtitle: 'Pilih kategori yang paling sesuai',
      child: DropdownButtonHideUnderline(
        child: DropdownButton<JobCategory>(
          value: _selectedCategory,
          isExpanded: true,
          style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16),
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
        ),
      ),
    );
  }

  Widget _buildTitleSection() {
    return _buildFormSection(
      icon: Icons.title_rounded,
      title: 'Judul Pekerjaan',
      subtitle: 'Buat judul yang singkat dan jelas',
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
    return _buildFormSection(
      icon: Icons.description_rounded,
      title: 'Detail Pekerjaan',
      subtitle: 'Jelaskan kebutuhan Anda secara rinci',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Deskripsi',
            style: TextStyle(
              color: Color(0xFF4F4F4F),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _descriptionController,
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
          const Text(
            'Persyaratan',
            style: TextStyle(
              color: Color(0xFF4F4F4F),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _requirementsController,
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
    return _buildFormSection(
      icon: Icons.location_on_outlined,
      title: 'Lokasi & Jadwal',
      subtitle: 'Tentukan di mana dan kapan pekerjaan dilakukan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Alamat Lokasi',
            style: TextStyle(
              color: Color(0xFF4F4F4F),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            controller: _locationController,
            hintText: 'Contoh: Jl. Sudirman No. 123, Jakarta Selatan',
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Alamat lokasi harus diisi';
              }
              return null;
            },
          ),
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
                  icon: Icons.calendar_today,
                  label: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Pilih Tanggal',
                  onTap: _selectDate,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildScheduleField(
                  icon: Icons.access_time,
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
    return _buildFormSection(
      icon: Icons.attach_money_rounded,
      title: 'Harga yang Ditawarkan',
      subtitle: 'Tentukan anggaran yang sesuai',
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

  Widget _buildFormSection({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
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
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
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
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24, thickness: 0.5), // This was misplaced
          child, // The child widget for the form section
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? prefixText,
    TextInputType? keyboardType,
    int? maxLines,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16),
      decoration: InputDecoration(
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
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: validator,
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
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: label.contains('Pilih')
                      ? Colors.grey[500]
                      : const Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Center(
      child: SizedBox(
        width: 300,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _submitJob,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 5,
            shadowColor: const Color(0xFF10B981).withOpacity(0.4),
            padding: const EdgeInsets.symmetric(horizontal: 32),
          ),
          icon: const Icon(
            Icons.check_circle_outline_rounded,
            color: Colors.white,
          ),
          label: const Text(
            'Buat Pesanan',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Text(
        'Lengkapi detail di bawah ini untuk membuat pesanan layanan baru.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey[600], height: 1.5),
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
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1E293B),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: const Color(0xFF1E293B),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
              ),
            ), dialogTheme: DialogThemeData(backgroundColor: Colors.white),
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

  void _submitJob() {
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
                Icons.task_alt_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              const Text(
                'Konfirmasi Pesanan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: const Text(
            'Apakah Anda yakin ingin membuat pesanan ini?',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
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
                Navigator.pop(context);
                // Simulate API call
                Future.delayed(const Duration(seconds: 1), () {
                  _showSuccessDialog();
                });
              },
              child: const Text('Ya, Lanjutkan'),
            ),
          ],
        ),
      );
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
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF10B981),
                size: 56,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Pesanan Berhasil Dibuat!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pesanan Anda telah dikirim. Anda akan diberi tahu jika ada pekerja yang tertarik.',
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
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to previous screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Kembali ke Beranda',
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

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(
              Icons.tips_and_updates_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Text(
              'Tips Membuat Pesanan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpItem(
              'Judul yang Jelas',
              'Gunakan judul yang spesifik dan mudah dipahami.',
            ),
            _buildHelpItem(
              'Deskripsi Detail',
              'Jelaskan kebutuhan Anda dengan lengkap agar pekerja mengerti.',
            ),
            _buildHelpItem(
              'Harga Wajar',
              'Tentukan harga yang kompetitif dan sesuai dengan tingkat kesulitan pekerjaan.',
            ),
            _buildHelpItem(
              'Jadwal Fleksibel',
              'Jika memungkinkan, berikan opsi jadwal yang fleksibel.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Mengerti',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
