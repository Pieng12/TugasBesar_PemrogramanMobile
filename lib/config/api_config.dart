class ApiConfig {
  // Base URL untuk API Laravel
  static const String baseUrl = 'https://teshosting-production.up.railway.app/api';
  // Base URL untuk storage (untuk akses file upload)
  static const String storageUrl = 'https://teshosting-production.up.railway.app/storage';

  // Endpoints
  static const String registerEndpoint = '/register';
  static const String loginEndpoint = '/login';
  static const String logoutEndpoint = '/logout';
  static const String userEndpoint = '/user';
  static const String profileEndpoint = '/profile';
  static const String updateProfileEndpoint = '/profile/update';

  // Jobs endpoints
  static const String jobsEndpoint = '/jobs';

  // SOS endpoints
  static const String sosEndpoint = '/sos';

  // Rating/Review endpoints
  static const String ratingsEndpoint = '/ratings';

  // Admin endpoints
  static const String adminDashboardEndpoint = '/admin/dashboard';
  static const String adminUsersEndpoint = '/admin/users';
  static const String adminJobsEndpoint = '/admin/jobs';
  static const String adminSosEndpoint = '/admin/sos';
  static const String adminReviewsEndpoint = '/admin/reviews';

  // Location endpoints
  static const String updateLocationEndpoint = '/locations/update';
  static const String nearbyUsersEndpoint = '/locations/nearby-users';
  static const String nearbyJobsEndpoint = '/locations/nearby-jobs';
  static const String nearbySosEndpoint = '/locations/nearby-sos';

  // Headers
  static Map<String, String> getHeaders({String? token}) {
    Map<String, String> headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // Error messages
  static const String networkError =
      'Network error. Please check your connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String unauthorizedError = 'Unauthorized. Please login again.';
  static const String notFoundError = 'Resource not found.';
  static const String validationError =
      'Validation error. Please check your input.';

  // Helper method to get full image URL from relative path
  static String getImageUrl(String? imagePath) {
    if (imagePath == null || imagePath.isEmpty) {
      return '';
    }

    // If already a full URL, return as is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    // Remove leading slash if exists
    String cleanPath = imagePath.startsWith('/')
        ? imagePath.substring(1)
        : imagePath;

    // Construct full URL
    return '$storageUrl/$cleanPath';
  }
}
