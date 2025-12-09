import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service untuk handle notification events dan routing
///
/// Gunakan di main.dart untuk navigate ke halaman yang tepat
/// ketika user tap notification
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  /// Navigator key untuk routing dari notification
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Handle notification tap dan navigate ke halaman yang tepat
  static Future<void> handleNotificationTap(
    RemoteMessage message, {
    required BuildContext context,
  }) async {
    print('🔗 Handling notification tap: ${message.data}');

    final data = message.data;
    final type = data['type'] ?? '';
    final relatedType = data['related_type'];
    final relatedId = data['related_id'];

    switch (type) {
      // ===== JOB RELATED NOTIFICATIONS =====
      case 'job_applied':
        _navigateToJobDetail(context, relatedId, 'Job Application');
        break;

      case 'job_accepted':
        _navigateToJobDetail(context, relatedId, 'Job Accepted');
        break;

      case 'job_rejected':
        _navigateToJobDetail(context, relatedId, 'Job Rejected');
        break;

      case 'job_completed':
        _navigateToJobDetail(context, relatedId, 'Job Completed');
        break;

      case 'job_cancelled':
        _navigateToJobDetail(context, relatedId, 'Job Cancelled');
        break;

      // ===== SOS RELATED NOTIFICATIONS =====
      case 'sos_nearby':
        _navigateToSOSDetail(context, relatedId);
        break;

      case 'sos_accepted':
        _navigateToSOSDetail(context, relatedId);
        break;

      case 'sos_completed':
        _navigateToSOSDetail(context, relatedId);
        break;

      // ===== REVIEW RELATED NOTIFICATIONS =====
      case 'review_received':
        _navigateToReviewDetail(context, relatedId);
        break;

      // ===== SYSTEM NOTIFICATIONS =====
      case 'system':
      case 'admin':
      default:
        // Jika tidak ada tujuan spesifik, buka home atau notification center
        _navigateToNotificationCenter(context);
        break;
    }
  }

  /// Navigate ke detail job
  static void _navigateToJobDetail(
    BuildContext context,
    String? jobId,
    String title,
  ) {
    if (jobId == null || jobId.isEmpty) {
      print('❌ Job ID kosong, tidak bisa navigate');
      return;
    }

    print('🔗 Navigating to Job Detail: $jobId');

    // Navigator.of(context).pushNamed(
    //   '/job-detail',
    //   arguments: jobId,
    // );

    // Atau jika menggunakan Navigator.push:
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => JobDetailScreen(jobId: jobId),
    //   ),
    // );
  }

  /// Navigate ke detail SOS
  static void _navigateToSOSDetail(BuildContext context, String? sosId) {
    if (sosId == null || sosId.isEmpty) {
      print('❌ SOS ID kosong, tidak bisa navigate');
      return;
    }

    print('🔗 Navigating to SOS Detail: $sosId');

    // Navigator.of(context).pushNamed(
    //   '/sos-detail',
    //   arguments: sosId,
    // );
  }

  /// Navigate ke review
  static void _navigateToReviewDetail(BuildContext context, String? reviewId) {
    if (reviewId == null || reviewId.isEmpty) {
      print('❌ Review ID kosong, tidak bisa navigate');
      return;
    }

    print('🔗 Navigating to Review: $reviewId');

    // Atau buka profile page dengan rating/review section
    // Navigator.of(context).pushNamed('/profile');
  }

  /// Navigate ke notification center / inbox
  static void _navigateToNotificationCenter(BuildContext context) {
    print('🔗 Navigating to Notification Center');

    // Navigator.of(context).pushNamed('/notifications');
    // atau
    // Navigator.pushReplacementNamed(context, '/home');
  }

  /// Parse notification data dari string
  static Map<String, dynamic> _parseNotificationData(String? dataString) {
    if (dataString == null || dataString.isEmpty) {
      return {};
    }

    try {
      return jsonDecode(dataString);
    } catch (e) {
      print('❌ Error parsing notification data: $e');
      return {};
    }
  }
}

/// Helper extension untuk handle notification response
extension NotificationResponseHandler on NotificationResponse {
  /// Get payload data sebagai Map
  Map<String, dynamic> get payloadAsMap {
    if (payload == null || payload!.isEmpty) {
      return {};
    }

    try {
      return jsonDecode(payload!);
    } catch (e) {
      print('❌ Error parsing payload: $e');
      return {};
    }
  }

  /// Get notification type dari payload
  String get notificationType {
    return payloadAsMap['type'] ?? 'unknown';
  }

  /// Get related ID dari payload
  String? get relatedId {
    return payloadAsMap['related_id']?.toString();
  }
}
