import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:servify/screens/forgot_password_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import '../services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  bool _isLoginMode = true;
  bool _isLoading = false;

  // Controllers
  final _nameController = TextEditingController();
  final _nikController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Focus Nodes
  final _nameFocusNode = FocusNode();
  final _nikFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _addressFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _rememberMe = false;
  bool _isGettingLocation = false;
  bool _isSubmittingComplaint = false;
  double? _selectedLatitude;
  double? _selectedLongitude;
  String? _selectedGender;
  DateTime? _selectedDateOfBirth;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  final ApiService _apiService = ApiService();

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
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
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
    _scrollController.dispose();
    _nameController.dispose();
    _nikController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameFocusNode.dispose();
    _nikFocusNode.dispose();
    _emailFocusNode.dispose();
    _phoneFocusNode.dispose();
    _addressFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _apiService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response['success']) {
        // Simpan preferensi "remember me"
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('remember_me', _rememberMe);

        _showNotification('Login berhasil!', isSuccess: true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        _showNotification(response['message'] ?? 'Login gagal!');
      }
    } on ApiException catch (e) {
      if (e.statusCode == 403 && e.data is Map<String, dynamic>) {
        _showBannedDialog(Map<String, dynamic>.from(e.data));
      } else {
        _showNotification(e.message);
      }
    } catch (e) {
      _showNotification('Login gagal: Email atau password salah.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToFirstError() {
    // Find first field with error
    FocusNode? firstErrorFocus;

    if (!_isLoginMode) {
      if (_nameController.text.trim().isEmpty ||
          _nameController.text.trim().length < 2) {
        firstErrorFocus = _nameFocusNode;
      } else if (_nikController.text.trim().isNotEmpty &&
          _nikController.text.trim().length < 16) {
        firstErrorFocus = _nikFocusNode;
      } else if (_emailController.text.trim().isEmpty ||
          !RegExp(
            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
          ).hasMatch(_emailController.text.trim())) {
        firstErrorFocus = _emailFocusNode;
      } else if (_phoneController.text.trim().isNotEmpty &&
          _phoneController.text.trim().length < 10) {
        firstErrorFocus = _phoneFocusNode;
      } else if (_addressController.text.trim().isEmpty ||
          _selectedLatitude == null ||
          _selectedLongitude == null) {
        firstErrorFocus = _addressFocusNode;
      } else if (_passwordController.text.isEmpty ||
          _passwordController.text.length < 8) {
        firstErrorFocus = _passwordFocusNode;
      } else if (_confirmPasswordController.text.isEmpty ||
          _confirmPasswordController.text != _passwordController.text) {
        firstErrorFocus = _confirmPasswordFocusNode;
      }
    } else {
      if (_emailController.text.trim().isEmpty ||
          !RegExp(
            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
          ).hasMatch(_emailController.text.trim())) {
        firstErrorFocus = _emailFocusNode;
      } else if (_passwordController.text.isEmpty ||
          _passwordController.text.length < 6) {
        firstErrorFocus = _passwordFocusNode;
      }
    }

    if (firstErrorFocus != null) {
      // Scroll to field
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          // Calculate approximate position based on field order
          double offset = 0;
          if (firstErrorFocus == _nameFocusNode) {
            offset = 0;
          } else if (firstErrorFocus == _nikFocusNode) {
            offset = 80;
          } else if (firstErrorFocus == _emailFocusNode) {
            offset = _isLoginMode ? 0 : 160;
          } else if (firstErrorFocus == _phoneFocusNode) {
            offset = 240;
          } else if (firstErrorFocus == _addressFocusNode) {
            offset = 320;
          } else if (firstErrorFocus == _passwordFocusNode) {
            offset = _isLoginMode ? 100 : 500;
          } else if (firstErrorFocus == _confirmPasswordFocusNode) {
            offset = 600;
          }

          _scrollController.animateTo(
            offset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }

        // Focus the field
        Future.delayed(const Duration(milliseconds: 350), () {
          firstErrorFocus?.requestFocus();
        });
      });
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      _scrollToFirstError();
      return;
    }
    if (!_agreeToTerms) {
      _showNotification('Anda harus menyetujui syarat dan ketentuan!');
      // Scroll to terms checkbox
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? dateOfBirthStr;
      if (_selectedDateOfBirth != null) {
        dateOfBirthStr = DateFormat('yyyy-MM-dd').format(_selectedDateOfBirth!);
      }

      final response = await _apiService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        nik: _nikController.text.trim().isNotEmpty
            ? _nikController.text.trim()
            : null,
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        address: _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        dateOfBirth: dateOfBirthStr,
        gender: _selectedGender,
      );

      if (response['success']) {
        if (_selectedLatitude != null &&
            _selectedLongitude != null &&
            _addressController.text.trim().isNotEmpty) {
          await _saveInitialAddress();
        }

        _showNotification('Registrasi berhasil!', isSuccess: true);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        // This is a fallback for non-standard errors from the API
        _showNotification(response['message'] ?? 'Registrasi gagal!');
      }
    } on ApiException catch (e) {
      // Handle specific API validation errors
      if (e.statusCode == 422 && e.errors != null) {
        final errors = e.errors!;
        String errorMessage = 'Harap periksa kembali data Anda.'; // Default message
        if (errors.containsKey('email')) {
          errorMessage = 'Email sudah digunakan. Silahkan login.';
        } else if (errors.containsKey('nik')) {
          errorMessage = 'NIK sudah terdaftar pada akun lain.';
        } else if (errors.entries.isNotEmpty) {
          // Get the first error message from the backend
          errorMessage = errors.entries.first.value[0];
        }
        _showNotification(errorMessage);
      } else {
        // Handle other API errors (like 500, 404, etc.)
        _showNotification(e.message);
      }
    } catch (e) {
      // Handle generic errors (network, etc.)
      _showNotification('Terjadi kesalahan. Periksa koneksi internet Anda.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveInitialAddress() async {
    try {
      final label = 'Alamat Utama';
      final recipient = _nameController.text.trim().isNotEmpty
          ? _nameController.text.trim()
          : 'Saya';
      final phone = _phoneController.text.trim();

      await _apiService.createAddress({
        'label': label,
        'address': _addressController.text.trim(),
        'recipient': recipient,
        'phone': phone.isNotEmpty ? phone : '-',
        'notes': 'Alamat ditambahkan saat registrasi',
        'latitude': _selectedLatitude,
        'longitude': _selectedLongitude,
        'is_default': true,
      });
    } catch (e) {
      debugPrint('Failed to save initial address: $e');
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateOfBirth = picked);
    }
  }

  void _toggleMode() {
    setState(() {
      _isLoginMode = !_isLoginMode;
      _formKey.currentState?.reset();
      _agreeToTerms = false;
      _selectedGender = null;
      _selectedDateOfBirth = null;
      _selectedLatitude = null;
      _selectedLongitude = null;
      _addressController.clear();
    });
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 40),
                    _buildModeToggle(),
                    const SizedBox(height: 32),
                    _buildForm(),
                    const SizedBox(height: 24),
                    _buildActionButton(),
                    const SizedBox(height: 20),
                    _buildSwitchModeText(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 50,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _isLoginMode ? 'Selamat Datang' : 'Buat Akun Baru',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E293B),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _isLoginMode
              ? 'Masuk ke akun Anda untuk melanjutkan'
              : 'Lengkapi data berikut untuk mendaftar',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
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
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              label: 'Masuk',
              isActive: _isLoginMode,
              onTap: () {
                if (!_isLoginMode) _toggleMode();
              },
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              label: 'Daftar',
              isActive: !_isLoginMode,
              onTap: () {
                if (_isLoginMode) _toggleMode();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Container(
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isLoginMode) ...[
            _buildInputField(
              controller: _nameController,
              focusNode: _nameFocusNode,
              label: 'Nama Lengkap',
              hint: 'Masukkan nama lengkap Anda',
              icon: Icons.person_outline_rounded,
              validator: (value) {
                if (!_isLoginMode && (value == null || value.isEmpty)) {
                  return 'Nama tidak boleh kosong';
                }
                if (!_isLoginMode && value != null && value.length < 2) {
                  return 'Nama minimal 2 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildInputField(
              controller: _nikController,
              focusNode: _nikFocusNode,
              label: 'NIK',
              hint: 'Masukkan NIK Anda (opsional)',
              icon: Icons.badge_outlined,
              keyboardType: TextInputType.number,
              maxLength: 16,
              validator: (value) {
                if (!_isLoginMode &&
                    value != null &&
                    value.isNotEmpty &&
                    value.length < 16) {
                  return 'NIK harus 16 digit';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
          ],
          _buildInputField(
            controller: _emailController,
            focusNode: _emailFocusNode,
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
          if (!_isLoginMode) ...[
            const SizedBox(height: 20),
            _buildInputField(
              controller: _phoneController,
              focusNode: _phoneFocusNode,
              label: 'Nomor Telepon',
              hint: 'Masukkan nomor telepon Anda',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              maxLength: 15,
              validator: (value) {
                if (!_isLoginMode &&
                    value != null &&
                    value.isNotEmpty &&
                    value.length < 10) {
                  return 'Nomor telepon minimal 10 digit';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _buildAddressField(),
            const SizedBox(height: 20),
            _buildDateOfBirthField(),
            const SizedBox(height: 20),
            _buildGenderField(),
            const SizedBox(height: 20),
          ],
          _buildInputField(
            controller: _passwordController,
            focusNode: _passwordFocusNode,
            label: 'Password',
            hint: 'Masukkan password Anda',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password tidak boleh kosong';
              }
              if (!_isLoginMode && value.length < 8) {
                return 'Password minimal 8 karakter';
              }
              if (_isLoginMode && value.length < 6) {
                return 'Password minimal 6 karakter';
              }
              return null;
            },
          ),
          if (_isLoginMode) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFF2563EB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const Text(
                      'Ingat saya',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to Forgot Password Screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => ForgotPasswordScreen()),
                    );
                  },
                  child: const Text(
                    'Lupa Password?',
                    style: TextStyle(
                      color: Color(0xFF2563EB),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (!_isLoginMode) ...[
            const SizedBox(height: 20),
            _buildInputField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              label: 'Konfirmasi Password',
              hint: 'Ulangi password Anda',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              isConfirmPassword: true,
              validator: (value) {
                if (!_isLoginMode && (value == null || value.isEmpty)) {
                  return 'Konfirmasi password tidak boleh kosong';
                }
                if (!_isLoginMode && value != _passwordController.text) {
                  return 'Password tidak sama';
                }
                return null;
              },
            ),
          ],
          if (!_isLoginMode) ...[
            const SizedBox(height: 20),
            _buildTermsCheckbox(),
          ],
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isConfirmPassword = false,
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          obscureText: isPassword
              ? (isConfirmPassword
                    ? !_isConfirmPasswordVisible
                    : !_isPasswordVisible)
              : false,
          maxLines: maxLines,
          maxLength: maxLength,
          validator: validator,
          style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            counterText: '', // Hide the default counter
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
            prefixIcon: Icon(icon, color: const Color(0xFF2563EB), size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      (isConfirmPassword
                              ? _isConfirmPasswordVisible
                              : _isPasswordVisible)
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: Colors.grey[400],
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
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
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

  Widget _buildDateOfBirthField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tanggal Lahir',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDateOfBirth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF2563EB),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  _selectedDateOfBirth != null
                      ? DateFormat('dd MMMM yyyy').format(_selectedDateOfBirth!)
                      : 'Pilih tanggal lahir',
                  style: TextStyle(
                    fontSize: 15,
                    color: _selectedDateOfBirth != null
                        ? const Color(0xFF1E293B)
                        : Colors.grey[400],
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_drop_down, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Jenis Kelamin',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildGenderOption('male', 'Laki-laki')),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderOption('female', 'Perempuan')),
          ],
        ),
      ],
    );
  }

  Widget _buildGenderOption(String value, String label) {
    final isSelected = _selectedGender == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2563EB).withOpacity(0.1)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[200]!,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isSelected ? const Color(0xFF2563EB) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agreeToTerms,
          onChanged: (value) => setState(() => _agreeToTerms = value ?? false),
          activeColor: const Color(0xFF2563EB),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                children: [
                  const TextSpan(text: 'Saya menyetujui '),
                  TextSpan(
                    text: 'Syarat dan Ketentuan',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' dan '),
                  TextSpan(
                    text: 'Kebijakan Privasi',
                    style: const TextStyle(
                      color: Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : (_isLoginMode ? _handleLogin : _handleRegister),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _isLoginMode
                        ? Icons.login_rounded
                        : Icons.person_add_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isLoginMode ? 'Masuk' : 'Daftar',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSwitchModeText() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isLoginMode ? 'Belum punya akun? ' : 'Sudah punya akun? ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        GestureDetector(
          onTap: _toggleMode,
          child: Text(
            _isLoginMode ? 'Daftar' : 'Masuk',
            style: const TextStyle(
              color: Color(0xFF2563EB),
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alamat',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _addressController,
          focusNode: _addressFocusNode,
          readOnly: true,
          validator: (value) {
            if (!_isLoginMode) {
              if (value == null || value.isEmpty) {
                return 'Alamat tidak boleh kosong';
              }
              if (_selectedLatitude == null || _selectedLongitude == null) {
                return 'Pilih lokasi dari peta terlebih dahulu';
              }
            }
            return null;
          },
          style: const TextStyle(fontSize: 15, color: Color(0xFF1E293B)),
          decoration: InputDecoration(
            hintText: _selectedLatitude != null
                ? 'Alamat telah dipilih'
                : 'Pilih lokasi dari peta',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
            prefixIcon: const Icon(
              Icons.location_on_rounded,
              color: Color(0xFF2563EB),
              size: 20,
            ),
            suffixIcon: IconButton(
              icon: const Icon(Icons.map_rounded, color: Color(0xFF2563EB)),
              onPressed: _showLocationPickerDialog,
            ),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        if (_selectedLatitude != null && _selectedLongitude != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Koordinat: ${_selectedLatitude!.toStringAsFixed(6)}, ${_selectedLongitude!.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ),
      ],
    );
  }

  void _showLocationPickerDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.my_location_rounded),
                    label: Text(
                      _isGettingLocation
                          ? 'Mengambil lokasi...'
                          : 'Gunakan Lokasi Saat Ini',
                    ),
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
                    icon: const Icon(Icons.edit_location_alt_rounded),
                    label: const Text('Masukkan Alamat Manual'),
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
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isGettingLocation = true;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showNotification(
          'Layanan lokasi tidak aktif. Silakan aktifkan di pengaturan.',
          isSuccess: false,
        );
        setState(() {
          _isGettingLocation = false;
        });
        Navigator.pop(context);
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showNotification(
            'Izin lokasi diperlukan untuk mengambil lokasi saat ini.',
            isSuccess: false,
          );
          setState(() {
            _isGettingLocation = false;
          });
          Navigator.pop(context);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showNotification(
          'Izin lokasi ditolak permanen. Aktifkan di pengaturan.',
          isSuccess: false,
        );
        setState(() {
          _isGettingLocation = false;
        });
        Navigator.pop(context);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // Get address from coordinates
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

      setState(() {
        _isGettingLocation = false;
        _selectedLatitude = position.latitude;
        _selectedLongitude = position.longitude;
        _addressController.text = address;
      });

      Navigator.pop(context);
      _showLocationConfirmationDialog(
        address,
        position.latitude,
        position.longitude,
      );
    } catch (e) {
      setState(() {
        _isGettingLocation = false;
      });
      Navigator.pop(context);
      _showNotification(
        'Error mengambil lokasi: ${e.toString()}',
        isSuccess: false,
      );
    }
  }

  void _showManualLocationDialog() {
    final searchController = TextEditingController();

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
                              Icons.edit_location_alt_rounded,
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
                          labelText: 'Masukkan alamat',
                          hintText: 'Contoh: Jl. Sudirman No. 123, Jakarta',
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                        ),
                        onSubmitted: (value) async {
                          if (value.trim().isEmpty) return;
                          await _searchAddress(value.trim());
                        },
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (searchController.text.trim().isEmpty) {
                              _showNotification(
                                'Masukkan alamat terlebih dahulu',
                                isSuccess: false,
                              );
                              return;
                            }
                            await _searchAddress(searchController.text.trim());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cari'),
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

  Future<void> _searchAddress(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);

      if (locations.isEmpty) {
        _showNotification('Alamat tidak ditemukan', isSuccess: false);
        return;
      }

      final location = locations.first;
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      String fullAddress = address;
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        fullAddress = [
          place.street,
          place.subLocality,
          place.locality,
          place.administrativeArea,
          place.postalCode,
          place.country,
        ].where((s) => s != null && s.isNotEmpty).join(', ');
      }

      setState(() {
        _selectedLatitude = location.latitude;
        _selectedLongitude = location.longitude;
        _addressController.text = fullAddress;
      });

      Navigator.pop(context); // Close search dialog
      _showLocationConfirmationDialog(
        fullAddress,
        location.latitude,
        location.longitude,
      );
    } catch (e) {
      _showNotification(
        'Error mencari alamat: ${e.toString()}',
        isSuccess: false,
      );
    }
  }

  void _showLocationConfirmationDialog(
    String address,
    double latitude,
    double longitude,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Konfirmasi Lokasi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(address, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 8),
            Text(
              'Koordinat: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
            ),
            child: const Text('Konfirmasi'),
          ),
        ],
      ),
    );
  }

  void _showBannedDialog(Map<String, dynamic> banData) {
    final reason =
        banData['ban_reason'] ??
        banData['reason'] ??
        'Akun Anda telah diblokir oleh admin.';
    final bannedUntilRaw = banData['banned_until'];
    DateTime? bannedUntil;
    if (bannedUntilRaw != null) {
      bannedUntil = DateTime.tryParse(bannedUntilRaw.toString());
    }
    final latestComplaint = banData['complaint'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.report_gmailerrorred_rounded,
                color: Color(0xFFEF4444),
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Akun Diblokir',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reason,
              style: const TextStyle(color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 12),
            if (bannedUntil != null)
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat(
                      'dd MMM yyyy, HH:mm',
                      'id_ID',
                    ).format(bannedUntil),
                    style: const TextStyle(
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(
                    Icons.block_rounded,
                    size: 16,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Blokir Permanen',
                    style: TextStyle(
                      color: Color(0xFFEF4444),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            if (latestComplaint != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Komplain Terakhir',
                      style: TextStyle(
                        color: Color(0xFF1E293B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      (latestComplaint['status'] ?? 'pending')
                          .toString()
                          .toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (latestComplaint['admin_notes'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          latestComplaint['admin_notes'].toString(),
                          style: const TextStyle(
                            color: Color(0xFF475569),
                            height: 1.3,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showComplaintSheet();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Ajukan Komplain'),
          ),
        ],
      ),
    );
  }

  void _showComplaintSheet() {
    final reasonController = TextEditingController();
    final evidenceController = TextEditingController();
    String? errorMessage;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setSheetState) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.forum_rounded,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Ajukan Komplain',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Jelaskan alasan Anda',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      maxLines: 5,
                      onChanged: (value) {
                        if (errorMessage != null && value.trim().length >= 20) {
                          setSheetState(() => errorMessage = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText:
                            'Tuliskan penjelasan lengkap minimal 20 karakter',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: errorMessage != null
                                ? const Color(0xFFEF4444)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        errorText: errorMessage,
                        errorMaxLines: 2,
                      ),
                    ),
                    if (errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: Color(0xFFEF4444),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    const Text(
                      'Link bukti pendukung (opsional)',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: evidenceController,
                      decoration: InputDecoration(
                        hintText: 'Masukkan link Google Drive / lainnya',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmittingComplaint
                            ? null
                            : () async {
                                final explanation = reasonController.text
                                    .trim();
                                if (explanation.length < 20) {
                                  setSheetState(() {
                                    errorMessage =
                                        'Mohon berikan penjelasan minimal 20 karakter.';
                                  });
                                  FocusScope.of(context).unfocus();
                                  return;
                                }
                                setSheetState(
                                  () => _isSubmittingComplaint = true,
                                );
                                final success = await _submitBanComplaint(
                                  explanation,
                                  evidenceUrl:
                                      evidenceController.text.trim().isEmpty
                                      ? null
                                      : evidenceController.text.trim(),
                                );
                                setSheetState(
                                  () => _isSubmittingComplaint = false,
                                );
                                if (success && context.mounted)
                                  Navigator.pop(context);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSubmittingComplaint
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                'Kirim Komplain',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<bool> _submitBanComplaint(
    String explanation, {
    String? evidenceUrl,
  }) async {
    setState(() {
      _isSubmittingComplaint = true;
    });
    try {
      final response = await _apiService.submitBanComplaint(
        email: _emailController.text.trim(),
        reason: explanation,
        evidenceUrl: evidenceUrl,
      );
      _showNotification(
        response['message'] ?? 'Komplain berhasil dikirim.',
        isSuccess: true,
      );
      return true;
    } on ApiException catch (e) {
      _showNotification(e.message);
      return false;
    } catch (e) {
      _showNotification('Gagal mengirim komplain: ${e.toString()}');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingComplaint = false;
        });
      }
    }
  }

  void _showNotification(String message, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_outline
                  : Icons.error_outline_rounded,
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
        backgroundColor: isSuccess
            ? const Color(0xFF10B981)
            : const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
