import 'dart:convert';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  // Set token untuk authentication
  Future<void> setToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Clear token
  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Load token from storage
  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
  }

  // Get token
  String? get token => _token;

  // Generic method untuk HTTP requests
  Future<Map<String, dynamic>> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, String>? queryParams,
  }) async {
    try {
      Uri url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

      if (queryParams != null) {
        url = url.replace(queryParameters: queryParams);
      }

      print('🌐 Making request to: $url');
      print('📋 Method: $method');
      print('🔑 Token: ${_token != null ? 'Present' : 'None'}');

      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(url, headers: ApiConfig.getHeaders(token: _token))
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await http
              .post(
                url,
                headers: ApiConfig.getHeaders(token: _token),
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 20));
          break;
        case 'PUT':
          response = await http
              .put(
                url,
                headers: ApiConfig.getHeaders(token: _token),
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(const Duration(seconds: 20));
          break;
        case 'DELETE':
          final request = http.Request('DELETE', url);
          request.headers.addAll(ApiConfig.getHeaders(token: _token));
          if (body != null) {
            request.body = jsonEncode(body);
          }
          final streamedResponse = await request.send().timeout(
            const Duration(seconds: 20),
          );
          response = await http.Response.fromStream(streamedResponse);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Request successful');
        return responseData;
      } else {
        print('❌ Request failed with status: ${response.statusCode}');
        throw ApiException(
          message: responseData['message'] ?? 'Unknown error',
          statusCode: response.statusCode,
          errors: responseData['errors'],
          data: responseData['data'] ?? responseData,
        );
      }
    } catch (e) {
      print('💥 Request error: $e');
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException(message: ApiConfig.networkError, statusCode: 0);
      }
    }
  }

  Future<Map<String, dynamic>> workerCompleteJob(String jobId) async {
    await loadToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/jobs/$jobId/worker-complete'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> customerConfirmCompletion(String jobId) async {
    await loadToken();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/jobs/$jobId/customer-confirm'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );
    return json.decode(response.body);
  }

  // Authentication methods
  Future<Map<String, dynamic>> forgotPassword({
    required String email,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.forgotPasswordEndpoint,
      body: {'email': email},
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.resetPasswordEndpoint,
      body: {
        'email': email,
        'token': token,
        'password': password,
        'password_confirmation': passwordConfirmation,
      },
    );
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? nik,
    String? phone,
    String? address,
    String? dateOfBirth,
    String? gender,
  }) async {
    print('🔗 API Service: Starting register request');
    print('🌐 URL: ${ApiConfig.baseUrl}${ApiConfig.registerEndpoint}');

    final body = {
      'name': name,
      'email': email,
      'password': password,
      if (nik != null && nik.isNotEmpty) 'nik': nik,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
      if (dateOfBirth != null && dateOfBirth.isNotEmpty)
        'date_of_birth': dateOfBirth,
      if (gender != null && gender.isNotEmpty) 'gender': gender,
    };

    print('📦 Request body: $body');

    final response = await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.registerEndpoint,
      body: body,
    );

    print('📨 Register response: $response');

    // Set token setelah register berhasil
    if (response['success'] && response['data']['token'] != null) {
      await setToken(response['data']['token']);
      print('🔑 Token set: ${response['data']['token'].substring(0, 20)}...');

      // After registering, try to send device FCM token to backend
      try {
        final prefs = await SharedPreferences.getInstance();
        final rememberMe = prefs.getBool('remember_me') ?? false;
        if (rememberMe) {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await updateFcmToken(fcmToken);
          }
        } else {
          print('Remember me false — not sending FCM token after register');
        }
      } catch (e) {
        print('Could not send FCM token after register: $e');
      }
    }

    return response;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.loginEndpoint,
      body: {'email': email, 'password': password},
    );

    // Set token setelah login berhasil
    if (response['success'] && response['data']['token'] != null) {
      await setToken(response['data']['token']);

      // After successful login, try to send device FCM token to backend
      try {
        final prefs = await SharedPreferences.getInstance();
        final rememberMe = prefs.getBool('remember_me') ?? false;
        if (rememberMe) {
          final fcmToken = await FirebaseMessaging.instance.getToken();
          if (fcmToken != null && fcmToken.isNotEmpty) {
            await updateFcmToken(fcmToken);
          }
        } else {
          print('Remember me false — not sending FCM token after login');
        }
      } catch (e) {
        print('Could not send FCM token after login: $e');
      }
    }

    return response;
  }

  Future<Map<String, dynamic>> logout() async {
    final response = await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.logoutEndpoint,
    );

    // Clear token setelah logout
    await clearToken();

    return response;
  }

  Future<Map<String, dynamic>> getUser() async {
    print('🔍 API Service: Getting user data...');
    print('🔑 Token: ${_token != null ? 'Present' : 'None'}');

    final response = await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.userEndpoint,
    );

    print('📋 User API Response: $response');
    return response;
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/change-password',
      body: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );
  }

  Future<Map<String, dynamic>> getActiveSessions() async {
    return await _makeRequest(method: 'GET', endpoint: '/sessions');
  }

  Future<Map<String, dynamic>> logoutAll() async {
    return await _makeRequest(method: 'POST', endpoint: '/logout-all');
  }

  Future<Map<String, dynamic>> revokeToken(String tokenId) async {
    return await _makeRequest(method: 'DELETE', endpoint: '/sessions/$tokenId');
  }

  Future<Map<String, dynamic>> updateUserProfile({
    String? name,
    String? phone,
    String? address,
    String? gender,
    String? dateOfBirth, // ISO or yyyy-MM-dd
  }) async {
    Map<String, dynamic> body = {};
    if (name != null) body['name'] = name;
    if (phone != null) body['phone'] = phone;
    if (address != null) body['address'] = address;
    if (gender != null) body['gender'] = gender;
    if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;

    try {
      // Try common Laravel style: PUT /user (may fail with 405)
      return await _makeRequest(
        method: 'PUT',
        endpoint: ApiConfig.userEndpoint,
        body: body,
      );
    } on ApiException catch (e) {
      // Fallback 1: PUT /profile
      if (e.statusCode == 405 || e.statusCode == 404) {
        try {
          return await _makeRequest(
            method: 'PUT',
            endpoint: ApiConfig.profileEndpoint,
            body: body,
          );
        } on ApiException catch (e2) {
          // Fallback 2: POST /profile/update
          if (e2.statusCode == 405 || e2.statusCode == 404) {
            return await _makeRequest(
              method: 'POST',
              endpoint: ApiConfig.updateProfileEndpoint,
              body: body,
            );
          }
          rethrow;
        }
      }
      rethrow;
    }
  }

  // Upload profile image
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    await loadToken();

    if (_token == null) {
      throw ApiException(
        message: 'Please login to upload profile image',
        statusCode: 401,
      );
    }

    try {
      print('📤 Uploading profile image...');

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}${ApiConfig.profileEndpoint}/upload-image',
      );

      var request = http.MultipartRequest('POST', uri);

      // Add headers
      request.headers.addAll({
        'Authorization': 'Bearer $_token',
        'Accept': 'application/json',
      });

      // Add image file
      final fileStream = http.ByteStream(imageFile.openRead());
      final fileLength = await imageFile.length();
      final multipartFile = http.MultipartFile(
        'image', // API expects 'image' field, not 'profile_image'
        fileStream,
        fileLength,
        filename: imageFile.path.split('/').last,
      );
      request.files.add(multipartFile);

      print('📡 Sending multipart request...');
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);
      print('📡 Response status: ${response.statusCode}');
      print('📄 Response body: ${response.body}');

      final responseData = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        print('✅ Profile image uploaded successfully');
        return responseData;
      } else {
        print('❌ Upload failed with status: ${response.statusCode}');
        throw ApiException(
          message: responseData['message'] ?? 'Failed to upload profile image',
          statusCode: response.statusCode,
          errors: responseData['errors'],
        );
      }
    } catch (e) {
      print('💥 Upload error: $e');
      if (e is ApiException) {
        rethrow;
      } else {
        throw ApiException(
          message: 'Error uploading profile image: ${e.toString()}',
          statusCode: 0,
        );
      }
    }
  }

  // Job methods
  Future<Map<String, dynamic>> getJobs({
    String? category,
    String? status,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    Map<String, String> queryParams = {};

    if (category != null) queryParams['category'] = category;
    if (status != null) queryParams['status'] = status;
    if (latitude != null) queryParams['latitude'] = latitude.toString();
    if (longitude != null) queryParams['longitude'] = longitude.toString();
    if (radius != null) queryParams['radius'] = radius.toString();

    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.jobsEndpoint,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  Future<Map<String, dynamic>> createJob(Map<String, dynamic> jobData) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.jobsEndpoint,
      body: jobData,
    );
  }

  Future<Map<String, dynamic>> getJob(String id) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '${ApiConfig.jobsEndpoint}/$id',
    );
  }

  Future<Map<String, dynamic>> getSOSRequests({int? limit}) async {
    Map<String, String> queryParams = {};

    if (limit != null) queryParams['limit'] = limit.toString();

    return await _makeRequest(
      method: 'GET',
      endpoint: '/sos',
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  Future<Map<String, dynamic>> updateJob({
    required String id,
    String? title,
    String? description,
    String? category,
    double? price,
    double? latitude,
    double? longitude,
    String? address,
    DateTime? scheduledTime,
    String? status,
    String? assignedWorkerId,
    List<String>? imageUrls,
    Map<String, dynamic>? additionalInfo,
  }) async {
    Map<String, dynamic> body = {};

    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (category != null) body['category'] = category;
    if (price != null) body['price'] = price;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (address != null) body['address'] = address;
    if (scheduledTime != null) {
      body['scheduled_time'] = scheduledTime.toIso8601String();
    }
    if (status != null) body['status'] = status;
    if (assignedWorkerId != null) body['assigned_worker_id'] = assignedWorkerId;
    if (imageUrls != null) body['image_urls'] = imageUrls;
    if (additionalInfo != null) body['additional_info'] = additionalInfo;

    return await _makeRequest(
      method: 'PUT',
      endpoint: '${ApiConfig.jobsEndpoint}/$id',
      body: body,
    );
  }

  Future<Map<String, dynamic>> deleteJob(String id) async {
    return await _makeRequest(
      method: 'DELETE',
      endpoint: '${ApiConfig.jobsEndpoint}/$id',
    );
  }

  // Apply to job
  Future<Map<String, dynamic>> applyJob(String jobId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.jobsEndpoint}/$jobId/apply',
    );
  }

  // Get user's applied jobs
  Future<Map<String, dynamic>> getMyAppliedJobs() async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '${ApiConfig.jobsEndpoint}/my-applications',
    );
  }

  // Get user's created jobs
  Future<Map<String, dynamic>> getMyCreatedJobs() async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '${ApiConfig.jobsEndpoint}/my-jobs',
    );
  }

  // Get jobs assigned to user (for workers)
  Future<Map<String, dynamic>> getMyAssignedJobs() async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '${ApiConfig.jobsEndpoint}/my-assigned-jobs',
    );
  }

  // Accept private order
  Future<Map<String, dynamic>> acceptPrivateOrder(String jobId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.jobsEndpoint}/$jobId/accept-private',
    );
  }

  // Reject private order
  Future<Map<String, dynamic>> rejectPrivateOrder(String jobId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.jobsEndpoint}/$jobId/reject-private',
    );
  }

  // Accept job application
  Future<Map<String, dynamic>> acceptApplication(String applicationId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/applications/$applicationId/accept',
    );
  }

  // Reject job application
  Future<Map<String, dynamic>> rejectApplication(String applicationId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/applications/$applicationId/reject',
    );
  }

  // Complete job
  Future<Map<String, dynamic>> completeJob(String jobId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.jobsEndpoint}/$jobId/complete',
    );
  }

  // Cancel job
  Future<Map<String, dynamic>> cancelJob(String jobId) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.jobsEndpoint}/$jobId/cancel',
    );
  }

  // Get job applications
  Future<Map<String, dynamic>> getJobApplications(String jobId) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '${ApiConfig.jobsEndpoint}/$jobId/applications',
    );
  }

  // SOS methods
  Future<Map<String, dynamic>> getSosRequests({
    String? status,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    Map<String, String> queryParams = {};

    if (status != null) queryParams['status'] = status;
    if (latitude != null) queryParams['latitude'] = latitude.toString();
    if (longitude != null) queryParams['longitude'] = longitude.toString();
    if (radius != null) queryParams['radius'] = radius.toString();

    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.sosEndpoint,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
  }

  Future<Map<String, dynamic>> createSosRequest({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    int? rewardAmount,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.sosEndpoint,
      body: {
        'title': title,
        'description': description,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'reward_amount': rewardAmount ?? 10000,
      },
    );
  }

  Future<Map<String, dynamic>> getSosRequest(String id) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '${ApiConfig.sosEndpoint}/$id',
    );
  }

  Future<Map<String, dynamic>> updateSosRequest({
    required String id,
    String? title,
    String? description,
    String? status,
    String? helperId,
  }) async {
    Map<String, dynamic> body = {};

    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (status != null) body['status'] = status;
    if (helperId != null) body['helper_id'] = helperId;

    return await _makeRequest(
      method: 'PUT',
      endpoint: '${ApiConfig.sosEndpoint}/$id',
      body: body.isNotEmpty ? body : null,
    );
  }

  Future<Map<String, dynamic>> respondToSos({
    required String sosId,
    required double latitude,
    required double longitude,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.sosEndpoint}/$sosId/respond',
      body: {'latitude': latitude, 'longitude': longitude},
    );
  }

  // Location methods
  Future<Map<String, dynamic>> updateLocation({
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: ApiConfig.updateLocationEndpoint,
      body: {'latitude': latitude, 'longitude': longitude, 'address': address},
    );
  }

  Future<Map<String, dynamic>> getNearbyUsers({
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.nearbyUsersEndpoint,
      queryParams: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
      },
    );
  }

  Future<Map<String, dynamic>> getNearbyJobs({
    required double latitude,
    required double longitude,
    required double radius,
    String? category,
  }) async {
    Map<String, String> queryParams = {
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'radius': radius.toString(),
    };

    if (category != null) queryParams['category'] = category;

    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.nearbyJobsEndpoint,
      queryParams: queryParams,
    );
  }

  Future<Map<String, dynamic>> getNearbySos({
    required double latitude,
    required double longitude,
    required double radius,
  }) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.nearbySosEndpoint,
      queryParams: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'radius': radius.toString(),
      },
    );
  }

  // Leaderboard methods
  Future<Map<String, dynamic>> getLeaderboard({
    String category = 'all',
    int limit = 20,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    // Gunakan endpoint protected jika ada token, atau fallback ke public
    final endpoint = _token != null ? '/leaderboard' : '/leaderboard-public';

    final queryParams = <String, String>{
      'category': category,
      'limit': limit.toString(),
    };

    // Add location parameters if provided (for "Area Sekitar" mode)
    if (latitude != null && longitude != null && radius != null) {
      queryParams['latitude'] = latitude.toString();
      queryParams['longitude'] = longitude.toString();
      queryParams['radius'] = radius.toString();
    }

    return await _makeRequest(
      method: 'GET',
      endpoint: endpoint,
      queryParams: queryParams,
    );
  }

  Future<Map<String, dynamic>> getUserRanking(String userId) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/leaderboard/user/$userId',
    );
  }

  // Notification methods
  Future<Map<String, dynamic>> getNotifications({
    int limit = 20,
    int offset = 0,
  }) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '/notifications',
      queryParams: {'limit': limit.toString(), 'offset': offset.toString()},
    );
  }

  Future<Map<String, dynamic>> markNotificationAsRead(
    String notificationId,
  ) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/notifications/mark-read',
      body: {'id': int.tryParse(notificationId) ?? notificationId},
    );
  }

  Future<Map<String, dynamic>> markAllNotificationsAsRead() async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/notifications/mark-all-read',
    );
  }

  // Address methods
  Future<Map<String, dynamic>> getAddresses() async {
    return await _makeRequest(method: 'GET', endpoint: '/addresses');
  }

  Future<Map<String, dynamic>> createAddress(
    Map<String, dynamic> addressData,
  ) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/addresses',
      body: addressData,
    );
  }

  Future<Map<String, dynamic>> updateAddress(
    String id,
    Map<String, dynamic> addressData,
  ) async {
    return await _makeRequest(
      method: 'PUT',
      endpoint: '/addresses/$id',
      body: addressData,
    );
  }

  Future<Map<String, dynamic>> deleteAddress(String id) async {
    return await _makeRequest(method: 'DELETE', endpoint: '/addresses/$id');
  }

  Future<Map<String, dynamic>> setDefaultAddress(String id) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/addresses/$id/set-default',
    );
  }

  // Admin endpoints
  Future<Map<String, dynamic>> getAdminDashboard() async {
    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.adminDashboardEndpoint,
    );
  }

  Future<Map<String, dynamic>> getAdminUsers({
    String? role,
    String? status,
    String? search,
    int page = 1,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (role != null) params['role'] = role;
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.adminUsersEndpoint,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> banUser(
    String userId, {
    int? durationDays,
    required String reason,
    bool isPermanent = false,
  }) async {
    final body = <String, dynamic>{
      'reason': reason,
      'is_permanent': isPermanent,
    };
    
    if (!isPermanent && durationDays != null) {
      body['duration_days'] = durationDays;
    }
    
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.adminUsersEndpoint}/$userId/ban',
      body: body,
    );
  }

  Future<Map<String, dynamic>> unbanUser(
    String userId, {
    String? reason,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.adminUsersEndpoint}/$userId/unban',
      body: reason != null && reason.isNotEmpty ? {'reason': reason} : null,
    );
  }

  Future<Map<String, dynamic>> getAdminJobs({
    String? status,
    String? search,
    int page = 1,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.adminJobsEndpoint,
      queryParams: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, dynamic>> forceCancelJob(
    String jobId, {
    required String reason,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.adminJobsEndpoint}/$jobId/force-cancel',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> getAdminSos({
    String? status,
    String? search,
    int page = 1,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;

    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.adminSosEndpoint,
      queryParams: params.isEmpty ? null : params,
    );
  }

  Future<Map<String, dynamic>> getAdminReviews({
    String? search,
    int page = 1,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (search != null && search.isNotEmpty) params['search'] = search;

    return await _makeRequest(
      method: 'GET',
      endpoint: ApiConfig.adminReviewsEndpoint,
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> deleteReview(
    String reviewId, {
    required String reason,
  }) async {
    return await _makeRequest(
      method: 'DELETE',
      endpoint: '${ApiConfig.adminReviewsEndpoint}/$reviewId',
      body: {'reason': reason},
    );
  }

  Future<Map<String, dynamic>> submitBanComplaint({
    required String email,
    required String reason,
    String? evidenceUrl,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/ban-complaints',
      body: {
        'email': email,
        'reason': reason,
        if (evidenceUrl != null && evidenceUrl.isNotEmpty)
          'evidence_url': evidenceUrl,
      },
    );
  }

  Future<Map<String, dynamic>> getAdminBanComplaints({
    String? status,
    String? search,
    int page = 1,
  }) async {
    final params = <String, String>{'page': page.toString()};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    if (search != null && search.isNotEmpty) params['search'] = search;

    return await _makeRequest(
      method: 'GET',
      endpoint: '/admin/ban-complaints',
      queryParams: params,
    );
  }

  Future<Map<String, dynamic>> handleBanComplaint(
    String complaintId, {
    required String status,
    String? adminNotes,
  }) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/admin/ban-complaints/$complaintId/handle',
      body: {
        'status': status,
        if (adminNotes != null && adminNotes.isNotEmpty)
          'admin_notes': adminNotes,
      },
    );
  }

  // Badge methods
  Future<Map<String, dynamic>> getUserBadges() async {
    return await _makeRequest(method: 'GET', endpoint: '/badges');
  }

  Future<Map<String, dynamic>> getAllBadges() async {
    return await _makeRequest(method: 'GET', endpoint: '/badges/all');
  }

  // Rating/Review methods
  Future<Map<String, dynamic>> submitRating({
    required String jobId,
    required String ratedUserId,
    required int rating,
    String? comment,
  }) async {
    // Use the correct endpoint: /jobs/{id}/review
    return await _makeRequest(
      method: 'POST',
      endpoint: '${ApiConfig.jobsEndpoint}/$jobId/review',
      body: {
        'rating': rating,
        if (comment != null && comment.isNotEmpty) 'comment': comment,
      },
    );
  }

  Future<Map<String, dynamic>> getWorkerReviews(String workerId) async {
    return await _makeRequest(
      method: 'GET',
      endpoint: '${ApiConfig.ratingsEndpoint}/worker/$workerId',
    );
  }

  Future<Map<String, dynamic>> getWorkerDetail(String workerId) async {
    return await _makeRequest(method: 'GET', endpoint: '/workers/$workerId');
  }

  /// Update FCM token di backend (user harus sudah login / punya token)
  Future<Map<String, dynamic>> updateFcmToken(String fcmToken) async {
    return await _makeRequest(
      method: 'POST',
      endpoint: '/fcm/token',
      body: {'fcm_token': fcmToken},
    );
  }
}

// Custom exception class untuk API errors
class ApiException implements Exception {
  final String message;
  final int statusCode;
  final Map<String, dynamic>? errors;
  final dynamic data;

  ApiException({
    required this.message,
    required this.statusCode,
    this.errors,
    this.data,
  });

  @override
  String toString() {
    return 'ApiException: $message (Status: $statusCode)';
  }
}

Future<void> sendTokenToBackend(String? token) async {
  if (token == null) return;

  final api = ApiService();
  // Pastikan auth token sudah dimuat (kalau user sudah pernah login)
  await api.loadToken();

  if (api.token == null) {
    // Belum login, jadi belum bisa kirim FCM token ke backend
    return;
  }

  try {
    await api.updateFcmToken(token);
  } on ApiException catch (e) {
    // Kalau gagal, cukup log saja (jangan crash app)
    print('Failed to update FCM token: $e');
  }
}
