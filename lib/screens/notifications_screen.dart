import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'sos_detail_screen.dart';
import 'job_detail_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shimmer/shimmer.dart';

enum NotificationType {
  order,
  promo,
  system,
  warning,
  jobApplication,
  jobAccepted,
  jobRejected,
  jobCompleted,
  jobCancelled,
  privateOrderAccepted,
  privateOrderRejected,
  sosNearby,
  adminAction,
}

class NotificationItem {
  final String id;
  final String title;
  final String body;
  final DateTime receivedAt;
  final NotificationType type;
  bool isRead;
  String? relatedId;
  String? relatedType;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.receivedAt,
    required this.type,
    this.isRead = false,
    this.relatedId,
    this.relatedType,
  });

  // Method to set related data
  void setRelatedData(String id, String type) {
    relatedId = id;
    relatedType = type;
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with WidgetsBindingObserver {
  final List<NotificationItem> _notifications = [];
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  bool _hasActiveSOS = false;
  String? _activeSosId;
  Map<String, dynamic>? _activeSosData;
  List<Map<String, dynamic>> _nearbySosList = [];
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeNotifications();
  }

  Future<void> _initializeNotifications() async {
    await _getUserLocation();
    // Load notifications first, which will also load nearby SOS
    await _loadNotifications();
    await _checkActiveSOS();
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      _userPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      print('Error getting location: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh when app comes back to foreground
      _initializeNotifications();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh when screen becomes visible again
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeNotifications();
    });
  }

  Future<List<NotificationItem>> _loadNearbySOSNotifications() async {
    List<NotificationItem> sosNotifications = [];

    try {
      // Always try to get location if not available
      if (_userPosition == null) {
        await _getUserLocation();
      }

      // If still no location, try one more time with explicit permission request
      if (_userPosition == null) {
        print('User position not available, attempting to get location...');
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission != LocationPermission.denied &&
              permission != LocationPermission.deniedForever) {
            _userPosition = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
            );
          }
        }
      }

      if (_userPosition == null) {
        print('User position still not available for SOS notifications');
        return sosNotifications;
      }

      print(
        'Loading nearby SOS from: ${_userPosition!.latitude}, ${_userPosition!.longitude}',
      );
      final response = await _apiService.getNearbySos(
        latitude: _userPosition!.latitude,
        longitude: _userPosition!.longitude,
        radius: 10.0, // 10 km radius
      );

      print('SOS Response: ${response['success']}');

      if (response['success']) {
        final dynamic data = response['data'];
        List<Map<String, dynamic>> sosList = [];

        if (data is Map && data.containsKey('data')) {
          sosList = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          sosList = List<Map<String, dynamic>>.from(data);
        }

        print('Found ${sosList.length} total SOS requests from API');

        // Get current user ID to filter out own SOS
        await _apiService.loadToken();
        final userResponse = await _apiService.getUser();
        String? currentUserId;
        if (userResponse['success']) {
          currentUserId = userResponse['data']['id']?.toString();
          print('Current user ID: $currentUserId');
        }

        // Filter out own SOS and only active SOS
        final nearbySos = sosList.where((sos) {
          final requesterId = sos['requester_id']?.toString();
          final requester = sos['requester'] as Map<String, dynamic>?;
          final requesterIdFromRelation = requester?['id']?.toString();
          final status = sos['status']?.toString() ?? 'active';

          // Check both requester_id and requester.id to ensure we filter correctly
          final isOwnSOS =
              (requesterId != null && requesterId == currentUserId) ||
              (requesterIdFromRelation != null &&
                  requesterIdFromRelation == currentUserId);

          // Only show active SOS that are not from current user
          final shouldShow = !isOwnSOS && status == 'active';

          if (shouldShow) {
            print(
              '✓ Including SOS ${sos['id']}: requester=$requesterId (not current user $currentUserId), status=$status',
            );
          } else {
            print(
              '✗ Excluding SOS ${sos['id']}: requester=$requesterId/$requesterIdFromRelation, currentUserId=$currentUserId, status=$status, isOwn=$isOwnSOS',
            );
          }
          return shouldShow;
        }).toList();

        print('Filtered to ${nearbySos.length} nearby SOS (excluding own)');

        setState(() {
          _nearbySosList = nearbySos;
        });

        // Add notifications for ALL nearby SOS from other users
        // Show SOS created within last 24 hours for better coverage
        final now = DateTime.now();

        for (var sos in nearbySos) {
          final distance = sos['distance'] ?? 0.0;
          final sosId = sos['id']?.toString();
          final createdAt = DateTime.tryParse(sos['created_at'] ?? '');

          if (createdAt == null) {
            print('SOS $sosId has invalid created_at, skipping');
            continue;
          }

          // Show SOS created within last 24 hours
          final timeDiff = now.difference(createdAt);
          if (timeDiff.inHours > 24) {
            print(
              'SOS $sosId is too old (${timeDiff.inHours} hours), skipping',
            );
            continue;
          }

          final notification = NotificationItem(
            id: 'sos_nearby_$sosId',
            title: '🚨 SOS Darurat di Sekitar',
            body:
                'Ada sinyal darurat "${sos['title'] ?? 'SOS'}" sekitar ${distance.toStringAsFixed(1)} km dari lokasi Anda',
            receivedAt: createdAt,
            type: NotificationType.sosNearby,
            isRead: false,
          );
          notification.setRelatedData(sosId!, 'sos');
          sosNotifications.add(notification);
          print(
            '✓ Added SOS notification for $sosId (${distance.toStringAsFixed(1)} km away)',
          );
        }

        print(
          '✓ Successfully added ${sosNotifications.length} SOS notifications from nearby users',
        );
      } else {
        print('✗ Failed to load nearby SOS: ${response['message']}');
      }
    } catch (e) {
      print('✗ Error loading nearby SOS: $e');
      print('Stack trace: ${StackTrace.current}');
    }

    return sosNotifications;
  }

  Future<void> _checkActiveSOS() async {
    try {
      await _apiService.loadToken();
      if (_apiService.token == null) return;

      final response = await _apiService.getSosRequests(status: 'active');

      if (response['success']) {
        final dynamic data = response['data'];
        List<Map<String, dynamic>> sosData = [];

        if (data is Map && data.containsKey('data')) {
          sosData = List<Map<String, dynamic>>.from(data['data']);
        } else if (data is List) {
          sosData = List<Map<String, dynamic>>.from(data);
        }

        // Check if user has active SOS
        if (sosData.isNotEmpty) {
          final userResponse = await _apiService.getUser();
          if (userResponse['success']) {
            final userId = userResponse['data']['id']?.toString();
            for (var sos in sosData) {
              if (sos['requester_id']?.toString() == userId) {
                setState(() {
                  _hasActiveSOS = true;
                  _activeSosId = sos['id']?.toString();
                  _activeSosData = sos;
                });
                break;
              }
            }
          }
        } else {
          setState(() {
            _hasActiveSOS = false;
            _activeSosId = null;
            _activeSosData = null;
          });
        }
      }
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadNotifications() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      await _apiService.loadToken();

      if (_apiService.token == null) {
        setState(() {
          _error = 'Silakan login untuk melihat notifikasi';
          _isLoading = false;
        });
        return;
      }

      // Get current user ID first to filter out own SOS from API notifications
      final userResponse = await _apiService.getUser();
      String? currentUserId;
      if (userResponse['success']) {
        currentUserId = userResponse['data']['id']?.toString();
      }

      // Load notifications from API
      final response = await _apiService.getNotifications();

      print('Notification API Response: ${response.toString()}');

      if (response['success']) {
        final dynamic data = response['data'];
        List<Map<String, dynamic>> notificationsData = [];

        // Handle paginated or direct list response
        if (data is Map && data.containsKey('data')) {
          // Nested data structure
          notificationsData = List<Map<String, dynamic>>.from(data['data']);
          print(
            'Found ${notificationsData.length} notifications in nested data structure',
          );
        } else if (data is List) {
          // Direct list response
          notificationsData = List<Map<String, dynamic>>.from(data);
          print(
            'Found ${notificationsData.length} notifications in direct list',
          );
        } else {
          print('Unexpected data format: ${data.runtimeType}');
        }

        // Convert API notifications
        // Note: We'll handle SOS notifications separately via _loadNearbySOSNotifications
        // to ensure we get all nearby SOS from other users, not just from backend API
        final apiNotifications = notificationsData
            .map((data) {
              try {
                return _convertToNotificationItem(data);
              } catch (e) {
                print('Error converting notification: $e, data: $data');
                return null;
              }
            })
            .whereType<NotificationItem>()
            .toList();

        print(
          'Successfully converted ${apiNotifications.length} API notifications',
        );

        // Load additional notifications from jobs and applications
        final additionalNotifications = await _loadJobRelatedNotifications();

        // Load nearby SOS notifications (this will include SOS from other users)
        // This is important: we want to show SOS from nearby users, not just our own
        final sosNotifications = await _loadNearbySOSNotifications();

        print('Total API notifications: ${apiNotifications.length}');
        print(
          'Total job-related notifications: ${additionalNotifications.length}',
        );
        print('Total nearby SOS notifications: ${sosNotifications.length}');

        // Combine all notifications
        // Priority: nearby SOS notifications should be included even if there are duplicates
        final allNotifications = [
          ...apiNotifications,
          ...additionalNotifications,
          ...sosNotifications, // Add nearby SOS notifications last so they take priority
        ];

        // Remove duplicates based on ID, but prioritize SOS notifications from nearby users
        final uniqueNotifications = <String, NotificationItem>{};
        for (var notification in allNotifications) {
          // If it's a nearby SOS notification, always include it (even if there's a duplicate)
          if (notification.type == NotificationType.sosNearby &&
              notification.id.startsWith('sos_nearby_')) {
            uniqueNotifications[notification.id] = notification;
          } else if (!uniqueNotifications.containsKey(notification.id)) {
            uniqueNotifications[notification.id] = notification;
          }
        }

        final finalNotifications = uniqueNotifications.values.toList();
        finalNotifications.sort((a, b) => b.receivedAt.compareTo(a.receivedAt));

        print('Final notifications count: ${finalNotifications.length}');
        print(
          'SOS notifications in final list: ${finalNotifications.where((n) => n.type == NotificationType.sosNearby).length}',
        );

        setState(() {
          _notifications.clear();
          _notifications.addAll(finalNotifications);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Gagal memuat notifikasi';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error memuat notifikasi: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<List<NotificationItem>> _loadJobRelatedNotifications() async {
    List<NotificationItem> notifications = [];

    try {
      // Load user's created jobs (for customer notifications)
      final createdJobsResponse = await _apiService.getMyCreatedJobs();
      if (createdJobsResponse['success']) {
        final createdJobsData = createdJobsResponse['data'];
        List<Map<String, dynamic>> createdJobs = [];

        if (createdJobsData is Map && createdJobsData.containsKey('data')) {
          createdJobs = List<Map<String, dynamic>>.from(
            createdJobsData['data'],
          );
        } else if (createdJobsData is List) {
          createdJobs = List<Map<String, dynamic>>.from(createdJobsData);
        }

        // Check for new applications
        for (var job in createdJobs) {
          final jobId = job['id']?.toString();
          final applicantCount = job['applicant_count'] ?? 0;
          final jobStatus = job['status'] ?? 'pending';

          if (applicantCount > 0 && jobStatus == 'pending') {
            notifications.add(
              NotificationItem(
                id: 'job_application_$jobId',
                title: '📝 Ada Pekerja yang Melamar',
                body:
                    '$applicantCount pekerja mengajukan diri untuk pekerjaan "${job['title'] ?? 'Pekerjaan Anda'}"',
                receivedAt:
                    DateTime.tryParse(
                      job['updated_at'] ?? job['created_at'] ?? '',
                    ) ??
                    DateTime.now(),
                type: NotificationType.jobApplication,
                isRead: false,
              )..setRelatedData(jobId!, 'job'),
            );
          }
        }
      }

      // Load user's applied jobs (for worker notifications)
      final appliedJobsResponse = await _apiService.getMyAppliedJobs();
      if (appliedJobsResponse['success']) {
        final appliedJobsData = appliedJobsResponse['data'];
        List<Map<String, dynamic>> applications = [];

        if (appliedJobsData is Map && appliedJobsData.containsKey('data')) {
          applications = List<Map<String, dynamic>>.from(
            appliedJobsData['data'],
          );
        } else if (appliedJobsData is List) {
          applications = List<Map<String, dynamic>>.from(appliedJobsData);
        }

        for (var application in applications) {
          final job = application['job'];
          if (job == null) continue;

          final applicationStatus = application['status'] ?? 'pending';
          final jobId = job['id']?.toString();
          final applicationId = application['id']?.toString();

          if (applicationStatus == 'accepted') {
            notifications.add(
              NotificationItem(
                id: 'job_accepted_$applicationId',
                title: '✅ Lamaran Diterima',
                body:
                    'Lamaran Anda untuk pekerjaan "${job['title'] ?? 'Pekerjaan'}" telah diterima!',
                receivedAt:
                    DateTime.tryParse(
                      application['updated_at'] ??
                          application['applied_at'] ??
                          '',
                    ) ??
                    DateTime.now(),
                type: NotificationType.jobAccepted,
                isRead: false,
              )..setRelatedData(jobId!, 'job'),
            );
          } else if (applicationStatus == 'rejected') {
            notifications.add(
              NotificationItem(
                id: 'job_rejected_$applicationId',
                title: '❌ Lamaran Ditolak',
                body:
                    'Lamaran Anda untuk pekerjaan "${job['title'] ?? 'Pekerjaan'}" telah ditolak',
                receivedAt:
                    DateTime.tryParse(
                      application['updated_at'] ??
                          application['applied_at'] ??
                          '',
                    ) ??
                    DateTime.now(),
                type: NotificationType.jobRejected,
                isRead: false,
              )..setRelatedData(jobId!, 'job'),
            );
          }
        }
      }

      // Load assigned jobs (private orders) - for worker
      final assignedJobsResponse = await _apiService.getMyAssignedJobs();
      if (assignedJobsResponse['success']) {
        final assignedJobsData = assignedJobsResponse['data'];
        List<Map<String, dynamic>> assignedJobs = [];

        if (assignedJobsData is Map && assignedJobsData.containsKey('data')) {
          assignedJobs = List<Map<String, dynamic>>.from(
            assignedJobsData['data'],
          );
        } else if (assignedJobsData is List) {
          assignedJobs = List<Map<String, dynamic>>.from(assignedJobsData);
        }

        for (var job in assignedJobs) {
          final jobStatus = job['status'] ?? 'pending';
          final jobId = job['id']?.toString();
          final updatedAt = job['updated_at'] ?? job['created_at'];
          final isPrivate = _isPrivateOrder(job);

          if (!isPrivate) continue;

          // Notifikasi untuk pesanan pribadi baru
          if (jobStatus == 'pending') {
            notifications.add(
              NotificationItem(
                id: 'private_order_new_$jobId',
                title: '📌 Pesanan Pribadi Baru',
                body:
                    'Anda mendapat pesanan pribadi: "${job['title'] ?? 'Pekerjaan'}"',
                receivedAt:
                    DateTime.tryParse(job['created_at'] ?? '') ??
                    DateTime.now(),
                type: NotificationType.privateOrderAccepted,
                isRead: false,
              )..setRelatedData(jobId!, 'job'),
            );
          }
          // Notifikasi untuk pesanan pribadi yang mengajukan penyelesaian
          else if (jobStatus == 'pending_completion') {
            notifications.add(
              NotificationItem(
                id: 'private_order_completion_$jobId',
                title: '✅ Pesanan Pribadi Menunggu Konfirmasi',
                body:
                    'Pekerjaan "${job['title'] ?? 'Pekerjaan'}" telah selesai dan menunggu konfirmasi Anda',
                receivedAt:
                    DateTime.tryParse(updatedAt ?? job['created_at'] ?? '') ??
                    DateTime.now(),
                type: NotificationType.jobCompleted,
                isRead: false,
              )..setRelatedData(jobId!, 'job'),
            );
          }
          // Notifikasi untuk pesanan pribadi yang dibatalkan
          else if (jobStatus == 'cancelled') {
            notifications.add(
              NotificationItem(
                id: 'private_order_cancelled_$jobId',
                title: '❌ Pesanan Pribadi Dibatalkan',
                body:
                    'Pesanan pribadi "${job['title'] ?? 'Pekerjaan'}" telah dibatalkan',
                receivedAt:
                    DateTime.tryParse(updatedAt ?? job['created_at'] ?? '') ??
                    DateTime.now(),
                type: NotificationType.jobCancelled,
                isRead: false,
              )..setRelatedData(jobId!, 'job'),
            );
          }
        }
      }

      // Load created jobs untuk cek notifikasi pesanan pribadi dari sisi customer
      if (createdJobsResponse['success']) {
        final createdJobsData = createdJobsResponse['data'];
        List<Map<String, dynamic>> createdJobs = [];

        if (createdJobsData is Map && createdJobsData.containsKey('data')) {
          createdJobs = List<Map<String, dynamic>>.from(
            createdJobsData['data'],
          );
        } else if (createdJobsData is List) {
          createdJobs = List<Map<String, dynamic>>.from(createdJobsData);
        }

        for (var job in createdJobs) {
          final jobStatus = job['status'] ?? 'pending';
          final jobId = job['id']?.toString();
          final updatedAt = job['updated_at'] ?? job['created_at'];
          final isPrivate = _isPrivateOrder(job);
          final assignedWorkerId = job['assigned_worker_id']?.toString();

          if (!isPrivate) continue;

          // Notifikasi untuk pesanan pribadi yang diterima oleh worker
          if (jobStatus == 'inProgress' && assignedWorkerId != null) {
            // Cek apakah baru saja diupdate (dalam 30 menit terakhir untuk coverage lebih baik)
            final updatedTime = DateTime.tryParse(updatedAt ?? '');
            if (updatedTime != null) {
              final timeDiff = DateTime.now().difference(updatedTime);
              if (timeDiff.inMinutes <= 30) {
                notifications.add(
                  NotificationItem(
                    id: 'private_order_accepted_$jobId',
                    title: '✅ Pesanan Pribadi Diterima',
                    body:
                        'Pesanan pribadi "${job['title'] ?? 'Pekerjaan'}" telah diterima oleh pekerja',
                    receivedAt: updatedTime,
                    type: NotificationType.privateOrderAccepted,
                    isRead: false,
                  )..setRelatedData(jobId!, 'job'),
                );
              }
            }
          }
          // Notifikasi untuk pesanan pribadi yang mengajukan penyelesaian
          else if (jobStatus == 'pending_completion') {
            notifications.add(
              NotificationItem(
                id: 'private_order_completion_request_$jobId',
                title: '⏳ Konfirmasi Penyelesaian',
                body:
                    'Pekerja mengajukan penyelesaian untuk pesanan "${job['title'] ?? 'Pekerjaan'}". Silakan konfirmasi.',
                receivedAt:
                    DateTime.tryParse(updatedAt ?? job['created_at'] ?? '') ??
                    DateTime.now(),
                type: NotificationType.jobCompleted,
                isRead: false,
              )..setRelatedData(jobId!, 'job'),
            );
          }
          // Notifikasi untuk pesanan pribadi yang dibatalkan
          else if (jobStatus == 'cancelled') {
            final cancelledTime = DateTime.tryParse(
              updatedAt ?? job['created_at'] ?? '',
            );
            if (cancelledTime != null) {
              final timeDiff = DateTime.now().difference(cancelledTime);
              // Hanya tampilkan jika dibatalkan dalam 24 jam terakhir
              if (timeDiff.inHours <= 24) {
                notifications.add(
                  NotificationItem(
                    id: 'private_order_cancelled_customer_$jobId',
                    title: '❌ Pesanan Pribadi Dibatalkan',
                    body:
                        'Pesanan pribadi "${job['title'] ?? 'Pekerjaan'}" telah dibatalkan',
                    receivedAt: cancelledTime,
                    type: NotificationType.jobCancelled,
                    isRead: false,
                  )..setRelatedData(jobId!, 'job'),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error loading job notifications: $e');
    }

    return notifications;
  }

  bool _isPrivateOrder(Map<String, dynamic> job) {
    // Check if this is a private order based on additional_info or assigned_worker_id
    final additionalInfo = job['additional_info'];
    if (additionalInfo is Map<String, dynamic>) {
      return additionalInfo['is_private_order'] == true;
    }

    // Alternative check: if assigned_worker_id exists and no applicants, it's likely private
    return job['assigned_worker_id'] != null &&
        (job['applicant_count'] == null || job['applicant_count'] == 0);
  }

  NotificationItem _convertToNotificationItem(Map<String, dynamic> data) {
    final notification = NotificationItem(
      id: data['id']?.toString() ?? '',
      title: data['title'] ?? 'No Title',
      body: data['body'] ?? 'No Body',
      receivedAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      type: _stringToNotificationType(data['type']),
      isRead: data['is_read'] ?? false,
    );

    // Store additional data for navigation
    if (data['related_id'] != null && data['related_type'] != null) {
      notification.setRelatedData(
        data['related_id'].toString(),
        data['related_type'].toString(),
      );
    } else if (data['sos_id'] != null) {
      // Fallback: check for sos_id directly
      notification.setRelatedData(data['sos_id'].toString(), 'sos');
    }

    return notification;
  }

  NotificationType _stringToNotificationType(String? type) {
    switch (type) {
      case 'order':
      case 'job_created':
        return NotificationType.order;
      case 'job_application':
      case 'application':
        return NotificationType.jobApplication;
      case 'job_accepted':
      case 'application_accepted':
        return NotificationType.jobAccepted;
      case 'job_rejected':
      case 'application_rejected':
        return NotificationType.jobRejected;
      case 'job_completed':
        return NotificationType.jobCompleted;
      case 'job_cancelled':
        return NotificationType.jobCancelled;
      case 'private_order_new':
      case 'private_order_accepted':
        return NotificationType.privateOrderAccepted;
      case 'private_order_rejected':
        return NotificationType.privateOrderRejected;
      case 'promo':
        return NotificationType.promo;
      case 'system':
        return NotificationType.system;
      case 'warning':
        return NotificationType.warning;
      case 'sos':
      case 'sos_nearby':
      case 'sos_request':
        return NotificationType.sosNearby;
      case 'admin_action':
      case 'admin_ban':
      case 'admin_unban':
      case 'admin_job_cancelled':
      case 'admin_review_removed':
        return NotificationType.adminAction;
      default:
        print('Unknown notification type: $type, defaulting to system');
        return NotificationType.system;
    }
  }

  Future<void> _handleNotificationTap(NotificationItem notification) async {
    // Mark as read if not already
    if (!notification.isRead) {
      _apiService.markNotificationAsRead(notification.id);
      setState(() {
        notification.isRead = true;
      });
    }

    // Navigate based on notification type and related data
    if (notification.relatedType == 'sos' && notification.relatedId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SOSDetailScreen(sosId: notification.relatedId!),
        ),
      ).then((_) {
        // Reload notifications when returning from detail screen
        _loadNotifications();
      });
    } else if (notification.type == NotificationType.sosNearby &&
        notification.relatedId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SOSDetailScreen(sosId: notification.relatedId!),
        ),
      ).then((_) {
        // Reload notifications when returning from detail screen
        _loadNotifications();
      });
    } else if (notification.relatedType == 'job' &&
        notification.relatedId != null) {
      // Determine the correct viewContext based on user's role for this job
      await _navigateToJobDetail(notification.relatedId!);
    }
  }

  Future<void> _navigateToJobDetail(String jobId) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Load job data and user data in parallel
      final results = await Future.wait([
        _apiService.getJob(jobId),
        _apiService.getUser(),
      ]);

      final jobResponse = results[0];
      final userResponse = results[1];

      // Close loading
      if (mounted) Navigator.pop(context);

      if (!jobResponse['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                jobResponse['message'] ?? 'Gagal memuat detail pekerjaan',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!userResponse['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Gagal memuat data user'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final jobData = jobResponse['data'];
      final currentUserId = userResponse['data']?['id']?.toString();
      final customerId = jobData['customer_id']?.toString();
      final assignedWorkerId = jobData['assigned_worker_id']?.toString();

      // Determine viewContext based on user's role
      JobDetailViewContext viewContext;

      if (currentUserId == customerId) {
        // User is the customer/owner of the job
        viewContext = JobDetailViewContext.customer;
      } else if (currentUserId == assignedWorkerId) {
        // User is the assigned worker
        viewContext = JobDetailViewContext.worker;
      } else {
        // User is neither customer nor assigned worker
        // Check if user has applied for this job
        final appliedJobsResponse = await _apiService.getMyAppliedJobs();
        bool hasApplied = false;

        if (appliedJobsResponse['success']) {
          final dynamic appliedData = appliedJobsResponse['data'];
          List<Map<String, dynamic>> appliedJobs = [];

          if (appliedData is Map && appliedData.containsKey('data')) {
            appliedJobs = List<Map<String, dynamic>>.from(appliedData['data']);
          } else if (appliedData is List) {
            appliedJobs = List<Map<String, dynamic>>.from(appliedData);
          }

          hasApplied = appliedJobs.any(
            (app) => app['job']?['id']?.toString() == jobId,
          );
        }

        if (hasApplied) {
          // User has applied for this job
          viewContext = JobDetailViewContext.worker;
        } else {
          // User doesn't have access to this job
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Anda tidak memiliki akses ke pekerjaan ini'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      // Navigate to job detail with correct context
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                JobDetailScreen(jobId: jobId, viewContext: viewContext),
          ),
        );
      }
    } catch (e) {
      // Close loading if still open
      if (mounted) Navigator.pop(context);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _loadMockNotifications() {
    setState(() {
      _notifications.addAll([
        NotificationItem(
          id: '1',
          title: 'Pesanan Selesai',
          body:
              'Pesanan "Bersihkan Rumah 3 Kamar" telah diselesaikan oleh pekerja.',
          receivedAt: DateTime.now().subtract(const Duration(minutes: 5)),
          type: NotificationType.order,
        ),
        NotificationItem(
          id: '2',
          title: 'Promo Spesial Untukmu!',
          body:
              'Dapatkan diskon 50% untuk layanan kebersihan. Gunakan kode: BERSIH50.',
          receivedAt: DateTime.now().subtract(const Duration(hours: 2)),
          type: NotificationType.promo,
          isRead: true,
        ),
        NotificationItem(
          id: '3',
          title: 'Pekerja Baru Mendaftar',
          body:
              'Ada pekerja baru yang mendaftar untuk pekerjaan "Perbaiki AC Rusak".',
          receivedAt: DateTime.now().subtract(const Duration(hours: 8)),
          type: NotificationType.order,
        ),
        NotificationItem(
          id: '4',
          title: 'Update Sistem',
          body: 'Aplikasi telah diperbarui ke versi 1.1.0 dengan fitur baru.',
          receivedAt: DateTime.now().subtract(const Duration(days: 1)),
          type: NotificationType.system,
          isRead: true,
        ),
        NotificationItem(
          id: '5',
          title: 'Peringatan Keamanan',
          body:
              'Password Anda akan segera berakhir. Harap perbarui untuk keamanan.',
          receivedAt: DateTime.now().subtract(const Duration(days: 2)),
          type: NotificationType.warning,
        ),
      ]);
    });
  }

  Future<void> _markAllAsRead() async {
    try {
      final response = await _apiService.markAllNotificationsAsRead();

      if (response['success']) {
        setState(() {
          for (var notification in _notifications) {
            notification.isRead = true;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Semua notifikasi ditandai telah dibaca'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Failed to mark notifications as read',
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    }
  }

  void _clearAll() {
    // This function is removed as it's not appropriate to clear all notifications
    // Users should use mark all as read instead
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: _initializeNotifications,
        color: const Color(0xFF2563EB),
        backgroundColor: Colors.white,
        child: CustomScrollView(
          slivers: [
            _buildSliverAppBar(),
            if (_isLoading)
              SliverFillRemaining(child: _buildLoadingState())
            else if (_error != null)
              SliverFillRemaining(child: _buildErrorState())
            else if (_notifications.isEmpty && !_hasActiveSOS)
              SliverFillRemaining(child: _buildEmptyState())
            else
              _buildNotificationsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return SliverAppBar(
      expandedHeight: 140,
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
              // Decorative elements
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
              ),
              Positioned(
                right: 80,
                top: 60,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
              ),
              Positioned(
                left: -30,
                bottom: 20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Stack(
                              children: [
                                const Icon(
                                  Icons.notifications_rounded,
                                  color: Colors.white,
                                  size: 34,
                                ),
                                if (unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        unreadCount > 99
                                            ? '99+'
                                            : '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Notifikasi',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unreadCount > 0
                                      ? '$unreadCount notifikasi belum dibaca'
                                      : 'Semua sudah dibaca',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.9),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_notifications.any((n) => !n.isRead))
                            IconButton(
                              onPressed: _markAllAsRead,
                              icon: const Icon(
                                Icons.done_all_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              tooltip: 'Tandai semua telah dibaca',
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

  Widget _buildLoadingState() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: List.generate(
          5,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildNotificationCardSkeleton(),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCardSkeleton() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFF1E293B),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _initializeNotifications,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Coba Lagi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          if (_hasActiveSOS && index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _buildActiveSOSBanner(),
            );
          }
          final notificationIndex = _hasActiveSOS ? index - 1 : index;
          if (notificationIndex >= _notifications.length) return null;
          final notification = _notifications[notificationIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildNotificationCard(notification),
          );
        }, childCount: _notifications.length + (_hasActiveSOS ? 1 : 0)),
      ),
    );
  }

  Widget _buildActiveSOSBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFEF4444), const Color(0xFFDC2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (_activeSosId != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SOSDetailScreen(sosId: _activeSosId!),
                ),
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emergency_rounded,
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
                        '⚠️ SOS Aktif',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _activeSosData?['title'] ??
                            'Sinyal darurat Anda sedang aktif',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_activeSosData?['address'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _activeSosData!['address'],
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_off_outlined,
                  size: 64,
                  color: Color(0xFF6366F1),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Tidak Ada Notifikasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Semua notifikasi Anda akan muncul di sini.',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem notification) {
    final iconData = _getIconForType(notification.type);
    final iconColor = _getColorForType(notification.type);
    final timeAgo = _getTimeAgo(notification.receivedAt);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: notification.isRead
              ? const Color(0xFFE2E8F0)
              : iconColor.withOpacity(0.3),
          width: notification.isRead ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: notification.isRead
                ? Colors.black.withOpacity(0.04)
                : iconColor.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _handleNotificationTap(notification);
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withOpacity(0.2),
                        iconColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: iconColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(iconData, color: iconColor, size: 28),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: notification.isRead
                                    ? Colors.grey[700]
                                    : const Color(0xFF1E293B),
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: iconColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: iconColor.withOpacity(0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        notification.body,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return Icons.receipt_long_rounded;
      case NotificationType.jobApplication:
        return Icons.person_add_alt_1_rounded;
      case NotificationType.jobAccepted:
        return Icons.check_circle_rounded;
      case NotificationType.jobRejected:
        return Icons.cancel_rounded;
      case NotificationType.jobCompleted:
        return Icons.task_alt_rounded;
      case NotificationType.jobCancelled:
        return Icons.cancel_outlined;
      case NotificationType.privateOrderAccepted:
        return Icons.person_pin_circle_rounded;
      case NotificationType.privateOrderRejected:
        return Icons.block_rounded;
      case NotificationType.sosNearby:
        return Icons.emergency_rounded;
      case NotificationType.promo:
        return Icons.local_offer_rounded;
      case NotificationType.system:
        return Icons.settings_suggest_rounded;
      case NotificationType.warning:
        return Icons.warning_amber_rounded;
      case NotificationType.adminAction:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.order:
        return const Color(0xFF3B82F6);
      case NotificationType.jobApplication:
        return const Color(0xFF6366F1);
      case NotificationType.jobAccepted:
        return const Color(0xFF10B981);
      case NotificationType.jobRejected:
        return const Color(0xFFEF4444);
      case NotificationType.jobCompleted:
        return const Color(0xFF059669);
      case NotificationType.jobCancelled:
        return const Color(0xFFDC2626);
      case NotificationType.privateOrderAccepted:
        return const Color(0xFF2D9CDB);
      case NotificationType.privateOrderRejected:
        return const Color(0xFFF59E0B);
      case NotificationType.sosNearby:
        return const Color(0xFFEF4444);
      case NotificationType.promo:
        return const Color(0xFF10B981);
      case NotificationType.system:
        return const Color(0xFF6366F1);
      case NotificationType.warning:
        return const Color(0xFFF59E0B);
      case NotificationType.adminAction:
        return const Color(0xFFDB2777);
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays} hari yang lalu';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} jam yang lalu';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} menit yang lalu';
    } else {
      return 'Baru saja';
    }
  }
}
