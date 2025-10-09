import 'package:flutter/material.dart';
import 'home_screen.dart';

class RegisterWorkerScreen extends StatefulWidget {
  const RegisterWorkerScreen({super.key});

  @override
  State<RegisterWorkerScreen> createState() => _RegisterWorkerScreenState();
}

class _RegisterWorkerScreenState extends State<RegisterWorkerScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _addressController = TextEditingController();
  final _experienceController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  final List<String> _selectedCategories = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final List<Map<String, dynamic>> _categories = [
    {
      'value': 'cleaning',
      'label': 'Bersih-bersih',
      'icon': Icons.cleaning_services,
      'color': Color(0xFF27AE60),
    },
    {
      'value': 'delivery',
      'label': 'Antar-Jemput',
      'icon': Icons.delivery_dining,
      'color': Color(0xFF2D9CDB),
    },
    {
      'value': 'maintenance',
      'label': 'Perbaikan',
      'icon': Icons.build,
      'color': Color(0xFFF2C94C),
    },
    {
      'value': 'gardening',
      'label': 'Kebun',
      'icon': Icons.local_florist,
      'color': Color(0xFF27AE60),
    },
    {
      'value': 'cooking',
      'label': 'Memasak',
      'icon': Icons.restaurant,
      'color': Color(0xFFEB5757),
    },
    {
      'value': 'tutoring',
      'label': 'Edukasi',
      'icon': Icons.school,
      'color': Color(0xFF2D9CDB),
    },
    {
      'value': 'photography',
      'label': 'Fotografi',
      'icon': Icons.camera_alt,
      'color': Color(0xFFF2C94C),
    },
    {
      'value': 'petCare',
      'label': 'Perawatan Hewan',
      'icon': Icons.pets,
      'color': Color(0xFF27AE60),
    },
  ];

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
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _addressController.dispose();
    _experienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Color(0xFF4F4F4F),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Daftar Worker',
          style: TextStyle(
            color: const Color(0xFF4F4F4F),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 20),
              // Header
              _buildHeader(),
              const SizedBox(height: 30),
              // Form Register
              _buildRegisterForm(),
              const SizedBox(height: 30),
              // Login Link
              _buildLoginLink(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          children: [
            // Icon Container
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF2D9CDB), // Biru Cerah untuk Brand
                    Color(0xFF1E88E5), // Biru yang lebih gelap
                  ],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2D9CDB).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                size: 50,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Daftar sebagai Worker',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF4F4F4F),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Buat akun worker untuk menawarkan layanan',
              style: TextStyle(
                fontSize: 16,
                color: const Color(0xFFBDBDBD),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name Field
                _buildInputField(
                  controller: _nameController,
                  label: 'Nama Lengkap',
                  hint: 'Masukkan nama lengkap Anda',
                  icon: Icons.person_outline_rounded,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nama tidak boleh kosong';
                    }
                    if (value.length < 2) {
                      return 'Nama minimal 2 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Email Field
                _buildInputField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'Masukkan email Anda',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Email tidak boleh kosong';
                    }
                    if (!RegExp(
                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                    ).hasMatch(value)) {
                      return 'Format email tidak valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Phone Field
                _buildInputField(
                  controller: _phoneController,
                  label: 'Nomor Telepon',
                  hint: 'Masukkan nomor telepon Anda',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Nomor telepon tidak boleh kosong';
                    }
                    if (value.length < 10) {
                      return 'Nomor telepon minimal 10 digit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Address Field
                _buildInputField(
                  controller: _addressController,
                  label: 'Alamat',
                  hint: 'Masukkan alamat lengkap Anda',
                  icon: Icons.location_on_outlined,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Alamat tidak boleh kosong';
                    }
                    if (value.length < 10) {
                      return 'Alamat minimal 10 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Experience Field
                _buildInputField(
                  controller: _experienceController,
                  label: 'Pengalaman (Tahun)',
                  hint: 'Masukkan tahun pengalaman Anda',
                  icon: Icons.work_outline_rounded,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Pengalaman tidak boleh kosong';
                    }
                    if (int.tryParse(value) == null) {
                      return 'Masukkan angka yang valid';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Password Field
                _buildInputField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Masukkan password Anda',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password tidak boleh kosong';
                    }
                    if (value.length < 6) {
                      return 'Password minimal 6 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Confirm Password Field
                _buildInputField(
                  controller: _confirmPasswordController,
                  label: 'Konfirmasi Password',
                  hint: 'Ulangi password Anda',
                  icon: Icons.lock_outline_rounded,
                  isPassword: true,
                  isConfirmPassword: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Konfirmasi password tidak boleh kosong';
                    }
                    if (value != _passwordController.text) {
                      return 'Password tidak sama';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Service Categories
                _buildServiceCategories(),
                const SizedBox(height: 20),
                // Terms and Conditions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF2D9CDB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: const Color(0xFF4F4F4F),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            children: [
                              const TextSpan(text: 'Saya menyetujui '),
                              TextSpan(
                                text: 'Syarat dan Ketentuan',
                                style: TextStyle(
                                  color: const Color(0xFF2D9CDB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' dan '),
                              TextSpan(
                                text: 'Kebijakan Privasi',
                                style: TextStyle(
                                  color: const Color(0xFF2D9CDB),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Register Button
                _buildRegisterButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmPassword = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: const Color(0xFF4F4F4F),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: isPassword
              ? (!_isPasswordVisible && !isConfirmPassword) ||
                    (!_isConfirmPasswordVisible && isConfirmPassword)
              : false,
          validator: validator,
          style: const TextStyle(fontSize: 16, color: Color(0xFF4F4F4F)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: const Color(0xFFBDBDBD), fontSize: 16),
            prefixIcon: Icon(icon, color: const Color(0xFF2D9CDB), size: 22),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      (isConfirmPassword
                              ? !_isConfirmPasswordVisible
                              : !_isPasswordVisible)
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: const Color(0xFFBDBDBD),
                    ),
                    onPressed: () {
                      setState(() {
                        if (isConfirmPassword) {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        } else {
                          _isPasswordVisible = !_isPasswordVisible;
                        }
                      });
                    },
                  )
                : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: const Color(0xFFE0E0E0), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: const Color(0xFFE0E0E0), width: 1),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2D9CDB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEB5757), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCategories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategori Layanan',
          style: TextStyle(
            color: const Color(0xFF4F4F4F),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pilih kategori layanan yang Anda tawarkan',
          style: TextStyle(
            color: const Color(0xFFBDBDBD),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: _categories.map((category) {
            final isSelected = _selectedCategories.contains(category['value']);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(category['value']);
                  } else {
                    _selectedCategories.add(category['value']);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (category['color'] as Color).withOpacity(0.1)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? category['color'] as Color
                        : const Color(0xFFE0E0E0),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      color: isSelected
                          ? category['color'] as Color
                          : const Color(0xFFBDBDBD),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      category['label'] as String,
                      style: TextStyle(
                        color: isSelected
                            ? category['color'] as Color
                            : const Color(0xFF4F4F4F),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selectedCategories.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Pilih minimal satu kategori layanan',
              style: TextStyle(
                color: const Color(0xFFEB5757),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF2D9CDB), // Biru Cerah untuk Brand
            Color(0xFF1E88E5), // Biru yang lebih gelap
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2D9CDB).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: (_agreeToTerms && _selectedCategories.isNotEmpty)
            ? () {
                if (_formKey.currentState!.validate()) {
                  _showNotification('Registrasi berhasil!');
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.work_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Daftar sebagai Worker',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Sudah punya akun? ',
              style: TextStyle(
                color: const Color(0xFF4F4F4F),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Masuk',
                style: TextStyle(
                  color: const Color(0xFF2D9CDB),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
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
        backgroundColor: const Color(0xFF2D9CDB), // Biru Cerah untuk Brand
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
