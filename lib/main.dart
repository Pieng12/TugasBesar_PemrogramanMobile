import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pemob - On-Demand Services',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins', // Mengganti font agar lebih modern
        scaffoldBackgroundColor: const Color(
          0xFFF2F2F2,
        ), // Abu-abu terang untuk background
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF2D9CDB), // Biru Cerah untuk header
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.black.withOpacity(0.1),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.05),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        // Custom color scheme
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2D9CDB), // Brand & Header
          secondary: Color(0xFF27AE60), // Latar belakang utama
          error: Color(0xFFEB5757), // SOS / Darurat
          surface: Color(0xFFFFFFFF), // Background
          onSurface: Color(0xFF1E293B), // Teks utama
          onSurfaceVariant: Color(0xFFBDBDBD), // Abu-abu terang
        ),
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
