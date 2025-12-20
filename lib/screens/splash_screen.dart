import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import '../widgets/servify_logo.dart';
import '../services/api_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late AnimationController _rippleController;
  late Animation<double> _rippleAnimation;
  late AnimationController _floatingController;
  late Animation<double> _floatingAnimation;
  late AnimationController _textController;
  late Animation<double> _textOpacity;

  final ApiService _apiService = ApiService();
  final List<FloatingIcon> _floatingIcons = [];

  @override
  void initState() {
    super.initState();
    _initializeFloatingIcons();
    _initializeAnimations();
    _checkAuthState();
  }

  void _initializeFloatingIcons() {
    // Tambahkan berbagai ikon jasa yang mengambang dengan posisi melingkar
    final radius = 120.0; // Radius lingkaran
    final count = 8;

    for (int i = 0; i < count; i++) {
      final angle = 2 * math.pi * i / count;
      final x = radius * math.cos(angle);
      final y = radius * math.sin(angle);

      _floatingIcons.add(
        FloatingIcon(icon: _getServiceIcons()[i], x: x, y: y, delay: i * 0.2),
      );
    }
  }

  List<IconData> _getServiceIcons() {
    return [
      Icons.design_services,
      Icons.code,
      Icons.edit,
      Icons.camera_alt,
      Icons.translate,
      Icons.business_center,
      Icons.music_note,
      Icons.school,
    ];
  }

  void _initializeAnimations() {
    // Main controller untuk sequence
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Logo animations
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeInCubic),
    );

    // Ripple effect
    _rippleController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat();

    _rippleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _rippleController, curve: Curves.easeOut),
    );

    // Floating icons animation
    _floatingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    _floatingAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _floatingController, curve: Curves.easeInOutSine),
    );

    // Text animations
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Start animation sequence
    _mainController.forward().then((_) {
      _textController.forward();
    });
  }

  Future<void> _checkAuthState() async {
    await Future.delayed(const Duration(milliseconds: 3500));

    if (!mounted) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final rememberMe = prefs.getBool('remember_me') ?? false;

      if (!mounted) return;

      try {
        await _apiService.loadToken();
      } catch (e) {
        print('Error loading token: $e');
      }

      if (!mounted) return;

      if (rememberMe && _apiService.token != null) {
        try {
          final userResponse = await _apiService.getUser().timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

          if (!mounted) return;

          if (userResponse['success'] == true) {
            _navigateToHome();
            return;
          }
        } catch (e) {
          print('Auto-login failed: $e');
          try {
            await _apiService.clearToken();
          } catch (_) {}
        }
      }

      if (!mounted) return;

      _navigateToAuth();
    } catch (e) {
      print('Error checking auth state: $e');
      if (mounted) {
        _navigateToAuth();
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  void _navigateToAuth() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const AuthScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _rippleController.dispose();
    _floatingController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE3F2FD),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              // Background dengan gradient biru muda
              _buildBackground(),

              // Floating icons - DIPOSISIKAN DI TENGAH
              _buildFloatingIcons(),

              // Ripple effects
              _buildRipples(),

              // Geometric shapes
              _buildGeometricShapes(),

              // MAIN CONTENT - PASTI DI TENGAH
              Positioned(
                top: constraints.maxHeight * 0.1,
                left: 0,
                right: 0,
                bottom: constraints.maxHeight * 0.1,
                child: _buildMainContent(),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFE3F2FD), Color(0xFFBBDEFB), Color(0xFF90CAF9)],
          stops: [0.0, 0.6, 1.0],
        ),
      ),
      child: CustomPaint(painter: _BackgroundPatternPainter()),
    );
  }

  Widget _buildFloatingIcons() {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        return Stack(
          children: _floatingIcons.map((icon) {
            final animationValue =
                (_floatingAnimation.value + icon.delay) % 1.0;
            final offsetY = math.sin(animationValue * 2 * math.pi) * 10;
            final scale = 0.8 + math.sin(animationValue * 2 * math.pi) * 0.2;

            return Positioned(
              // POSISI DI TENGAH LAYAR + OFFSET LINGKARAN
              left:
                  MediaQuery.of(context).size.width / 2 +
                  icon.x -
                  20, // -20 untuk center icon
              top:
                  MediaQuery.of(context).size.height / 2 +
                  icon.y +
                  offsetY -
                  150, // -20 untuk center icon
              child: Transform.rotate(
                angle: animationValue * 0.3,
                child: Transform.scale(
                  scale: scale,
                  child: Opacity(
                    opacity: 0.8 + math.sin(animationValue * 2 * math.pi) * 0.2,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF42A5F5).withOpacity(0.3),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF42A5F5).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        icon.icon,
                        size: 20,
                        color: const Color(0xFF1976D2),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildRipples() {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        return CustomPaint(
          painter: _RipplePainter(animationValue: _rippleAnimation.value),
          size: Size.infinite,
        );
      },
    );
  }

  Widget _buildGeometricShapes() {
    return Stack(
      children: [
        // Top left circle
        Positioned(
          top: -50,
          left: -30,
          child: Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF42A5F5).withOpacity(0.1),
            ),
          ),
        ),
        // Bottom right circle
        Positioned(
          bottom: -40,
          right: -20,
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2196F3).withOpacity(0.1),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo section
        Expanded(flex: 4, child: _buildLogoSection()),

        // Text section
        Expanded(flex: 2, child: _buildTextSection()),

        // Loading section
        Expanded(flex: 1, child: _buildLoadingSection()),
      ],
    );
  }

  Widget _buildLogoSection() {
    return Center(
      child: AnimatedBuilder(
        animation: _mainController,
        builder: (context, child) {
          return Transform.scale(
            scale: _logoScale.value,
            child: Opacity(
              opacity: _logoOpacity.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow effect
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF42A5F5).withOpacity(0.3),
                          const Color(0xFF90CAF9).withOpacity(0.1),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Main logo container
                  Container(
                    width: 140,
                    height: 140,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF42A5F5).withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: 5,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.white.withOpacity(0.8),
                          blurRadius: 20,
                          spreadRadius: 2,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(
                        color: Colors.white.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: ServifyLogo(
                        size: 80,
                        variant: ServifyLogoVariant.png,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTextSection() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Opacity(
          opacity: _textOpacity.value,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Main title dengan gradient biru
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [
                      Color(0xFF1976D2),
                      Color(0xFF42A5F5),
                      Color(0xFF64B5F6),
                    ],
                    stops: [0.0, 0.5, 1.0],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: const Text(
                    'SERVIFY',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      height: 1.1,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Subtitle
                const Text(
                  'Platform Jasa Professional',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF1565C0),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),

                const SizedBox(height: 12),

                // Deskripsi
                const Text(
                  'Temukan talenta terbaik atau tawarkan\nkeahlian Anda dengan percaya diri',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF546E7A),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingSection() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Opacity(
          opacity: _textOpacity.value,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              // Modern loading dots dengan animasi wave
              SizedBox(
                height: 25,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return AnimatedBuilder(
                      animation: _floatingController,
                      builder: (context, child) {
                        final animationValue =
                            (_floatingAnimation.value + index * 0.2) % 1.0;
                        final scale = 0.8 + animationValue * 0.4;
                        final offsetY =
                            math.sin(animationValue * 2 * math.pi) * 8;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: Transform.translate(
                            offset: Offset(0, offsetY),
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1976D2),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF42A5F5,
                                      ).withOpacity(0.6),
                                      blurRadius: 6,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ),
              ),

              const SizedBox(height: 16),

              // Loading text
              const Text(
                'Mempersiapkan pengalaman terbaik...',
                style: TextStyle(
                  color: Color(0xFF546E7A),
                  fontWeight: FontWeight.w500,
                  fontSize: 12,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FloatingIcon {
  final IconData icon;
  final double x;
  final double y;
  final double delay;

  FloatingIcon({
    required this.icon,
    required this.x,
    required this.y,
    required this.delay,
  });
}

class _RipplePainter extends CustomPainter {
  final double animationValue;

  _RipplePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final adjustedValue = (animationValue - i * 0.3).clamp(0.0, 1.0);

      if (adjustedValue <= 0) continue;

      final radius = adjustedValue * math.min(size.width, size.height) * 0.4;
      final opacity = (1 - adjustedValue) * 0.05;

      final paint = Paint()
        ..color = const Color(0xFF42A5F5).withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RipplePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF42A5F5).withOpacity(0.03)
      ..style = PaintingStyle.fill;

    // Draw subtle grid pattern
    final gridSize = 40.0;
    for (double x = 0; x < size.width; x += gridSize) {
      for (double y = 0; y < size.height; y += gridSize) {
        if ((x ~/ gridSize + y ~/ gridSize) % 2 == 0) {
          canvas.drawCircle(
            Offset(x + gridSize / 2, y + gridSize / 2),
            1,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
