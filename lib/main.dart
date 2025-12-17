import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/api_service.dart';

// Instance untuk local notifications
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initialize local notifications
Future<void> initializeLocalNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      // Handle ketika user tap notifikasi
      print('Notification tapped: ${response.payload}');
    },
  );

  // PENTING: Request permission untuk Android 13+
  // Ini WAJIB untuk notifikasi muncul di notification bar saat app ditutup
  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  if (androidPlugin != null) {
    await androidPlugin.requestNotificationsPermission();
    print('✅ Android notification permission requested');
  }

  // Buat notification channel dengan importance TINGGI (untuk sound & vibration)
  // SANGAT PENTING agar notifikasi muncul saat app ditutup
  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'servify_channel',
    'Servify Notifications',
    description: 'Notifikasi penting dari aplikasi Servify',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  await androidPlugin?.createNotificationChannel(channel);
  print('✅ Android notification channel created');
}

/// Show notification di notification bar (bahkan saat app ditutup)
Future<void> showNotification(RemoteMessage message) async {
  // Gunakan channel yang sama seperti di initializeLocalNotifications
  const AndroidNotificationDetails androidPlatformChannelSpecifics =
      AndroidNotificationDetails(
        'servify_channel', // HARUS sama dengan nama channel yang dibuat
        'Servify Notifications',
        channelDescription: 'Notifikasi penting dari aplikasi Servify',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        // PENTING: bagikan dengan semua notifikasi
        visibility: NotificationVisibility.public,
      );

  const NotificationDetails platformChannelSpecifics = NotificationDetails(
    android: androidPlatformChannelSpecifics,
  );

  // Gunakan unique ID untuk setiap notifikasi (jangan hardcode 0)
  final uniqueId = DateTime.now().millisecondsSinceEpoch.remainder(100000);

  await flutterLocalNotificationsPlugin.show(
    uniqueId,
    message.notification?.title ?? 'Servify',
    message.notification?.body ?? '',
    platformChannelSpecifics,
    payload: message.data.toString(),
  );

  print('✅ Notification shown with ID: $uniqueId');
}

/// BACKGROUND HANDLER (ketika aplikasi ditutup / background)
/// HANDLER INI AKAN DIPANGGIL OLEH ANDROID MESKIPUN APP DITUTUP/KILLED
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Jangan gunakan widget context di sini
  // Pastikan binding tersedia di background isolate sebelum menggunakan plugins
  WidgetsFlutterBinding.ensureInitialized();
  print('🔔 Background Handler Called');
  print('📨 Notification Title: ${message.notification?.title}');
  print('📨 Notification Body: ${message.notification?.body}');

  try {
    // Inisialisasi Firebase jika belum
    await Firebase.initializeApp();
    print('✅ Firebase initialized in background');

    // Inisialisasi local notifications (lightweight, no permission requests)
    await initializeLocalNotificationsForBackground();
    print('✅ Local notifications (background) initialized');

    // Tampilkan notifikasi system di notification bar
    // INI ADALAH BAGIAN PENTING YANG MEMBUAT NOTIFIKASI MUNCUL SAAT APP DITUTUP
    if (message.notification != null) {
      await showNotification(message);
      print('✅ Background notification displayed');
    }
  } catch (e) {
    print('❌ Background handler error: $e');
    // Jangan throw exception, cukup log saja
  }
}

@pragma('vm:entry-point')
/// Lightweight initialization used inside the background isolate.
/// Do NOT request runtime permissions from background isolate.
Future<void> initializeLocalNotificationsForBackground() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      print('Notification tapped (background init): ${response.payload}');
    },
  );

  final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
      flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'servify_channel',
    'Servify Notifications',
    description: 'Notifikasi penting dari aplikasi Servify',
    importance: Importance.high,
    enableVibration: true,
    playSound: true,
  );

  await androidPlugin?.createNotificationChannel(channel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Firebase (WAJIB di awal)
  await Firebase.initializeApp();

  // Initialize local notifications
  await initializeLocalNotifications();

  // Handler pesan saat background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Jalankan app segera, operasi lain dilakukan di background
  runApp(const MyApp());

  // Operasi non-critical dilakukan di background setelah UI muncul
  _initializeAppInBackground();
}

/// Inisialisasi operasi non-critical di background
Future<void> _initializeAppInBackground() async {
  try {
    // Initialize date formatting
    await initializeDateFormatting('id_ID', null);

    // Load token dari storage (non-blocking)
    await ApiService().loadToken();

    // Request permission FCM (non-blocking)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Get FCM token (non-blocking)
    String? token = await FirebaseMessaging.instance.getToken();
    print("FCM TOKEN : $token");

    // Kirim FCM token ke backend (non-blocking)
    await sendTokenToBackend(token);
  } catch (e) {
    print('Background initialization error: $e');
    // Jangan crash app jika background init gagal
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // ========== HANDLER 1: NOTIFIKASI SAAT APP TERBUKA (FOREGROUND) ==========
    // Ketika app sudah terbuka dan menerima notifikasi, tampilkan di notification bar
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print('🔔 FOREGROUND NOTIFICATION RECEIVED');
      print('📨 Title: ${message.notification?.title}');
      print('📨 Body: ${message.notification?.body}');

      // Tampilkan notifikasi di notification bar (BUKAN dialog dalam app)
      // Ini penting agar user tahu ada notifikasi baru
      if (message.notification != null) {
        await showNotification(message);
      }
    });

    // ========== HANDLER 2: KETIKA USER KLIK NOTIFIKASI ==========
    // Triggered ketika user klik notifikasi (dari notification bar)
    // dan app membuka/sudah terbuka
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('✅ NOTIFICATION CLICKED');
      print('📨 Title: ${message.notification?.title}');
      print('📨 Data: ${message.data}');

      // BISA NAVIGATE KE HALAMAN TERTENTU BERDASARKAN DATA NOTIFIKASI
      // Contoh:
      // if (message.data['type'] == 'job_applied') {
      //   Navigator.push(...);
      // }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Servify',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFF2D9CDB),
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
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2D9CDB),
          secondary: Color(0xFF22C55E),
          error: Color(0xFFEB5757),
          surface: Color(0xFFFFFFFF),
          onSurface: Color(0xFF1E293B),
          onSurfaceVariant: Color(0xFF64748B),
        ),
      ),
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
